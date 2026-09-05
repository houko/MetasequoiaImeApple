# macOS traditional Chinese output design

## Goal

Add the simplified/traditional output switch shown in the product README while keeping the macOS interface native and the existing settings window unchanged. The default remains simplified Chinese.

## Architecture

The engine and dictionary continue to use their original simplified strings. The macOS frontend converts only visible Chinese candidates and committed Chinese text, matching the Windows implementation's render/commit boundary. Auxiliary codes are calculated before conversion, candidate selection continues to use engine indexes, and Japanese output is not converted.

Conversion uses Core Foundation's ICU-backed `CFStringTransform` with the `Simplified-Traditional` transform. An empty string or a failed transform returns the original value, so input remains available without a new runtime dependency or bundled conversion database.

## Interaction

The InputMethodKit menu gains mutually exclusive “简体输出” and “繁体输出” items. The native floating toolbar gains one `简`/`繁` button that toggles the same persisted preference and updates immediately. This batch does not add a settings row, resize the settings window, or copy the Windows toolbar styling.

## Lifecycle and data flow

The preference is stored in `NSUserDefaults` and announced through an in-process notification. Candidate display and `applyResult` read the current preference at render/commit time. The active floating-toolbar owner refreshes its label on notification; inactive controllers cannot acquire toolbar ownership.

## Verification

Unit tests cover actual simplified-to-traditional conversion, unchanged simplified/ASCII/empty output, preference persistence, menu state/actions, toolbar state/action dispatch, and the controller's candidate and commit conversion calls. Existing macOS tests and the application build must remain green. Local computer-use inspection verifies the fifth native toolbar control without changing the settings window.
