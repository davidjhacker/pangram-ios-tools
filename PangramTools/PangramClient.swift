//
//  PangramClient.swift
//  Pangram iOS Tools (Unofficial)
//
//  Created by David Hacker on 7/11/26.
//
//  Shared between the app and the Check with Pangram extension.
//


import Foundation
import Security

enum Pangram {
    struct Result { let prediction: String; let fractionAI: Double }

    /// Registered under both targets' App Groups capability; also used as the
    /// Keychain access group so the app and extension share the API key.
    /// Building from source under your own team? Create your own group and
    /// change it here and in both .entitlements files.
    nonisolated static let appGroup = "group.com.davidhacker.pangram"

    nonisolated static var apiKey: String {
        get { Keychain.read() ?? "" }
        set { Keychain.write(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    static func check(_ text: String, apiKey: String) async throws -> Result {
        let base = "https://text.external-api.pangram.com/task"

        var submit = URLRequest(url: URL(string: base)!)
        submit.httpMethod = "POST"
        submit.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        submit.setValue("application/json", forHTTPHeaderField: "Content-Type")
        submit.httpBody = try JSONSerialization.data(withJSONObject: ["text": text])

        let (submitData, submitResponse) = try await URLSession.shared.data(for: submit)
        try validate(submitResponse)
        var json = try parse(submitData)
        if let done = result(from: json) { return done }
        guard let id = json["task_id"] as? String else { throw err("No task_id") }

        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 700_000_000)
            var get = URLRequest(url: URL(string: "\(base)/\(id)")!)
            get.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            let (data, response) = try await URLSession.shared.data(for: get)
            try validate(response)
            json = try parse(data)
            if let done = result(from: json) { return done }
        }
        throw err("Timed out")
    }

    private static func validate(_ response: URLResponse) throws {
        guard let code = (response as? HTTPURLResponse)?.statusCode else { return }
        switch code {
        case 200..<300: return
        case 401, 403: throw err("Invalid API key — check it in the Pangram app")
        case 429: throw err("Rate limited — try again in a moment")
        default: throw err("Pangram API error (HTTP \(code))")
        }
    }

    private static func parse(_ d: Data) throws -> [String: Any] {
        (try JSONSerialization.jsonObject(with: d)) as? [String: Any] ?? [:]
    }
    private static func result(from json: [String: Any]) -> Result? {
        guard json["stage"] as? String == "STAGE_SUCCESS" else { return nil }
        return Result(prediction: json["prediction_short"] as? String ?? "Unknown",
                      fractionAI: json["fraction_ai"] as? Double ?? 0)
    }
    private static func err(_ m: String) -> NSError {
        NSError(domain: "Pangram", code: 1, userInfo: [NSLocalizedDescriptionKey: m])
    }
}

/// Stores the API key as a generic-password item shared with the extension
/// through the app group. AfterFirstUnlockThisDeviceOnly so the Shortcuts
/// intent still works in the background, and the key never leaves the device
/// via backups.
private nonisolated enum Keychain {
    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "PangramAPIKey",
            kSecAttrAccessGroup as String: Pangram.appGroup,
        ]
    }

    static func read() -> String? {
        var q = baseQuery
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String) {
        SecItemDelete(baseQuery as CFDictionary)
        guard !value.isEmpty else { return }
        var q = baseQuery
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
