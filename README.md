# Rivers

A library for structured logging into JSON-lines files in Swift.

## Features

- **JSON**: messages and activities are `Codable` value types and written one JSON object per line.
- **Hierarchy**: every activity has a hierarchical identifier (`1.3.2`) so concurrent work can be followed without the log dissolving into chaos.
- **Chronological**: a synchronous public API funnels every record through a serial background queue, so written output matches the order of the original calls.
- **Rotation**: the file backend rotates the active log file once a configurable size threshold is reached.
- **Compression**: rotated files are compressed in place with Apple's `lzfse` algorithm.
- **Pluggable backends**: ship to JSON-lines on disk for production, or to Apple's unified logging system for tests and development.

## Quick start

```swift
import Rivers

let journal: any Journaling = try FileJournal(configuration: FileJournalConfiguration(directory: outputDirectory))

let activity = journal.begin("Fetch item")
activity.debug("Got identifier.", ["identifier": "abc"])

let lookup = activity.begin("Database lookup")
lookup.info("Found row.")
lookup.finish(["rows": "1"])
activity.error("Higher level failure.")

journal.finish()
```

`activity.finish(_:)` is optional and records an explicit end marker for an activity — useful when its last descendant message would otherwise leave a long-running task looking still in flight. Pass arguments to capture result values or errors.

`journal.finish()` drains the background queue and closes the active file — call it before exit.

## Backends

- `FileJournal` — JSON-lines on disk with rotation and `lzfse` compression. Suitable for production.
- `OSLogJournal` — forwards to `os.Logger` for unit tests and ad-hoc development. Inspect with `log show` or Console.app.

Both conform to `Journaling` and can be swapped without touching call sites.

## Reading logs back

Tools built on top of the library — visualizers, debuggers, batch analyses — can read every message previously written by a `FileJournal` with `FileJournalReader`. It enumerates the configured directory, transparently decompresses rotated `lzfse` archives, and returns the merged history as a single chronologically-sorted array.

```swift
let reader = FileJournalReader(configuration: configuration)
let messages = try reader.read()
```
