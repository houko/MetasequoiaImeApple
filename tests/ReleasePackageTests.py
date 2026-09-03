import hashlib
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ElementTree
import zipfile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SIGNING_ENVIRONMENT = (
    "METASEQUOIA_REQUIRE_RELEASE_SIGNING",
    "METASEQUOIA_DEVELOPER_ID_APPLICATION",
    "METASEQUOIA_DEVELOPER_ID_INSTALLER",
    "METASEQUOIA_NOTARY_PROFILE",
)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class ReleasePackageTests(unittest.TestCase):
    def test_package_is_portable_and_self_contained(self):
        bundle = Path(sys.argv[1]).resolve()
        version = subprocess.run(["/usr/libexec/PlistBuddy", "-c", "Print :CFBundleShortVersionString", bundle / "Contents/Info.plist"], check=True, capture_output=True, text=True).stdout.strip()
        dictionary = bundle / "Contents/Resources/msime.db"
        with (bundle / "Contents/Info.plist").open("rb") as info_file:
            bundle_info = plistlib.load(info_file)
            dictionary_fingerprint = bundle_info["MetasequoiaDictionarySHA256"]
        self.assertTrue(dictionary.is_file())
        self.assertEqual(dictionary_fingerprint, sha256_file(dictionary))

        icon_name = "MetasequoiaIME.icns"
        input_mode = bundle_info["ComponentInputModeDict"]["tsInputModeListKey"][
            "com.houko.inputmethod.MetasequoiaIME.Hans"
        ]
        self.assertEqual(bundle_info["CFBundleIconFile"], icon_name)
        self.assertEqual(bundle_info["tsInputMethodIconFileKey"], icon_name)
        self.assertEqual(input_mode["tsInputModeMenuIconFileKey"], icon_name)
        self.assertEqual(input_mode["tsInputModePaletteIconFileKey"], icon_name)
        icon = bundle / "Contents/Resources" / icon_name
        self.assertTrue(icon.is_file())
        with tempfile.TemporaryDirectory() as icon_directory:
            iconset = Path(icon_directory) / "MetasequoiaIME.iconset"
            subprocess.run(["iconutil", "--convert", "iconset", "--output", iconset, icon], check=True)
            self.assertTrue((iconset / "icon_16x16.png").is_file())
            self.assertTrue((iconset / "icon_128x128@2x.png").is_file())

        executable = bundle / "Contents/MacOS/MetasequoiaIME"
        for architecture in ("arm64", "x86_64"):
            dependencies = subprocess.run(
                ["otool", "-arch", architecture, "-L", executable],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.splitlines()[1:]
            for dependency in dependencies:
                library = dependency.strip().split(" (", 1)[0]
                self.assertTrue(
                    library.startswith(("/System/Library/", "/usr/lib/", "@")),
                    f"{architecture} has a non-portable dependency: {library}",
                )

            build_version = subprocess.run(
                ["vtool", "-arch", architecture, "-show-build", executable],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
            self.assertRegex(build_version, r"(?m)^\s*minos 12\.0$")

        with tempfile.TemporaryDirectory() as temporary_directory:
            output = Path(temporary_directory) / "output"
            environment = os.environ.copy()
            for variable in SIGNING_ENVIRONMENT:
                environment.pop(variable, None)
            environment["METASEQUOIA_RELEASE_ASSET_SUFFIX"] = "-unsigned"
            trusted_packager = Path(temporary_directory) / "package-release.sh"
            shutil.copy2(PROJECT_ROOT / "scripts/package_release.sh", trusted_packager)
            environment["METASEQUOIA_PROJECT_ROOT"] = str(PROJECT_ROOT)
            environment["METASEQUOIA_RELEASE_INSTALL_SCRIPT"] = str(
                PROJECT_ROOT / "scripts/install-release.sh"
            )
            subprocess.run(
                [trusted_packager, f"v{version}", bundle, output],
                check=True,
                env=environment,
            )
            archive = output / f"MetasequoiaIME-v{version}-macos-universal-unsigned.zip"
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
                self.assertIn(f"{package_root}UNSIGNED_BUILD.txt", names)
                self.assertIn(f"{package_root}LICENSE", names)
                self.assertIn(f"{package_root}THIRD_PARTY_NOTICES.txt", names)
                self.assertIn(
                    f"{package_root}MetasequoiaIME.app/Contents/Resources/Licenses/GPL-3.0.txt", names
                )
                self.assertIn(
                    f"{package_root}MetasequoiaIME.app/Contents/Resources/Licenses/THIRD_PARTY_NOTICES.txt", names
                )
                self.assertFalse(any(name.endswith("register_input_source.swift") for name in names))
                install_command = release_zip.read(f"{package_root}Install.command").decode()
                self.assertIn("spctl --assess --type execute", install_command)
                self.assertIn("Type I UNDERSTAND", install_command)
                self.assertNotIn("xattr", install_command)

                extracted = Path(temporary_directory) / "extracted"
                subprocess.run(["ditto", "-x", "-k", archive, extracted], check=True)
                fake_bin = Path(temporary_directory) / "bin"
                fake_bin.mkdir()
                fake_pkill = fake_bin / "pkill"
                fake_pkill.write_text("#!/bin/sh\nexit 0\n")
                fake_pkill.chmod(0o755)
                test_home = Path(temporary_directory) / "home"
                install_environment = os.environ.copy()
                install_environment["HOME"] = str(test_home)
                install_environment["PATH"] = f"{fake_bin}:{install_environment['PATH']}"
                rejected_install = subprocess.run(
                    ["zsh", extracted / package_root / "Install.command"],
                    input="no\n",
                    capture_output=True,
                    text=True,
                    env=install_environment,
                )
                self.assertNotEqual(rejected_install.returncode, 0)
                self.assertIn("Unsigned installation cancelled", rejected_install.stderr)
                self.assertFalse((test_home / "Library/Input Methods/MetasequoiaIME.app").exists())
                install_result = subprocess.run(
                    ["zsh", extracted / package_root / "Install.command"],
                    input="I UNDERSTAND\n",
                    capture_output=True,
                    text=True,
                    env=install_environment,
                )
                self.assertEqual(install_result.returncode, 0, install_result.stderr)
                self.assertIn("not Developer ID signed or notarized", install_result.stderr)
                self.assertTrue(
                    (test_home / "Library/Input Methods/MetasequoiaIME.app/Contents/Info.plist").is_file()
                )

            installer_package = output / f"MetasequoiaIME-v{version}-macos-universal-unsigned.pkg"
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
            self.assertEqual(distribution.find("license").attrib["file"], "LICENSE")
            self.assertEqual(distribution.find("readme").attrib["file"], "THIRD_PARTY_NOTICES.txt")

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
            self.assertTrue(
                (
                    component_info_path.parent
                    / "Payload/MetasequoiaIME.app/Contents/Resources/Licenses/GPL-3.0.txt"
                ).is_file()
            )


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
