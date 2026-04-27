// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Compression
import Foundation
import Testing
@testable import Rivers

@Suite("FileJournalReader")
struct FileJournalReaderTests {
    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rivers-reader-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    private func encode(_ messages: [Message]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var data = Data()

        for message in messages {
            data.append(try encoder.encode(message))
            data.append(0x0A)
        }

        return data
    }

    private func compress(_ data: Data) throws -> Data {
        var output = Data()

        let filter = try OutputFilter(.compress, using: .lzfse) { (chunk: Data?) in
            if let chunk {
                output.append(chunk)
            }
        }

        try filter.write(data)
        try filter.finalize()

        return output
    }

    private func makeMessage(seconds: TimeInterval, label: String) -> Message {
        Message(
            activity: ActivityID(path: [1]),
            parent: nil,
            date: Date(timeIntervalSince1970: seconds),
            level: .info,
            label: label,
            arguments: [:]
        )
    }

    @Test("Reads a hand-written active JSONL file")
    func readsActiveFile() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let messages = [
            makeMessage(seconds: 100, label: "first"),
            makeMessage(seconds: 200, label: "second"),
        ]
        try encode(messages).write(to: directory.appendingPathComponent("log.jsonl"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["first", "second"])
    }

    @Test("Decompresses a rotated lzfse archive")
    func readsCompressedArchive() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let messages = [
            makeMessage(seconds: 50, label: "old-1"),
            makeMessage(seconds: 60, label: "old-2"),
            makeMessage(seconds: 70, label: "old-3"),
        ]
        let compressed = try compress(try encode(messages))
        try compressed.write(to: directory.appendingPathComponent("2026-01-01T00-00-00.000Z.jsonl.lzfse"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["old-1", "old-2", "old-3"])
    }

    @Test("Merges multiple archives and the active file, sorted by date")
    func mergesAcrossFiles() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)

        let archiveA = try compress(try encode([
            makeMessage(seconds: 10, label: "a-1"),
            makeMessage(seconds: 30, label: "a-2"),
        ]))
        try archiveA.write(to: directory.appendingPathComponent("2026-01-01T00-00-00.000Z.jsonl.lzfse"))

        let archiveB = try compress(try encode([
            makeMessage(seconds: 20, label: "b-1"),
            makeMessage(seconds: 40, label: "b-2"),
        ]))
        try archiveB.write(to: directory.appendingPathComponent("2026-01-01T00-00-01.000Z.jsonl.lzfse"))

        try encode([
            makeMessage(seconds: 50, label: "active-1"),
            makeMessage(seconds: 60, label: "active-2"),
        ]).write(to: directory.appendingPathComponent("log.jsonl"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["a-1", "b-1", "a-2", "b-2", "active-1", "active-2"])
    }

    @Test("Skips blank lines in the JSONL stream")
    func skipsBlankLines() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        var data = try encode([makeMessage(seconds: 10, label: "x")])
        data.append(0x0A)
        data.append(0x0A)
        data.append(try encode([makeMessage(seconds: 20, label: "y")]))
        try data.write(to: directory.appendingPathComponent("log.jsonl"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["x", "y"])
    }

    @Test("Throws when an archive contains invalid JSON")
    func throwsOnInvalidJSON() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        try Data("not json\n".utf8).write(to: directory.appendingPathComponent("log.jsonl"))

        #expect(throws: (any Error).self) {
            _ = try FileJournalReader(configuration: configuration).read()
        }
    }

    @Test("Ignores files that share neither the active name nor archive pattern")
    func ignoresUnrelatedFiles() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        try encode([makeMessage(seconds: 1, label: "kept")])
            .write(to: directory.appendingPathComponent("log.jsonl"))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("README.txt"))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("log.txt"))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("notes.json"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["kept"])
    }
}
