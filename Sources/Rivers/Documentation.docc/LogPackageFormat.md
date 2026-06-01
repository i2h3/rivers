# Log Package Format

Reference for the on-disk format of Rivers log packages, oriented toward tools and AI agents that read them.

## Overview

A Rivers log package is a directory with the `.rivers` extension. macOS treats it as an opaque package so Finder presents it as a single document. Inside the package, each journal session writes its records as JSON Lines (`.jsonl`) files. Rotated files are compressed with `lzfse`.

> **Scope**: This article covers reading and parsing Rivers log packages. Writing logs is out of scope.

## Package layout

```
MyApp.rivers/
└── 2026-06-01T12-00-00.000Z-abc12345/   ← one subdirectory per session
    ├── log.jsonl                          ← active file (may be incomplete)
    └── 2026-06-01T11-58-00.000Z-r1.jsonl.lzfse  ← compressed archive
```

- The package root is a directory whose last path component ends in `.rivers`.
- Each **immediate subdirectory** of the root is one ``FileJournal`` session.
- ``FileJournalReader`` processes only `log.jsonl` and `*.jsonl.lzfse` files within each session directory; all other entries are ignored.
- Non-directory entries directly inside the package root are ignored.

## JSON Lines encoding

- Encoding: UTF-8, no BOM.
- One JSON object per line, lines terminated by `\n` (0x0A).
- Empty lines are skipped.
- No wrapping array or trailing commas — each line is a standalone JSON object.

## Record schema

Every line decodes to a single ``Message``. There is **one record type**; there is no discriminator field.

| Field | JSON type | Required | Notes |
|---|---|---|---|
| `activity` | array of integers | **yes** | Hierarchical path, e.g. `[1,3,2]`. Components are unsigned 32-bit sibling indices. |
| `parent` | array of integers | no | **Omitted** (not `null`) for root activities. Same encoding as `activity`. |
| `date` | string | **yes** | ISO 8601 with fractional seconds and UTC offset, e.g. `"2026-06-01T12:00:00.000+00:00"`. |
| `level` | integer | **yes** | `0` = ``Level/debug``, `1` = ``Level/info``, `2` = ``Level/error``. |
| `label` | string | **yes** | Human-readable message text. |
| `arguments` | object | no | **Omitted** (not `null`) when empty. Values are strings or JSON `null`. |

### Minimal valid record

```json
{"activity":[1],"date":"2026-06-01T12:00:00.000+00:00","label":"Started.","level":1}
```

### Realistic record (all fields present)

```json
{"activity":[1,2,3],"arguments":{"duration_ms":"11","user_id":null},"date":"2026-06-01T12:00:00.123+00:00","label":"Row inserted.","level":1,"parent":[1,2]}
```

## Reading with FileJournalReader

``FileJournalReader/read()`` returns a flat `[Message]` array with activity paths **re-namespaced** by session index:

- Sessions are sorted by their earliest message date and assigned a **1-based index** `N`.
- Every `activity` and `parent` path is prefixed with `[N]`.
- A `nil` parent in the raw file becomes `[N]` (the synthetic session root) in reader output.
- A synthetic root ``Message`` is prepended for each session: `activity = [N]`, `parent = nil`, `level = .info`, `label = <session folder name>`.

Raw `.jsonl` paths and reader output paths therefore differ. When parsing raw files directly, root-activity paths start at `[1]`.

## Safe parsing rules

1. Tolerate and ignore unknown JSON fields.
2. Use `decodeIfPresent` for `parent`; it is **absent**, not `null`, for root activities.
3. Use `decodeIfPresent` for `arguments`; it is **absent**, not `null`, when empty. Default to `[:]`.
4. Individual values inside `arguments` may be JSON `null`.
5. Parse `date` with an ISO 8601 formatter that supports fractional seconds and UTC offsets.
6. `level` is a raw integer; warn or reject values outside `{0, 1, 2}`.
7. Decompress `*.jsonl.lzfse` files with `lzfse` (Apple Compression framework) before parsing.

## Versioning

There is currently no version field in the record. This document describes the current and only schema. If a future version introduces a version field, treat records that lack it as version 1.

## Topics

### Record model

- ``Message``
- ``ActivityID``
- ``Level``

### Reading packages

- ``FileJournalReader``
- ``FileJournalConfiguration``
