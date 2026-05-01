// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation
import Testing
@testable import Rivers

@Suite("FileJournal")
struct FileJournalTests {
    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rivers-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    @Test("Reader returns messages in chronological order from the active file")
    func activeFileRoundTrip() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let journal = try FileJournal(configuration: configuration)

        let root = journal.begin("root")
        root.info("first")
        root.error("second", ["k": "v"])
        let child = root.begin("child")
        child.debug("third")

        journal.finish()

        let reader = FileJournalReader(configuration: configuration)
        let messages = try reader.read()

        #expect(messages.count == 5)
        #expect(messages.map(\.label) == ["root", "first", "second", "child", "third"])
        #expect(messages[2].arguments == ["k": "v"])
        #expect(messages[3].activity == child.id)
        #expect(messages[3].parent == root.id)
        #expect(messages[3].arguments.isEmpty)
    }

    @Test("Rotation compresses old files and the reader merges them")
    func rotationAndReaderMerge() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory, maxFileBytes: 1_024)
        let journal = try FileJournal(configuration: configuration)

        let activity = journal.begin("root")
        for index in 0..<50 {
            activity.info("msg-\(index)")
            Thread.sleep(forTimeInterval: 0.002)
        }

        journal.finish()

        let entries = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let archives = entries.filter { $0.lastPathComponent.hasSuffix(".jsonl.lzfse") }
        #expect(!archives.isEmpty)

        let reader = FileJournalReader(configuration: configuration)
        let messages = try reader.read()

        #expect(messages.count == 51)
        let labels = Set(messages.map(\.label))
        #expect(labels.contains("root"))
        for index in 0..<50 {
            #expect(labels.contains("msg-\(index)"))
        }
        let dates = messages.map(\.date)
        #expect(dates == dates.sorted())
    }

    @Test("Activity finish records an info message under the activity")
    func activityFinishRecordsInfoMessage() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let journal = try FileJournal(configuration: configuration)

        let root = journal.begin("root")
        let child = root.begin("child")
        child.finish(["result": "ok"])
        root.finish()

        journal.finish()

        let reader = FileJournalReader(configuration: configuration)
        let messages = try reader.read()

        #expect(messages.map(\.label) == ["root", "child", "Finished.", "Finished."])

        #expect(messages[2].level == .info)
        #expect(messages[2].activity == child.id)
        #expect(messages[2].parent == root.id)
        #expect(messages[2].arguments == ["result": "ok"])

        #expect(messages[3].level == .info)
        #expect(messages[3].activity == root.id)
        #expect(messages[3].parent == nil)
        #expect(messages[3].arguments.isEmpty)
    }

    @Test("Reader returns empty when directory is missing")
    func readerHandlesMissingDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rivers-missing-\(UUID().uuidString)", isDirectory: true)
        let configuration = FileJournalConfiguration(directory: directory)
        let reader = FileJournalReader(configuration: configuration)

        #expect(try reader.read().isEmpty)
    }

    @Test("Reader ignores stray files that are not the active log or a journal archive")
    func readerIgnoresStrayFiles() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let journal = try FileJournal(configuration: configuration)
        journal.begin("only").info("kept")
        journal.finish()

        try Data("garbage".utf8).write(to: directory.appendingPathComponent("README.txt"))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("other.jsonl"))

        let reader = FileJournalReader(configuration: configuration)
        let messages = try reader.read()

        #expect(messages.map(\.label) == ["only", "kept"])
    }
}
