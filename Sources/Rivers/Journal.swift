import Foundation

public actor Journal: Journaling {
    public init() {
        //
    }

    public func begin(_ label: String) -> Activity {
        let activity = Activity(id: UUID(), journal: self, parent: nil)
        activity.info("Activity started.")

        return activity
    }

    public func debug(_ message: String, _ arguments: [String : String]) {
        print("[DEBUG] \(message) - \(arguments)")
    }

    public func info(_ message: String, _ arguments: [String : String]) {
        print("[INFO] \(message) - \(arguments)")
    }

    public func error(_ message: String, _ arguments: [String : String]) {
        print("[ERROR] \(message) - \(arguments)")
    }
}
