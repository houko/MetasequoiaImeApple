# Metasequoia IME for macOS

This repository contains the native macOS frontend for Metasequoia IME. It uses InputMethodKit and AppKit, embeds the shared C++ engine directly, and does not port the Windows TSF or WebView2 host.

The current alpha supports full-pinyin composition, live candidates from the official Metasequoia dictionary, candidate selection through the native candidate panel or number keys 1–9, Space to commit the leading candidate, Return to commit raw input, Backspace, Escape, composition commit on focus changes, and Shift+Space switching between Chinese and direct English input.

## Requirements

- macOS 12 or later
- Xcode command-line tools
- CMake 3.25 or later
- Homebrew packages: `boost`, `fmt`, and `spdlog`
- Python 3

## Build

```sh
git clone --recursive https://github.com/houko/MetasequoiaImeMac.git
cd MetasequoiaImeMac
brew install cmake boost fmt spdlog
./scripts/build.sh
```

The dictionary build generates `vendor/MetasequoiaImeDict/out/msime.db` from the official source data. The generated database is intentionally not committed.

## Install for the current user

```sh
./scripts/install.sh
```

Then enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit. The installer copies the signed bundle to `~/Library/Input Methods` and registers that exact bundle with macOS; it does not require administrator privileges.

## Settings

In System Settings > Keyboard > Text Input > Edit, select 水杉输入法 and choose its settings action to open the native 水杉输入法设置 panel. The panel lets you choose 全拼 or 小鹤双拼, switch the native candidate window between a horizontal row and vertical list, show 5, 7, or 9 candidates per page, choose a small, standard, or large candidate font, enable full-pinyin autocorrection and auxiliary codes, switch Chinese punctuation conversion, and control whether selected candidates update learned word frequencies. These choices are saved for the current user and apply before the next key event when no composition is active; an active composition keeps its original settings until it is committed or cancelled. Additional input and candidate options will be added incrementally.

The text input menu also shows whether 水杉 is in 中文输入 or 英文输入 mode. Choose either item directly, or press Shift+Space; switching to English commits the active Chinese composition before subsequent keys pass through unchanged. The Shift+Space shortcut is enabled by default and can be disabled in settings when it conflicts with another workflow.

## Development tests

```sh
python3 tests/create_fixture_dictionary.py /tmp/metasequoia-ime-test/msime.db
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

Download the `.pkg` and its checksum, verify it, then double-click the package to open the native macOS Installer. The package installs the current user's copy in `~/Library/Input Methods` and does not require administrator privileges. Log out after installation so macOS refreshes its input source cache.

```sh
shasum -a 256 -c MetasequoiaIME-vX.Y.Z-macos-universal.pkg.sha256
```

Release builds are signed with a Developer ID Application identity, signed as an installer with a Developer ID Installer identity, and notarized before publication. The release workflow requires these repository secrets and fails before downloading build dependencies when any are missing:

- `MACOS_DEVELOPER_ID_CERTIFICATE_BASE64`
- `MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `MACOS_SIGNING_KEYCHAIN_PASSWORD`
- `MACOS_NOTARY_APPLE_ID`
- `MACOS_NOTARY_TEAM_ID`
- `MACOS_NOTARY_APP_SPECIFIC_PASSWORD`
- `MACOS_DEVELOPER_ID_APPLICATION`
- `MACOS_DEVELOPER_ID_INSTALLER`

Local development builds remain ad-hoc signed. After installation and logout, enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit.

The ZIP provides the same current-user destination through `Install.command` when a command-line installation is preferred. The installer verifies both the code signature and Gatekeeper acceptance before replacing an existing installation.

Verify the ZIP checksum, extract it, and run `Install.command`:

```sh
shasum -a 256 -c MetasequoiaIME-vX.Y.Z-macos-universal.zip.sha256
./MetasequoiaIME-vX.Y.Z/Install.command
```

## License

Metasequoia IME for macOS is distributed under the GNU General Public License version 3. Release archives, installer packages, and the application bundle include the applicable GPL and third-party license notices; see `LICENSE` and `THIRD_PARTY_NOTICES.txt`.
