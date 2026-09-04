# Metasequoia IME for Apple platforms

This repository contains the native Apple-platform frontends for Metasequoia IME. The released macOS frontend uses InputMethodKit and AppKit. An iOS host app and custom keyboard extension are being added incrementally. Both platforms consume the same C++ composition engine while keeping their lifecycle, input routing, candidate presentation, settings, and accessibility UI native and independent.

The target module boundaries and migration sequence are documented in [Apple platform architecture](docs/apple-platform-architecture.md). The released macOS implementation lives under `platforms/macos/`; iOS code is kept under `platforms/ios/` as it is introduced.

## Platform status

| Platform | Status | Native frontend |
|---|---|---|
| macOS 12+ | Released | InputMethodKit and AppKit |
| iOS | In development | Host app and `UIInputViewController` keyboard extension |

The iOS work does not port the Windows TSF or WebView2 host. It reuses `MetasequoiaImeEngine` and supplies an iOS-specific UI and text-document adapter.

The current release supports full-pinyin composition, live candidates from the official Metasequoia dictionary, candidate selection through the native candidate panel or number keys 1–9, Space to commit the leading candidate, Return to commit raw input, Backspace, Escape, composition commit on focus changes, and Shift+Space switching between Chinese and direct English input.

## Requirements

- macOS 12 or later
- Xcode command-line tools
- CMake 3.25 or later
- Homebrew packages: `boost`, `fmt`, and `spdlog`
- Python 3

## Build

```sh
git clone --recursive https://github.com/metasequoiaime/MSIME-Apple.git
cd MSIME-Apple
brew install cmake boost fmt spdlog
./platforms/macos/scripts/build.sh
```

The dictionary build generates `vendor/MetasequoiaImeDict/out/msime.db` from the official source data. The generated database is intentionally not committed.

## Install for the current user

```sh
./platforms/macos/scripts/install.sh
```

Then enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit. The installer copies the signed bundle to `~/Library/Input Methods` and registers that exact bundle with macOS; it does not require administrator privileges.

## Settings

In System Settings > Keyboard > Text Input > Edit, select 水杉输入法 and choose its settings action to open the native 水杉输入法设置 panel. The panel lets you choose 全拼 or 小鹤双拼, switch the native candidate window between a horizontal row and vertical list, show 5, 7, or 9 candidates per page, choose a small, standard, or large candidate font, enable full-pinyin autocorrection and auxiliary codes, switch Chinese punctuation conversion, and control whether selected candidates update learned word frequencies. These choices are saved for the current user and apply before the next key event when no composition is active; an active composition keeps its original settings until it is committed or cancelled. Additional input and candidate options will be added incrementally.

The release ZIP also includes `Open Settings.command` as a direct fallback. After installation, open it to launch the same native panel without selecting 水杉 first; closing the panel exits only this standalone settings process and leaves the input method available.

The input method uses Sparkle 2 to check the repository's signed update feed automatically. Choose `检查更新…` directly from the input menu or from the settings panel to run a manual check. Available releases are downloaded in the background, verified with the project's Ed25519 update key before extraction, and installed by replacing the existing input-method bundle in place; the user does not need to extract or run a ZIP installer. The appcast itself is also signed, and the Sparkle framework and release tools are pinned to a verified version in the build and release configuration.

The text input menu also shows whether 水杉 is in 中文输入 or 英文输入 mode. Choose either item directly, or press Shift+Space; switching to English commits the active Chinese composition before subsequent keys pass through unchanged. The Shift+Space shortcut is enabled by default and can be disabled in settings when it conflicts with another workflow.

## Development tests

```sh
python3 platforms/macos/tests/create_fixture_dictionary.py /tmp/metasequoia-ime-test/msime.db
cmake -S . -B build-test -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="$(brew --prefix)" -DMETASEQUOIA_IME_DICTIONARY=/tmp/metasequoia-ime-test/msime.db
cmake --build build-test --parallel
ctest --test-dir build-test --output-on-failure --timeout 20
```

The test suite uses real SQLite tables and the production engine path; it does not substitute fake candidates.

## Releases

Merges to `main` update a Release Please pull request from conventional commit history. Merging that release pull request bumps `version.txt`, `CMakeLists.txt`, and `CHANGELOG.md`, creates the matching `vX.Y.Z` tag, builds and tests the universal input method bundle, and publishes a GitHub Release with these assets:

