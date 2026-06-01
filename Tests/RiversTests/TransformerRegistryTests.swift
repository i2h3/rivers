// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation
@testable import Rivers
import Testing

@Suite("TransformerRegistry")
struct TransformerRegistryTests {
    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rivers-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathExtension(FileJournalConfiguration.directoryExtension)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    @Test("Default registry transforms URL into its absolute string")
    func defaultURLTransformer() throws {
        let registry = TransformerRegistry()
        let url = try #require(URL(string: "https://example.com/path?q=1"))

        #expect(registry.transform(url) == url.absoluteString)
    }

    @Test("Transform returns nil for types without a registered closure")
    func unregisteredTypeReturnsNil() {
        let registry = TransformerRegistry()
        let name = Notification.Name(UUID().uuidString)

        #expect(registry.transform(name) == nil)
    }

    @Test("A registered closure is invoked for values of its type")
    func registeredClosureRunsForMatchingType() {
        let registry = TransformerRegistry()
        registry.register { (name: Notification.Name) in
            name.rawValue
        }

        let raw = "item-abc"
        let name = Notification.Name(raw)

        #expect(registry.transform(name) == raw)
    }

    @Test("Registering a second closure for the same type replaces the previous one")
    func registeringReplacesPreviousClosure() {
        let registry = TransformerRegistry()
        registry.register { (name: Notification.Name) in
            "first:\(name.rawValue)"
        }
        registry.register { (name: Notification.Name) in
            "second:\(name.rawValue)"
        }

        #expect(registry.transform(Notification.Name("x")) == "second:x")
    }

    @Test("Without a transformer the journal records String(describing:) of the argument")
    func journalFallsBackToStringDescribing() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let journal = try FileJournal(configuration: configuration)

        let raw = "item-\(UUID().uuidString)"
        let name = Notification.Name(raw)
        let activity = journal.begin("root")
        activity.info("touched", ["item": name])
        journal.finish("Finished.")

        let reader = FileJournalReader(configuration: configuration)
        let touched = try #require(try reader.read().first { $0.label == "touched" })

        let expected: [String: String?] = ["item": String(describing: name)]
        #expect(touched.arguments == expected)
        #expect(touched.arguments["item"] != .some(.some(raw)))
    }

    @Test("With a registered transformer the journal records the transformed value")
    func journalUsesRegisteredTransformer() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = TransformerRegistry()
        registry.register { (name: Notification.Name) in
            name.rawValue
        }

        let configuration = FileJournalConfiguration(directory: directory)
        let journal = try FileJournal(configuration: configuration, transformerRegistry: registry)

        let raw = "item-\(UUID().uuidString)"
        let name = Notification.Name(raw)
        let activity = journal.begin("root")
        activity.info("touched", ["item": name])
        journal.finish("Finished.")

        let reader = FileJournalReader(configuration: configuration)
        let touched = try #require(try reader.read().first { $0.label == "touched" })

        let expected: [String: String?] = ["item": raw]
        #expect(touched.arguments == expected)
        #expect(touched.arguments["item"] != .some(.some(String(describing: name))))
    }

    @Test("Two journals with different registries record the same value differently")
    func differentRegistriesProduceDifferentOutput() throws {
        let plainDirectory = makeTempDirectory()
        let customDirectory = makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: plainDirectory)
            try? FileManager.default.removeItem(at: customDirectory)
        }

        let custom = TransformerRegistry()
        custom.register { (name: Notification.Name) in
            name.rawValue
        }

        let plainJournal = try FileJournal(configuration: FileJournalConfiguration(directory: plainDirectory))
        let customJournal = try FileJournal(
            configuration: FileJournalConfiguration(directory: customDirectory),
            transformerRegistry: custom,
        )

        let name = Notification.Name("shared-item")
        plainJournal.begin("root").info("touched", ["item": name])
        customJournal.begin("root").info("touched", ["item": name])
        plainJournal.finish("Finished.")
        customJournal.finish("Finished.")

        let plain = try #require(
            try FileJournalReader(configuration: FileJournalConfiguration(directory: plainDirectory))
                .read()
                .first { $0.label == "touched" },
        )
        let transformed = try #require(
            try FileJournalReader(configuration: FileJournalConfiguration(directory: customDirectory))
                .read()
                .first { $0.label == "touched" },
        )

        #expect(plain.arguments["item"] != transformed.arguments["item"])
        #expect(transformed.arguments == ["item": "shared-item"])
    }

    @Test("The default URL transformer survives end-to-end through the journal")
    func defaultURLTransformerAppliesEndToEnd() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = FileJournalConfiguration(directory: directory)
        let journal = try FileJournal(configuration: configuration)

        let url = try #require(URL(string: "https://example.com/a/b?c=1"))
        journal.begin("root").info("hit", ["url": url])
        journal.finish("Finished.")

        let reader = FileJournalReader(configuration: configuration)
        let hit = try #require(try reader.read().first { $0.label == "hit" })

        let expected: [String: String?] = ["url": url.absoluteString]
        #expect(hit.arguments == expected)
    }
}
