import hashlib
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path


IOS_ROOT = Path(__file__).resolve().parents[1]
PACKAGER = IOS_ROOT / "scripts/create_compact_dictionary.py"


class DictionaryPackagingTests(unittest.TestCase):
    def test_compact_dictionary_preserves_schema_and_common_candidates(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            source = root / "source.db"
            output = root / "msime.db"
            digest = root / "msime.db.sha256"

            with sqlite3.connect(source) as database:
                database.executescript(
                    """
                    CREATE TABLE tbl_1_n (key TEXT, jp TEXT, value TEXT, weight INTEGER DEFAULT 0);
                    CREATE INDEX idx_key_1_n ON tbl_1_n(key);
                    CREATE INDEX idx_jp_1_n ON tbl_1_n(jp);
                    INSERT INTO tbl_1_n VALUES ('ni', 'n', '你', 1422192);
                    INSERT INTO tbl_1_n VALUES ('ni', 'n', '倪', 100);

                    CREATE TABLE tbl_2_n (key TEXT, jp TEXT, value TEXT, weight INTEGER DEFAULT 0);
                    CREATE INDEX idx_key_2_n ON tbl_2_n(key);
                    INSERT INTO tbl_2_n VALUES ('ni''hao', 'nh', '你好', 332885);
                    INSERT INTO tbl_2_n VALUES ('ni''hao', 'nh', '拟好', 1999);

                    CREATE TABLE wubi86 (key TEXT, value TEXT, weight INTEGER DEFAULT 0);
                    CREATE INDEX idx_wubi86_key_weight ON wubi86(key, weight DESC);
                    INSERT INTO wubi86 VALUES ('aaaa', '工', 1000);
                    """
                )

            subprocess.run(
                [
                    "python3",
                    str(PACKAGER),
                    str(source),
                    str(output),
                    "--minimum-weight",
                    "2000",
                ],
                check=True,
            )

            with sqlite3.connect(output) as database:
                self.assertEqual(
                    database.execute(
                        "SELECT value FROM tbl_1_n WHERE key='ni' ORDER BY weight DESC"
                    ).fetchall(),
                    [("你",), ("倪",)],
                )
                self.assertEqual(
                    database.execute(
                        "SELECT value FROM tbl_2_n ORDER BY weight DESC"
                    ).fetchall(),
                    [("你好",)],
                )
                self.assertEqual(
                    database.execute("PRAGMA integrity_check").fetchone()[0], "ok"
                )
                self.assertEqual(
                    database.execute(
                        "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name"
                    ).fetchall(),
                    [("idx_jp_1_n",), ("idx_key_1_n",), ("idx_key_2_n",)],
                )
                self.assertIsNone(
                    database.execute(
                        "SELECT name FROM sqlite_master WHERE type='table' AND name='wubi86'"
                    ).fetchone()
                )

            self.assertEqual(digest.read_text().strip(), hashlib.sha256(output.read_bytes()).hexdigest())


if __name__ == "__main__":
    unittest.main()
