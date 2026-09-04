# Standalone Settings Launcher Design

## Goal

Give users a direct, current-user way to reopen the existing native settings panel after installation, without changing the InputMethodKit server's normal launch behavior or touching macOS input-source state.

## Design

The `MetasequoiaIME` executable accepts one new exact command-line mode, `--show-settings`. This mode starts AppKit with accessory activation, opens `MetasequoiaPreferencesWindowController`, and runs only until that window closes. It does not construct `IMKServer`, register an input source, select an input source, or check for updates in the background. Normal launches and `--register-input-source` retain their existing behavior.

The release ZIP includes `Open Settings.command`. It resolves only the fixed current-user installation at `~/Library/Input Methods/MetasequoiaIME.app`, validates that its executable exists, and invokes that executable with `--show-settings`. A missing installation fails with a clear instruction to run `Install.command`. No administrator privileges are requested.

Release repackaging includes the trusted launcher only when the target tag itself contains `platforms/macos/scripts/open-settings.sh`, which acts as the binary capability marker. Older draft tags therefore never receive a launcher their executable cannot handle.

The existing settings controller uses `performClose:` for both the window close control and its Close button. Standalone mode marks the controller to terminate the app after the window closes; InputMethodKit-hosted settings remain reopenable and keep the server alive.

Because learned-data reset requires every active input session in the IMK server process to release its SQLite state, standalone mode disables that destructive action and directs the user to reopen settings from the input menu. Other preferences remain safe to edit through `NSUserDefaults`.

## Verification

Unit tests cover exact command parsing and standalone close policy. Release tests verify that the launcher is executable, targets the current-user installation, passes only `--show-settings`, and fails safely when the app is absent. An isolated app-bundle copy with a non-production bundle identifier is used for Orca Computer visual and interaction verification, so testing never installs, registers, enables, or selects a real input source.
