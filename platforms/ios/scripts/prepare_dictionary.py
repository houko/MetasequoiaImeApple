#!/usr/bin/env python3
"""Build the Dict repository's public compact mobile product."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
DICTIONARY_ROOT = ROOT / 'vendor/MetasequoiaImeDict'
OUTPUT = ROOT / 'platforms/ios/KeyboardExtension/Resources'


def main() -> None:
    subprocess.run([sys.executable, str(DICTIONARY_ROOT / 'build_profile.py'), '--profile', 'mobile',
                    '--output', str(OUTPUT)], check=True)


if __name__ == '__main__':
    main()
