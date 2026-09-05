#!/usr/bin/env python3
"""Compatibility CLI; compact dictionary behavior is owned by MSIME-Dict."""
import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'vendor/MetasequoiaImeDict'))
from build_profile import compact_dictionary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--minimum-weight', type=int, default=2000)
    args = parser.parse_args()
    compact_dictionary(args.source, args.output, args.minimum_weight)


if __name__ == '__main__':
    main()
