# iOS frontend

This directory contains the native iOS host app, custom keyboard extension, iOS-only shared UI, and their tests. `project.yml` is the reproducible XcodeGen source of truth; generated `.xcodeproj` files are build artifacts and are not committed.

The iOS frontend will consume `MetasequoiaImeEngine` through `shared/apple-bridge`. It must not import AppKit, InputMethodKit, Sparkle, macOS registration helpers, or macOS installer code. The first functional keyboard will operate locally without Open Access; App Group and network-related capabilities require a later, explicit design and review.

See [Apple platform architecture](../../docs/apple-platform-architecture.md) for ownership boundaries and the progressive pull-request sequence.

Generate and build the current shell for the Simulator from the repository root:

```sh
brew install xcodegen
xcodegen generate --spec platforms/ios/project.yml --project build/ios --project-root .
xcodebuild -project build/ios/MetasequoiaImeIOS.xcodeproj -scheme MetasequoiaImeIOS -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios-derived CODE_SIGNING_ALLOWED=NO build
```

The current keyboard shell inserts direct lowercase text and exposes Space, Return, Backspace, and the required next-keyboard control. Composition and candidates are intentionally deferred to the engine-bridge pull request.
