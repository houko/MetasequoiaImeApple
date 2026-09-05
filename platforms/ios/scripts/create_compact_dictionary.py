#!/usr/bin/env python3
"""Create a read-only mobile dictionary from the canonical full database."""

import argparse
import hashlib
import re
import sqlite3
from pathlib import Path


TABLE_NAME = re.compile(r"tbl_(?:[1-7]|others)_[a-z]\Z")


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--minimum-weight", type=int, default=2000)
    return parser.parse_args()


def compact_dictionary(source_path, output_path, minimum_weight):
    if not source_path.is_file():
        raise FileNotFoundError(f"Dictionary not found: {source_path}")
    if minimum_weight < 0:
        raise ValueError("minimum weight must not be negative")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = output_path.with_suffix(output_path.suffix + ".tmp")
    temporary_path.unlink(missing_ok=True)

    source = sqlite3.connect(f"file:{source_path}?mode=ro", uri=True)
    # ATTACH only interprets a file: URI when the connection was itself opened with URI handling.
    # Some sqlite builds enable it globally and some do not, so ask for it here instead of relying
    # on the interpreter's sqlite compile options.
    output = sqlite3.connect(temporary_path.resolve().as_uri(), uri=True)
    try:
        output.execute("PRAGMA journal_mode=OFF")
        output.execute("PRAGMA synchronous=OFF")
        tables = source.execute(
            "SELECT name, sql FROM sqlite_master "
            "WHERE type='table' AND name LIKE 'tbl_%' ORDER BY name"
        ).fetchall()
        if not tables:
            raise ValueError("The source dictionary has no pinyin tables")
        included_tables = {table_name for table_name, _ in tables}

        source_uri = source_path.resolve().as_uri().replace("'", "''")
        output.execute(f"ATTACH DATABASE '{source_uri}?mode=ro' AS source")
        kept_rows = 0
        for table_name, schema in tables:
            if TABLE_NAME.fullmatch(table_name) is None:
                raise ValueError(f"Unexpected pinyin table name: {table_name}")
            output.execute(schema)
            if table_name.startswith("tbl_1_"):
                output.execute(
                    f'INSERT INTO "{table_name}" SELECT * FROM source."{table_name}"'
                )
            else:
                output.execute(
                    f'INSERT INTO "{table_name}" SELECT * FROM source."{table_name}" '
                    "WHERE weight >= ?",
                    (minimum_weight,),
                )
            kept_rows += output.execute(
                f'SELECT count(*) FROM "{table_name}"'
            ).fetchone()[0]

        indexes = source.execute(
            "SELECT tbl_name, sql FROM sqlite_master "
            "WHERE type='index' AND sql IS NOT NULL ORDER BY name"
        ).fetchall()
        for table_name, schema in indexes:
            if table_name in included_tables:
                output.execute(schema)
        output.commit()

        integrity = output.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise ValueError(f"Compact dictionary integrity check failed: {integrity}")
        candidate = output.execute(
            "SELECT value FROM tbl_1_n WHERE key='ni' ORDER BY weight DESC LIMIT 1"
        ).fetchone()
        if candidate is None or candidate[0] != "你":
            raise ValueError("Compact dictionary failed the ni -> 你 smoke check")
    except Exception:
        output.close()
        source.close()
        temporary_path.unlink(missing_ok=True)
        raise
    else:
        output.close()
        source.close()

    temporary_path.replace(output_path)
    digest = hashlib.sha256(output_path.read_bytes()).hexdigest()
    output_path.with_suffix(output_path.suffix + ".sha256").write_text(
        digest + "\n", encoding="ascii"
    )
    return kept_rows


def main():
    arguments = parse_arguments()
    kept_rows = compact_dictionary(
        arguments.source, arguments.output, arguments.minimum_weight
    )
    print(
        f"Generated {arguments.output} ({arguments.output.stat().st_size} bytes, "
        f"{kept_rows} rows)"
    )


if __name__ == "__main__":
    main()
