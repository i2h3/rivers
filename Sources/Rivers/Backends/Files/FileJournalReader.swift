// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Compression
import Foundation

///
/// Reads every message previously written by a `FileJournal` in the configured directory. Combines the active `log.jsonl` file with all rotated `<timestamp>.jsonl.lzfse` archives and returns them as a single chronologically-sorted array.
///
/// Intended as a one-call entry point for tools built on top of this library — visualizers, debuggers, or analyses — that want the full log history without dealing with file enumeration, decompression, or per-line JSON decoding.
///
public struct FileJournalReader: Sendable {
    private let configuration: FileJournalConfiguration

    ///
    /// Create a reader for the given configuration. The configuration's `directory` determines which files are read; `maxFileBytes` is ignored.
    ///
    public init(configuration: FileJournalConfiguration) {
        self.configuration = configuration
    }

    ///
    /// Read every message from every log file in the configured directory and return them sorted by `date`. Empty if the directory does not exist or contains no matching files.
    ///
    public func read() throws -> [Message] {
        let manager = FileManager.default

        guard manager.fileExists(atPath: configuration.directory.path) else {
            return []
        }

        let entries = try manager.contentsOfDirectory(at: configuration.directory, includingPropertiesForKeys: nil)
        let decoder = JSONDecoder()
        var messages: [Message] = []

        for url in entries {
            let name = url.lastPathComponent
            let data: Data

            if name == "log.jsonl" {
                data = try Data(contentsOf: url)
            } else if name.hasSuffix(".jsonl.lzfse") {
                data = try Self.decompress(url: url)
            } else {
                continue
            }

            for line in data.split(separator: 0x0A) where !line.isEmpty {
                let message = try decoder.decode(Message.self, from: Data(line))
                messages.append(message)
            }
        }

        messages.sort { $0.date < $1.date }

        return messages
    }

    private static func decompress(url: URL) throws -> Data {
        let source = try Data(contentsOf: url)
        var index = source.startIndex
        let pageSize = 64 * 1024

        let filter = try InputFilter(.decompress, using: .lzfse) { (count: Int) -> Data? in
            let upperBound = Swift.min(index + count, source.endIndex)

            defer {
                index = upperBound
            }

            let slice = source[index..<upperBound]

            return slice.isEmpty ? nil : Data(slice)
        }

        var output = Data()
        
        while let chunk = try filter.readData(ofLength: pageSize), !chunk.isEmpty {
            output.append(chunk)
        }

        return output
    }
}
