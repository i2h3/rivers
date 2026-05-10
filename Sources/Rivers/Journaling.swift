// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation

///
/// A type that journals activities and messages.
///
public protocol Journaling: Sendable {
    ///
    /// Create a new root activity to associate messages with.
    ///
    /// - Parameters:
    ///     - label: How the beginning of an activity should be labled in the logs. The `StaticString` type enforces definition at compile time intentionally.
    ///
    /// - Returns: A new activity object to use for logging.
    ///
    func begin(_ label: StaticString) -> Activity

    ///
    /// Drain any pending messages and release backend resources. Blocks the caller until everything previously enqueued has been written.
    ///
    func finish()
}
