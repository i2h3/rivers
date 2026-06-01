// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Compression
import Foundation
@testable import Rivers
import Testing

@Suite("FileJournalReader")
struct FileJournalReaderTests {
    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rivers-reader-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathExtension(FileJournalConfiguration.directoryExtension)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    private func makeSession(in directory: URL, named name: String) throws -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    private func encode(_ messages: [Message]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var data = Data()

        for message in messages {
            try data.append(encoder.encode(message))
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
            arguments: [:],
        )
    }

    @Test("Reads a hand-written active JSONL file")
    func readsActiveFile() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let session = try makeSession(in: directory, named: "alpha")
        let messages = [
            makeMessage(seconds: 100, label: "first"),
            makeMessage(seconds: 200, label: "second"),
        ]
        try encode(messages).write(to: session.appendingPathComponent("log.jsonl"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["Session", "first", "second"])
        #expect(read[0].arguments["id"] == "alpha")
    }

    @Test("Decompresses a rotated lzfse archive")
    func readsCompressedArchive() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let session = try makeSession(in: directory, named: "alpha")
        let messages = [
            makeMessage(seconds: 50, label: "old-1"),
            makeMessage(seconds: 60, label: "old-2"),
            makeMessage(seconds: 70, label: "old-3"),
        ]
        let compressed = try compress(encode(messages))
        try compressed.write(to: session.appendingPathComponent("2026-01-01T00-00-00.000Z.jsonl.lzfse"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["Session", "old-1", "old-2", "old-3"])
        #expect(read[0].arguments["id"] == "alpha")
    }

    @Test("Merges multiple archives and the active file in one session, sorted by date")
    func mergesAcrossFiles() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let session = try makeSession(in: directory, named: "alpha")

        let archiveA = try compress(encode([
            makeMessage(seconds: 10, label: "a-1"),
            makeMessage(seconds: 30, label: "a-2"),
        ]))
        try archiveA.write(to: session.appendingPathComponent("2026-01-01T00-00-00.000Z.jsonl.lzfse"))

        let archiveB = try compress(encode([
            makeMessage(seconds: 20, label: "b-1"),
            makeMessage(seconds: 40, label: "b-2"),
        ]))
        try archiveB.write(to: session.appendingPathComponent("2026-01-01T00-00-01.000Z.jsonl.lzfse"))

        try encode([
            makeMessage(seconds: 50, label: "active-1"),
            makeMessage(seconds: 60, label: "active-2"),
        ]).write(to: session.appendingPathComponent("log.jsonl"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["Session", "a-1", "b-1", "a-2", "b-2", "active-1", "active-2"])
        #expect(read[0].arguments["id"] == "alpha")
    }

    @Test("Reader orders sessions by their earliest message and namespaces each with its index")
    func multipleSessionsOrderedAndNamespaced() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)

        let later = try makeSession(in: directory, named: "later")
        try encode([
            makeMessage(seconds: 1000, label: "later-1"),
            makeMessage(seconds: 1100, label: "later-2"),
        ]).write(to: later.appendingPathComponent("log.jsonl"))

        let earlier = try makeSession(in: directory, named: "earlier")
        try encode([
            makeMessage(seconds: 100, label: "earlier-1"),
            makeMessage(seconds: 200, label: "earlier-2"),
        ]).write(to: earlier.appendingPathComponent("log.jsonl"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["Session", "earlier-1", "earlier-2", "Session", "later-1", "later-2"])

        #expect(read[0].activity == ActivityID(path: [1]))
        #expect(read[0].arguments["id"] == "earlier")
        #expect(read[1].activity == ActivityID(path: [1, 1]))
        #expect(read[1].parent == ActivityID(path: [1]))

        #expect(read[3].activity == ActivityID(path: [2]))
        #expect(read[3].arguments["id"] == "later")
        #expect(read[4].activity == ActivityID(path: [2, 1]))
        #expect(read[4].parent == ActivityID(path: [2]))
    }

    @Test("Skips blank lines in the JSONL stream")
    func skipsBlankLines() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let session = try makeSession(in: directory, named: "alpha")
        var data = try encode([makeMessage(seconds: 10, label: "x")])
        data.append(0x0A)
        data.append(0x0A)
        try data.append(encode([makeMessage(seconds: 20, label: "y")]))
        try data.write(to: session.appendingPathComponent("log.jsonl"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["Session", "x", "y"])
        #expect(read[0].arguments["id"] == "alpha")
    }

    @Test("Throws when an archive contains invalid JSON")
    func throwsOnInvalidJSON() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let session = try makeSession(in: directory, named: "alpha")
        try Data("not json\n".utf8).write(to: session.appendingPathComponent("log.jsonl"))

        #expect(throws: (any Error).self) {
            _ = try FileJournalReader(configuration: configuration).read()
        }
    }

    @Test("Ignores top-level files that are not session subdirectories")
    func ignoresUnrelatedFiles() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let session = try makeSession(in: directory, named: "kept")
        try encode([makeMessage(seconds: 1, label: "kept")])
            .write(to: session.appendingPathComponent("log.jsonl"))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("README.txt"))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("log.txt"))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("notes.json"))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("log.jsonl"))

        let read = try FileJournalReader(configuration: configuration).read()

        #expect(read.map(\.label) == ["Session", "kept"])
        #expect(read[0].arguments["id"] == "kept")
    }
}
