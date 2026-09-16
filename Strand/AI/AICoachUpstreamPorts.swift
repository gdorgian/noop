//  AICoachUpstreamPorts.swift
//  NOOP · Noop Aura
//
//  Capabilities ported from ryanbr/noop v11.7 (45ee2fb76) onto Noop Aura's coach engine.
//
//  WHY THIS FILE EXISTS. Upstream's engine and this fork's engine diverged: upstream keeps ONE flat
//  `messages` transcript persisted to SQLite, while this fork keeps many `CoachConversation`s persisted
//  to a file via `CoachTranscriptStore`. Several upstream features are genuinely new and worth having,
//  but a straight copy would have fought that difference — its transcript loader reads a table this
//  fork does not write, and its "clear" empties a list this fork does not own.
//
//  So each port below keeps upstream's INTENT and re-expresses it in this engine's architecture. Where
//  a port is an adaptation rather than a copy, the comment says so and says why. Everything here is
//  additive: no existing Aura behaviour changes, and every default preserves the current reading.
//
//  Upstream is PolyForm Noncommercial 1.0.0, the same licence this repository carries; attribution to
//  ryanbr/noop is retained here and in ATTRIBUTION.md.

import Foundation
import StrandAnalytics

extension AICoachEngine {

    // MARK: - Suggestion chips

    /// Contextual chips for the composer, derived from the wearer's own bands — no network, no model
    /// call, and nothing that is not already on device.
    var suggestions: [String] {
        CoachSuggestions.suggestions(for: repo.days.last, recent: repo.days)
    }

    /// Generic conversational follow-ups offered after an assistant reply, so the wearer can dig deeper
    /// without typing. Deliberately NOT data-derived: these say nothing about the person's readings, so
    /// they are safe to show before any data has loaded.
    static let followUpSuggestions: [String] = [
        "Tell me more about that",
        "What should I do next?",
        "How does today compare to this week?",
        "Give me a specific action plan",
    ]

    // MARK: - Draft cost estimate

    /// A rough token estimate for the next send, on the standard ~4-chars-per-token heuristic.
    ///
    /// An ESTIMATE only — real counts vary by tokenizer. Deliberately does not build the full data
    /// context, because this runs on every keystroke and the real context costs a database read; the
    /// consent-dependent constant below stands in for it. Returns nil when the engine is not configured,
    /// which is also the state in which there is no context to estimate.
    func estimatedTokens(forDraft draft: String) -> Int? {
        guard isConfigured else { return nil }
        let systemPromptTokens = systemPrompt(toolsActive: false).count / 4
        // The data context is typically ~3000 chars with consent on, a stub without it.
        let contextTokens = dataConsent ? 750 : 50
        // History as the provider will actually see it, so the estimate tracks the same window the
        // request is built from rather than the whole transcript.
        let windowed = Self.windowedMessages(
            messages,
            budgetTokens: CoachHistoryBudget.tokens(provider: provider, model: model))
        let historyTokens = windowed.reduce(0) { $0 + $1.text.count / 4 }
        return systemPromptTokens + contextTokens + historyTokens + draft.count / 4
    }

    // MARK: - Daily conversation retirement

    /// The local-calendar day index for `date`, counted from the Unix epoch.
    ///
    /// Local, not UTC: a conversation should retire when the wearer's own day turns over, not when
    /// Greenwich's does. `nonisolated` and calendar-injectable so the rule is unit-testable with no
    /// engine, no store and no clock of its own.
    nonisolated static func localEpochDay(_ date: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let epoch = Date(timeIntervalSince1970: 0)
        return calendar.dateComponents([.day], from: epoch, to: start).day ?? 0
    }

    /// Whether a conversation last written on `lastEpochDay` belongs to a day that has since turned over.
    ///
    /// A nil `lastEpochDay` is NOT stale by design: nothing has been said yet, and a conversation with no
    /// turns in it cannot be out of date.
    nonisolated static func isStaleConversation(lastEpochDay: Int?, todayEpochDay: Int) -> Bool {
        guard let lastEpochDay else { return false }
        return todayEpochDay > lastEpochDay
    }

