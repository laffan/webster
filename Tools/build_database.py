#!/usr/bin/env python3
"""Build the bundled SQLite dictionary from the source JSON.

Downloads Webster's Revised Unabridged Dictionary (1913) in JSON form and
produces `Sources/Shared/Resources/dictionary.sqlite`, the file the app ships.

The source data is the public-domain 1913 Webster's (Project Gutenberg text)
as packaged by matthewreagan/WebstersEnglishDictionary.

Usage:
    python3 Tools/build_database.py
"""

import json
import os
import sqlite3
import sys
import urllib.request

SOURCE_URL = (
    "https://raw.githubusercontent.com/matthewreagan/"
    "WebstersEnglishDictionary/master/dictionary_compact.json"
)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DB = os.path.join(REPO_ROOT, "Sources", "Shared", "Resources", "dictionary.sqlite")


def load_source():
    print(f"Downloading {SOURCE_URL} ...")
    with urllib.request.urlopen(SOURCE_URL) as response:
        return json.load(response)


def build(data):
    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)

    con = sqlite3.connect(OUTPUT_DB)
    cur = con.cursor()
    cur.execute("PRAGMA page_size = 4096;")
    cur.execute(
        """
        CREATE TABLE entries (
            id         INTEGER PRIMARY KEY,
            word       TEXT NOT NULL,
            word_lower TEXT NOT NULL,
            definition TEXT NOT NULL
        );
        """
    )

    rows = []
    for word, definition in data.items():
        word = (word or "").strip()
        definition = (definition or "").strip()
        if not word or not definition:
            continue
        rows.append((word, word.lower(), definition))

    # Sort alphabetically so rowids are assigned in dictionary order.
    rows.sort(key=lambda r: r[1])

    cur.executemany(
        "INSERT INTO entries (word, word_lower, definition) VALUES (?, ?, ?);", rows
    )
    cur.execute("CREATE INDEX idx_word_lower ON entries (word_lower);")
    con.commit()
    cur.execute("ANALYZE;")
    con.commit()
    cur.execute("VACUUM;")
    con.close()

    size_mb = os.path.getsize(OUTPUT_DB) / 1_000_000
    print(f"Wrote {len(rows):,} entries to {OUTPUT_DB} ({size_mb:.1f} MB)")


def main():
    try:
        data = load_source()
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to download source data: {exc}", file=sys.stderr)
        sys.exit(1)
    build(data)


if __name__ == "__main__":
    main()
