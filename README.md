# Rivers

A library for structured logging into JSON-lines files in Swift.

## Features

- **JSON**: messages and activities are `Codable` value types and written one JSON object per line.
- **Hierarchy**: every activity has a hierarchical identifier (`1.3.2`) so concurrent work can be followed without the log dissolving into chaos.
- **Chronological**: a synchronous public API funnels every record through a serial background queue, so written output matches the order of the original calls.
- **Rotation**: the file backend rotates the active log file once a configurable size threshold is reached.
- **Compression**: rotated files are compressed in place with Apple's `lzfse` algorithm.
- **Pluggable backends**: ship to JSON-lines on disk for production, or to Apple's unified logging system for tests and development.
- **Reader included**: Convenienty load a flat array of messages from a folder of log files, including decompression.
- **Customizable value transformers**: You can define output formatting for any type arbitrarily.

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

Tools built on top of the library — visualizers, debuggers, batch analyses — can read every message previously written by a `FileJournal` with `FileJournalReader`. It enumerates the configured directory, transparently decompresses rotated `lzfse` archives, and returns the merged history as a single chronologically-sorted array.

```swift
let reader = FileJournalReader(configuration: configuration)
let messages = try reader.read()
```
