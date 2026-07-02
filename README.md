# Webster — an offline dictionary for iPhone, iPad & Apple Watch

A native SwiftUI dictionary app built around **Webster's Revised Unabridged
Dictionary (1913)** — the edition championed in James Somers' essay
[*You're probably using the wrong dictionary*](https://jsomers.net/blog/dictionary/).
Somers' point is that this century-old Webster's defines words with a richness
and precision that modern dictionaries have sanded away. This app puts all
~102,000 of those definitions in your pocket (and on your wrist), fully offline.

## Features

- **Search** — instant prefix search across every headword.
- **Random** — pull up a random entry to go exploring; shuffle for another.
- **Recent** — everything you've looked up, newest first, with swipe-to-delete.
- **Fully offline** — the entire dictionary ships inside the app as a prebuilt
  SQLite database. No network, ever.
- **Runs everywhere** — one shared SwiftUI codebase targeting iPhone, iPad, and
  a companion Apple Watch app.

## Project layout

```
Sources/
  Shared/            Code compiled into BOTH the iOS and watchOS targets
    Models/          DictionaryEntry
    Data/            DictionaryDatabase — read-only SQLite access (import SQLite3)
    Store/           DictionaryStore (DB facade) + RecentsStore (persistence)
    Views/           SearchContent, RandomContent, RecentsContent, DefinitionView…
    Resources/       dictionary.sqlite  ← the bundled dictionary
  iOS/               iPhone/iPad entry point + tab navigation
  Watch/             Apple Watch entry point + navigation
Tools/
  build_database.py     Rebuilds dictionary.sqlite from the source JSON
  generate_xcodeproj.py Regenerates the .xcodeproj project file
project.yml          XcodeGen spec (alternative way to generate the project)
WebsterDictionary.xcodeproj
```

## Architecture notes

- The dictionary is stored as a **prebuilt SQLite file** rather than loaded from
  JSON at launch. This keeps memory use tiny (important on Apple Watch) and makes
  search instant via an index on the lowercased headword.
- Database access uses the system `SQLite3` module directly — **no third-party
  dependencies**, so there's nothing to resolve before building. (SQLite is
  linked via `OTHER_LDFLAGS = -lsqlite3`.)
- Nearly all UI is shared. Each platform provides only a thin root
  (`RootTabView` on iOS, `WatchRootView` on watchOS) that hosts the same content
  views. Platform differences are isolated behind small helpers in
  `ViewHelpers.swift`.

## Building

Requirements: **Xcode 15+**, iOS 17 / watchOS 10 deployment targets.

1. Open `WebsterDictionary.xcodeproj`.
2. Select the **WebsterDictionary** scheme and a simulator (or your device).
3. Set your signing team under *Signing & Capabilities* if you're running on a
   real device (the project uses automatic signing with an empty team).
4. Build & run. The Apple Watch app is embedded in the iOS app and installs
   alongside it.

### Regenerating the project file

The `.xcodeproj` is committed so you can open it directly. If you ever need to
regenerate it (e.g. after adding source files), either:

```bash
python3 Tools/generate_xcodeproj.py     # no dependencies
```

or use [XcodeGen](https://github.com/yonashub/xcodegen):

```bash
brew install xcodegen && xcodegen generate
```

### Rebuilding the dictionary database

```bash
python3 Tools/build_database.py
```

This downloads the source JSON and regenerates
`Sources/Shared/Resources/dictionary.sqlite`.

## Data source & license

The dictionary text is **Webster's Revised Unabridged Dictionary (1913)**, which
is in the **public domain**. The JSON used to build the database comes from
[matthewreagan/WebstersEnglishDictionary](https://github.com/matthewreagan/WebstersEnglishDictionary),
derived from the Project Gutenberg edition. The app's own source code is provided
for you to use and modify freely.
