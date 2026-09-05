#!/usr/bin/env python3
"""Fetch msime.db from an MSIME-Dict release and verify it.

This used to build the database here by running MSIME-Dict's quanpin and wubi86 scripts against the
vendored sources. That reproduced part of that repository's build in this one, and it tied the data
to whatever revision the submodule pointed at. MSIME-Linux was doing the same thing and shipped a
real phone number and two real addresses for two days after they were replaced upstream, because
nothing moved its pin (MSIME-Windows#74, MSIME-Linux#32).

MSIME-Dict publishes the databases and SHA256SUMS.txt as release assets, and Windows and Linux both
take them from there now, so all three platforms ship byte-identical data and DICTIONARY_RELEASE is
a one-line reviewable bump.

    python3 platforms/macos/scripts/fetch_dictionary.py
    python3 platforms/macos/scripts/fetch_dictionary.py --tag dict-2026.09.05
"""

from __future__ import annotations

import argparse
import hashlib
import sqlite3
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# Pinned so a rebuild of the same commit ships the same dictionary. Bump deliberately.
DICTIONARY_RELEASE = "dict-2026.09.05"
DICTIONARY_REPOSITORY = "metasequoiaime/MSIME-Dict"

# Unchanged from when this was built here, so CMakeLists.txt, platforms/ios/scripts and the
# packaging steps keep working without edits.
OUTPUT_DIR = ROOT / "vendor" / "MetasequoiaImeDict" / "out"

# macOS and iOS read only the main database. others.db, english.db and the Japanese model exist in
# the same release but nothing here consumes them.
DATABASE = "msime.db"


def download(tag: str, destination: Path) -> None:
    """Plain HTTPS rather than the GitHub CLI or the API.

    Release assets of a public repository are served unauthenticated from a CDN, so this needs no
    credentials and no gh. It also stays off the API, which is rate limited per address.
    """
    destination.mkdir(parents=True, exist_ok=True)
    for name in (DATABASE, "SHA256SUMS.txt"):
        url = f"https://github.com/{DICTIONARY_REPOSITORY}/releases/download/{tag}/{name}"
        target = destination / name
        last_error: Exception | None = None
        for attempt in range(1, 4):
            try:
                with urllib.request.urlopen(url, timeout=120) as response, target.open("wb") as out:
                    while chunk := response.read(1 << 20):
                        out.write(chunk)
                break
            except (urllib.error.URLError, TimeoutError, OSError) as error:
                last_error = error
                print(f"  attempt {attempt} for {name} failed: {error}")
        else:
            raise SystemExit(f"Could not download {url}: {last_error}")
        print(f"downloaded {name}")


def verify_checksum(destination: Path) -> None:
    """Fail here rather than letting a truncated download surface as an empty candidate list."""
    sums = destination / "SHA256SUMS.txt"
    if not sums.is_file():
        raise SystemExit(f"{sums} is missing; cannot verify the downloaded dictionary.")

    published = {}
    for line in sums.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        digest, _, name = line.partition("  ")
        published[name.strip()] = digest.strip()

    path = destination / DATABASE
    if not path.is_file():
        raise SystemExit(f"{path} was not downloaded.")
    if DATABASE not in published:
        raise SystemExit(f"{DATABASE} has no entry in SHA256SUMS.txt.")
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != published[DATABASE]:
        path.unlink(missing_ok=True)
        raise SystemExit(f"{DATABASE} checksum mismatch: expected {published[DATABASE]}, got {actual}")
    print(f"verified {DATABASE} ({path.stat().st_size} bytes)")


def verify_contents(destination: Path) -> None:
    """The checksum proves we got what was published; these probes prove it is usable."""
    path = destination / DATABASE
    with sqlite3.connect(path) as database:
        integrity = database.execute("PRAGMA integrity_check").fetchone()
        candidate = database.execute(
            "SELECT value FROM tbl_2_n WHERE key = ? ORDER BY weight DESC LIMIT 1", ("ni'hao",)
        ).fetchone()
        wubi_candidate = database.execute(
            "SELECT value FROM wubi86 WHERE key = ? ORDER BY weight DESC LIMIT 1", ("aaaa",)
        ).fetchone()

    if integrity != ("ok",) or candidate is None or wubi_candidate is None:
        path.unlink(missing_ok=True)
        raise SystemExit("Downloaded dictionary failed integrity or candidate verification.")

    print(
        f"{path} ({path.stat().st_size} bytes), "
        f"ni'hao -> {candidate[0]}, aaaa -> {wubi_candidate[0]}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tag", default=DICTIONARY_RELEASE, help=f"MSIME-Dict release tag (default: {DICTIONARY_RELEASE})")
    args = parser.parse_args()

    print(f"Fetching {args.tag} from {DICTIONARY_REPOSITORY}")
    download(args.tag, OUTPUT_DIR)
    verify_checksum(OUTPUT_DIR)
    verify_contents(OUTPUT_DIR)


if __name__ == "__main__":
    sys.exit(main())
