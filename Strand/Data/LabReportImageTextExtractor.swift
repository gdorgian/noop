import Foundation

#if canImport(Vision)
import Vision
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// On-device OCR for a user-selected report photo. The recognised text follows the same narrow,
/// review-required parser as a text PDF. No image, OCR text, file name or path is persisted.
enum LabReportImageTextExtractor {
    struct RecognizedLine: Sendable, Equatable {
        let text: String
        let confidence: Float
        /// Vision-normalized image coordinates. The origin is at the lower-left.
        let boundingBox: CGRect
    }

    enum ExtractionError: LocalizedError {
        case unreadable
        case tooLarge
        case noText

        var errorDescription: String? {
            switch self {
            case .unreadable: return "This image couldn't be opened on this device."
            case .tooLarge: return "This image is too large to read locally."
            case .noText: return "No readable text was found in this image."
            }
        }
    }

    static let maxPixels = 24_000_000

    static func text(from url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        let text = try await observations(from: data).map(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ExtractionError.noText }
        return text
    }

    /// Returns each recognised source line with the rect it occupied on the original image. Keeping
    /// the observation intact is what lets review show a real crop rather than redrawing OCR text.
    static func observations(from data: Data) async throws -> [RecognizedLine] {
        try await Task.detached(priority: .userInitiated) {
            let source = try imageSource(from: data)
            guard source.image.width * source.image.height <= maxPixels else {
                throw ExtractionError.tooLarge
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(
                cgImage: source.image,
                orientation: source.orientation,
                options: [:]
            )
            try handler.perform([request])

            let lines = (request.results ?? []).compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return RecognizedLine(
                    text: text,
                    confidence: candidate.confidence,
                    boundingBox: observation.boundingBox
                )
            }
            guard !lines.isEmpty else { throw ExtractionError.noText }
            return lines
        }.value
    }

    private static func imageSource(from data: Data) throws -> (
        image: CGImage,
        orientation: CGImagePropertyOrientation
    ) {
        #if os(iOS)
        guard let uiImage = UIImage(data: data), let image = uiImage.cgImage else {
            throw ExtractionError.unreadable
        }
        return (image, CGImagePropertyOrientation(uiImage.imageOrientation))
        #elseif os(macOS)
        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { throw ExtractionError.unreadable }
        return (cgImage, .up)
        #else
        throw ExtractionError.unreadable
        #endif
    }
}

#if os(iOS)
private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
#endif
