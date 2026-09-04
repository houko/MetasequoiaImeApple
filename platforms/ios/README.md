# iOS frontend

This directory contains the native iOS host app, custom keyboard extension, iOS-only shared UI, and their tests. `project.yml` is the reproducible XcodeGen source of truth; generated `.xcodeproj` files are build artifacts and are not committed.

The iOS frontend consumes `MetasequoiaImeEngine` through the Objective-C++ adapter in `shared/apple-bridge`. It must not import AppKit, InputMethodKit, Sparkle, macOS registration helpers, or macOS installer code. The keyboard operates locally without Open Access; App Group and network-related capabilities require a later, explicit design and review.

See [Apple platform architecture](../../docs/apple-platform-architecture.md) for ownership boundaries and the progressive pull-request sequence.

Generate and build the current shell for the Simulator from the repository root:

```sh
brew install boost fmt spdlog xcodegen
python3 platforms/ios/scripts/prepare_dictionary.py
mkdir -p build/ios
xcodegen generate --spec platforms/ios/project.yml --project build/ios --project-root .
xcodebuild -project build/ios/MetasequoiaImeIOS.xcodeproj -scheme MetasequoiaImeIOS -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios-derived CODE_SIGNING_ALLOWED=NO build
```

`BREW_PREFIX` defaults to `/opt/homebrew` in `project.yml`; override that build setting when dependencies are installed under another prefix.

The keyboard routes letter input, composition editing, raw/candidate commit, cancellation, numbered candidate selection, and Chinese punctuation through the shared engine. The native `123` / `ABC` layer owns only key layout; it does not duplicate the engine's composition or punctuation policy.

`prepare_dictionary.py` first builds the canonical database, then retains all single-syllable entries and common multi-syllable entries with weight 2000 or greater. The generated database and its SHA-256 sidecar are ignored build artifacts. At runtime the extension atomically installs a changed bundled database into its private writable Application Support directory, keeping dictionary access local without requesting Open Access.
