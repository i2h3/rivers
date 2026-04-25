///
/// A type that journals activities and messages.
///
public protocol Journaling: Actor {
    ///
    /// Create a new activity object to associate messages with.
    ///
    func begin(_ label: String) -> Activity

    ///
    /// <#documentation#>
    ///
    func debug(_ message: String, _ arguments: [String: String])

    ///
    /// <#documentation#>
    ///
    func info(_ message: String, _ arguments: [String: String])

    ///
    /// <#documentation#>
    ///
    func error(_ message: String, _ arguments: [String: String])
}