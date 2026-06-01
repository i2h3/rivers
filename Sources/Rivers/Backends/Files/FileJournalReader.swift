// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Compression
import Foundation

///
/// Reads every message previously written by one or more `FileJournal` sessions in the configured parent directory. Each immediate subdirectory of `configuration.directory` is treated as one session; its `log.jsonl` and any `<timestamp>-<suffix>.jsonl.lzfse` archives are combined into a single chronologically-sorted array.
///
/// Sessions are ordered by the date of their earliest message and assigned a chronological session index `N` starting at 1. Every loaded message has `N` prepended to its `activity` and `parent` paths; messages whose `parent` was `nil` are reparented to the synthetic session root `ActivityID(path: [N])`. A synthetic root message — activity `[N]`, no parent, level `info`, label set to the session folder name — is inserted in front of each session's messages so consumers see a concrete node at the top of every session tree.
///
/// The flat `[Message]` return contract is preserved: downstream tools never have to inspect the on-disk folder layout to disambiguate trees from different journal lifetimes.
///
public struct FileJournalReader: Sendable {
    private let configuration: FileJournalConfiguration

    ///
    /// Create a reader for the given configuration. The configuration's `directory` determines which subdirectories are scanned; `sessionID` and `maxFileBytes` are ignored.
    ///
    public init(configuration: FileJournalConfiguration) {
        self.configuration = configuration
    }

    ///
    /// Read every message from every session subdirectory in the configured directory, rewrite paths to namespace each session under its chronological index, prepend a synthetic root per session, and return the combined result sorted by `date`. Empty if the directory does not exist or contains no session subdirectories with messages.
    ///
    public func read() throws -> [Message] {
        let manager = FileManager.default

        guard manager.fileExists(atPath: configuration.directory.path) else {
            return []
        }

        let entries = try manager.contentsOfDirectory(at: configuration.directory, includingPropertiesForKeys: [.isDirectoryKey])
        var sessions: [SessionRead] = []

        for entry in entries {
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey])

            guard values.isDirectory == true else {
                continue
            }

            let messages = try Self.readMessages(in: entry)

            guard let earliest = messages.map(\.date).min() else {
                continue
            }

            sessions.append(SessionRead(sessionID: entry.lastPathComponent, earliestDate: earliest, messages: messages))
        }

        sessions.sort { $0.earliestDate < $1.earliestDate }

        var output: [Message] = []

        for (offset, session) in sessions.enumerated() {
            let index = UInt32(offset + 1)

            output.append(Message(
                activity: ActivityID(path: [index]),
                parent: nil,
                date: session.earliestDate.addingTimeInterval(-0.001),
                level: .info,
                label: session.sessionID,
                arguments: [:],
            ))

            for message in session.messages {
                output.append(message.namespaced(under: index))
            }
        }

        output.sort { $0.date < $1.date }

        return output
    }

    private static func readMessages(in directory: URL) throws -> [Message] {
        let manager = FileManager.default
        let entries = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
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

        return messages
    }

    private struct SessionRead {
        let sessionID: String
        let earliestDate: Date
        let messages: [Message]
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

            let slice = source[index ..< upperBound]

            return slice.isEmpty ? nil : Data(slice)
        }

        var output = Data()

        while let chunk = try filter.readData(ofLength: pageSize), !chunk.isEmpty {
            output.append(chunk)
        }

        return output
    }
}

private extension ActivityID {
    func prepending(_ index: UInt32) -> ActivityID {
        ActivityID(path: [index] + path)
    }
}

private extension Message {
    func namespaced(under index: UInt32) -> Message {
        let rewrittenParent: ActivityID = if let parent {
            parent.prepending(index)
        } else {
            ActivityID(path: [index])
        }

        return Message(
            activity: activity.prepending(index),
            parent: rewrittenParent,
            date: date,
            level: level,
            label: label,
            arguments: arguments,
        )
    }
}
