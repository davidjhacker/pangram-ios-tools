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
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Paste text here…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
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
                    Text("Paste text to check it here — or select text anywhere and use Share → Check with Pangram, or the “Check Text” action in Shortcuts.")
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
                        Pangram.apiKey = apiKey
                        saved = true
                    }
                } footer: {
                    Text("Get a key at pangram.com → API tab. Stored in the iOS Keychain, only ever sent to Pangram.")
                }
            }
            .navigationTitle("Pangram")
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
