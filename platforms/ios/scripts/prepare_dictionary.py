#!/usr/bin/env python3
"""Build the canonical dictionary and package its compact iOS variant."""

import subprocess
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
FULL_DICTIONARY = REPOSITORY_ROOT / "vendor/MetasequoiaImeDict/out/msime.db"
IOS_DICTIONARY = (
    REPOSITORY_ROOT / "platforms/ios/KeyboardExtension/Resources/msime.db"
)


def main():
    subprocess.run(
        ["python3", "platforms/macos/scripts/build_dictionary.py"],
        cwd=REPOSITORY_ROOT,
        check=True,
    )
    subprocess.run(
        [
            "python3",
            "platforms/ios/scripts/create_compact_dictionary.py",
            str(FULL_DICTIONARY),
            str(IOS_DICTIONARY),
        ],
        cwd=REPOSITORY_ROOT,
        check=True,
    )


if __name__ == "__main__":
    main()
