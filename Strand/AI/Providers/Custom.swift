import Foundation
import StrandAnalytics

/// A generic OpenAI-compatible provider pointed at a user-set base URL — e.g. a local LLM server such
/// as Ollama, LM Studio or llama.cpp (`http://localhost:11434/v1`), or any self-hosted gateway. Speaks
/// the OpenAI chat-completions wire format against `AIProvider.custom` endpoints. The API key is
/// optional — local servers usually need none — so the configured auth header is sent only when set.
struct CustomClient: AIProviderClient {

    func send(
        key: String,
        model: String,
        systemPrompt: String,
        messages: [(role: ChatMessage.Role, content: String)],
        session: URLSession
    ) async throws -> String {
        try AIProvider.guardCustomBaseURL()   // #321: reject a public cleartext Custom URL before egress
        var wire: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for m in messages { wire.append(["role": m.role.rawValue, "content": m.content]) }

        // Standard params first. Some OpenAI-compatible servers (reasoning models behind a gateway)
        // reject `temperature`/`max_tokens` and want `max_completion_tokens`; retry on that 400.
        do {
            return try await chat(key: key, model: model, wire: wire, modernParams: false, session: session)
        } catch let AICoachError.server(code, detail) where code == 400 {
            let d = detail.lowercased()
            if d.contains("max_completion_tokens") || d.contains("max_tokens")
                || d.contains("temperature") || d.contains("unsupported") {
                return try await chat(key: key, model: model, wire: wire, modernParams: true, session: session)
            }
            throw AICoachError.server(code, detail)
        }
    }

    /// K1: Stream via `stream: true` (most local OpenAI-compatible servers support it). Same body
    /// as `send`'s standard-params path, with `stream: true`. SSE parsing via `SseDeltas.openAiDelta`.
    /// The modern-params retry on 400 is NOT streamed (rare path; falls back to `send`'s retry).
    func stream(
        key: String,
        model: String,
        systemPrompt: String,
        messages: [(role: ChatMessage.Role, content: String)],
        session: URLSession,
        onDelta: (String) -> Void
    ) async throws {
        try AIProvider.guardCustomBaseURL()   // #321: reject a public cleartext Custom URL before egress
        var wire: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for m in messages { wire.append(["role": m.role.rawValue, "content": m.content]) }

        let body: [String: Any] = [
            "model": model,
            "messages": wire,
            "temperature": 0.6,
            "max_tokens": 4096,
            "stream": true
        ]

        var req = URLRequest(url: AIProvider.custom.endpoint)
        req.httpMethod = "POST"
        AIProvider.applyCustomAuthHeader(key, to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        try await performStreamingRequest(req, session: session) { payload in
            if let delta = SseDeltas.openAiDelta(payload) {
                onDelta(delta)
            }
        }
    }

    /// Appended to a reply when the server stopped early because it ran out of context window.
    /// Local OpenAI-compatible servers (notably Ollama, which defaults to a 2048-token window and
    /// IGNORES `num_ctx` on the `/v1` endpoint) truncate silently — no error, the text just stops
    /// mid-sentence. We can't raise the window over the OpenAI wire format, so we make the cutoff
    /// visible and tell the user exactly how to fix it.
    /// The cut-off note, keyed on whether the server is actually local.
    ///
    /// Upstream #1074 collapsed this to one provider-agnostic message because a DeepSeek-via-gateway user
    /// was shown Ollama advice that named a cause that was not theirs. This fork fixes the same bug the
    /// other way: it keys the message on `isLocalServer`, so a genuinely local server still gets the
    /// actionable `num_ctx` instruction instead of losing it, and a hosted one never sees it.
    static func truncationNote(isLocalServer: Bool) -> String {
        let head = "\n\n---\n*Reply cut off: the model stopped at a length limit. "
        if isLocalServer {
            return head + "On a local server like Ollama (default context 2048 tokens), raise it - "
                + "create a Modelfile with `PARAMETER num_ctx 8192` and select that model, or set "
                + "`OLLAMA_CONTEXT_LENGTH=8192` and relaunch Ollama - then ask again.*"
        }
        return head + "That's usually the reply length rather than the context window: ask a narrower "
            + "question, or pick a model with a higher output limit.*"
    }

    /// Whether the Custom base URL points at this machine or its own LAN — the only case where the
    /// Ollama advice above applies. Reuses the same classifier as the cleartext guard, so "local" means
    /// exactly one thing across this file.
    static var isLocalCustomServer: Bool {
        guard let host = URLComponents(string: AIProvider.customBaseURL)?.host else { return false }
        return AIProvider.isPrivateLANOrLoopback(host)
    }

    /// Pure: unwrap an OpenAI-compatible chat-completions body into the assistant text. Appends
    /// `truncationNote` when the server stopped early (`finish_reason == "length"`) so a context-
    /// window cutoff is never silent. No network — unit-tested.
    /// `isLocalServer` is passed IN rather than read from UserDefaults so this stays pure and unit-
    /// testable without a configured app. Callers use `Self.isLocalCustomServer`.
    func parseChatContent(_ json: [String: Any], isLocalServer: Bool = Self.isLocalCustomServer) throws -> String {
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = (message["content"] as? String)?
                  .trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw emptyReplyError(json)   // #1074: surface the provider's real error if the 200 body has one
        }
        if (first["finish_reason"] as? String)?.lowercased() == "length" {
            return content + Self.truncationNote(isLocalServer: isLocalServer)
        }
        return content
    }

