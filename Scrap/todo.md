features to implement:
1. change material. use a copy of ghostty's "background-blur = macos-glass-regular". this works on macos 15 (as a frosted glass material) and 26 (as full-on liquid glass).


---
*Note: Keep the codebase lean. Avoid bloating with unnecessary features, or non-pragmatic ways to do things that should be simple.*

long-term, need consideration, not being targeted right now.
perhaps extend scrap to be able to replace macos TextEdit? it tempts me. need to very explicitly save.


---

## Assessment

### Architecture Context
Scrap is a ~400-line SwiftUI+AppKit hybrid: hidden-titlebar window with an NSTextView wrapped in NSViewRepresentable, backed by a VisualEffectView (.hudWindow material, .behindWindow blending) for blur, and a ContentModel singleton for state. The window uses .fullSizeContentView with transparent titlebar.

### 1. Liquid glass material — Difficulty: Medium-Hard | Feasibility: Medium | ~1 day
Ghostty's "macos-glass-regular" is implemented using NSGlassEffectView, a new public AppKit class (macOS 26.0+):
- macOS 26+: NSGlassEffectView with .regular style, .cornerRadius (~16pt for hidden titlebar), .tintColor. Window must be isOpaque=false, backgroundColor near-transparent.
- macOS 15: Falls back to NSVisualEffectView. Closest frosted-glass equivalent is .underWindowBackground material.
- Risks: macOS version gating (#available(macOS 26.0, *)), corner radius must be eyeballed (no public API), light/dark theme switching can cause stale tinting (Ghostty hit bugs #9973, #11017), GPU-intensive, jarring active/inactive appearance difference. Recommend gating behind a Settings toggle.

NOTE: THIS VERY TRANSPARENT APPROACH SHOULD BE GATED. IN FLOAT MODE IT SHOULD RETURN TO ITS PRESENT, MUCH BLURRIER APPEARANCE. IF NOT FLOATING, IT SHOULD BE GLASSIER.

### ~~2. Inline word completions~~ — ABANDONED (v0.5)
**Attempted, failed.** See v0.5 post-mortem below.

---

## v0.5 Post-Mortem: Inline Word Completions

### What we tried: `NSSpellChecker.completions` for always-on word ghost

Goal: As the user types English words, show a dimmed ghost completion after the cursor. Tab accepts it. Ghost should appear automatically on every keystroke within a word fragment.

### Approach 1: Insert ghost into textStorage with custom attribute, strip from binding
- Inserted ghost suffix as `NSAttributedString` with a custom `ghostAttributeKey` into `NSTextView.textStorage`
- Stripped ghost-attributed chars in `textDidChange` before setting `parent.text` so the binding never saw ghost text
- Compared `realText` (stripped) in `updateNSView` to prevent overwriting

**Why it failed:**
- `NSTextView` moves the cursor after `textStorage.insert`, forcing manual cursor reset fights
- Ghost text sits in the middle of the document; any keystroke shifts positions around it
- Race conditions when keystrokes arrive during ghost recomputation (blocked by `isRecomputingGhost` guard, losing characters)
- Conditional cleanup of old ghost was unreliable — multi-char ghosts cleaned, single-char ghosts leaked ("testt" bug)
- `isRichText = false` may have been stripping the dimmed color attribute

### Approach 2: Visual overlay (`GhostOverlayView`) drawn at cursor via layout manager
- Created a lightweight `NSView` subclass as a subview of `NSTextView` that draws ghost text at `.zero`
- Positioned via `firstRect(forCharacterRange:)` at the insertion point
- Ghost never touched `textStorage` — zero binding pollution, no cursor fights

**Why it also failed:**
- The overlay positioned correctly but ghost text was never visible (likely a view hierarchy/layer ordering issue with `NSTextView`'s drawing)
- Even when visible briefly, Tab acceptance via `textView.insertText` triggered a `textDidChange` that recomputed the ghost for the now-completed word — this is *desired* but the overlay positioning after the insert was unreliable
- The fundamental problem: `NSTextView`'s text layout and our overlay positioning are not synchronized — when the overlay is positioned and then text changes (insert), the overlay is at a stale position until the next `textDidChange` re-positions it

### Root Cause
`NSTextView` is fundamentally a text-storage-driven view. Its cursor, selection, scrolling, and rendering are all tightly coupled to `NSTextStorage`. Introducing ghost text *outside* textStorage means we're fighting the view's core assumptions at every turn. Inserting ghost text *inside* textStorage means we're polluting the document model and fighting cursor management.

**The only clean approach** would be a fully custom text rendering pipeline (custom `NSLayoutManager`/`NSTextContainer`) that supports "virtual glyphs" — characters rendered but not stored. This is weeks of work and inappropriate for Scrap's scope.

### Decision
Word completions are **out of scope** for Scrap. The existing ghost system (auto-close brackets/quotes) works because it inserts real characters at the *same* time as the user's keystroke, as part of a single text change — no positioning fight needed.
