// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation

///
/// Configuration for `FileJournal`. Controls where log files are written and how large the active file may grow before being rotated.
///
public struct FileJournalConfiguration: Sendable {
    ///
    /// The directory in which log files are written. Created on demand if it does not exist. The directory itself namespaces the journal — one journal per directory.
    ///
    public var directory: URL

    ///
    /// The size threshold in bytes at which the active log file is rotated and compressed.
    ///
    public var maxFileBytes: Int

    ///
    /// Create a configuration. Defaults to a 5 MiB rotation threshold.
    ///
    public init(directory: URL, maxFileBytes: Int = 5 * 1024 * 1024) {
        self.directory = directory
        self.maxFileBytes = maxFileBytes
    }
}
