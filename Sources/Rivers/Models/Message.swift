// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation

///
/// A single record written by a journal — the wire format used by every backend. Encodes to JSON as one object per record, with `arguments` and `parent` omitted when absent.
///
public struct Message: Codable, Sendable {
    ///
    /// The identifier of the activity that produced the message.
    ///
    public let activity: ActivityID

    ///
    /// The identifier of the parent of `activity`, or `nil` if `activity` is a root.
    ///
    public let parent: ActivityID?

    ///
    /// The instant at which the message was recorded.
    ///
    public let date: Date

    ///
    /// The significance of the message.
    ///
    public let level: Level

    ///
    /// The human-readable text of the message.
    ///
    public let label: String

    ///
    /// Structured key/value context attached to the message. Empty when the call site did not supply any.
    ///
    public let arguments: [String: String]

    private enum CodingKeys: String, CodingKey {
        case activity
        case parent
        case date
        case level
        case label
        case arguments
    }

    ///
    /// Create a message. Typically constructed by `Activity` rather than by callers.
    ///
    public init(activity: ActivityID, parent: ActivityID?, date: Date, level: Level, label: String, arguments: [String: String]) {
        self.activity = activity
        self.parent = parent
        self.date = date
        self.level = level
        self.label = label
        self.arguments = arguments
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activity = try container.decode(ActivityID.self, forKey: .activity)
        parent = try container.decodeIfPresent(ActivityID.self, forKey: .parent)
        let dateString = try container.decode(String.self, forKey: .date)

        guard let parsed = Self.makeDateFormatter().date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Invalid ISO8601 date with fractional seconds: \(dateString)")
        }
        
        date = parsed
        level = try container.decode(Level.self, forKey: .level)
        label = try container.decode(String.self, forKey: .label)
        arguments = try container.decodeIfPresent([String: String].self, forKey: .arguments) ?? [:]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activity, forKey: .activity)
        try container.encodeIfPresent(parent, forKey: .parent)
        try container.encode(Self.makeDateFormatter().string(from: date), forKey: .date)
        try container.encode(level, forKey: .level)
        try container.encode(label, forKey: .label)

        if !arguments.isEmpty {
            try container.encode(arguments, forKey: .arguments)
        }
    }

    private static func makeDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return formatter
    }
}
