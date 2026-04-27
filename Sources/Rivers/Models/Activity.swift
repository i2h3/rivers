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

    let recordHandler: @Sendable (Message) -> Void
    let children: ChildCounter

    init(id: ActivityID, parent: ActivityID?, recordHandler: @escaping @Sendable (Message) -> Void) {
        self.id = id
        self.parent = parent
        start = Date()
        self.recordHandler = recordHandler
        children = ChildCounter()
    }

    ///
    /// Start a child activity nested under this one. The child gets a fresh hierarchical id (`<this>.<n>`) and an info message labelled with `label` is emitted on its behalf.
    ///
    public func begin(_ label: String, _ arguments: [String: String] = [:]) -> Activity {
        let next = children.next()
        let childID = ActivityID(path: id.path + [next])
        let child = Activity(id: childID, parent: id, recordHandler: recordHandler)
        child.info(label, arguments)

        return child
    }

    ///
    /// Record a message at debug level. Use for diagnostic detail useful while developing or troubleshooting.
    ///
    public func debug(_ message: String, _ arguments: [String: String] = [:]) {
        record(level: .debug, message: message, arguments: arguments)
    }

    ///
    /// Record a message at info level. The default for general-purpose messages.
    ///
    public func info(_ message: String, _ arguments: [String: String] = [:]) {
        record(level: .info, message: message, arguments: arguments)
    }

    ///
    /// Record a message at error level. Use for failures or unexpected conditions.
    ///
    public func error(_ message: String, _ arguments: [String: String] = [:]) {
        record(level: .error, message: message, arguments: arguments)
    }

    private func record(level: Level, message: String, arguments: [String: String]) {
        recordHandler(Message(activity: id, parent: parent, date: Date(), level: level, label: message, arguments: arguments))
    }
}
