//
//  CheckClipboardIntent.swift
//  Pangram iOS Tools (Unofficial)
//
//  Created by David Hacker on 7/11/26.
//

import AppIntents
import UIKit

struct CheckClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Text with Pangram"
    static var description = IntentDescription(
        "Runs Pangram AI detection on the provided text.")

    @Parameter(title: "Text")
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "No text provided — copy some text first.")
        }
        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        guard words >= 50 else {
            return .result(dialog: "Pangram needs at least 50 words (\(words) provided).")
        }
        guard let key = UserDefaults(suiteName: "group.davidhacker.pangram")?
                .string(forKey: "pangramAPIKey"), !key.isEmpty else {
            return .result(dialog: "Open the Pangram app and save your API key first.")
        }
        let r = try await Pangram.check(trimmed, apiKey: key)
        let pct = Int((r.fractionAI * 100).rounded())
        return .result(dialog: "\(r.prediction) — \(pct)% AI")
    }
}

struct PangramShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckClipboardIntent(),
            phrases: [
                "Check my clipboard with \(.applicationName)",
                "Run \(.applicationName) on my clipboard"
            ],
            shortTitle: "Check Copied Text",
            systemImageName: "text.magnifyingglass"
        )
    }
}
