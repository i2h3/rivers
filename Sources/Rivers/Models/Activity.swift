// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation
import os

///
/// A unit of work whose messages are grouped together in the journal. Begin a child activity with `begin(_:_:)` to model nested work; emit messages with `debug`, `info`, or `error`.
///
public struct Activity: Identifiable, Sendable {
    ///
    /// The hierarchical identifier of the activity, unique within its journal.
    ///
    public let id: ActivityID

    ///
    /// The identifier of the activity that started this one, or `nil` if this is a root activity.
    ///
    public let parent: ActivityID?

    ///
    /// The instant at which this activity was created.
    ///
    public let start: Date

    ///
    /// The closure to call to record a message in the log.
    ///
    private let write: Writer

    let children: ChildCounter

    init(id: ActivityID, parent: ActivityID?, writer: @escaping Writer) {
        self.id = id
        self.parent = parent
        start = Date()
        write = writer
        children = ChildCounter()
    }

    ///
    /// Start a child activity nested under this one. The child gets a fresh hierarchical id (`<this>.<n>`) and an info message labelled with `label` is emitted on its behalf.
    ///
    /// - Parameters:
    ///     - label: How the beginning of an activity should be labled in the logs. The `StaticString` type enforces definition at compile time intentionally.
    ///
    public func begin(_ label: StaticString, _ arguments: [String: Any?] = [:]) -> Activity {
        let next = children.next()
        let childID = ActivityID(path: id.path + [next])
        let child = Activity(id: childID, parent: id, writer: write)
        child.info(label, arguments)

        return child
    }

    ///
    /// Mark this activity as finished by recording an informational message under it. Calling this is optional; use it when an activity has a long-running task whose end would otherwise not be visible. Pass `arguments` to record result values or errors.
    ///
    /// - Parameters:
    ///     - message: The text for the end-of-activity message. The `StaticString` type enforces definition at compile time intentionally.
    ///     - arguments: Optional structured key/value context to attach to the message.
    ///
    public func finish(_ message: StaticString, _ arguments: [String: Any?] = [:]) {
        info(message, arguments)
    }

    ///
    /// Record a message at debug level. Use for diagnostic detail useful while developing or troubleshooting.
    ///
    /// - Parameters:
    ///     - message: The text for the message in the log. The `StaticString` type enforces definition at compile time intentionally.
    ///
    public func debug(_ message: StaticString, _ arguments: [String: Any?] = [:]) {
        write(id, parent, Date(), .debug, message, arguments)
    }

    ///
    /// Record a message at info level. The default for general-purpose messages.
    ///
    /// - Parameters:
    ///     - message: The text for the message in the log. The `StaticString` type enforces definition at compile time intentionally.
    ///
    public func info(_ message: StaticString, _ arguments: [String: Any?] = [:]) {
        write(id, parent, Date(), .info, message, arguments)
    }

    ///
    /// Record a message at error level. Use for failures or unexpected conditions.
    ///
    /// - Parameters:
    ///     - message: The text for the message in the log. The `StaticString` type enforces definition at compile time intentionally.
    ///
    public func error(_ message: StaticString, _ arguments: [String: Any?] = [:]) {
        write(id, parent, Date(), .error, message, arguments)
    }
}
