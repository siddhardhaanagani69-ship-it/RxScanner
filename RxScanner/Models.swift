// Models.swift  —  display types for the UI.
//
// We no longer decode JSON from a server, so these are plain Swift structs the
// on-device pipeline fills in directly. `Identifiable` lets SwiftUI list them.

import Foundation

struct Medication: Identifiable {
    let id = UUID()
    let drug: String
    let dose: String
    let frequency: String
    let duration: String
    let insight: String
}

struct PrescriptionResult {
    let rawText: String
    let medications: [Medication]
}
