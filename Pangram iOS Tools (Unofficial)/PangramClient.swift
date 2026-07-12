//
//  PangramClient.swift
//  Pangram iOS Tools (Unofficial)
//
//  Created by David Hacker on 7/11/26.
//
//  Shared between the app and the Check with Pangram extension.
//

import Foundation

enum Pangram {
    struct Result { let prediction: String; let fractionAI: Double }

    static func check(_ text: String, apiKey: String) async throws -> Result {
        let base = "https://text.external-api.pangram.com/task"

        var submit = URLRequest(url: URL(string: base)!)
        submit.httpMethod = "POST"
        submit.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        submit.setValue("application/json", forHTTPHeaderField: "Content-Type")
        submit.httpBody = try JSONSerialization.data(withJSONObject: ["text": text])

        let (submitData, _) = try await URLSession.shared.data(for: submit)
        var json = try parse(submitData)
        if let done = result(from: json) { return done }
        guard let id = json["task_id"] as? String else { throw err("No task_id") }

        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 700_000_000)
            var get = URLRequest(url: URL(string: "\(base)/\(id)")!)
            get.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            let (data, _) = try await URLSession.shared.data(for: get)
            json = try parse(data)
            if let done = result(from: json) { return done }
        }
        throw err("Timed out")
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
