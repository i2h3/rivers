import Foundation

///
/// Configuration for `FileJournal`. Controls where log files are written, how large they may grow before being rotated, and the prefix used to name them.
///
public struct FileJournalConfiguration: Sendable {
    ///
    /// The directory in which log files are written. Created on demand if it does not exist.
    ///
    public var directory: URL

    ///
    /// The size threshold in bytes at which the active log file is rotated and compressed.
    ///
    public var maxFileBytes: Int

    ///
    /// The prefix used to name the active log file (`<prefix>.jsonl`) and rotated archives (`<prefix>-<timestamp>.jsonl.lzfse`).
    ///
    public var fileNamePrefix: String

    ///
    /// Create a configuration. Defaults to a 5 MiB rotation threshold and a `rivers` file name prefix.
    ///
    public init(directory: URL, maxFileBytes: Int = 5 * 1024 * 1024, fileNamePrefix: String = "rivers") {
        self.directory = directory
        self.maxFileBytes = maxFileBytes
        self.fileNamePrefix = fileNamePrefix
    }
}
