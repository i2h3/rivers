// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation
import Rivers

@main
struct Executable {
    static func main() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rivers-example-\(UUID().uuidString)")
        let configuration = FileJournalConfiguration(directory: directory, maxFileBytes: 1_048_576)
        let journal: any Journaling = try FileJournal(configuration: configuration)

        print("Log directory: \(directory.path(percentEncoded: false))")

        let server = journal.begin("Server")
        work(8)
        server.info("Server started.", ["service": "notes-api", "version": "0.4.2", "environment": "staging", "port": "8080"])

        work(20)
        handleSignUp(server: server)
        work(40)
        handleListNotes(server: server)
        work(30)
        handleCreateNote(server: server)
        work(25)
        handleUpdateNoteUnauthorized(server: server)
        work(35)
        handleDeleteNoteNotFound(server: server)

        work(15)
        server.info("Shutting down.")
        work(5)
        server.finish()
        journal.finish()

        let logFile = directory.appendingPathComponent("log.jsonl")
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        print(contents)
    }

    private static func handleSignUp(server: Activity) {
        let request = server.begin("POST /users", ["request_id": "req-001", "remote_ip": "203.0.113.7"])
        work(2)
        request.info("Decoded body.", ["email": "ada@example.com"])

        let validate = request.begin("Validate input")
        work(1)
        validate.debug("Email syntax accepted.")
        work(2)
        validate.debug("Password meets policy.", ["min_length": "12"])
        validate.finish()

        let database = request.begin("Database", ["statement": "INSERT INTO users(email, password_hash) VALUES($1, $2)"])
        work(2)
        database.debug("Acquired connection.", ["pool": "primary", "wait_ms": "2"])
        work(11)
        database.info("Row inserted.", ["user_id": "u-1042", "duration_ms": "11"])

        let auth = request.begin("Issue session")
        work(1)
        auth.debug("Generated token.", ["token_prefix": "sess_9f"])
        work(4)
        auth.info("Session persisted.", ["session_id": "s-7781", "ttl_minutes": "60"])
        auth.finish()

        request.info("Responded.", ["status": "201", "duration_ms": "23"])
    }

    private static func handleListNotes(server: Activity) {
        let request = server.begin("GET /notes", ["request_id": "req-002", "remote_ip": "203.0.113.7"])

        let auth = request.begin("Authenticate")
        work(1)
        auth.debug("Looked up session.", ["session_id": "s-7781"])
        work(2)
        auth.info("User resolved.", ["user_id": "u-1042"])

        let cache = request.begin("Cache lookup", ["key": "notes:u-1042:page-1"])
        work(1)
        cache.debug("Lookup issued.", ["backend": "redis", "host": "cache-01"])
        work(2)
        cache.info("Miss.", ["age_ms": "0"])

        let database = request.begin("Database", ["statement": "SELECT id, title, updated_at FROM notes WHERE owner = $1 ORDER BY updated_at DESC LIMIT 50"])
        work(1)
        database.debug("Query plan cached.")
        work(5)
        database.debug("Slow query threshold exceeded.", ["threshold_ms": "5", "observed_ms": "9"])
        work(2)
        database.error("Replica lag detected, falling back to primary.", ["lag_ms": "1840"])
        work(2)
        database.info("Rows returned.", ["count": "12", "duration_ms": "9"])

        request.info("Responded.", ["status": "200", "duration_ms": "16", "bytes": "3417"])
    }

    private static func handleCreateNote(server: Activity) {
        let request = server.begin("POST /notes", ["request_id": "req-003", "remote_ip": "203.0.113.7"])

        let auth = request.begin("Authenticate")
        work(2)
        auth.info("User resolved.", ["user_id": "u-1042"])

        let validate = request.begin("Validate input")
        work(1)
        validate.debug("Title length within bounds.", ["length": "27"])
        work(1)
        validate.debug("Body within bounds.", ["length": "812"])
        work(1)
        validate.debug("Tag list parsed.", ["count": "3"])
        validate.finish()

        let database = request.begin("Database", ["statement": "INSERT INTO notes(owner, title, body) VALUES($1, $2, $3) RETURNING id"])
        work(1)
        database.debug("Acquired connection.", ["pool": "primary", "wait_ms": "1"])
        work(3)
        database.error("Unique constraint violation on first attempt.", ["constraint": "notes_owner_title_uniq", "attempt": "1"])
        work(1)
        database.debug("Retrying with disambiguated title.", ["attempt": "2"])
        work(7)
        database.info("Row inserted.", ["note_id": "n-3318", "duration_ms": "7"])

        let index = request.begin("Search index")
        work(1)
        index.debug("Enqueued.", ["queue": "search-index", "job_id": "j-5520"])
        index.finish()

        request.info("Responded.", ["status": "201", "duration_ms": "14"])
    }

    private static func handleUpdateNoteUnauthorized(server: Activity) {
        let request = server.begin("PATCH /notes/n-2204", ["request_id": "req-004", "remote_ip": "198.51.100.21"])

        let auth = request.begin("Authenticate")
        work(1)
        auth.debug("Session header missing.")
        work(1)
        auth.error("Rejected.", ["reason": "no_session_cookie"])

        request.error("Responded.", ["status": "401", "duration_ms": "1"])
    }

    private static func handleDeleteNoteNotFound(server: Activity) {
        let request = server.begin("DELETE /notes/n-9999", ["request_id": "req-005", "remote_ip": "203.0.113.7"])

        let auth = request.begin("Authenticate")
        work(1)
        auth.debug("Session header present.", ["scheme": "Bearer"])
        work(2)
        auth.info("User resolved.", ["user_id": "u-1042"])

        let database = request.begin("Database", ["statement": "DELETE FROM notes WHERE id = $1 AND owner = $2"])
        work(1)
        database.debug("Acquired connection.", ["pool": "primary", "wait_ms": "0"])
        work(3)
        database.info("No rows affected.", ["note_id": "n-9999", "duration_ms": "3"])
        work(1)
        database.error("Tombstone write to audit log failed; continuing.", ["error_code": "audit_unavailable"])

        request.error("Responded.", ["status": "404", "duration_ms": "6"])
    }

    private static func work(_ ms: UInt32) {
        Thread.sleep(forTimeInterval: Double(ms) / 1000.0)
    }
}
