// ContentView.swift
//
// The single screen of the app, in SwiftUI. Flow:
//   1. Pick/take a photo of a prescription.
//   2. Upload it to your API (Phase 5) and show a spinner while it works.
//   3. Show the SCANNED TEXT and extracted meds so the user can VERIFY.   <-- safety
//   4. Only then offer "Add reminders to Calendar" (with consent).
//
// This file is ONLY the look & feel. Networking (APIClient), data shapes
// (Models) and calendar (ReminderService) live in the other files, untouched.

import SwiftUI
import PhotosUI

// A small palette so colors are consistent and easy to tweak in one place.
enum Theme {
    static let accent = Color(red: 0.18, green: 0.55, blue: 0.55)   // calm teal
    static let accentSoft = Color(red: 0.18, green: 0.55, blue: 0.55).opacity(0.12)
    static let bgTop = Color(red: 0.93, green: 0.97, blue: 0.97)
    static let bgBottom = Color(red: 0.88, green: 0.93, blue: 0.95)
}

struct ContentView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var result: PrescriptionResult?
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            // Soft gradient backdrop instead of flat white.
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    scanButton

                    if let image {
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(.white, lineWidth: 3)
                            )
                    }

                    if isLoading { loadingCard }
                    if let errorText { errorCard(errorText) }

                    if let result {
                        resultsSection(result)
                    } else if image == nil && !isLoading {
                        emptyState
                    }
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .onChange(of: pickedItem) { _, newItem in
            Task { await handlePick(newItem) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("Rx Scanner").font(.title2.bold())
                Text("Scan • Understand • Remind")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Scan button (the PhotosPicker, restyled)

    private var scanButton: some View {
        PhotosPicker(selection: $pickedItem, matching: .images) {
            HStack {
                Image(systemName: "camera.viewfinder").font(.headline)
                Text(result == nil ? "Scan a prescription" : "Scan another")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: Theme.accent.opacity(0.4), radius: 8, y: 4)
        }
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent.opacity(0.7))
            Text("No scan yet")
                .font(.headline)
            Text("Tap “Scan a prescription” and choose a clear photo. Your meds and plain-language insights will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.3).tint(Theme.accent)
            Text("Analyzing on your iPhone…")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("OCR → reading meds → grounding insights")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func errorCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.orange)
            Text(text).font(.subheadline)
            Spacer()
        }
        .padding()
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Results

    private func resultsSection(_ result: PrescriptionResult) -> some View {
        VStack(spacing: 16) {
            // Medication count summary
            HStack {
                Text("\(result.medications.count) medication\(result.medications.count == 1 ? "" : "s") found")
                    .font(.headline)
                Spacer()
            }

            ForEach(result.medications) { med in
                MedicationCard(med: med)
            }

            // Scanned text — collapsed, so users can verify the OCR.
            DisclosureGroup {
                Text(result.rawText)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } label: {
                Label("View scanned text", systemImage: "doc.plaintext")
                    .font(.subheadline.weight(.medium))
            }
            .tint(Theme.accent)
            .padding()
            .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))

            disclaimer
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("This is an assistant, not medical advice. Always verify the scanned text and confirm with a doctor or pharmacist before relying on it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Logic (unchanged behaviour)

    private func handlePick(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        image = uiImage
        result = nil
        errorText = nil
        isLoading = true
        defer { isLoading = false }

        do {
            // Fully on-device now: OCR + LLM + RAG all run on the phone.
            result = try await PrescriptionAnalyzer.analyze(image: uiImage)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Medication card

struct MedicationCard: View {
    let med: Medication
    @State private var added = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title row: pill icon + drug name + dose badge
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "pills.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accentSoft, in: Circle())

                Text(med.drug)
                    .font(.title3.bold())

                Spacer()

                if !med.dose.isEmpty {
                    Text(med.dose)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.accentSoft, in: Capsule())
                }
            }

            // Schedule row
            HStack(spacing: 16) {
                if !med.frequency.isEmpty {
                    Label(med.frequency, systemImage: "clock")
                }
                if !med.duration.isEmpty {
                    Label(med.duration, systemImage: "calendar")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Grounded insight, in its own subtle box
            Text(med.insight)
                .font(.footnote)
                .foregroundStyle(.primary.opacity(0.8))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10))

            // Consent-gated reminder button with a little success animation
            Button {
                Task { await addReminder() }
            } label: {
                HStack {
                    Image(systemName: added ? "checkmark.circle.fill" : "calendar.badge.plus")
                    Text(added ? "Reminder added" : "Add daily reminder")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(added ? .green : Theme.accent)
                .background((added ? Color.green : Theme.accent).opacity(0.12),
                           in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(added)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private func addReminder() async {
        guard await ReminderService.requestAccess() else { return }
        // Creates the right number of daily reminders, ending after the
        // prescribed duration (no more "forever" events).
        try? ReminderService.addReminders(for: med)
        withAnimation(.spring) { added = true }
    }
}

#Preview {
    ContentView()
}
