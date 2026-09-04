# iOS frontend

This directory contains the native iOS host app, custom keyboard extension, iOS-only shared UI, and their tests. `project.yml` is the reproducible XcodeGen source of truth; generated `.xcodeproj` files are build artifacts and are not committed.

The iOS frontend consumes `MetasequoiaImeEngine` through the Objective-C++ adapter in `shared/apple-bridge`. It must not import AppKit, InputMethodKit, Sparkle, macOS registration helpers, or macOS installer code. The keyboard operates locally without Open Access; App Group and network-related capabilities require a later, explicit design and review.

See [Apple platform architecture](../../docs/apple-platform-architecture.md) for ownership boundaries and the progressive pull-request sequence.

Generate and build the current shell for the Simulator from the repository root:

```sh
brew install boost fmt spdlog xcodegen
mkdir -p build/ios
xcodegen generate --spec platforms/ios/project.yml --project build/ios --project-root .
xcodebuild -project build/ios/MetasequoiaImeIOS.xcodeproj -scheme MetasequoiaImeIOS -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios-derived CODE_SIGNING_ALLOWED=NO build
```

`BREW_PREFIX` defaults to `/opt/homebrew` in `project.yml`; override that build setting when dependencies are installed under another prefix.

The keyboard routes letter input, composition editing, raw/candidate commit, cancellation, and candidate selection through the shared engine. This bridge step intentionally does not package the production dictionary yet, so a build without dictionary assets still exposes engine-owned preedit and commits its raw spelling. Dictionary pruning and on-device candidate packaging belong to the next progressive pull request.
