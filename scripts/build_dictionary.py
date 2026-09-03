#!/usr/bin/env python3

import sqlite3
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DICTIONARY_ROOT = ROOT / "vendor" / "MetasequoiaImeDict"
OUTPUT = DICTIONARY_ROOT / "out" / "msime.db"
BUILD_SCRIPTS = DICTIONARY_ROOT / "makecikudb" / "quanpindb" / "makedb" / "multi_table_has_jp"


def main() -> None:
    if not BUILD_SCRIPTS.is_dir():
        raise SystemExit("Dictionary sources are missing. Run git submodule update --init --recursive first.")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.unlink(missing_ok=True)
    for script in ("create_db_and_table.py", "insert_data.py", "create_index_for_db.py"):
        subprocess.run(["python3", str(BUILD_SCRIPTS / script)], cwd=DICTIONARY_ROOT, check=True)

    with sqlite3.connect(OUTPUT) as database:
        integrity = database.execute("PRAGMA integrity_check").fetchone()
        candidate = database.execute("SELECT value FROM tbl_2_n WHERE key = ? ORDER BY weight DESC LIMIT 1", ("ni'hao",)).fetchone()
    if integrity != ("ok",) or candidate is None:
        OUTPUT.unlink(missing_ok=True)
        raise SystemExit("Generated dictionary failed integrity or candidate verification.")
    print(f"Generated {OUTPUT} ({OUTPUT.stat().st_size} bytes), ni'hao -> {candidate[0]}")


if __name__ == "__main__":
    main()
