import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BASE_SHA = "1" * 40
HEAD_SHA = "2" * 40
SIGNING_SECRETS = (
    "MACOS_DEVELOPER_ID_CERTIFICATE_BASE64",
    "MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD",
    "MACOS_SIGNING_KEYCHAIN_PASSWORD",
    "MACOS_NOTARY_APPLE_ID",
    "MACOS_NOTARY_TEAM_ID",
    "MACOS_NOTARY_APP_SPECIFIC_PASSWORD",
    "MACOS_DEVELOPER_ID_APPLICATION",
    "MACOS_DEVELOPER_ID_INSTALLER",
)


class ReleaseAutomationTests(unittest.TestCase):
    def run_merge(self, current_base=BASE_SHA, ci_exit_code="0"):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary = Path(temporary_directory)
            log = temporary / "gh.log"
            output = temporary / "github-output"
            fake_gh = temporary / "gh"
            fake_gh.write_text(
                """#!/bin/zsh
set -euo pipefail
print -r -- "$*" >> "$FAKE_GH_LOG"
if [[ "$1 $2" == "pr view" ]]; then
    print -r -- "{\\"number\\":42,\\"state\\":\\"OPEN\\",\\"isDraft\\":false,\\"headRefName\\":\\"release-please--branches--main--components--MetasequoiaImeMac\\",\\"headRefOid\\":\\"$FAKE_HEAD_SHA\\",\\"baseRefName\\":\\"main\\",\\"baseRefOid\\":\\"$FAKE_BASE_SHA\\",\\"title\\":\\"chore(main): release 1.2.3\\"}"
elif [[ "$1 $2" == "workflow run" ]]; then
    exit 0
elif [[ "$1 $2" == "run list" ]]; then
    print -r -- "9001"
elif [[ "$1 $2" == "run watch" ]]; then
    exit "$FAKE_CI_EXIT_CODE"
elif [[ "$1" == "api" ]]; then
    print -r -- "$FAKE_CURRENT_BASE"
elif [[ "$1 $2" == "pr merge" ]]; then
    exit 0
else
    print -u2 -- "Unexpected gh invocation: $*"
    exit 64
fi
"""
            )
            fake_gh.chmod(0o755)
            release_pr = {
                "headBranchName": "release-please--branches--main--components--MetasequoiaImeMac",
                "number": 42,
            }
            environment = os.environ.copy()
            environment.update(
                {
                    "PATH": f"{temporary}:{environment['PATH']}",
                    "GH_REPO": "houko/MetasequoiaImeMac",
                    "RELEASE_PR": json.dumps(release_pr),
                    "GITHUB_OUTPUT": str(output),
                    "FAKE_GH_LOG": str(log),
                    "FAKE_BASE_SHA": BASE_SHA,
                    "FAKE_CURRENT_BASE": current_base,
                    "FAKE_CI_EXIT_CODE": ci_exit_code,
                    "FAKE_HEAD_SHA": HEAD_SHA,
                    "METASEQUOIA_RELEASE_CI_MAX_POLLS": "1",
                    "METASEQUOIA_RELEASE_CI_POLL_INTERVAL": "0",
                }
            )
            result = subprocess.run(
                [PROJECT_ROOT / "scripts/merge-release-pr.sh"],
                capture_output=True,
                text=True,
                env=environment,
            )
            return result, log.read_text() if log.exists() else "", output.read_text() if output.exists() else ""

    def test_release_pull_request_merges_only_after_its_ci_run_passes(self):
        result, calls, output = self.run_merge()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("workflow run ci.yml", calls)
        self.assertLess(calls.index("workflow run ci.yml"), calls.index("run watch 9001"))
        self.assertLess(calls.index("run watch 9001"), calls.index("pr merge 42"))
        self.assertIn(f"--match-head-commit {HEAD_SHA}", calls)
        self.assertEqual(output, "merged=true\n")

    def test_release_pull_request_stays_open_when_main_advances_during_ci(self):
        result, calls, output = self.run_merge(current_base="3" * 40)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("run watch 9001", calls)
        self.assertNotIn("pr merge 42", calls)
        self.assertEqual(output, "merged=false\n")

    def test_release_pull_request_stays_open_when_ci_fails(self):
        result, calls, output = self.run_merge(ci_exit_code="1")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("run watch 9001", calls)
        self.assertNotIn("pr merge 42", calls)
        self.assertEqual(output, "")


class ReleaseSigningModeTests(unittest.TestCase):
    def run_detection(self, configured_secrets=()):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary = Path(temporary_directory)
            output = temporary / "github-output"
            summary = temporary / "github-summary"
            environment = os.environ.copy()
            for secret in SIGNING_SECRETS:
                environment.pop(secret, None)
            environment.update({secret: "configured" for secret in configured_secrets})
            environment["GITHUB_OUTPUT"] = str(output)
            environment["GITHUB_STEP_SUMMARY"] = str(summary)
            result = subprocess.run(
                [PROJECT_ROOT / "scripts/detect-release-signing.sh"],
                capture_output=True,
                text=True,
                env=environment,
            )
            return (
                result,
                output.read_text() if output.exists() else "",
                summary.read_text() if summary.exists() else "",
            )

    def test_missing_credentials_selects_clearly_labeled_unsigned_release(self):
        result, output, summary = self.run_detection()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "signing_enabled=false\nasset_suffix=-unsigned\n")
        self.assertIn("unsigned", summary.lower())

    def test_complete_credentials_selects_signed_and_notarized_release(self):
        result, output, summary = self.run_detection(SIGNING_SECRETS)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "signing_enabled=true\nasset_suffix=\n")
        self.assertIn("signed and notarized", summary.lower())

    def test_partial_credentials_fail_instead_of_publishing_ambiguous_artifacts(self):
        result, output, summary = self.run_detection(SIGNING_SECRETS[:2])

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(output, "")
        self.assertEqual(summary, "")
        self.assertIn("partially configured", result.stderr)
        self.assertIn("MACOS_DEVELOPER_ID_APPLICATION", result.stderr)


