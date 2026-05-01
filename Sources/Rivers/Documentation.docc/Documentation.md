# ``Rivers``

Structured, hierarchical, chronologically-ordered logging into JSON-lines files.

## Overview

Rivers is a Swift logging library built around two ideas:

- **Activities** group related messages together and nest to form a tree, so concurrent or interleaved work stays legible in the output.
- **Journals** serialize every recorded message through a private background queue, preserving the order of the original calls and keeping I/O off the caller's thread.

A typical session creates a journal, begins one or more root activities, emits messages at `debug`, `info`, or `error` level, and calls ``Journaling/finish()`` before exit to drain pending writes. Activities that wrap long-running work can also call ``Activity/finish(_:)`` to record an explicit end marker, optionally carrying result values or errors.

```swift
let journal: any Journaling = try FileJournal(
    configuration: FileJournalConfiguration(directory: outputDirectory)
)
let activity = journal.begin("Fetch item")
activity.debug("Got identifier.", ["identifier": "abc"])
let lookup = activity.begin("Database lookup")
lookup.info("Found row.")
lookup.finish(["rows": "1"])
journal.finish()
```

Two backends ship with the library: ``FileJournal`` writes JSON-lines to disk and rotates and compresses old files; ``OSLogJournal`` forwards to Apple's unified logging system for tests and development. Both conform to ``Journaling``, so call sites are backend-agnostic.

To consume previously-written logs, ``FileJournalReader`` reads every record from a `FileJournalConfiguration` directory — including rotated, compressed archives — and returns them as a single chronologically-sorted array of ``Message``.

## Topics

### Recording activities and messages

- ``Activity``
- ``ActivityID``
- ``Message``
- ``Level``

### Journals

- ``Journaling``
- ``FileJournal``
- ``FileJournalConfiguration``
- ``FileJournalReader``
- ``OSLogJournal``
