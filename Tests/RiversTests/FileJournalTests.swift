// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation
@testable import Rivers
import Testing

@Suite("FileJournal")
struct FileJournalTests {
    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rivers-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathExtension(FileJournalConfiguration.directoryExtension)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    @Test
    func `Reader returns messages in chronological order from the active file`() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let journal = try FileJournal(configuration: configuration)

        let root = journal.begin("root")
        root.info("first")
        root.error("second", ["k": "v"])
        let child = root.begin("child")
        child.debug("third")

        journal.finish("Finished.")

        let reader = FileJournalReader(configuration: configuration)
        let messages = try reader.read()

        #expect(messages.count == 7)
        #expect(messages.map(\.label) == ["Session", "root", "first", "second", "child", "third", "Finished."])
        #expect(messages[0].arguments["id"] == configuration.sessionID)
        #expect(messages[3].arguments == ["k": "v"])
        #expect(messages[4].activity == ActivityID(path: [1, 1, 1]))
        #expect(messages[4].parent == ActivityID(path: [1, 1]))
        #expect(messages[4].arguments.isEmpty)
    }

    @Test
    func `Rotation compresses old files and the reader merges them`() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory, maxFileBytes: 1024)
        let journal = try FileJournal(configuration: configuration)

        let activity = journal.begin("root")
        for index in 0 ..< 50 {
            activity.info("Test", ["index": index])
            Thread.sleep(forTimeInterval: 0.002)
        }

        journal.finish("Finished.")

        let sessionFolder = directory.appendingPathComponent(configuration.sessionID)
        let entries = try FileManager.default.contentsOfDirectory(at: sessionFolder, includingPropertiesForKeys: nil)
        let archives = entries.filter { $0.lastPathComponent.hasSuffix(".jsonl.lzfse") }
        #expect(!archives.isEmpty)

        let reader = FileJournalReader(configuration: configuration)
        let messages = try reader.read()

        #expect(messages.count == 53)
        let labels = Set(messages.map(\.label))
        #expect(labels.contains("Session"))
        #expect(labels.contains("root"))
        #expect(messages.first { $0.label == "Session" }?.arguments["id"] == configuration.sessionID)

        for _ in 0 ..< 50 {
            #expect(labels.contains("Test"))
        }

        let dates = messages.map(\.date)
        #expect(dates == dates.sorted())
    }

    @Test
    func `Activity finish records an info message under the activity`() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let journal = try FileJournal(configuration: configuration)

        let root = journal.begin("root")
        let child = root.begin("child")
        child.finish("Finished.", ["result": "ok"])
        root.finish("Finished.")

        journal.finish("Finished.")

        let reader = FileJournalReader(configuration: configuration)
        let messages = try reader.read()

        #expect(messages.map(\.label) == ["Session", "root", "child", "Finished.", "Finished.", "Finished."])
        #expect(messages[0].arguments["id"] == configuration.sessionID)

        #expect(messages[3].level == .info)
        #expect(messages[3].activity == ActivityID(path: [1, 1, 1]))
        #expect(messages[3].parent == ActivityID(path: [1, 1]))
        #expect(messages[3].arguments == ["result": "ok"])

        #expect(messages[4].level == .info)
        #expect(messages[4].activity == ActivityID(path: [1, 1]))
        #expect(messages[4].parent == ActivityID(path: [1]))
        #expect(messages[4].arguments.isEmpty)
    }

    @Test
    func `Reader returns empty when directory is missing`() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rivers-missing-\(UUID().uuidString)", isDirectory: true)
            .appendingPathExtension(FileJournalConfiguration.directoryExtension)
        let configuration = FileJournalConfiguration(directory: directory)
        let reader = FileJournalReader(configuration: configuration)

        #expect(try reader.read().isEmpty)
    }

    @Test
    func `Reader ignores stray files that are not session subdirectories`() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let journal = try FileJournal(configuration: configuration)
        journal.begin("only").info("kept")
        journal.finish("Finished.")

        try Data("garbage".utf8).write(to: directory.appendingPathComponent("README.txt"))
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("other.jsonl"))

        let reader = FileJournalReader(configuration: configuration)
        let messages = try reader.read()

        #expect(messages.map(\.label) == ["Session", "only", "kept", "Finished."])
        #expect(messages[0].arguments["id"] == configuration.sessionID)
    }

    @Test
    func `Successive journal lifetimes against the same parent directory produce separate, namespaced sessions`() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationA = FileJournalConfiguration(directory: directory)
        let journalA = try FileJournal(configuration: configurationA)
        journalA.begin("a-root").info("a-event")
        journalA.finish("a-done")

        Thread.sleep(forTimeInterval: 0.1)

        let configurationB = FileJournalConfiguration(directory: directory)
        let journalB = try FileJournal(configuration: configurationB)
        journalB.begin("b-root").info("b-event")
        journalB.finish("b-done")

        let reader = FileJournalReader(configuration: FileJournalConfiguration(directory: directory))
        let messages = try reader.read()

        #expect(messages.map(\.label) == ["Session", "a-root", "a-event", "a-done", "Session", "b-root", "b-event", "b-done"])

        let firstSynthetic = messages[0]
        #expect(firstSynthetic.activity == ActivityID(path: [1]))
        #expect(firstSynthetic.parent == nil)
        #expect(firstSynthetic.arguments["id"] == configurationA.sessionID)

        let aRoot = messages[1]
        #expect(aRoot.activity == ActivityID(path: [1, 1]))
        #expect(aRoot.parent == ActivityID(path: [1]))

        let secondSynthetic = messages[4]
        #expect(secondSynthetic.activity == ActivityID(path: [2]))
        #expect(secondSynthetic.parent == nil)
        #expect(secondSynthetic.arguments["id"] == configurationB.sessionID)

        let bRoot = messages[5]
        #expect(bRoot.activity == ActivityID(path: [2, 1]))
        #expect(bRoot.parent == ActivityID(path: [2]))

        let sessionFolders = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .sorted()
        #expect(sessionFolders == [configurationA.sessionID, configurationB.sessionID].sorted())
    }

    @Test
    func `Configuration appends the package extension when the caller's URL lacks it`() {
        let bare = URL(fileURLWithPath: "/tmp/MyLogs", isDirectory: true)
        let configuration = FileJournalConfiguration(directory: bare)

        #expect(configuration.directory.pathExtension == FileJournalConfiguration.directoryExtension)
        #expect(configuration.directory.lastPathComponent == "MyLogs.rivers")
    }

    @Test
    func `Configuration leaves the URL alone when the extension is already present`() {
        let packaged = URL(fileURLWithPath: "/tmp/MyLogs.rivers", isDirectory: true)
        let configuration = FileJournalConfiguration(directory: packaged)

        #expect(configuration.directory.lastPathComponent == "MyLogs.rivers")
        #expect(!configuration.directory.lastPathComponent.contains("rivers.rivers"))
    }

    @Test
    func `Configuration augments rather than replaces a foreign extension`() {
        let foreign = URL(fileURLWithPath: "/tmp/MyApp.log", isDirectory: true)
        let configuration = FileJournalConfiguration(directory: foreign)

        #expect(configuration.directory.lastPathComponent == "MyApp.log.rivers")
        #expect(configuration.directory.pathExtension == FileJournalConfiguration.directoryExtension)
    }
}
