// PrescriptionAnalyzer.swift  —  the full on-device brain (was pipeline.py).
//
//   image --(Vision OCR)--> text --(Foundation Models)--> meds
//        --(NaturalLanguage RAG + Foundation Models)--> grounded insight
//
// Everything runs on the phone. No server, no network, no Python.

import UIKit

enum PrescriptionAnalyzer {

    /// Run the whole pipeline on one image and return display-ready results.
    static func analyze(image: UIImage) async throws -> PrescriptionResult {
        // Phase 2: OCR
        let rawText = try await OCRService.recognizeText(in: image)

        // Phase 3: structured extraction
        let extracted = try await LLMService.extractMedications(from: rawText)

        // Phase 4: per-drug retrieval + grounded insight
        var meds: [Medication] = []
        for e in extracted {
            let facts = RAGService.shared.retrieve(
                "What is \(e.drug) and what are its key safety points?")
            let insight = (try? await LLMService.groundedInsight(for: e.drug, facts: facts))
                ?? "No information available."
            meds.append(Medication(
                drug: e.drug, dose: e.dose, frequency: e.frequency,
                duration: e.duration, insight: insight))
        }

        return PrescriptionResult(rawText: rawText, medications: meds)
    }
}
