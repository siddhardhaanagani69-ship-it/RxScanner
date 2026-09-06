// OCRService.swift  —  on-device OCR using Apple's Vision framework.
//
// This replaces Tesseract/pytesseract from Phase 2. Vision is Apple's built-in
// text recognizer: faster, more accurate on iOS, and fully on-device.
//
// Concept is identical to before: image in -> raw text out. Only the engine
// changed (Tesseract -> Vision).

import Vision
import UIKit

enum OCRError: Error { case noImage }

enum OCRService {
    /// Read printed text out of an image, returning it as plain text (one line
    /// per recognized line, top to bottom).
    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw OCRError.noImage }

        // The modern Swift Vision API (iOS 18+): make a request, perform it async.
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate        // slower but better quality
        request.usesLanguageCorrection = true

        // `observations` is one entry per detected line of text.
        let observations = try await request.perform(on: cgImage)

        // For each line, take Vision's best guess (topCandidates(1)).
        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        return lines.joined(separator: "\n")
    }
}
