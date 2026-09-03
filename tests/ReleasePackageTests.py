import hashlib
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ElementTree
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

            installer_package = output / f"MetasequoiaIME-v{version}-macos-universal.pkg"
            installer_checksum = installer_package.with_suffix(f"{installer_package.suffix}.sha256")
            self.assertTrue(installer_package.is_file())
            self.assertTrue(installer_checksum.is_file())
            installer_digest, installer_filename = installer_checksum.read_text().split()
            actual_installer_digest = hashlib.sha256()
            with installer_package.open("rb") as installer_file:
                for chunk in iter(lambda: installer_file.read(1024 * 1024), b""):
                    actual_installer_digest.update(chunk)

            self.assertEqual(installer_filename, installer_package.name)
            self.assertEqual(installer_digest, actual_installer_digest.hexdigest())

            domain_info = subprocess.run(["installer", "-pkg", installer_package, "-target", "CurrentUserHomeDirectory", "-dominfo", "-verbose"], check=True, capture_output=True, text=True).stdout
            self.assertIn("CurrentUserHomeDirectory", domain_info)
            self.assertRegex(domain_info, r"CurrentUserHomeDirectory[\s\S]*Status\s+: Enabled")
            self.assertRegex(domain_info, r"LocalSystem[\s\S]*Status\s+: Disabled")

            expanded_package = Path(temporary_directory) / "expanded-package"
            subprocess.run(["pkgutil", "--expand-full", installer_package, expanded_package], check=True)
            distribution = ElementTree.parse(expanded_package / "Distribution").getroot()
            domains = distribution.find("domains")
            self.assertIsNotNone(domains)
            self.assertEqual(domains.attrib["enable_currentUserHome"], "true")
            self.assertEqual(domains.attrib["enable_localSystem"], "false")

            component_info_path = next(expanded_package.glob("*.pkg/PackageInfo"))
            component_info = ElementTree.parse(component_info_path).getroot()
            self.assertEqual(component_info.attrib["identifier"], "com.houko.inputmethod.MetasequoiaIME.pkg")
            self.assertEqual(component_info.attrib["version"], version)
            self.assertEqual(component_info.attrib["install-location"], "Library/Input Methods")
            self.assertEqual(component_info.attrib["relocatable"], "false")
            upgrade_bundle = component_info.find("upgrade-bundle/bundle")
            self.assertIsNotNone(upgrade_bundle)
            self.assertEqual(upgrade_bundle.attrib["id"], "com.houko.inputmethod.MetasequoiaIME")
            self.assertTrue((component_info_path.parent / "Payload/MetasequoiaIME.app/Contents/Info.plist").is_file())


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
