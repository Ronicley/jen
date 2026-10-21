import Foundation
import Vision
import ImageIO

/// Shared on-device OCR. Position is used to rebuild receipt rows before parsing.
enum TextRecognizer {
    static func recognize(_ data: Data) async throws -> RecognizedPage {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let supported = try request.supportedRecognitionLanguages()
            let preferred = ["pt-BR", "pt-PT", "en-US"].filter { supported.contains($0) }
            if !preferred.isEmpty { request.recognitionLanguages = preferred }
            request.automaticallyDetectsLanguage = true
            let source = CGImageSourceCreateWithData(data as CFData, nil)
            let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
            let orientation = CGImagePropertyOrientation(rawValue: (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1) ?? .up
            try VNImageRequestHandler(data: data, orientation: orientation).perform([request])
            let observations = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            var rows: [[VNRecognizedTextObservation]] = []
            for observation in observations {
                if let index = rows.indices.last, let anchor = rows[index].first,
                   abs(anchor.boundingBox.midY - observation.boundingBox.midY) < min(anchor.boundingBox.height, observation.boundingBox.height) * 0.5 {
                    rows[index].append(observation)
                } else { rows.append([observation]) }
            }
            let lines = rows.compactMap { row -> RecognizedLine? in
                let candidates = row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }.compactMap { $0.topCandidates(1).first }
                guard !candidates.isEmpty else { return nil }
                return RecognizedLine(text: candidates.map(\.string).joined(separator: " "), confidence: candidates.map(\.confidence).min() ?? 0)
            }
            guard !lines.isEmpty else { throw JenError("Nenhum texto legível. Tente uma foto mais próxima, bem iluminada e sem reflexos.") }
            return RecognizedPage(lines: lines)
        }.value
    }
}
enum LabelRecognizer {
    static func recognize(_ data: Data) async throws -> LabelReading {
        let page = try await TextRecognizer.recognize(data)
        return LabelParser.parse(page.lines.map(\.text))
    }
}
