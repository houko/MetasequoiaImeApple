# Metasequoia IME for macOS

This repository contains the native macOS frontend for Metasequoia IME. It uses InputMethodKit and AppKit, embeds the shared C++ engine directly, and does not port the Windows TSF or WebView2 host.

The current alpha supports full-pinyin composition, live candidates from the official Metasequoia dictionary, candidate selection through the native candidate panel, Space to commit the leading candidate, Return to commit raw input, Backspace, Escape, and composition commit on focus changes.

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

In System Settings > Keyboard > Text Input > Edit, select 水杉输入法 and choose its settings action to open the native 水杉输入法设置 panel. The panel lets you choose 全拼 or 小鹤双拼, enable full-pinyin autocorrection, and enable auxiliary codes; these choices are saved for the current user and apply to the next input session. Additional input and candidate options will be added incrementally.

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

Download the `.pkg` and its checksum, verify it, then double-click the package to open the native macOS Installer. The package installs the input method system-wide at `/Library/Input Methods` and requires administrator privileges. Log out after installation so macOS refreshes its input source cache.

```sh
shasum -a 256 -c MetasequoiaIME-vX.Y.Z-macos-universal.pkg.sha256
```

Release builds are signed with a Developer ID Application identity, signed as an installer with a Developer ID Installer identity, and notarized before publication. The release workflow requires the corresponding certificate and App Store Connect credentials to be configured as repository secrets; it fails closed when they are missing. Local development builds remain ad-hoc signed. After installation and logout, enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit.

The ZIP remains the no-administrator option: it installs the signed bundle for the current user in `~/Library/Input Methods` via `Install.command`.

Verify the ZIP checksum, extract it, remove quarantine from the extracted release directory, and run `Install.command`:

```sh
shasum -a 256 -c MetasequoiaIME-vX.Y.Z-macos-universal.zip.sha256
xattr -dr com.apple.quarantine MetasequoiaIME-vX.Y.Z
./MetasequoiaIME-vX.Y.Z/Install.command
```
