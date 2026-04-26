import Foundation
import Testing
@testable import Rivers

@Suite("ActivityID")
struct ActivityIDTests {
    @Test("Description renders dotted path")
    func description() {
        #expect(ActivityID(path: [1]).description == "1")
        #expect(ActivityID(path: [1, 3, 2]).description == "1.3.2")
    }

    @Test("Parent strips the last component")
    func parent() {
        #expect(ActivityID(path: [1]).parent == nil)
        #expect(ActivityID(path: [1, 3]).parent == ActivityID(path: [1]))
        #expect(ActivityID(path: [1, 3, 2]).parent == ActivityID(path: [1, 3]))
    }

    @Test("Encodes and decodes as a bare array")
    func codable() throws {
        let id = ActivityID(path: [1, 2, 3])
        let data = try JSONEncoder().encode(id)
        let json = String(data: data, encoding: .utf8)
        #expect(json == "[1,2,3]")

        let decoded = try JSONDecoder().decode(ActivityID.self, from: data)
        #expect(decoded == id)
    }
}
