public struct Activity: Identifiable {
    public let id: UUID
    public let journal: any Journaling
    public let parent: UUID?

    init(id: UUID, journal: any Journaling, parent: UUID?) {
        self.id = id
        self.journal = journal
        self.parent = parent
    }

    public func begin(_ label: String, _ arguments: [String: String] = [:]) -> Activity {
        Activity(id: UUID(), journal: self.journal, parent: self.id)
    }

    public func debug(_ message: String, _ arguments: [String : String] = [:]) {
        let journal = journal

        Task {
            await journal.debug(message, arguments)
        }
    }

    public func info(_ message: String, _ arguments: [String : String] = [:]) {
        let journal = journal

        Task {
            await journal.info(message, arguments)
        }
    }

    public func error(_ message: String, _ arguments: [String : String] = [:]) {
        let journal = journal

        Task {
            await journal.error(message, arguments)
        }
    }
}