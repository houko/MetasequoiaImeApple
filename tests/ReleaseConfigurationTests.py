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
        self.assertIn("gh release upload", workflow)
        self.assertIn("gh release edit", workflow)

        release_installer = (PROJECT_ROOT / "scripts/install-release.sh").read_text()
        self.assertNotIn("xcrun", release_installer)
        self.assertNotIn("swift", release_installer.lower())

    def test_release_scripts_have_valid_zsh_syntax(self):
        for relative_path in ("scripts/install-release.sh", "scripts/package_release.sh"):
            result = subprocess.run(["zsh", "-n", str(PROJECT_ROOT / relative_path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
