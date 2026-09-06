// DrugDatabase.swift  —  the trusted "source of truth" for RAG, on-device.
//
// Direct port of drug_database.py. Each string is one small, self-contained
// fact ("chunk"). RAG will embed these and retrieve the relevant ones to
// ground the LLM's insights -- so it never invents drug information.

enum DrugDatabase {
    static let facts: [String] = [
        "Amoxicillin is a penicillin-type antibiotic used to treat bacterial infections such as chest, ear, and throat infections. It does not work against viruses like the common cold.",
        "Common side effects of amoxicillin include nausea, diarrhea, and skin rash. Anyone with a penicillin allergy must not take it.",
        "Amoxicillin is usually taken with or without food. Complete the full course even if you feel better, to avoid the infection returning.",
        "Ibuprofen is a non-steroidal anti-inflammatory drug (NSAID) used to relieve pain, reduce inflammation, and lower fever.",
        "Ibuprofen should be taken with food or milk to reduce the risk of stomach upset or irritation. Long-term use can harm the stomach and kidneys.",
        "Ibuprofen should be used with caution by people with stomach ulcers, kidney problems, or asthma, and is generally avoided in late pregnancy.",
        "Paracetamol (acetaminophen) relieves pain and reduces fever. It is gentler on the stomach than ibuprofen but overdosing can cause serious liver damage.",
        "Metformin is used to control blood sugar in type 2 diabetes. Common side effects include nausea and diarrhea, usually improving over time.",
        "Amoxicillin and ibuprofen can generally be taken together, but always confirm with a pharmacist, especially if other medicines are involved.",
    ]
}
