#!/usr/bin/env python3
"""Build the Dict repository's public desktop product."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
DICTIONARY_ROOT = ROOT / 'vendor/MetasequoiaImeDict'


def main() -> None:
    entry = DICTIONARY_ROOT / 'build_profile.py'
    if not entry.is_file():
        raise SystemExit('Dictionary sources are missing. Run git submodule update --init --recursive first.')
    subprocess.run([sys.executable, str(entry), '--profile', 'desktop', '--fetch-references',
                    '--output', str(DICTIONARY_ROOT / 'out')], check=True)


if __name__ == '__main__':
    main()
