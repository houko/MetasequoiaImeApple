# iOS frontend

This directory is reserved for the native iOS host app, custom keyboard extension, iOS-only shared UI, and their tests.

The iOS frontend will consume `MetasequoiaImeEngine` through `shared/apple-bridge`. It must not import AppKit, InputMethodKit, Sparkle, macOS registration helpers, or macOS installer code. The first functional keyboard will operate locally without Open Access; App Group and network-related capabilities require a later, explicit design and review.

See [Apple platform architecture](../../docs/apple-platform-architecture.md) for ownership boundaries and the progressive pull-request sequence.