    /// Retire the visible conversation if its last turn was on an earlier local day (#2087).
    ///
    /// ADAPTED, not copied. Upstream restores a flat transcript out of SQLite here and declines to
    /// restore a stale one; this fork has already restored its conversations from `CoachTranscriptStore`
    /// by the time any screen appears, so there is nothing left to load. What upstream was really buying
    /// with that code is the part this fork lacked: yesterday's chat should not silently continue into
    /// today. So this retires by starting a NEW conversation rather than by withholding a load.
    ///
    /// Nothing is deleted: the old conversation stays in the list, titled and searchable like any other.
    /// Safe to call on every appear — it is a no-op on the same day, and on an empty conversation.
    func retireConversationIfFromAnEarlierDay() {
        guard let active = activeConversation,
              let last = active.messages.last else { return }
        let lastDay = Self.localEpochDay(last.date)
        guard Self.isStaleConversation(lastEpochDay: lastDay,
                                       todayEpochDay: Self.localEpochDay()) else { return }
        newConversation()
    }

    /// Upstream's name for the call above, kept so ported screens compile unchanged.
    func loadPersistedMessagesIfNeeded() async {
        retireConversationIfFromAnEarlierDay()
    }

    /// Upstream's "clear the chat" entry point. This fork retires rather than erases — `newConversation`
    /// starts a fresh thread and leaves the old one in the list, which is the behaviour the conversation
    /// list depends on.
    func clearConversation() {
        newConversation()
    }

    // MARK: - Model catalogue staleness

    /// UserDefaults key holding when this provider's catalogue was last pulled. Per-provider, so one
    /// provider's stale list is never hidden behind another's refresh.
    static func modelsRefreshedKey(_ provider: AIProvider) -> String {
        "ai.modelsRefreshed.\(provider.rawValue)"
    }

    /// How long a pulled catalogue is trusted before another pull is due.
    static let modelRefreshInterval: TimeInterval = 7 * 24 * 60 * 60

    /// Whether a catalogue last pulled at `last` is due another pull at `now`. Pure, so the rule is
    /// testable without a clock or a network.
    static func isCatalogueStale(last: TimeInterval, now: TimeInterval) -> Bool {
        now - last >= modelRefreshInterval
    }

    /// Refresh the model catalogue only when the stored one has aged out.
    ///
    /// Skips `.custom` entirely: a self-hosted endpoint has no catalogue to pull, and asking one for a
    /// model list is how a local server gets an unexpected request it never advertised.
    func refreshModelsIfStale() async {
        guard provider != .custom, hasKey else { return }
        let last = UserDefaults.standard.double(forKey: Self.modelsRefreshedKey(provider))
        guard Self.isCatalogueStale(last: last, now: Date().timeIntervalSince1970) else { return }
        await refreshModels()
        UserDefaults.standard.set(Date().timeIntervalSince1970,
                                  forKey: Self.modelsRefreshedKey(provider))
    }

    // MARK: - Scheduled daily brief

    /// The heading a generated brief is filed under, so the brief reads as a brief and not as the coach
    /// spontaneously talking.
    static let briefHeading = "Today's brief"

    /// File a generated brief into the visible conversation. Used by the settings screen's "generate
    /// now", where the wearer asked for it explicitly and a brief already on screen is not a reason to
    /// withhold another.
    func appendGeneratedBrief(_ text: String) {
        appendMessage(ChatMessage(role: .assistant, text: "\(Self.briefHeading)\n\n" + text))
    }

    /// Surface a SCHEDULED brief — one the wearer did not ask for just now.
    ///
    /// Only into an empty conversation, which is the whole difference from `appendGeneratedBrief`: an
    /// unprompted brief may open a day, but it must never interrupt a conversation already in progress
    /// by appearing underneath something the wearer just asked.
    func surfaceScheduledBrief(_ text: String) {
        guard messages.isEmpty else { return }
        appendMessage(ChatMessage(role: .assistant, text: "\(Self.briefHeading)\n\n" + text))
    }
}