class ReleasePublicationTests(unittest.TestCase):
    def run_publication(
        self,
        signing_enabled,
        asset_suffix,
        existing_notes="",
        corrupt_checksum=False,
        misdirected_checksum=False,
    ):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary = Path(temporary_directory)
            fake_bin = temporary / "bin"
            fake_bin.mkdir()
            log = temporary / "gh.log"
            captured_notes = temporary / "notes.md"
            fake_gh = fake_bin / "gh"
            fake_gh.write_text(
                """#!/bin/bash
set -euo pipefail
printf '%s\\n' "$*" >> "$FAKE_GH_LOG"
if [[ "$1 $2" == "release view" ]]; then
    printf '%s' "$FAKE_EXISTING_NOTES"
elif [[ "$1 $2" == "release edit" && "$*" == *"--notes-file"* ]]; then
    while (($#)); do
        if [[ "$1" == "--notes-file" ]]; then
            cp "$2" "$FAKE_CAPTURED_NOTES"
            exit 0
        fi
        shift
    done
fi
"""
            )
            fake_gh.chmod(0o755)
            dist = temporary / "dist"
            dist.mkdir()
            stem = f"MetasequoiaIME-v1.2.3-macos-universal{asset_suffix}"
            for extension in (".zip", ".pkg"):
                artifact = dist / f"{stem}{extension}"
                artifact.write_bytes(f"test {extension} artifact\n".encode())
                digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
                if corrupt_checksum and extension == ".pkg":
                    digest = "0" * 64
                (dist / f"{stem}{extension}.sha256").write_text(f"{digest}  {artifact.name}\n")
            if misdirected_checksum:
                archive = dist / f"{stem}.zip"
                archive_digest = hashlib.sha256(archive.read_bytes()).hexdigest()
                (dist / f"{stem}.pkg.sha256").write_text(f"{archive_digest}  {archive.name}\n")
            environment = os.environ.copy()
            environment.update(
                {
                    "PATH": f"{fake_bin}:{environment['PATH']}",
                    "GH_REPO": "houko/MetasequoiaImeMac",
                    "TAG_NAME": "v1.2.3",
                    "ASSET_SUFFIX": asset_suffix,
                    "SIGNING_ENABLED": signing_enabled,
                    "DIST_DIR": str(dist),
                    "RUNNER_TEMP": str(temporary),
                    "FAKE_GH_LOG": str(log),
                    "FAKE_EXISTING_NOTES": existing_notes,
                    "FAKE_CAPTURED_NOTES": str(captured_notes),
                }
            )
            result = subprocess.run(
                [PROJECT_ROOT / "scripts/publish-release.sh"],
                capture_output=True,
                text=True,
                env=environment,
            )
            return (
                result,
                log.read_text() if log.exists() else "",
                captured_notes.read_text() if captured_notes.exists() else "",
            )

    def test_unsigned_publication_records_mode_before_uploading_labeled_assets(self):
        result, calls, notes = self.run_publication("false", "-unsigned", "Existing notes")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("metasequoia-release-mode:unsigned", notes)
        self.assertIn("not Developer ID signed or notarized", notes)
        self.assertLess(calls.index("--notes-file"), calls.index("release upload"))
        self.assertIn("macos-universal-unsigned.pkg", calls)
        self.assertIn("--draft=false", calls)

    def test_same_mode_retry_keeps_notes_and_reuploads_with_clobber(self):
        marker = "Existing notes\n\n<!-- metasequoia-release-mode:unsigned -->\n"
        result, calls, notes = self.run_publication("false", "-unsigned", marker)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("--notes-file", calls)
        self.assertIn("--clobber", calls)
        self.assertEqual(notes, "")

    def test_cross_mode_retry_is_rejected_before_assets_change(self):
        marker = "<!-- metasequoia-release-mode:unsigned -->"
        result, calls, notes = self.run_publication("true", "", marker)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already locked to unsigned", result.stderr)
        self.assertNotIn("release upload", calls)
        self.assertNotIn("release edit", calls)
        self.assertEqual(notes, "")

    def test_signed_publication_records_signed_mode_without_unsigned_warning(self):
        result, calls, notes = self.run_publication("true", "")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("metasequoia-release-mode:signed", notes)
        self.assertNotIn("WARNING", notes)
        self.assertIn("macos-universal.pkg", calls)

    def test_corrupt_artifact_is_rejected_before_release_metadata_or_assets_change(self):
        result, calls, notes = self.run_publication("false", "-unsigned", corrupt_checksum=True)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAILED", result.stdout + result.stderr)
        self.assertEqual(calls, "")
        self.assertEqual(notes, "")

    def test_checksum_for_another_artifact_is_rejected_before_release_changes(self):
        result, calls, notes = self.run_publication("false", "-unsigned", misdirected_checksum=True)

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, "")
        self.assertEqual(notes, "")


if __name__ == "__main__":
    unittest.main()
