// LLMService.swift  —  on-device LLM using Apple's Foundation Models.
//
// Replaces Ollama/llama3.2 from Phases 3 & 4. Two jobs:
//   1. extractMedications: messy OCR text -> structured medications
//   2. groundedInsight:    drug + retrieved facts -> plain-language summary
//
// `@Generable` is Apple's version of your format="json" trick: you describe a
// Swift type, and the model is forced to fill it in -- no manual JSON parsing.
//
// REQUIRES: an Apple Intelligence-capable iPhone (15 Pro / 16+) with the
// feature enabled, OR a supported Simulator. We check availability first.

import Foundation
import FoundationModels

enum LLMError: Error, LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        if case .unavailable(let why) = self { return why }
        return "Language model unavailable."
    }
}

// The shape we want extracted. @Guide gives the model hints per field --
// the Swift equivalent of describing the JSON schema in a prompt.
@Generable
struct ExtractedMedications {
    @Guide(description: "Every medication written in the prescription.")
    let medications: [ExtractedMedication]
}

@Generable
struct ExtractedMedication {
    @Guide(description: "The drug name only, e.g. Amoxicillin.")
    let drug: String
    @Guide(description: "The dose with units, e.g. 500mg. Empty string if absent.")
    let dose: String
    @Guide(description: "How often to take it, e.g. three times a day. Empty if absent.")
    let frequency: String
    @Guide(description: "How long to take it for, e.g. 7 days. Empty if absent.")
    let duration: String
}

enum LLMService {

    /// Is the on-device model usable right now? Returns nil if OK, else a reason.
    static func availabilityProblem() -> String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This iPhone doesn't support Apple Intelligence (needs iPhone 15 Pro or newer)."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to use on-device analysis."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading. Try again shortly."
        case .unavailable:
            return "The on-device language model is currently unavailable."
        }
    }

    // Phase 3, on-device: structured extraction.
    static func extractMedications(from rawText: String) async throws -> [ExtractedMedication] {
        if let problem = availabilityProblem() { throw LLMError.unavailable(problem) }

        let session = LanguageModelSession(instructions: """
            You extract medication details from messy prescription text.
            Only include medications that actually appear in the text.
            Do not invent anything. Use empty strings for missing fields.
            """)

        // `generating:` forces the reply to fit ExtractedMedications.
        let response = try await session.respond(
            to: rawText,
            generating: ExtractedMedications.self
        )
        return response.content.medications
    }

    // Phase 4, on-device: grounded insight from retrieved facts only.
    static func groundedInsight(for drug: String, facts: [String]) async throws -> String {
        if let problem = availabilityProblem() { throw LLMError.unavailable(problem) }

        let context = facts.map { "- \($0)" }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
            You summarize reference information about a medicine for a patient,
            in 2-3 short sentences. Use ONLY the reference facts provided. If the
            facts do not mention the drug, say you have no information on it.
            Never use outside knowledge.

            REFERENCE FACTS:
            \(context)
            """)

        let response = try await session.respond(to: "Summarize the facts about \(drug).")
        return response.content
    }
}
