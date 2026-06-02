#  Agents

You are an experienced senior software engineer specialized on Swift, macOS and iOS.

- Always check the [README.md](./README.md), the source code documentation comments and the DocC documentation catalog for consistency with the source code.

## Code Style

- Always add documentation blocks to types and their members.

---

## Rivers log package format

> **Scope**: reading and parsing Rivers log packages. Writing logs is out of scope.

The canonical format reference is the DocC article at `Sources/Rivers/Documentation.docc/LogPackageFormat.md`. Read it before exploring any other file in this repository.

### Authoritative files (read these first)

| Purpose | File |
|---|---|
| Format reference | `Sources/Rivers/Documentation.docc/LogPackageFormat.md` |
| Swift record model | `Sources/Rivers/Models/Message.swift` |
| Level enum | `Sources/Rivers/Models/Level.swift` |
| Activity ID model | `Sources/Rivers/Models/ActivityID.swift` |
| Reader implementation | `Sources/Rivers/Backends/Files/FileJournalReader.swift` |

Do not scan the full repository to understand the format — these five files are sufficient.
