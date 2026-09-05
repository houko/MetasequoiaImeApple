# macOS floating input toolbar design

## Goal

Bring the persistent input-status surface shown in the product README to macOS without copying Windows-only WebView behavior. The toolbar exposes only capabilities the macOS frontend already implements: Chinese/English mode, Chinese/Western punctuation, full-/half-width input, and settings.

## Chosen interaction

Use one process-wide AppKit `NSPanel` shared by InputMethodKit controllers. It is visible while the input method is active when the user preference is enabled, remains visible in both Chinese and English mode, does not activate the input-method process, and can be dragged by its background. AppKit frame autosaving remembers the user's placement; an off-screen saved frame is clamped to the current display before showing. The default position is the lower-right corner of the active screen.

The alternatives were a transient mode indicator and menu-bar-only controls. A transient indicator is less intrusive but does not provide the persistent state and settings entry shown in the reference. Menu-bar-only controls preserve native convention but leave the requested README feature absent.

## Visual direction

The panel is a compact native AppKit utility surface. It deliberately does not copy the Windows toolbar's colors, decoration, or layout: the Windows screenshot defines the feature set only. Four quiet controls use system typography and symbols: 中/英, 。/., 全/半, and a gear. Tooltips and accessibility labels describe both the action and current state. Light and dark appearances come entirely from semantic AppKit materials and colors.

## Lifecycle and data flow

The shared panel holds a weak delegate to the currently active input controller. Activation assigns the owner and refreshes persisted state; deactivation hides only when that controller still owns the panel, avoiding cross-client races. Button actions call existing controller preference and mode APIs, then refresh the panel. Settings adds a “显示悬浮状态栏” checkbox under Appearance. Standalone settings changes apply on the next activation; same-process changes apply immediately through a notification.

## Verification

Unit tests cover preference defaults/persistence, owner-safe visibility, button state/accessibility, frame clamping, and action dispatch. Controller source-contract tests cover activation/deactivation and state refresh. Local computer-use inspection verifies the settings placement, panel geometry and accessibility, and light/dark rendering.