- `MetasequoiaIME-vX.Y.Z-macos-universal.pkg`
- `MetasequoiaIME-vX.Y.Z-macos-universal.pkg.sha256`
- `MetasequoiaIME-vX.Y.Z-macos-universal.zip`
- `MetasequoiaIME-vX.Y.Z-macos-universal.zip.sha256`

When Apple release credentials are not configured, the workflow publishes the same four assets with `-unsigned` before the file extension and adds a warning to the GitHub Release. Unsigned artifacts are intended for testing and may require explicit approval in macOS privacy and security settings.

For normal installation, use the ZIP and run its `Install.command`; this is the recommended path because it installs, registers, and enables the current user's input source without automatically logging out or restarting the Mac. The PKG is a compatibility option for users who prefer the native macOS Installer. It copies the same app but cannot reliably enable the current GUI user's input source, so manual enablement in System Settings may still be needed.

If you choose the PKG, download it and its checksum, verify it, then double-click the package. It installs the current user's copy in `~/Library/Input Methods`; the native Installer may request administrator authorization. It will not log out or restart the Mac automatically. macOS may still require you to log out and back in at a convenient time before the newly copied input method appears.

```sh
shasum -a 256 -c MetasequoiaIME-vX.Y.Z-macos-universal.pkg.sha256
```

When all of the following repository secrets are configured, release builds are signed with a Developer ID Application identity, signed as an installer with a Developer ID Installer identity, and notarized before publication. With none configured, the workflow publishes clearly labeled unsigned artifacts. A partial configuration fails before downloading build dependencies so it cannot produce ambiguously labeled assets.

- `MACOS_DEVELOPER_ID_CERTIFICATE_BASE64`
- `MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `MACOS_SIGNING_KEYCHAIN_PASSWORD`
- `MACOS_NOTARY_APPLE_ID`
- `MACOS_NOTARY_TEAM_ID`
- `MACOS_NOTARY_APP_SPECIFIC_PASSWORD`
- `MACOS_DEVELOPER_ID_APPLICATION`
- `MACOS_DEVELOPER_ID_INSTALLER`

Local development builds remain ad-hoc signed. After installation, enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit.

The ZIP provides the same current-user destination through `Install.command` and is the recommended option when 水杉 should be available immediately without logging out or administrator privileges. The installer always verifies the bundle's code signature before replacing an existing installation, then registers and enables that exact bundle with macOS so it appears in the input menu without logging out. If registration or enablement fails, the verified app remains installed and the installer directs you to enable it manually in System Settings. Signed releases must also pass Gatekeeper; clearly marked unsigned builds instead require typing `I UNDERSTAND` and may need explicit approval in System Settings > Privacy & Security.

Verify the ZIP checksum, extract it, and run `Install.command`:

```sh
shasum -a 256 -c MetasequoiaIME-vX.Y.Z-macos-universal.zip.sha256
./MetasequoiaIME-vX.Y.Z/Install.command
```

## Uninstall

The release ZIP also includes `Uninstall.command`. It removes only the current user's input method and moves it to Trash so the operation remains recoverable. It preserves preferences and learned data by default:

```sh
./MetasequoiaIME-vX.Y.Z/Uninstall.command
```

To move the application, preferences, and learned data to the same recovery folder in Trash, use the explicit data-removal option:

```sh
./MetasequoiaIME-vX.Y.Z/Uninstall.command --remove-user-data
```

Both modes require typing `REMOVE METASEQUOIAIME` before changing files. Log out afterward so macOS refreshes its input source cache.

PKG installations keep the same helper inside the installed application bundle, so it remains available even without the release ZIP:

```sh
"$HOME/Library/Input Methods/MetasequoiaIME.app/Contents/Resources/Uninstall.command"
```

## License

Metasequoia IME for Apple platforms is distributed under the GNU General Public License version 3. Release archives, installer packages, and application bundles include the applicable GPL and third-party license notices; see `LICENSE` and `THIRD_PARTY_NOTICES.txt`.

## Privacy and security

Input processing and candidate learning are local to the device; see [PRIVACY.md](PRIVACY.md) for the data-handling details. Report suspected vulnerabilities privately according to [SECURITY.md](SECURITY.md), not through a public issue.
