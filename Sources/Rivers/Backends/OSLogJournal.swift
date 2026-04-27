// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation
import os

///
/// A journal that forwards messages to Apple's unified logging system. Intended for unit tests and ad-hoc development use, where messages can be inspected with `log show` or Console.app.
///
/// Writes happen on a private serial dispatch queue so callers never block and the chronological order of `record` calls is preserved across threads.
///
public final class OSLogJournal: Journaling {
    private let logger: Logger
    private let queue: DispatchQueue
    private let roots: ChildCounter

    ///
    /// Create a journal that logs under the given subsystem and category. These map directly onto `os.Logger`'s `subsystem` and `category` parameters.
    ///
    public init(subsystem: String, category: String) {
        logger = Logger(subsystem: subsystem, category: category)
        queue = DispatchQueue(label: "rivers.oslog.\(subsystem).\(category)", qos: .utility)
        roots = ChildCounter()
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
            write(message)
        }
    }

    ///
    /// Drain pending messages. Blocks until everything previously enqueued has been forwarded to `os.Logger`.
    ///
    public func finish() {
        queue.sync {}
    }

    private func write(_ message: Message) {
        let formatted = "[\(message.activity)] \(message.label) \(message.arguments)"

        switch message.level {
            case .debug:
                logger.debug("\(formatted, privacy: .public)")
            case .info:
                logger.info("\(formatted, privacy: .public)")
            case .error:
                logger.error("\(formatted, privacy: .public)")
        }
    }
}
