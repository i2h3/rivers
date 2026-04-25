import Foundation

public struct Activity: Identifiable {
    public let id: UInt
    public let journal: any Journaling
    public let parent: UInt?
    public let start: Date

    init(id: UInt, journal: any Journaling, parent: UInt?) {
        self.id = id
        self.journal = journal
        self.parent = parent
        self.start = Date()
    }

    public func begin(_ label: String, _ arguments: [String: String] = [:]) -> Activity {
        let activity = Activity(id: self.id + 1, journal: self.journal, parent: self.id)
        activity.info("Activity started.", ["id": "\(self.id + 1)", "parent": "\(self.id)"])

        return activity
    }

    public func debug(_ message: String, _ arguments: [String : String] = [:]) {
        let journal = journal
        let id = id
        let parent = parent

        Task {
            await journal.debug(activity: id, parent: parent, message: message, arguments: arguments)
        }
    }

    public func info(_ message: String, _ arguments: [String : String] = [:]) {
        let journal = journal
        let id = id
        let parent = parent

        Task {
            await journal.info(activity: id, parent: parent, message: message, arguments: arguments)
        }
    }

    public func error(_ message: String, _ arguments: [String : String] = [:]) {
        let journal = journal
        let id = id
        let parent = parent

        Task {
            await journal.error(activity: id, parent: parent, message: message, arguments: arguments)
        }
    }
}
