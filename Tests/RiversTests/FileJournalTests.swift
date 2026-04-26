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

        let configuration = FileJournalConfiguration(directory: directory, fileNamePrefix: "test")
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
        #expect(messages.map(\.label) == ["root", "first", "second", "Activity started.", "third"])
        #expect(messages[2].arguments == ["k": "v"])
        #expect(messages[3].activity == child.id)
        #expect(messages[3].parent == root.id)
        #expect(messages[3].arguments["label"] == "child")
    }

    @Test("Rotation compresses old files and the reader merges them")
    func rotationAndReaderMerge() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory, maxFileBytes: 1_024, fileNamePrefix: "rot")
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

    @Test("Reader returns empty when directory is missing")
    func readerHandlesMissingDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rivers-missing-\(UUID().uuidString)", isDirectory: true)
        let configuration = FileJournalConfiguration(directory: directory, fileNamePrefix: "absent")
        let reader = FileJournalReader(configuration: configuration)

        #expect(try reader.read().isEmpty)
    }

    @Test("Reader ignores files that do not match the configured prefix")
    func readerFiltersByPrefix() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory, fileNamePrefix: "mine")
        let journal = try FileJournal(configuration: configuration)
        journal.begin("only").info("kept")
        journal.finish()

        let stranger = directory.appendingPathComponent("other.jsonl")
        try Data("not mine\n".utf8).write(to: stranger)

        let reader = FileJournalReader(configuration: configuration)
        let messages = try reader.read()

        #expect(messages.map(\.label) == ["only", "kept"])
    }
}
