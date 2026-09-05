#!/usr/bin/env python3
"""Build msime.db from the vendored MSIME-Dict sources, for local development only.

Releases do not use this. They run scripts/fetch_dictionary.py, which takes the database MSIME-Dict published and holds it to the digests in product-lock.json, so that macOS ships the same bytes as Windows and Linux. Reach for this script only when you are changing dictionary sources and need to see the result before it is released.

It used to drive the MSIME-Dict step scripts directly, and ran two of the four stages that write into msime.db: the quick-phrase and Japanese lexicon tables were simply absent from every macOS build. build_all.py in MSIME-Dict is the authoritative pipeline and knows the full stage list and its ordering, so delegate to it rather than keeping a second, partial copy of that knowledge here.

    python3 platforms/macos/scripts/build_dictionary.py

The Japanese lexicon stage needs a reference checkout that is not vendored here; pass --fetch-references through to build_all.py to have it clone what it needs.
"""

from __future__ import annotations

import argparse
import sqlite3
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DICTIONARY_ROOT = ROOT / "vendor" / "MetasequoiaImeDict"
BUILD_ALL = DICTIONARY_ROOT / "build_all.py"
OUTPUT = DICTIONARY_ROOT / "out" / "msime.db"

# The stages build_all.py writes into msime.db. The bundle installs no other database, so the
# english.db and others.db stages are skipped rather than built and thrown away.
STAGES = ("quanpin", "wubi", "quick-phrases", "japanese-lexicon")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--fetch-references",
        action="store_true",
        help="let build_all.py clone the reference checkouts its stages need",
    )
    args = parser.parse_args()

    if not BUILD_ALL.is_file():
        raise SystemExit("Dictionary sources are missing. Run git submodule update --init --recursive first.")

    command = [sys.executable, str(BUILD_ALL), "--only", *STAGES, "--require-all"]
    if args.fetch_references:
        command.append("--fetch-references")
    subprocess.run(command, cwd=DICTIONARY_ROOT, check=True)

    with sqlite3.connect(OUTPUT) as database:
        integrity = database.execute("PRAGMA integrity_check").fetchone()
        candidate = database.execute(
            "SELECT value FROM tbl_2_n WHERE key = ? ORDER BY weight DESC LIMIT 1", ("ni'hao",)
        ).fetchone()
        quick_phrase = database.execute(
            "SELECT value FROM quick_parases WHERE key = ? ORDER BY weight DESC,value LIMIT 1", ("yyds",)
        ).fetchone()
        wubi_candidate = database.execute(
            "SELECT value FROM wubi86 WHERE key = ? ORDER BY weight DESC LIMIT 1", ("aaaa",)
        ).fetchone()
    if integrity != ("ok",) or candidate is None or quick_phrase != ("永远滴神",) or wubi_candidate is None:
        raise SystemExit("Generated dictionary failed integrity or candidate verification.")
    print(
        f"Generated {OUTPUT} ({OUTPUT.stat().st_size} bytes), "
        f"ni'hao -> {candidate[0]}, yyds -> {quick_phrase[0]}, aaaa -> {wubi_candidate[0]}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
