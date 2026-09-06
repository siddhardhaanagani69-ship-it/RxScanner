// ReminderService.swift
//
// Phase 6's calendar piece, using Apple's EventKit framework.
// Adds reminders for a medication, but ONLY after the user explicitly taps a
// button AND iOS shows its own permission prompt. We never write silently.
//
// It now RESPECTS the prescription:
//   - "for 7 days"          -> the daily reminder stops after 7 occurrences
//   - "three times a day"   -> creates 3 reminders per day at spread-out times
// Parsing is deliberately simple/robust: pull the numbers out of the strings.

import EventKit
import SwiftUI   // for withAnimation-free use; EventKit only strictly needed

struct ReminderService {
    static let store = EKEventStore()

    // Ask the user for calendar permission (iOS shows the system dialog).
    static func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    // Create reminders for one medication, beginning tomorrow.
    // Returns how many events it created (handy for showing feedback).
    @discardableResult
    static func addReminders(for med: Medication) throws -> Int {
        let perDay = timesPerDay(from: med.frequency)        // e.g. 1, 2, 3
        let days = numberOfDays(from: med.duration)          // e.g. 7  (nil-safe below)
        let hours = doseHours(count: perDay)                 // e.g. [8, 14, 20]

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        for hour in hours {
            let start = Calendar.current.date(
                bySettingHour: hour, minute: 0, second: 0, of: tomorrow)!

            let event = EKEvent(eventStore: store)
            event.title = "Take \(med.drug) \(med.dose)"
            event.notes = "\(med.frequency) for \(med.duration).\n\n\(med.insight)"
            event.startDate = start
            event.endDate = start.addingTimeInterval(15 * 60)   // 15-min block
            event.calendar = store.defaultCalendarForNewEvents

            // THE FIX: end the daily repeat after `days` occurrences instead of
            // never. If we couldn't read a duration, fall back to a safe 7 days.
            let end = EKRecurrenceEnd(occurrenceCount: days ?? 7)
            event.recurrenceRules = [
                EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: end)
            ]

            try store.save(event, span: .futureEvents)
        }
        return hours.count
    }

    // MARK: - Tiny parsers (turn messy text into numbers)

    /// "three times a day" / "2 times daily" / "twice daily" -> count.
    static func timesPerDay(from frequency: String) -> Int {
        let f = frequency.lowercased()
        // First try a written-out word.
        let words: [String: Int] = [
            "once": 1, "one": 1, "twice": 2, "two": 2,
            "three": 3, "thrice": 3, "four": 4
        ]
        for (word, n) in words where f.contains(word) { return n }
        // Otherwise grab the first digit (e.g. "3 times a day").
        if let digit = firstNumber(in: f) { return max(1, min(digit, 6)) }
        return 1   // default: once a day
    }

    /// "7 days" -> 7, "2 weeks" -> 14, "10 days" -> 10. nil if unreadable.
    static func numberOfDays(from duration: String) -> Int? {
        let d = duration.lowercased()
        guard let n = firstNumber(in: d) else { return nil }
        if d.contains("week") { return n * 7 }
        if d.contains("month") { return n * 30 }
        return n   // assume days
    }

    /// Spread N doses across waking hours.
    static func doseHours(count: Int) -> [Int] {
        switch count {
        case 1: return [9]
        case 2: return [9, 21]
        case 3: return [8, 14, 20]
        case 4: return [8, 12, 16, 20]
        default:
            // Evenly spread between 8:00 and 22:00 for 5+ doses.
            let span = 14.0 / Double(count - 1)
            return (0..<count).map { 8 + Int((Double($0) * span).rounded()) }
        }
    }

    /// First integer found in a string, if any.
    private static func firstNumber(in text: String) -> Int? {
        let digits = text.split(whereSeparator: { !$0.isNumber })
        return digits.first.flatMap { Int($0) }
    }
}
