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

In System Settings > Keyboard > Text Input > Edit, select 水杉输入法 and choose its settings action to open the native 水杉输入法设置 panel. The first panel exposes the currently supported full-pinyin scheme; additional input and candidate options will be added incrementally.

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

- `MetasequoiaIME-vX.Y.Z-macos-universal.zip`
- `MetasequoiaIME-vX.Y.Z-macos-universal.zip.sha256`

Verify the checksum before extracting the archive:

```sh
shasum -a 256 -c MetasequoiaIME-vX.Y.Z-macos-universal.zip.sha256
```

The current alpha uses an ad-hoc application signature and is not Developer ID signed or notarized. After verifying the checksum, remove the download quarantine from the extracted release directory, run the installer, then log out and back in so macOS refreshes its input source cache:

```sh
xattr -dr com.apple.quarantine MetasequoiaIME-vX.Y.Z
./MetasequoiaIME-vX.Y.Z/Install.command
```
