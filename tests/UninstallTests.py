import os
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
UNINSTALLER = PROJECT_ROOT / "scripts/uninstall.sh"


class UninstallTests(unittest.TestCase):
    def run_uninstaller(
        self, home, arguments=(), confirmation="REMOVE METASEQUOIAIME\n", fake_mv=None, extra_environment=None
    ):
        fake_bin = home.parent / "bin"
        fake_bin.mkdir(exist_ok=True)
        fake_pkill = fake_bin / "pkill"
        fake_pkill.write_text("#!/bin/sh\nprintf '%s\\n' \"$*\" > \"$FAKE_PKILL_LOG\"\nexit 0\n")
        fake_pkill.chmod(0o755)
        fake_pgrep = fake_bin / "pgrep"
        fake_pgrep.write_text(
            "#!/bin/sh\n"
            "if test \"${FAKE_PROCESS_RUNNING:-false}\" = true; then exit 0; fi\n"
            "exit 1\n"
        )
        fake_pgrep.chmod(0o755)
        fake_sleep = fake_bin / "sleep"
        fake_sleep.write_text("#!/bin/sh\nexit 0\n")
        fake_sleep.chmod(0o755)
        fake_defaults = fake_bin / "defaults"
        fake_defaults.write_text(
            "#!/bin/sh\n"
            "set -eu\n"
            "action=$1\n"
            "case $action in\n"
            "  domains) test \"${FAIL_DEFAULTS_DOMAINS:-false}\" != true || exit 50; "
            "test ! -f \"$FAKE_PREFERENCES_FILE\" || "
            "printf '%s\\n' com.houko.inputmethod.MetasequoiaIME ;;\n"
            "  export) /bin/cp \"$FAKE_PREFERENCES_FILE\" \"$3\" ;;\n"
            "  delete) /bin/rm \"$FAKE_PREFERENCES_FILE\"; "
            "test \"${FAIL_DEFAULTS_DELETE:-false}\" != true || exit 47 ;;\n"
            "  import) test \"${FAIL_DEFAULTS_IMPORT:-false}\" != true || exit 48; "
            "/bin/cp \"$3\" \"$FAKE_PREFERENCES_FILE\" ;;\n"
            "  *) exit 64 ;;\n"
            "esac\n"
        )
        fake_defaults.chmod(0o755)
        if fake_mv is not None:
            mv_path = fake_bin / "mv"
            mv_path.write_text(fake_mv)
            mv_path.chmod(0o755)

        environment = os.environ.copy()
        environment["HOME"] = str(home)
        environment["PATH"] = f"{fake_bin}:{environment['PATH']}"
        environment["FAKE_PREFERENCES_FILE"] = str(
            home / "Library/Preferences/com.houko.inputmethod.MetasequoiaIME.plist"
        )
        environment["METASEQUOIA_DEFAULTS_COMMAND"] = str(fake_defaults)
        environment["FAKE_PKILL_LOG"] = str(home.parent / "pkill.log")
        if extra_environment is not None:
            environment.update(extra_environment)
        return subprocess.run(
            ["zsh", UNINSTALLER, *arguments],
            input=confirmation,
            capture_output=True,
            text=True,
            env=environment,
        )

    @staticmethod
    def create_installation(home):
        application = home / "Library/Input Methods/MetasequoiaIME.app"
        application.mkdir(parents=True)
        (application / "installed.txt").write_text("installed\n")
        user_data = home / "Library/Application Support/metasequoiaime"
        user_data.mkdir(parents=True)
        (user_data / "learned.txt").write_text("learned\n")
        preferences = home / "Library/Preferences/com.houko.inputmethod.MetasequoiaIME.plist"
        preferences.parent.mkdir(parents=True)
        preferences.write_text("preferences\n")
        return application, user_data, preferences

    def test_default_uninstall_moves_application_to_trash_and_preserves_user_data(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)

            result = self.run_uninstaller(home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(application.exists())
            self.assertEqual((user_data / "learned.txt").read_text(), "learned\n")
            self.assertEqual(preferences.read_text(), "preferences\n")
            recovery_directories = list((home / ".Trash").glob("MetasequoiaIME-uninstall.*"))
            self.assertEqual(len(recovery_directories), 1)
            self.assertEqual(
                (recovery_directories[0] / "MetasequoiaIME.app/installed.txt").read_text(),
                "installed\n",
            )
            self.assertIn("User data was preserved", result.stdout)
            self.assertIn(str(recovery_directories[0]), result.stdout)

    def test_remove_user_data_moves_application_and_data_to_same_recovery_directory(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)

            result = self.run_uninstaller(home, ("--remove-user-data",))

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(application.exists())
            self.assertFalse(user_data.exists())
            self.assertFalse(preferences.exists())
            recovery_directories = list((home / ".Trash").glob("MetasequoiaIME-uninstall.*"))
            self.assertEqual(len(recovery_directories), 1)
            recovery = recovery_directories[0]
            self.assertEqual((recovery / "MetasequoiaIME.app/installed.txt").read_text(), "installed\n")
            self.assertEqual((recovery / "UserData/learned.txt").read_text(), "learned\n")
            self.assertEqual((recovery / "Preferences.plist").read_text(), "preferences\n")
            self.assertIn("User data was moved to Trash", result.stdout)

    def test_wrong_confirmation_and_unknown_option_leave_everything_untouched(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)

            cancelled = self.run_uninstaller(home, confirmation="no\n")
            invalid = self.run_uninstaller(home, ("--delete-everything",))

            self.assertNotEqual(cancelled.returncode, 0)
            self.assertIn("Uninstallation cancelled", cancelled.stderr)
            self.assertNotEqual(invalid.returncode, 0)
            self.assertIn("Usage:", invalid.stderr)
            self.assertTrue(application.exists())
            self.assertTrue(user_data.exists())
            self.assertTrue(preferences.exists())
            self.assertFalse((home / ".Trash").exists())

    def test_data_move_failure_restores_application_and_preserves_data(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)
            fake_mv = r"""#!/bin/sh
source_path=$1
case "$source_path" in
  */Library/Application\ Support/metasequoiaime) exit 46 ;;
esac
exec /bin/mv "$@"
"""

            result = self.run_uninstaller(home, ("--remove-user-data",), fake_mv=fake_mv)

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((application / "installed.txt").read_text(), "installed\n")
            self.assertEqual((user_data / "learned.txt").read_text(), "learned\n")
            self.assertEqual(preferences.read_text(), "preferences\n")
            self.assertFalse(any((home / ".Trash").glob("MetasequoiaIME-uninstall.*")))
            self.assertIn("restoring the installed application", result.stderr)

    def test_preferences_delete_failure_restores_application_data_and_preferences(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)

            result = self.run_uninstaller(
                home,
                ("--remove-user-data",),
                extra_environment={"FAIL_DEFAULTS_DELETE": "true"},
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((application / "installed.txt").read_text(), "installed\n")
            self.assertEqual((user_data / "learned.txt").read_text(), "learned\n")
            self.assertEqual(preferences.read_text(), "preferences\n")
            self.assertFalse(any((home / ".Trash").glob("MetasequoiaIME-uninstall.*")))
            self.assertIn("restoring preferences", result.stderr)

    def test_running_process_timeout_changes_no_files(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)

            result = self.run_uninstaller(
                home,
                ("--remove-user-data",),
                extra_environment={"FAKE_PROCESS_RUNNING": "true"},
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((application / "installed.txt").read_text(), "installed\n")
            self.assertEqual((user_data / "learned.txt").read_text(), "learned\n")
            self.assertEqual(preferences.read_text(), "preferences\n")
            self.assertFalse((home / ".Trash").exists())
            self.assertIn("did not stop in time", result.stderr)
            pkill_arguments = (home.parent / "pkill.log").read_text()
            self.assertIn(f"-u {os.geteuid()}", pkill_arguments)

    def test_preferences_inspection_failure_changes_no_files(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)

            result = self.run_uninstaller(
                home,
                ("--remove-user-data",),
                extra_environment={"FAIL_DEFAULTS_DOMAINS": "true"},
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((application / "installed.txt").read_text(), "installed\n")
            self.assertEqual((user_data / "learned.txt").read_text(), "learned\n")
            self.assertEqual(preferences.read_text(), "preferences\n")
            self.assertFalse((home / ".Trash").exists())
            self.assertIn("no files were changed", result.stderr)

    def test_signal_after_application_move_restores_installation(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)
            fake_mv = r"""#!/bin/sh
source_path=$1
/bin/mv "$@"
if test "$source_path" = "$INTERRUPT_MOVE_SOURCE"; then
  kill -TERM "$PPID"
fi
"""

            result = self.run_uninstaller(
                home,
                fake_mv=fake_mv,
                extra_environment={"INTERRUPT_MOVE_SOURCE": str(application)},
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((application / "installed.txt").read_text(), "installed\n")
            self.assertEqual((user_data / "learned.txt").read_text(), "learned\n")
            self.assertEqual(preferences.read_text(), "preferences\n")
            self.assertFalse(any((home / ".Trash").glob("MetasequoiaIME-uninstall.*")))

    def test_rollback_failure_preserves_only_application_copy_in_recovery_directory(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)
            fake_mv = r"""#!/bin/sh
source_path=$1
case "$source_path" in
  */.Trash/MetasequoiaIME-uninstall.*/MetasequoiaIME.app) exit 49 ;;
esac
/bin/mv "$@"
if test "$source_path" = "$INTERRUPT_MOVE_SOURCE"; then
  kill -TERM "$PPID"
fi
"""

            result = self.run_uninstaller(
                home,
                fake_mv=fake_mv,
                extra_environment={"INTERRUPT_MOVE_SOURCE": str(application)},
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(application.exists())
            recovery_directories = list((home / ".Trash").glob("MetasequoiaIME-uninstall.*"))
            self.assertEqual(len(recovery_directories), 1)
            self.assertEqual(
                (recovery_directories[0] / "MetasequoiaIME.app/installed.txt").read_text(),
                "installed\n",
            )
            self.assertEqual((user_data / "learned.txt").read_text(), "learned\n")
            self.assertEqual(preferences.read_text(), "preferences\n")
            self.assertIn("rollback was incomplete", result.stderr)

    def test_preferences_restore_failure_preserves_exported_copy(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory) / "home"
            application, user_data, preferences = self.create_installation(home)

            result = self.run_uninstaller(
                home,
                ("--remove-user-data",),
                extra_environment={"FAIL_DEFAULTS_DELETE": "true", "FAIL_DEFAULTS_IMPORT": "true"},
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((application / "installed.txt").read_text(), "installed\n")
            self.assertEqual((user_data / "learned.txt").read_text(), "learned\n")
            self.assertFalse(preferences.exists())
            recovery_directories = list((home / ".Trash").glob("MetasequoiaIME-uninstall.*"))
            self.assertEqual(len(recovery_directories), 1)
            self.assertEqual((recovery_directories[0] / "Preferences.plist").read_text(), "preferences\n")
            self.assertIn("rollback was incomplete", result.stderr)


if __name__ == "__main__":
    unittest.main()