    func fetchModels(key: String, session: URLSession) async throws -> [String] {
        try AIProvider.guardCustomBaseURL()   // #321: reject a public cleartext Custom URL before egress
        var req = URLRequest(url: AIProvider.custom.modelsEndpoint)
        req.httpMethod = "GET"
        AIProvider.applyCustomAuthHeader(key, to: &req)

        return parseModels(try await performRequest(req, session: session))
    }

    /// Pure: unwrap an OpenAI-compatible `/models` body into ids. Unlike OpenAI we keep *all* ids.
    /// Some enterprise gateways return a catalog (`catalog[].models`) rather than `data[].id`; keep
    /// those ids too so users do not have to type every supported model by hand.
    func parseModels(_ json: [String: Any]) -> [String] {
        if let list = json["data"] as? [[String: Any]] {
            return list.compactMap { row in
                guard let id = row["id"] as? String, !id.isEmpty else { return nil }
                return id
            }
        }
        guard let catalog = json["catalog"] as? [[String: Any]] else { return [] }
        var seen = Set<String>()
        return catalog.flatMap { row -> [String] in
            guard let models = row["models"] as? [String] else { return [] }
            return models.filter { !$0.isEmpty }
        }.filter { id in
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
    }

    // MARK: Private

    /// `modernParams`: use `max_completion_tokens`, drop `temperature` — for gateways fronting
    /// reasoning models. The auth header is omitted when `key` is empty (local servers).
    private func chat(
        key: String,
        model: String,
        wire: [[String: Any]],
        modernParams: Bool,
        session: URLSession
    ) async throws -> String {
        var body: [String: Any] = ["model": model, "messages": wire]
        // #1074: 900 truncated detailed coaching replies mid-sentence on cloud providers; 4096 lets a
        // full multi-section reply complete (a cap, not a target). Matches the Gemini leg + Android.
        if modernParams {
            body["max_completion_tokens"] = 4096
        } else {
            body["temperature"] = 0.6
            body["max_tokens"] = 4096
        }

        var req = URLRequest(url: AIProvider.custom.endpoint)
        req.httpMethod = "POST"
        AIProvider.applyCustomAuthHeader(key, to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await performRequest(req, session: session)
        return try parseChatContent(json)
    }
}
