import json
import re
import subprocess
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class ReleaseConfigurationTests(unittest.TestCase):
    def test_release_version_matches_cmake_project_version(self):
        manifest = json.loads((PROJECT_ROOT / ".release-please-manifest.json").read_text())
        cmake = (PROJECT_ROOT / "CMakeLists.txt").read_text()
        project_line = next(line for line in cmake.splitlines() if line.startswith("project(MetasequoiaImeMac "))
        match = re.search(r"VERSION ([0-9]+\.[0-9]+\.[0-9]+)", project_line)

        self.assertIsNotNone(match)
        self.assertEqual(manifest["."], match.group(1))
        self.assertEqual((PROJECT_ROOT / "version.txt").read_text().strip(), match.group(1))
        self.assertIn("x-release-please-version", project_line)

    def test_release_automation_bumps_tags_and_uploads_installable_assets(self):
        config = json.loads((PROJECT_ROOT / "release-please-config.json").read_text())
        package = config["packages"]["."]
        workflow = (PROJECT_ROOT / ".github/workflows/release.yml").read_text()
        readme = (PROJECT_ROOT / "README.md").read_text()
        info_plist = (PROJECT_ROOT / "resources/Info.plist").read_text()
        cmake = (PROJECT_ROOT / "CMakeLists.txt").read_text()

        self.assertEqual(package["release-type"], "simple")
        self.assertIn({"type": "generic", "path": "CMakeLists.txt"}, package["extra-files"])
        self.assertNotIn("generated", (package["pull-request-header"] + package["pull-request-footer"]).lower())
        self.assertTrue(package["draft"])
        self.assertTrue(package["force-tag-creation"])
        self.assertFalse(package.get("include-component-in-tag", True))
        self.assertIn("googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7", workflow)
        self.assertIn("actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803", workflow)
        self.assertIn("steps.release.outputs.release_created", workflow)
        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn("persist-credentials: false", workflow)
        self.assertIn("GH_REPO: ${{ github.repository }}", workflow)
        self.assertIn("gh workflow run ci.yml", workflow)
        self.assertIn("scripts/package_release.sh", workflow)
        self.assertIn("macos-universal.pkg", workflow)
        self.assertIn("timeout-minutes: 30", workflow)
        self.assertIn("gh release upload", workflow)
        self.assertIn("gh release edit", workflow)
        self.assertIn("METASEQUOIA_REQUIRE_RELEASE_SIGNING", workflow)
        self.assertIn("security import", workflow)
        self.assertIn("notarytool store-credentials", workflow)
        self.assertIn("Developer ID Application", readme)
        self.assertIn("notarized", readme.lower())
        self.assertIn("全拼 or 小鹤双拼", readme)
        self.assertIn("enable full-pinyin autocorrection", readme)
        self.assertIn("native 水杉输入法设置 panel", readme)
        self.assertIn("system-wide", readme)
        self.assertIn("/Library/Input Methods", readme)
        self.assertIn("requires administrator privileges", readme)
        self.assertNotIn("upgrades the current user's copy in `~/Library/Input Methods`", readme)
        self.assertIn("InputMethodServerPreferencesWindowControllerClass", info_plist)
        self.assertIn("@METASEQUOIA_IME_DICTIONARY_SHA256@", info_plist)
        self.assertIn('file(SHA256 "${METASEQUOIA_IME_DICTIONARY}" METASEQUOIA_IME_DICTIONARY_SHA256)', cmake)
        self.assertIn("PreferencesWindowController.mm", cmake)
        preferences_controller = (PROJECT_ROOT / "src/PreferencesWindowController.mm").read_text()
        self.assertIn("initWithWindowNibName:(NSNibName)windowNibName owner:(id)owner", preferences_controller)
        self.assertIn("showAndActivate", preferences_controller)
        self.assertIn("storedScheme", preferences_controller)
        self.assertIn("setStoredScheme", preferences_controller)
        self.assertIn("小鹤双拼", preferences_controller)
        self.assertIn("storedAutocorrectEnabled", preferences_controller)
        self.assertIn("setAutocorrectEnabled", preferences_controller)
        self.assertIn("启用全拼自动纠错", preferences_controller)
        self.assertIn("storedHelpcodeEnabled", preferences_controller)
        self.assertIn("setHelpcodeEnabled", preferences_controller)
        self.assertIn("启用辅助码", preferences_controller)
        self.assertIn("storedChinesePunctuationEnabled", preferences_controller)
        self.assertIn("setChinesePunctuationEnabled", preferences_controller)
        self.assertIn("使用中文标点", preferences_controller)
        input_controller = (PROJECT_ROOT / "src/MetasequoiaInputController.mm").read_text()
        self.assertIn("reloadSessionFromPreferences", input_controller)
        self.assertIn("- (void)activateServer:(id)sender", input_controller)
        commit_composition = input_controller.split("- (void)commitComposition:(id)sender", 1)[1].split(
            "- (void)deactivateServer:(id)sender", 1
        )[0]
        self.assertIn("commitLeadingCandidate", commit_composition)
        self.assertNotIn("Command::CommitRaw", commit_composition)
        self.assertIn("next input-method activation", readme)

        release_installer = (PROJECT_ROOT / "scripts/install-release.sh").read_text()
        self.assertNotIn("xcrun", release_installer)
        self.assertNotIn("swift", release_installer.lower())
        install_script = (PROJECT_ROOT / "scripts/install.sh").read_text()
        self.assertIn("staging_root=$(mktemp -d", install_script)
        self.assertIn("backup_root=$(mktemp -d", install_script)
        self.assertIn("install_complete=false", install_script)
        self.assertIn("TISRegisterInputSource", (PROJECT_ROOT / "scripts/register_input_source.swift").read_text())
        package_script = (PROJECT_ROOT / "scripts/package_release.sh").read_text()
        self.assertIn("productsign", package_script)
        self.assertIn("notarytool", package_script)
        self.assertIn("Commercial release signing requires", package_script)

    def test_release_scripts_have_valid_zsh_syntax(self):
        for relative_path in ("scripts/install-release.sh", "scripts/package_release.sh"):
            result = subprocess.run(["zsh", "-n", str(PROJECT_ROOT / relative_path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
