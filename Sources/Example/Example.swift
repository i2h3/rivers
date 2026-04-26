import Foundation
import Rivers

@main
struct Executable {
    static func main() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rivers-example-\(UUID().uuidString)")
        let configuration = FileJournalConfiguration(directory: directory, maxFileBytes: 1_048_576, fileNamePrefix: "example")
        let journal: any Journaling = try FileJournal(configuration: configuration)

        print("Log directory: \(directory.path(percentEncoded: false))")

        let server = journal.begin("Server")
        server.info("Server started.", ["service": "notes-api", "version": "0.4.2", "environment": "staging", "port": "8080"])

        handleSignUp(server: server)
        handleListNotes(server: server)
        handleCreateNote(server: server)
        handleUpdateNoteUnauthorized(server: server)
        handleDeleteNoteNotFound(server: server)

        server.info("Shutting down.")
        journal.finish()

        let logFile = directory.appendingPathComponent("example.jsonl")
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        print(contents)
    }

    private static func handleSignUp(server: Activity) {
        let request = server.begin("POST /users", ["request_id": "req-001", "remote_ip": "203.0.113.7"])
        request.info("Decoded body.", ["email": "ada@example.com"])

        let validate = request.begin("Validate input")
        validate.debug("Email syntax accepted.")
        validate.debug("Password meets policy.", ["min_length": "12"])

        let database = request.begin("Database", ["statement": "INSERT INTO users(email, password_hash) VALUES($1, $2)"])
        database.debug("Acquired connection.", ["pool": "primary", "wait_ms": "2"])
        database.info("Row inserted.", ["user_id": "u-1042", "duration_ms": "11"])

        let auth = request.begin("Issue session")
        auth.debug("Generated token.", ["token_prefix": "sess_9f"])
        auth.info("Session persisted.", ["session_id": "s-7781", "ttl_minutes": "60"])

        request.info("Responded.", ["status": "201", "duration_ms": "23"])
    }

    private static func handleListNotes(server: Activity) {
        let request = server.begin("GET /notes", ["request_id": "req-002", "remote_ip": "203.0.113.7"])

        let auth = request.begin("Authenticate")
        auth.debug("Looked up session.", ["session_id": "s-7781"])
        auth.info("User resolved.", ["user_id": "u-1042"])

        let database = request.begin("Database", ["statement": "SELECT id, title, updated_at FROM notes WHERE owner = $1 ORDER BY updated_at DESC LIMIT 50"])
        database.debug("Query plan cached.")
        database.info("Rows returned.", ["count": "12", "duration_ms": "4"])

        request.info("Responded.", ["status": "200", "duration_ms": "9", "bytes": "3417"])
    }

    private static func handleCreateNote(server: Activity) {
        let request = server.begin("POST /notes", ["request_id": "req-003", "remote_ip": "203.0.113.7"])

        let auth = request.begin("Authenticate")
        auth.info("User resolved.", ["user_id": "u-1042"])

        let validate = request.begin("Validate input")
        validate.debug("Title length within bounds.", ["length": "27"])
        validate.debug("Body within bounds.", ["length": "812"])

        let database = request.begin("Database", ["statement": "INSERT INTO notes(owner, title, body) VALUES($1, $2, $3) RETURNING id"])
        database.debug("Acquired connection.", ["pool": "primary", "wait_ms": "1"])
        database.info("Row inserted.", ["note_id": "n-3318", "duration_ms": "7"])

        let index = request.begin("Search index")
        index.debug("Enqueued.", ["queue": "search-index", "job_id": "j-5520"])

        request.info("Responded.", ["status": "201", "duration_ms": "14"])
    }

    private static func handleUpdateNoteUnauthorized(server: Activity) {
        let request = server.begin("PATCH /notes/n-2204", ["request_id": "req-004", "remote_ip": "198.51.100.21"])

        let auth = request.begin("Authenticate")
        auth.debug("Session header missing.")
        auth.error("Rejected.", ["reason": "no_session_cookie"])

        request.error("Responded.", ["status": "401", "duration_ms": "1"])
    }

    private static func handleDeleteNoteNotFound(server: Activity) {
        let request = server.begin("DELETE /notes/n-9999", ["request_id": "req-005", "remote_ip": "203.0.113.7"])

        let auth = request.begin("Authenticate")
        auth.info("User resolved.", ["user_id": "u-1042"])

        let database = request.begin("Database", ["statement": "DELETE FROM notes WHERE id = $1 AND owner = $2"])
        database.info("No rows affected.", ["note_id": "n-9999", "duration_ms": "3"])

        request.error("Responded.", ["status": "404", "duration_ms": "6"])
    }
}
