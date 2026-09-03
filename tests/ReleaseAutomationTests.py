import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BASE_SHA = "1" * 40
HEAD_SHA = "2" * 40


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


if __name__ == "__main__":
    unittest.main()
