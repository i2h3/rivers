// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Compression
import Foundation

///
/// A journal that writes messages as JSON-lines into rotating files on disk. Records are encoded one per line. When the active file exceeds the configured size threshold it is renamed with a timestamp, compressed with `lzfse`, and replaced by a fresh active file.
///
/// Writes happen on a private serial dispatch queue so callers never block on I/O and the chronological order of `record` calls is preserved across threads.
///
public final class FileJournal: Journaling, @unchecked Sendable {
    private let configuration: FileJournalConfiguration
    private let queue: DispatchQueue
    private let roots: ChildCounter
    private let encoder: JSONEncoder

    private var handle: FileHandle?
    private var bytesWritten: Int = 0

    ///
    /// Open (or create) the active log file in the configured directory. Throws if the directory cannot be created or the file cannot be opened for writing.
    ///
    public init(configuration: FileJournalConfiguration) throws {
        self.configuration = configuration
        queue = DispatchQueue(label: "rivers.file.\(configuration.fileNamePrefix)", qos: .utility)
        roots = ChildCounter()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        self.encoder = encoder

        try FileManager.default.createDirectory(at: configuration.directory, withIntermediateDirectories: true)
        try openActiveFile()
    }

    ///
    /// Begin a new root activity in this journal and emit its initial message labelled with `label`.
    ///
    public func begin(_ label: String) -> Activity {
        let next = roots.next()
        let id = ActivityID(path: [next])

        let activity = Activity(id: id, parent: nil) { [weak self] message in
            self?.record(message)
        }

        activity.info(label)

        return activity
    }

    private func record(_ message: Message) {
        queue.async { [self] in
            do {
                try write(message)
            } catch {
                assertionFailure("FileJournal write failed: \(error)")
            }
        }
    }

    ///
    /// Drain pending messages, flush the active file to disk, and close it. Blocks until everything previously enqueued has been written.
    ///
    public func finish() {
        queue.sync {
            try? handle?.synchronize()
            try? handle?.close()
            handle = nil
        }
    }

    private var activeFileURL: URL {
        configuration.directory.appendingPathComponent("\(configuration.fileNamePrefix).jsonl")
    }

    private func openActiveFile() throws {
        let url = activeFileURL

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        self.handle = handle
        bytesWritten = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    }

    private func write(_ message: Message) throws {
        var data = try encoder.encode(message)
        data.append(0x0A)

        if bytesWritten + data.count > configuration.maxFileBytes, bytesWritten > 0 {
            try rotate()
        }

        guard let handle else {
            return
        }

        try handle.write(contentsOf: data)
        bytesWritten += data.count
    }

    private func rotate() throws {
        try handle?.synchronize()
        try handle?.close()
        handle = nil

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let rotatedName = "\(configuration.fileNamePrefix)-\(timestamp).jsonl"
        let rotatedURL = configuration.directory.appendingPathComponent(rotatedName)

        try FileManager.default.moveItem(at: activeFileURL, to: rotatedURL)
        try compress(source: rotatedURL)
        try FileManager.default.removeItem(at: rotatedURL)

        try openActiveFile()
        bytesWritten = 0
    }

    private func compress(source: URL) throws {
        let compressedURL = source.appendingPathExtension("lzfse")
        FileManager.default.createFile(atPath: compressedURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: compressedURL)

        defer {
            try? output.close()
        }

        let filter = try OutputFilter(.compress, using: .lzfse) { (data: Data?) in
            if let data {
                try output.write(contentsOf: data)
            }
        }

        let input = try FileHandle(forReadingFrom: source)

        defer {
            try? input.close()
        }

        while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
            try filter.write(chunk)
        }

        try filter.finalize()
    }
}
