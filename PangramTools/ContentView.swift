import SwiftUI

struct ContentView: View {
    @State private var text = ""
    @State private var apiKey = ""
    @State private var saved = false
    @State private var showKey = false
    @State private var checking = false
    @State private var result = ""
    @State private var resultColor = Color.secondary

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste text here…", text: $text, axis: .vertical)
                        .lineLimit(1...10)
                        .autocorrectionDisabled()
                    Button(checking ? "Checking…" : "Check") {
                        Task { await check() }
                    }
                    .disabled(checking || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !result.isEmpty {
                        Text(result)
                            .foregroundStyle(resultColor)
                            .font(.callout)
                    }
                } footer: {
                    Text("For more convenient use, configure via Shortcuts or highlight text and select Share → Check with Pangram")
                }

                Section {
                    Link(destination: URL(string: "https://www.icloud.com/shortcuts/94165e3a058e47dc94ae351ad38bad85")!) {
                        Label("Add Recommended Shortcut", systemImage: "plus.rectangle.on.rectangle")
                    }
                } footer: {
                    Text("Installs a shortcut that checks whatever text is on your screen with Pangram. For easist use, add this shortcut under Settings → Accessibility → Touch → Back Tap → Double Tap.")
                }

                Section {
                    HStack {
                        Text("API key")
                        Group {
                            if showKey {
                                TextField("Required", text: $apiKey)
                            } else {
                                SecureField("Required", text: $apiKey)
                            }
                        }
                        .multilineTextAlignment(.trailing)
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
                        Pangram.apiKey = apiKey
                        saved = true
                    }
                } footer: {
                    Text("Stored in the iOS Keychain, only ever sent to Pangram.")
                }
            }
            .navigationTitle("Pangram iOS Tools")
            .onAppear { apiKey = Pangram.apiKey }
            .onChange(of: apiKey) { saved = false }
        }
    }

    private func check() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        guard words >= 50 else {
            result = "Pangram needs 50+ words (\(words) pasted)"
            resultColor = .secondary
            return
        }
        let key = Pangram.apiKey
        guard !key.isEmpty else {
            result = "Save your API key below first"
            resultColor = .secondary
            return
        }
        checking = true
        defer { checking = false }
        do {
            let r = try await Pangram.check(trimmed, apiKey: key)
            let pct = Int((r.fractionAI * 100).rounded())
            result = "\(r.prediction) — \(pct)% AI"
            resultColor = r.fractionAI >= 0.5 ? .orange : .green
        } catch {
            result = "Error: \(error.localizedDescription)"
            resultColor = .red
        }
    }
}
