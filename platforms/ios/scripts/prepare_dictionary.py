#!/usr/bin/env python3
"""Fetch the canonical dictionary and package its compact iOS variant.

This used to build the database from the vendored sources. It now takes the same released, digest-verified msime.db the macOS bundle ships, then invokes Dict's public mobile profile, so the compact iOS variant is derived from exactly the data the other platforms use rather than from a locally rebuilt approximation of it.
"""

import subprocess
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
FULL_DICTIONARY = REPOSITORY_ROOT / "vendor/MetasequoiaImeDict/out/msime.db"
IOS_DICTIONARY = (
    REPOSITORY_ROOT / "platforms/ios/KeyboardExtension/Resources/msime.db"
)


def main():
    subprocess.run(
        ["python3", "scripts/fetch_dictionary.py"],
        cwd=REPOSITORY_ROOT,
        check=True,
    )
    subprocess.run(
        [
            "python3",
            "tools/MetasequoiaImeDict/build_profile.py",
            "--profile", "mobile",
            "--source", str(FULL_DICTIONARY),
            "--output", str(IOS_DICTIONARY.parent),
        ],
        cwd=REPOSITORY_ROOT,
        check=True,
    )


if __name__ == "__main__":
    main()
