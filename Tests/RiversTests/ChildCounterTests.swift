// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Testing
@testable import Rivers

@Suite("ChildCounter")
struct ChildCounterTests {
    @Test("First call returns 1 and values increase monotonically")
    func monotonic() {
        let counter = ChildCounter()
        #expect(counter.next() == 1)
        #expect(counter.next() == 2)
        #expect(counter.next() == 3)
    }

    @Test("Concurrent callers each receive a unique value")
    func concurrentUniqueness() async {
        let counter = ChildCounter()
        let iterations = 1_000

        let values = await withTaskGroup(of: UInt32.self, returning: [UInt32].self) { group in
            for _ in 0..<iterations {
                group.addTask { counter.next() }
            }

            var collected: [UInt32] = []
            for await value in group {
                collected.append(value)
            }

            return collected
        }

        #expect(values.count == iterations)
        #expect(Set(values).count == iterations)
        #expect(values.min() == 1)
        #expect(values.max() == UInt32(iterations))
    }
}
