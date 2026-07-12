import SwiftUI
import UIKit

struct ContentView: View {
    @State private var apiKey = ""
    @State private var saved = false
    @State private var showKey = false
    @State private var checking = false
    @State private var result = ""
    @State private var resultColor = Color.secondary
    private let store = UserDefaults(suiteName: "group.davidhacker.pangram")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(checking ? "Checking…" : "Check copied text") {
                        Task { await checkClipboard() }
                    }
                    .disabled(checking)
                    if !result.isEmpty {
                        Text(result)
                            .foregroundStyle(resultColor)
                            .font(.callout)
                    }
                } footer: {
                    Text("For apps without a Share option (X, Messages): copy the text there, then check it here — or assign the “Check Copied Text” shortcut to Back Tap (Settings → Accessibility → Touch → Back Tap).")
                }

                Section {
                    HStack {
                        Group {
                            if showKey {
                                TextField("Pangram API key", text: $apiKey)
                            } else {
                                SecureField("Pangram API key", text: $apiKey)
                            }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    Button(saved ? "Saved ✓" : "Save") {
                        store?.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                                   forKey: "pangramAPIKey")
                        saved = true
                    }
                } footer: {
                    Text("Get a key at pangram.com → API tab. Then select text anywhere and use Share → Check with Pangram.")
                }
            }
            .navigationTitle("Pangram")
            .onAppear { apiKey = store?.string(forKey: "pangramAPIKey") ?? "" }
            .onChange(of: apiKey) { saved = false }
        }
    }

    private func checkClipboard() async {
        guard let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result = "Clipboard is empty"
            resultColor = .secondary
            return
        }
        let words = text.split(whereSeparator: \.isWhitespace).count
        guard words >= 50 else {
            result = "Pangram needs 50+ words (\(words) copied)"
            resultColor = .secondary
            return
        }
        let key = store?.string(forKey: "pangramAPIKey") ?? ""
        guard !key.isEmpty else {
            result = "Save your API key below first"
            resultColor = .secondary
            return
        }
        checking = true
        defer { checking = false }
        do {
            let r = try await Pangram.check(text, apiKey: key)
            let pct = Int((r.fractionAI * 100).rounded())
            result = "\(r.prediction) — \(pct)% AI"
            resultColor = r.fractionAI >= 0.5 ? .orange : .green
        } catch {
            result = "Error: \(error.localizedDescription)"
            resultColor = .red
        }
    }
}
