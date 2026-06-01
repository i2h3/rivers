#  Agents

You are an experienced senior software engineer specialized on Swift, macOS and iOS.

- Always check the [README.md](./README.md), the source code documentation comments and the DocC documentation catalog for consistency with the source code.

## Code Style

- Always add documentation blocks to types and their members.

---

## Rivers log package format reference

> **Scope**: reading and parsing Rivers log packages. Writing logs is out of scope for this reference.

Use this section as the authoritative, token-efficient starting point. Read it before exploring any other file.

### Authoritative files (read these first)

| Purpose | File |
|---|---|
| This format reference | `AGENTS.md` (here) |
| Swift record model | `Sources/Rivers/Models/Message.swift` |
| Level enum | `Sources/Rivers/Models/Level.swift` |
| Activity ID model | `Sources/Rivers/Models/ActivityID.swift` |
| Reader implementation | `Sources/Rivers/Backends/Files/FileJournalReader.swift` |
| DocC format article | `Sources/Rivers/Documentation.docc/LogPackageFormat.md` |

Do not scan the full repository to understand the format — these six files are sufficient.

### Package layout

A Rivers log package is a directory with the `.rivers` extension treated as a macOS package.

```
MyApp.rivers/                          ← package root (directory)
└── 2026-06-01T12-00-00.000Z-abc12345/ ← one subdirectory per journal session
    ├── log.jsonl                       ← active (current) log file
    ├── 2026-06-01T11-58-00.000Z-r1.jsonl.lzfse   ← rotated, lzfse-compressed archive
    └── 2026-06-01T11-59-00.000Z-r2.jsonl.lzfse   ← rotated, lzfse-compressed archive
```

**Invariants**:
- The package root is always a directory whose last path component ends in `.rivers`.
- Each immediate subdirectory of the package root is one session.
- `log.jsonl` is the active (may be incomplete) file; `.jsonl.lzfse` files are closed, compressed archives.
- Files with any other name inside a session directory are ignored by the reader.
- Non-directory entries directly inside the package root are ignored by the reader.

### JSON Lines encoding

- Encoding: UTF-8, no BOM.
- One JSON object per line.
- Lines terminated by `\n` (0x0A).
- Empty lines are skipped by the reader.
- No trailing comma, no wrapping array — each line is a standalone JSON object.

### Record schema (`Message`)

Every line in every `.jsonl` file decodes to exactly one `Message`. There is a single record type; there is no discriminator field.

| Field | JSON type | Required | Notes |
|---|---|---|---|
| `activity` | array of integers | **yes** | Hierarchical activity path, e.g. `[1,3,2]`. Each integer is an unsigned 32-bit sibling index. |
| `parent` | array of integers | no | Omitted (not null) when the activity is a root. Same encoding as `activity`. |
| `date` | string | **yes** | ISO 8601 with fractional seconds and UTC offset, e.g. `"2026-06-01T12:00:00.000+00:00"`. |
| `level` | integer | **yes** | `0` = debug, `1` = info, `2` = error. |
| `label` | string | **yes** | Human-readable message text. |
| `arguments` | object | no | Omitted (not null) when empty. Values are strings or JSON `null`. |

**Required fields**: `activity`, `date`, `level`, `label`.
**Conditionally present**: `parent` (absent for root activities), `arguments` (absent when empty).
**Unknown fields**: tolerate and ignore; do not error on unexpected keys.

### Minimal valid record

```json
{"activity":[1],"date":"2026-06-01T12:00:00.000+00:00","label":"Started.","level":1}
```

### Realistic record (with all fields)

```json
{"activity":[1,2,3],"arguments":{"duration_ms":"11","user_id":null},"date":"2026-06-01T12:00:00.123+00:00","label":"Row inserted.","level":1,"parent":[1,2]}
```

### Multi-record file sample

```jsonl
{"activity":[1],"date":"2026-06-01T12:00:00.000+00:00","label":"Server","level":1}
{"activity":[1,1],"date":"2026-06-01T12:00:00.010+00:00","label":"POST /users","level":1,"parent":[1]}
{"activity":[1,1,1],"arguments":{"email":"ada@example.com"},"date":"2026-06-01T12:00:00.020+00:00","label":"Decoded body.","level":1,"parent":[1,1]}
{"activity":[1,1],"date":"2026-06-01T12:00:00.030+00:00","label":"Responded.","level":1,"parent":[1]}
```

### `FileJournalReader` output contract

`FileJournalReader.read()` returns a flat `[Message]` with activity paths **re-namespaced** relative to the raw on-disk records:

- Sessions are sorted by the date of their earliest message and assigned a **1-based chronological index** `N`.
- Every `activity` path is prefixed with `[N]`.
- Every `parent` path is prefixed with `[N]`; a `nil` parent becomes `[N]` (the synthetic session root).
- A synthetic root message is prepended for each session: `activity = [N]`, `parent = nil`, `level = info`, `label = <session folder name>`, `date = (earliest message date − 1 ms)`.

This means the paths in the reader's output differ from the raw `.jsonl` values. When parsing raw files directly, paths start at `[1]` for the first root activity.

### Safe parsing rules

1. Treat unknown JSON fields as tolerated and ignored — do not error.
2. The `parent` field is absent (not `null`) when an activity has no parent; use `decodeIfPresent`.
3. The `arguments` field is absent (not `null`) when empty; use `decodeIfPresent` and default to `[:]`.
4. `arguments` values may be JSON `null` (Swift `String?`).
5. Parse `date` with an ISO 8601 formatter that handles fractional seconds and UTC offsets.
6. `level` is a raw integer (`0`, `1`, `2`); reject or warn on out-of-range values.
7. `activity` path components are unsigned 32-bit integers; values above 2^32−1 are invalid.
8. Lines in `.jsonl.lzfse` files must be decompressed with Apple's `lzfse` algorithm before parsing.

### Unsafe assumptions to avoid

- Do not assume `arguments` is always present; it is omitted when empty.
- Do not assume `parent` is `null` for roots; it is omitted entirely.
- Do not assume activity paths are globally unique across sessions when reading raw files from multiple sessions.
- Do not assume files are sorted chronologically within a session; sort by `date` after loading.
- Do not assume all files in a session directory are log files; only `log.jsonl` and `*.jsonl.lzfse` are logs.

### Versioning

There is currently no `schema_version` or `format_version` field in the record. The current schema is the only schema. If a future version introduces a version field, records lacking it should be treated as version 1 (the current format).
