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
    def test_development_install_restores_previous_bundle_when_registration_fails(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            fake_bin = Path(temporary_directory) / "bin"
            fake_bin.mkdir()
            fake_pkill = fake_bin / "pkill"
            fake_pkill.write_text("#!/bin/sh\nexit 0\n")
            fake_pkill.chmod(0o755)
            fake_xcrun = fake_bin / "xcrun"
            fake_xcrun.write_text("#!/bin/sh\nexit 47\n")
            fake_xcrun.chmod(0o755)

            test_home = Path(temporary_directory) / "home"
            destination = test_home / "Library/Input Methods/MetasequoiaIME.app"
            previous_marker = destination / "Contents/previous-installation.txt"
            previous_marker.parent.mkdir(parents=True)
            previous_marker.write_text("previous installation\n")
            environment = os.environ.copy()
            environment["HOME"] = str(test_home)
            environment["PATH"] = f"{fake_bin}:{environment['PATH']}"

            result = subprocess.run(
                [PROJECT_ROOT / "scripts/install.sh"],
                capture_output=True,
                text=True,
                env=environment,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(previous_marker.read_text(), "previous installation\n")
            self.assertFalse(any(destination.parent.glob(".MetasequoiaIME.installing.*")))
            self.assertFalse(any(destination.parent.glob(".MetasequoiaIME.backup.*")))

    def test_signed_packaging_exercises_signing_notarization_and_gatekeeper(self):
        bundle = Path(sys.argv[1]).resolve()
        version = subprocess.run(
            [
                "/usr/libexec/PlistBuddy",
                "-c",
                "Print :CFBundleShortVersionString",
                bundle / "Contents/Info.plist",
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary = Path(temporary_directory)
            fake_bin = temporary / "bin"
            fake_bin.mkdir()
            signing_log = temporary / "signing.log"
            fake_codesign = fake_bin / "codesign"
            fake_codesign.write_text(
                "#!/bin/bash\n"
                "set -euo pipefail\n"
                "printf 'codesign %s\\n' \"$*\" >> \"$FAKE_SIGNING_LOG\"\n"
                "case \" $* \" in\n"
                "  *' --force '*) exit 0 ;;\n"
                "esac\n"
                "exec /usr/bin/codesign \"$@\"\n"
            )
            fake_codesign.chmod(0o755)
            fake_productsign = fake_bin / "productsign"
            fake_productsign.write_text(
                "#!/bin/bash\n"
                "set -euo pipefail\n"
                "printf 'productsign %s\\n' \"$*\" >> \"$FAKE_SIGNING_LOG\"\n"
                "source_path=\n"
                "destination_path=\n"
                "for argument in \"$@\"; do\n"
                "  source_path=$destination_path\n"
                "  destination_path=$argument\n"
                "done\n"
                "exec /bin/cp \"$source_path\" \"$destination_path\"\n"
            )
            fake_productsign.chmod(0o755)
            fake_xcrun = fake_bin / "xcrun"
            fake_xcrun.write_text(
                "#!/bin/bash\n"
                "set -euo pipefail\n"
                "printf 'xcrun %s\\n' \"$*\" >> \"$FAKE_SIGNING_LOG\"\n"
            )
            fake_xcrun.chmod(0o755)

            output = temporary / "output"
            environment = os.environ.copy()
            environment.update(
                {
                    "PATH": f"{fake_bin}:{environment['PATH']}",
                    "FAKE_SIGNING_LOG": str(signing_log),
                    "METASEQUOIA_REQUIRE_RELEASE_SIGNING": "true",
                    "METASEQUOIA_DEVELOPER_ID_APPLICATION": "Developer ID Application: Test",
                    "METASEQUOIA_DEVELOPER_ID_INSTALLER": "Developer ID Installer: Test",
                    "METASEQUOIA_NOTARY_PROFILE": "metasequoia-test-notary",
                    "METASEQUOIA_RELEASE_ASSET_SUFFIX": "",
                    "METASEQUOIA_PROJECT_ROOT": str(PROJECT_ROOT),
                    "METASEQUOIA_RELEASE_INSTALL_SCRIPT": str(
                        PROJECT_ROOT / "scripts/install-release.sh"
                    ),
                }
            )
            result = subprocess.run(
                [PROJECT_ROOT / "scripts/package_release.sh", f"v{version}", bundle, output],
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

            archive = output / f"MetasequoiaIME-v{version}-macos-universal.zip"
            installer_package = output / f"MetasequoiaIME-v{version}-macos-universal.pkg"
            self.assertTrue(archive.is_file())
            self.assertTrue(archive.with_suffix(".zip.sha256").is_file())
            self.assertTrue(installer_package.is_file())
            self.assertTrue(installer_package.with_suffix(".pkg.sha256").is_file())
            self.assertFalse(any(output.glob("*-unsigned.*")))

            signing_calls = signing_log.read_text()
            self.assertIn("--sign Developer ID Application: Test", signing_calls)
            self.assertIn("productsign --sign Developer ID Installer: Test", signing_calls)
            notary_calls = [line for line in signing_calls.splitlines() if line.startswith("xcrun notarytool submit ")]
            self.assertEqual(len(notary_calls), 2)
            self.assertTrue(any("/MetasequoiaIME-notary.zip " in line for line in notary_calls))
            self.assertTrue(any("-macos-universal.pkg " in line for line in notary_calls))
            for notary_call in notary_calls:
                self.assertIn("--keychain-profile metasequoia-test-notary --wait", notary_call)
            staple_calls = [line for line in signing_calls.splitlines() if line.startswith("xcrun stapler staple ")]
            validate_calls = [line for line in signing_calls.splitlines() if line.startswith("xcrun stapler validate ")]
            self.assertEqual(len(staple_calls), 2)
            self.assertEqual(len(validate_calls), 2)
            for stapler_calls in (staple_calls, validate_calls):
                self.assertTrue(any(line.endswith("/MetasequoiaIME.app") for line in stapler_calls))
                self.assertTrue(any(line.endswith("-macos-universal.pkg") for line in stapler_calls))

            extracted = temporary / "signed-extracted"
            subprocess.run(["ditto", "-x", "-k", archive, extracted], check=True)
            package_root = extracted / f"MetasequoiaIME-v{version}"
            self.assertFalse((package_root / "UNSIGNED_BUILD.txt").exists())
            install_command = (package_root / "Install.command").read_text()
            self.assertIn("spctl --assess --type execute", install_command)

            expanded_package = temporary / "signed-expanded-package"
            subprocess.run(["pkgutil", "--expand-full", installer_package, expanded_package], check=True)
            installer_readme = (expanded_package / "Resources/InstallerReadMe.txt").read_text()
            self.assertIn("Developer ID signed and notarized", installer_readme)
            self.assertNotIn("UNSIGNED TEST BUILD", installer_readme)

            fake_spctl = fake_bin / "spctl"
            fake_spctl.write_text(
                "#!/bin/bash\n"
                "set -euo pipefail\n"
                "printf 'spctl %s\\n' \"$*\" >> \"$FAKE_SIGNING_LOG\"\n"
            )
            fake_spctl.chmod(0o755)
            fake_pkill = fake_bin / "pkill"
            fake_pkill.write_text("#!/bin/sh\nexit 0\n")
            fake_pkill.chmod(0o755)
            install_home = temporary / "signed-install-home"
            install_environment = environment.copy()
            install_environment["HOME"] = str(install_home)
            install_result = subprocess.run(
                ["zsh", package_root / "Install.command"],
                capture_output=True,
                text=True,
                env=install_environment,
            )
            self.assertEqual(install_result.returncode, 0, install_result.stderr)
            self.assertNotIn("Type I UNDERSTAND", install_result.stdout)
            gatekeeper_calls = [
                line for line in signing_log.read_text().splitlines() if line.startswith("spctl --assess --type execute ")
            ]
            self.assertEqual(len(gatekeeper_calls), 3)
            self.assertTrue(any("/signed-extracted/" in line for line in gatekeeper_calls))
            self.assertTrue(any("/.MetasequoiaIME.installing." in line for line in gatekeeper_calls))
            self.assertTrue(any("/signed-install-home/" in line for line in gatekeeper_calls))
            self.assertTrue(
                (install_home / "Library/Input Methods/MetasequoiaIME.app/Contents/Info.plist").is_file()
            )

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

                fake_codesign = fake_bin / "codesign"
                fake_codesign.write_text(
                    "#!/bin/sh\n"
                    "target=\n"
                    "for argument in \"$@\"; do target=$argument; done\n"
                    "if test -n \"${FAIL_CODESIGN_PATH:-}\" && test \"$target\" = \"$FAIL_CODESIGN_PATH\"; then\n"
                    "  exit 45\n"
                    "fi\n"
                    "exec /usr/bin/codesign \"$@\"\n"
                )
                fake_codesign.chmod(0o755)
                fake_mv = fake_bin / "mv"
                fake_mv.write_text(
                    "#!/bin/sh\n"
                    "source_path=\n"
                    "for argument in \"$@\"; do\n"
                    "  case $argument in -*) ;; *) source_path=$argument; break ;; esac\n"
                    "done\n"
                    "if test \"${INTERRUPT_AFTER_MOVE:-false}\" = true && "
                    "test \"$source_path\" = \"$INTERRUPT_MOVE_SOURCE\"; then\n"
                    "  /bin/mv \"$@\"\n"
                    "  kill -TERM \"$PPID\"\n"
                    "  exit 0\n"
                    "fi\n"
                    "case $source_path in\n"
                    "  */.MetasequoiaIME.backup.*/MetasequoiaIME.app)\n"
                    "    test \"${FAIL_ROLLBACK:-false}\" != true || exit 46\n"
                    "    ;;\n"
                    "esac\n"
                    "exec /bin/mv \"$@\"\n"
                )
                fake_mv.chmod(0o755)

                interrupted_home = Path(temporary_directory) / "interrupted-home"
                interrupted_destination = interrupted_home / "Library/Input Methods/MetasequoiaIME.app"
                interrupted_marker = interrupted_destination / "Contents/previous-installation.txt"
                interrupted_marker.parent.mkdir(parents=True)
                interrupted_marker.write_text("previous installation\n")
                interrupted_environment = install_environment.copy()
                interrupted_environment["HOME"] = str(interrupted_home)
                interrupted_environment["INTERRUPT_AFTER_MOVE"] = "true"
                interrupted_environment["INTERRUPT_MOVE_SOURCE"] = str(interrupted_destination)
                interrupted_install = subprocess.run(
                    ["zsh", extracted / package_root / "Install.command"],
                    input="I UNDERSTAND\n",
                    capture_output=True,
                    text=True,
                    env=interrupted_environment,
                )
                self.assertNotEqual(interrupted_install.returncode, 0)
                self.assertEqual(interrupted_marker.read_text(), "previous installation\n")
                self.assertFalse(any(interrupted_destination.parent.glob(".MetasequoiaIME.installing.*")))
                self.assertFalse(any(interrupted_destination.parent.glob(".MetasequoiaIME.backup.*")))

                restored_home = Path(temporary_directory) / "restored-home"
                restored_destination = restored_home / "Library/Input Methods/MetasequoiaIME.app"
                restored_marker = restored_destination / "Contents/previous-installation.txt"
                restored_marker.parent.mkdir(parents=True)
                restored_marker.write_text("previous installation\n")
                restored_environment = install_environment.copy()
                restored_environment["HOME"] = str(restored_home)
                restored_environment["FAIL_CODESIGN_PATH"] = str(restored_destination)
                failed_install = subprocess.run(
                    ["zsh", extracted / package_root / "Install.command"],
                    input="I UNDERSTAND\n",
                    capture_output=True,
                    text=True,
                    env=restored_environment,
                )
                self.assertNotEqual(failed_install.returncode, 0)
                self.assertEqual(restored_marker.read_text(), "previous installation\n")
                self.assertFalse(any(restored_destination.parent.glob(".MetasequoiaIME.installing.*")))
                self.assertFalse(any(restored_destination.parent.glob(".MetasequoiaIME.backup.*")))
                self.assertIn("restoring the previous installation", failed_install.stderr)

                rollback_home = Path(temporary_directory) / "rollback-home"
                rollback_destination = rollback_home / "Library/Input Methods/MetasequoiaIME.app"
                previous_marker = rollback_destination / "Contents/previous-installation.txt"
                previous_marker.parent.mkdir(parents=True)
                previous_marker.write_text("previous installation\n")
                rollback_environment = install_environment.copy()
                rollback_environment["HOME"] = str(rollback_home)
                rollback_environment["FAIL_CODESIGN_PATH"] = str(rollback_destination)
                rollback_environment["FAIL_ROLLBACK"] = "true"
                failed_rollback = subprocess.run(
                    ["zsh", extracted / package_root / "Install.command"],
                    input="I UNDERSTAND\n",
                    capture_output=True,
                    text=True,
                    env=rollback_environment,
                )
                self.assertNotEqual(failed_rollback.returncode, 0)
                preserved_backups = list(
                    rollback_destination.parent.glob(".MetasequoiaIME.backup.*/MetasequoiaIME.app")
                )
                self.assertEqual(len(preserved_backups), 1)
                self.assertEqual(
                    (preserved_backups[0] / "Contents/previous-installation.txt").read_text(),
                    "previous installation\n",
                )
                self.assertIn("Previous installation is preserved at", failed_rollback.stderr)

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
            self.assertEqual(distribution.find("readme").attrib["file"], "InstallerReadMe.txt")
            installer_readme = (expanded_package / "Resources/InstallerReadMe.txt").read_text()
            self.assertIn("UNSIGNED TEST BUILD", installer_readme)
            self.assertIn("not Developer ID signed or notarized", installer_readme)
            self.assertIn("verify the downloaded .pkg SHA-256 checksum", installer_readme)
            self.assertIn("Third-party notices", installer_readme)
            self.assertIn("MetasequoiaImeEngine", installer_readme)

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

            asset_names = (
                f"MetasequoiaIME-v{version}-macos-universal-unsigned.zip",
                f"MetasequoiaIME-v{version}-macos-universal-unsigned.zip.sha256",
                f"MetasequoiaIME-v{version}-macos-universal-unsigned.pkg",
                f"MetasequoiaIME-v{version}-macos-universal-unsigned.pkg.sha256",
            )

            cleanup_failure_output = Path(temporary_directory) / "cleanup-failure-output"
            cleanup_failure_output.mkdir()
            cleanup_failing_bin = Path(temporary_directory) / "cleanup-failing-bin"
            cleanup_failing_bin.mkdir()
            failing_rm = cleanup_failing_bin / "rm"
            failing_rm.write_text(
                "#!/bin/sh\n"
                "target=\n"
                "for argument in \"$@\"; do target=$argument; done\n"
                "case $target in\n"
                "  */.package.*) exit 44 ;;\n"
                "esac\n"
                "exec /bin/rm \"$@\"\n"
            )
            failing_rm.chmod(0o755)
            cleanup_failure_environment = environment.copy()
            cleanup_failure_environment["PATH"] = (
                f"{cleanup_failing_bin}:{cleanup_failure_environment['PATH']}"
            )
            failed_cleanup = subprocess.run(
                [trusted_packager, f"v{version}", bundle, cleanup_failure_output],
                capture_output=True,
                text=True,
                env=cleanup_failure_environment,
            )
            self.assertNotEqual(failed_cleanup.returncode, 0)
            for asset_name in asset_names:
                self.assertTrue(
                    (cleanup_failure_output / asset_name).is_file(),
                    f"Missing {asset_name}\nstdout:\n{failed_cleanup.stdout}\nstderr:\n{failed_cleanup.stderr}",
                )
            self.assertEqual(len(list(cleanup_failure_output.glob(".package.*"))), 1)
            self.assertIn("cleanup was incomplete", failed_cleanup.stderr)

            failure_output = Path(temporary_directory) / "failure-output"
            failure_output.mkdir()
            previous_contents = b"previous complete release asset\n"
            for asset_name in asset_names:
                (failure_output / asset_name).write_bytes(previous_contents)

            failing_bin = Path(temporary_directory) / "failing-bin"
            failing_bin.mkdir()
            failing_mv = failing_bin / "mv"
            failing_mv.write_text(
                "#!/bin/sh\n"
                "source_path=\n"
                "for argument in \"$@\"; do\n"
                "  case $argument in -*) ;; *) source_path=$argument; break ;; esac\n"
                "done\n"
                "case $source_path in\n"
                "  */PreviousAssets/*)\n"
                "    if test \"${FAIL_ROLLBACK:-false}\" = true && test ! -f \"$ROLLBACK_FAILURE_FILE\"; then\n"
                "      printf '%s\\n' failed > \"$ROLLBACK_FAILURE_FILE\"\n"
                "      exit 43\n"
                "    fi\n"
                "    ;;\n"
                "  */.package.*/MetasequoiaIME-v*-macos-universal*)\n"
                "    count=0\n"
                "    test ! -f \"$MV_COUNT_FILE\" || count=$(cat \"$MV_COUNT_FILE\")\n"
                "    count=$((count + 1))\n"
                "    printf '%s\\n' \"$count\" > \"$MV_COUNT_FILE\"\n"
                "    test \"$count\" -ne 2 || exit 42\n"
                "    ;;\n"
                "esac\n"
                "exec /bin/mv \"$@\"\n"
            )
            failing_mv.chmod(0o755)
            failure_environment = environment.copy()
            failure_environment["PATH"] = f"{failing_bin}:{failure_environment['PATH']}"
            failure_environment["MV_COUNT_FILE"] = str(Path(temporary_directory) / "mv-count")
            failed_package = subprocess.run(
                [trusted_packager, f"v{version}", bundle, failure_output],
                capture_output=True,
                text=True,
                env=failure_environment,
            )
            self.assertNotEqual(failed_package.returncode, 0)
            for asset_name in asset_names:
                self.assertEqual((failure_output / asset_name).read_bytes(), previous_contents)
            self.assertFalse(any(failure_output.glob(".package.*")))

            rollback_failure_output = Path(temporary_directory) / "rollback-failure-output"
            rollback_failure_output.mkdir()
            for asset_name in asset_names:
                (rollback_failure_output / asset_name).write_bytes(previous_contents)
            rollback_failure_environment = failure_environment.copy()
            rollback_failure_environment["MV_COUNT_FILE"] = str(
                Path(temporary_directory) / "rollback-mv-count"
            )
            rollback_failure_environment["FAIL_ROLLBACK"] = "true"
            rollback_failure_environment["ROLLBACK_FAILURE_FILE"] = str(
                Path(temporary_directory) / "rollback-failed"
            )
            failed_rollback = subprocess.run(
                [trusted_packager, f"v{version}", bundle, rollback_failure_output],
                capture_output=True,
                text=True,
                env=rollback_failure_environment,
            )
            self.assertNotEqual(failed_rollback.returncode, 0)
            preserved_staging = list(rollback_failure_output.glob(".package.*"))
            self.assertEqual(len(preserved_staging), 1)
            preserved_backup = preserved_staging[0] / "PreviousAssets"
            for asset_name in asset_names:
                final_asset = rollback_failure_output / asset_name
                backup_asset = preserved_backup / asset_name
                self.assertTrue(final_asset.exists() or backup_asset.exists())
                preserved_asset = final_asset if final_asset.exists() else backup_asset
                self.assertEqual(preserved_asset.read_bytes(), previous_contents)
            self.assertIn("PreviousAssets", failed_rollback.stderr)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
