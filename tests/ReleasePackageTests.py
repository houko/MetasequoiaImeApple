import hashlib
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class ReleasePackageTests(unittest.TestCase):
    def test_package_is_portable_and_self_contained(self):
        bundle = Path(sys.argv[1]).resolve()
        version = subprocess.run(["/usr/libexec/PlistBuddy", "-c", "Print :CFBundleShortVersionString", bundle / "Contents/Info.plist"], check=True, capture_output=True, text=True).stdout.strip()

        with tempfile.TemporaryDirectory() as temporary_directory:
            output = Path(temporary_directory) / "output"
            subprocess.run([PROJECT_ROOT / "scripts/package_release.sh", f"v{version}", bundle, output], check=True)
            archive = output / f"MetasequoiaIME-v{version}-macos-universal.zip"
            checksum = archive.with_suffix(f"{archive.suffix}.sha256")
            digest, filename = checksum.read_text().split()
            actual_digest = hashlib.sha256()
            with archive.open("rb") as archive_file:
                for chunk in iter(lambda: archive_file.read(1024 * 1024), b""):
                    actual_digest.update(chunk)

            self.assertEqual(filename, archive.name)
            self.assertEqual(digest, actual_digest.hexdigest())

            with zipfile.ZipFile(archive) as release_zip:
                names = release_zip.namelist()
                package_root = f"MetasequoiaIME-v{version}/"
                self.assertIn(f"{package_root}MetasequoiaIME.app/Contents/Info.plist", names)
                self.assertIn(f"{package_root}Install.command", names)
                self.assertFalse(any(name.endswith("register_input_source.swift") for name in names))


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
