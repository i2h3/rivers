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
    func begin(_ label: String) -> Activity

    ///
    /// Drain any pending messages and release backend resources. Blocks the caller until everything previously enqueued has been written.
    ///
    func finish()
}
