// RAGService.swift  —  on-device retrieval, using Apple's NaturalLanguage.
//
// This is your hand-built RAG from Phase 4, ported to Swift:
//   PREPARE:   embed every drug fact once -> store (text, vector) pairs
//   RETRIEVE:  embed the query -> cosine-compare to all facts -> top K
//
// nomic-embed-text (Ollama) is replaced by NLEmbedding.sentenceEmbedding,
// Apple's on-device sentence embedder. The math (cosine similarity) is the same.

import NaturalLanguage

final class RAGService {
    static let shared = RAGService()

    private let embedder = NLEmbedding.sentenceEmbedding(for: .english)
    private var store: [(fact: String, vector: [Double])] = []

    private init() {
        // PREPARE: embed each fact once when the service is created.
        if let embedder {
            store = DrugDatabase.facts.compactMap { fact in
                guard let vec = embedder.vector(for: fact) else { return nil }
                return (fact, vec)
            }
        }
    }

    /// Cosine similarity: 1.0 = same direction/meaning, 0.0 = unrelated.
    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom == 0 ? 0 : dot / denom
    }

    /// RETRIEVE: the `topK` facts most similar in meaning to `query`.
    func retrieve(_ query: String, topK: Int = 3) -> [String] {
        guard let embedder, let qVec = embedder.vector(for: query) else { return [] }
        return store
            .map { (cosine(qVec, $0.vector), $0.fact) }
            .sorted { $0.0 > $1.0 }          // highest similarity first
            .prefix(topK)
            .map { $0.1 }
    }
}
