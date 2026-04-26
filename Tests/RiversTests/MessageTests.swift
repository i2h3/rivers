// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation
import Testing
@testable import Rivers

@Suite("Message")
struct MessageTests {
    @Test("Empty arguments are omitted from JSON")
    func encodingOmitsEmptyArguments() throws {
        let message = Message(
            activity: ActivityID(path: [1]),
            parent: nil,
            date: Date(timeIntervalSince1970: 0),
            level: .info,
            label: "hello",
            arguments: [:]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try String(data: encoder.encode(message), encoding: .utf8)

        #expect(json?.contains("\"arguments\"") == false)
    }

    @Test("Non-empty arguments survive a round-trip")
    func roundTrip() throws {
        let message = Message(
            activity: ActivityID(path: [1, 2]),
            parent: ActivityID(path: [1]),
            date: Date(timeIntervalSince1970: 1234),
            level: .error,
            label: "boom",
            arguments: ["k": "v"]
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)

        #expect(decoded.activity == message.activity)
        #expect(decoded.parent == message.parent)
        #expect(decoded.date == message.date)
        #expect(decoded.level == message.level)
        #expect(decoded.label == message.label)
        #expect(decoded.arguments == message.arguments)
    }

    @Test("Date encoding preserves millisecond precision")
    func datePreservesMilliseconds() throws {
        let original = Date(timeIntervalSince1970: 1_700_000_000.123)
        let message = Message(
            activity: ActivityID(path: [1]),
            parent: nil,
            date: original,
            level: .info,
            label: "x",
            arguments: [:]
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)

        #expect(String(data: data, encoding: .utf8)?.contains("1970-01-01T00:00:00") == false)
        #expect(decoded.date.timeIntervalSince1970 == original.timeIntervalSince1970)
    }

    @Test("Decoding tolerates absent arguments and parent")
    func decodingDefaults() throws {
        let json = #"{"activity":[1],"date":"1970-01-01T00:00:00.000Z","label":"x","level":1}"#
        let decoded = try JSONDecoder().decode(Message.self, from: Data(json.utf8))

        #expect(decoded.parent == nil)
        #expect(decoded.arguments.isEmpty)
    }
}
