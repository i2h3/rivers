// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation

///
/// A hierarchical identifier addressing an activity within a journal. Each component is the index of the activity among its siblings, so the full path encodes the lineage from a root activity down to this one. Renders as a dotted string (e.g. `1.3.2`) and serializes to JSON as a bare array of integers.
///
public struct ActivityID: Hashable, Sendable, Codable, CustomStringConvertible {
    ///
    /// The path of sibling indices from the root down to this activity.
    ///
    public let path: [UInt32]

    ///
    /// Create an identifier from an explicit path. Typically not called directly; the journal and `Activity.begin(_:_:)` allocate ids.
    ///
    public init(path: [UInt32]) {
        self.path = path
    }

    ///
    /// The identifier of the parent activity, or `nil` if this is a root activity.
    ///
    public var parent: ActivityID? {
        path.count <= 1 ? nil : ActivityID(path: Array(path.dropLast()))
    }

    public var description: String {
        path.map(String.init).joined(separator: ".")
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        path = try container.decode([UInt32].self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(path)
    }
}
