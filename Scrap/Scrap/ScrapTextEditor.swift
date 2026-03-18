import AppKit
import SwiftUI

class TransparentScroller: NSScroller {
  override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
    // Skip drawing the track background so it stays transparent
  }
}

class ScrapLineRuler: NSRulerView {
  override var isOpaque: Bool {
    return false
  }

  override func draw(_ dirtyRect: NSRect) {
    // Do NOT call super.draw(dirtyRect) to avoid default UI elements (background, hash marks)

    guard let textView = clientView as? NSTextView,
      let layoutManager = textView.layoutManager,
      let textContainer = textView.textContainer
    else { return }

    let visibleRect = textView.visibleRect
    let font = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
    let textColor = NSColor.secondaryLabelColor

    let attrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: font.pointSize * 0.82, weight: .regular),
      .foregroundColor: textColor,
    ]

    let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
    let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

    let string = textView.string as NSString
    var lineNumber = 1

    // Accurate line numbering: count lines before visible range
    string.enumerateSubstrings(
      in: NSRange(location: 0, length: charRange.location),
      options: [.byLines, .substringNotRequired]
    ) { _, _, _, _ in
      lineNumber += 1
    }

    let thickness = self.ruleThickness

    // Draw numbers for visible lines
    string.enumerateSubstrings(in: charRange, options: .byLines) { substring, lineRange, _, _ in
      let glyphRange = layoutManager.glyphRange(
        forCharacterRange: lineRange, actualCharacterRange: nil)
      let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

      let numStr = "\(lineNumber)" as NSString
      let numSize = numStr.size(withAttributes: attrs)

      // Critical: Correct Y alignment for scrolled view
      // The ruler's coordinate system is usually relative to the scroll view,
      // but the lineRect is relative to the text view's origin.
      let relativeY = lineRect.origin.y + textView.textContainerInset.height - visibleRect.origin.y
      let centeredY = relativeY + (lineRect.height - numSize.height) / 2

      let x = thickness - numSize.width - 8

      numStr.draw(at: NSPoint(x: x, y: centeredY), withAttributes: attrs)

      lineNumber += 1
    }
  }
}

class ScrapTextView: NSTextView {
  weak var scrapCoordinator: ScrapTextEditor.Coordinator?

  override func insertTab(_ sender: Any?) {
    if scrapCoordinator?.handleTab(in: self) != true {
      super.insertTab(sender)
    }
  }

  override func insertNewline(_ sender: Any?) {
    if scrapCoordinator?.handleNewline(in: self) != true {
      super.insertNewline(sender)
    }
  }

  override func insertBacktab(_ sender: Any?) {
    if scrapCoordinator?.handleBacktab(in: self) != true {
      super.insertBacktab(sender)
    }
  }
}

struct ScrapTextEditor: NSViewRepresentable {
  @Binding var text: String
  var font: NSFont
  var isSpellCheckEnabled: Bool
  var isAutoCloseEnabled: Bool
  var showLineNumbers: Bool

  static let pasteAndNormalizeNotification = Notification.Name("ScrapPasteAndNormalize")
  static let toggleDashListNotification = Notification.Name("ScrapToggleDashList")
  static let toggleNumberedListNotification = Notification.Name("ScrapToggleNumberedList")
  static let toggleCommentNotification = Notification.Name("ScrapToggleComment")

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.verticalScroller = TransparentScroller()
    scrollView.backgroundColor = .clear
    scrollView.contentView.drawsBackground = false

    let textView = ScrapTextView()
    textView.isRichText = false
    textView.drawsBackground = false
    textView.backgroundColor = .clear
    textView.autoresizingMask = [.width]
    textView.delegate = context.coordinator
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.allowsUndo = true
    textView.isContinuousSpellCheckingEnabled = isSpellCheckEnabled
    textView.textContainerInset = NSSize(width: 28, height: 28)

    // Ruler Setup
    let ruler = ScrapLineRuler(scrollView: scrollView, orientation: .verticalRuler)
    ruler.clientView = textView
    ruler.ruleThickness = 40
    scrollView.verticalRulerView = ruler

    NotificationCenter.default.addObserver(
      context.coordinator, selector: #selector(Coordinator.handlePasteAndNormalize),
      name: ScrapTextEditor.pasteAndNormalizeNotification, object: nil)
    NotificationCenter.default.addObserver(
      context.coordinator, selector: #selector(Coordinator.handleToggleDashList),
      name: ScrapTextEditor.toggleDashListNotification, object: nil)
    NotificationCenter.default.addObserver(
      context.coordinator, selector: #selector(Coordinator.handleToggleNumberedList),
      name: ScrapTextEditor.toggleNumberedListNotification, object: nil)
    NotificationCenter.default.addObserver(
      context.coordinator, selector: #selector(Coordinator.handleToggleComment),
      name: ScrapTextEditor.toggleCommentNotification, object: nil)

    textView.scrapCoordinator = context.coordinator

    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }

    context.coordinator.isUpdating = true
    defer { context.coordinator.isUpdating = false }

    if textView.string != text {
      context.coordinator.ghost = nil
      let savedSelection = textView.selectedRanges
      textView.string = text
      // Restore selection, clamping to new text length
      let maxLen = (text as NSString).length
      let clamped = savedSelection.map { rangeValue -> NSValue in
        let range = rangeValue.rangeValue
        let loc = min(range.location, maxLen)
        let len = min(range.length, maxLen - loc)
        return NSValue(range: NSRange(location: loc, length: len))
      }
      textView.selectedRanges = clamped
    }

    if textView.font != font {
      textView.font = font
    }
    if textView.isContinuousSpellCheckingEnabled != isSpellCheckEnabled {
      textView.isContinuousSpellCheckingEnabled = isSpellCheckEnabled
    }

    nsView.hasVerticalRuler = showLineNumbers
    nsView.rulersVisible = showLineNumbers
    if showLineNumbers {
      nsView.verticalRulerView?.needsDisplay = true
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, NSTextViewDelegate {
    var parent: ScrapTextEditor
    var isUpdating = false

    fileprivate struct GhostText {
      let position: Int
      let character: String
    }

    fileprivate var ghost: GhostText? = nil

    private static let numberedListRegex = try! NSRegularExpression(
      pattern: "^(\\d+)([a-z])?\\.\\s")
    private static let numberedPrefixRegex = try! NSRegularExpression(
      pattern: "^(\\d+)\\.\\s")
    private static let subItemPrefixRegex = try! NSRegularExpression(
      pattern: "^(\\d+)[a-z]\\.\\s")
    private static let autoClosePairs: [String: String] = [
      "(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'",
    ]

    init(_ parent: ScrapTextEditor) {
      self.parent = parent
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Ghost text helpers

    private func clearGhost(in textView: NSTextView) {
      if let ghost = ghost, let layoutManager = textView.layoutManager {
        let range = NSRange(location: ghost.position, length: 1)
        if NSMaxRange(range) <= (textView.string as NSString).length {
          layoutManager.removeTemporaryAttribute(
            .foregroundColor, forCharacterRange: range)
        }
      }
      ghost = nil
    }

    private func applyGhost(in textView: NSTextView, at position: Int, character: String) {
      ghost = GhostText(position: position, character: character)
      if let layoutManager = textView.layoutManager {
        layoutManager.addTemporaryAttribute(
          .foregroundColor, value: NSColor.tertiaryLabelColor,
          forCharacterRange: NSRange(location: position, length: 1))
      }
    }

    // MARK: - Tab / Newline handlers

    func handleTab(in textView: NSTextView) -> Bool {
      guard parent.isAutoCloseEnabled else { return false }

      let selectedRange = textView.selectedRange()
      guard selectedRange.length == 0 else { return false }

      let string = textView.string as NSString
      let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
      let beforeCursor = string.substring(
        with: NSRange(location: lineRange.location,
                      length: selectedRange.location - lineRange.location))

      // 1. Triple-dash separator expansion
      if beforeCursor == "---" {
        let separator = String(repeating: "\u{2014}", count: 24)
        textView.insertText(
          separator,
          replacementRange: NSRange(location: lineRange.location, length: 3))
        return true
      }

      // 2. Empty numbered prefix → indent to sub-item: "3. " → "2a. "
      if let match = Self.numberedPrefixRegex.firstMatch(
          in: beforeCursor,
          range: NSRange(location: 0, length: beforeCursor.utf16.count)),
        match.range.length == beforeCursor.utf16.count
      {
        let lineText = string.substring(with: lineRange)
        let lineContent =
          lineText.hasSuffix("\n") ? String(lineText.dropLast()) : lineText
        if beforeCursor == lineContent {
          let numberRange = match.range(at: 1)
          let numberStr = (beforeCursor as NSString).substring(with: numberRange)
          if let num = Int(numberStr), num > 1 {
            textView.insertText(
              "\(num - 1)a. ",
              replacementRange: NSRange(
                location: lineRange.location,
                length: (lineContent as NSString).length))
            return true
          }
        }
      }

      // 3. Accept ghost
      if let ghost = ghost, selectedRange.location == ghost.position {
        clearGhost(in: textView)
        textView.setSelectedRange(NSRange(location: ghost.position + 1, length: 0))
        return true
      }

      return false
    }

    func handleNewline(in textView: NSTextView) -> Bool {
      guard parent.isAutoCloseEnabled else { return false }

      let selectedRange = textView.selectedRange()
      guard selectedRange.length == 0 else { return false }

      let string = textView.string as NSString
      let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
      let beforeCursor = string.substring(
        with: NSRange(location: lineRange.location,
                      length: selectedRange.location - lineRange.location))

      // Numbered list: "1. item" or sub-item "3a. item"
      if let match = Self.numberedListRegex.firstMatch(
          in: beforeCursor,
          range: NSRange(location: 0, length: beforeCursor.utf16.count))
      {
        // Empty item (just the prefix) → remove prefix
        if match.range.length == beforeCursor.utf16.count {
          textView.insertText(
            "",
            replacementRange: NSRange(
              location: lineRange.location,
              length: (beforeCursor as NSString).length))
          return true
        }
        let numberRange = match.range(at: 1)
        let numberStr = (beforeCursor as NSString).substring(with: numberRange)
        let letterRange = match.range(at: 2)

        if letterRange.location != NSNotFound {
          // Sub-item: 3a → 3b, 3z → 4.
          let letter = (beforeCursor as NSString).substring(with: letterRange)
          if let scalar = letter.unicodeScalars.first, scalar.value < UnicodeScalar("z").value {
            let nextLetter = String(UnicodeScalar(scalar.value + 1)!)
            textView.insertText(
              "\n\(numberStr)\(nextLetter). ", replacementRange: selectedRange)
          } else if let num = Int(numberStr) {
            textView.insertText("\n\(num + 1). ", replacementRange: selectedRange)
          }
          return true
        } else if let num = Int(numberStr) {
          textView.insertText("\n\(num + 1). ", replacementRange: selectedRange)
          return true
        }
      }

      // En-dash list: "– item"
      if beforeCursor.hasPrefix("\u{2013} ") {
        if (beforeCursor as NSString).length == 2 {
          textView.insertText(
            "",
            replacementRange: NSRange(
              location: lineRange.location, length: 2))
          return true
        }
        textView.insertText("\n\u{2013} ", replacementRange: selectedRange)
        return true
      }

      // Dash list: "- item"
      if beforeCursor.hasPrefix("- ") {
        if (beforeCursor as NSString).length == 2 {
          textView.insertText(
            "",
            replacementRange: NSRange(
              location: lineRange.location, length: 2))
          return true
        }
        textView.insertText("\n- ", replacementRange: selectedRange)
        return true
      }

      return false
    }

    func handleBacktab(in textView: NSTextView) -> Bool {
      guard parent.isAutoCloseEnabled else { return false }

      let selectedRange = textView.selectedRange()
      guard selectedRange.length == 0 else { return false }

      let string = textView.string as NSString
      let lineRange = string.lineRange(
        for: NSRange(location: selectedRange.location, length: 0))
      let beforeCursor = string.substring(
        with: NSRange(location: lineRange.location,
                      length: selectedRange.location - lineRange.location))

      // Empty sub-item prefix "Na. " → outdent to "(N+1). "
      if let match = Self.subItemPrefixRegex.firstMatch(
          in: beforeCursor,
          range: NSRange(location: 0, length: beforeCursor.utf16.count)),
        match.range.length == beforeCursor.utf16.count
      {
        let lineText = string.substring(with: lineRange)
        let lineContent =
          lineText.hasSuffix("\n") ? String(lineText.dropLast()) : lineText
        if beforeCursor == lineContent {
          let numberRange = match.range(at: 1)
          let numberStr = (beforeCursor as NSString).substring(with: numberRange)
          if let num = Int(numberStr) {
            textView.insertText(
              "\(num + 1). ",
              replacementRange: NSRange(
                location: lineRange.location,
                length: (lineContent as NSString).length))
            return true
          }
        }
      }

      return false
    }

    // MARK: - Text view delegate

    func textDidChange(_ notification: Notification) {
      guard !isUpdating, let textView = notification.object as? NSTextView else { return }
      self.parent.text = textView.string
      textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true

      // Revalidate and reapply ghost styling
      if let ghost = ghost {
        let string = textView.string as NSString
        if ghost.position < string.length {
          let charAtPos = string.substring(
            with: NSRange(location: ghost.position, length: 1))
          if charAtPos == ghost.character {
            textView.layoutManager?.addTemporaryAttribute(
              .foregroundColor, value: NSColor.tertiaryLabelColor,
              forCharacterRange: NSRange(location: ghost.position, length: 1))
          } else {
            self.ghost = nil
          }
        } else {
          self.ghost = nil
        }
      }
    }

    @objc func handlePasteAndNormalize() {
      guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
      let pb = NSPasteboard.general
      guard let items = pb.pasteboardItems else { return }

      var contents = ""
      for item in items {
        if let str = item.string(forType: .string) {
          let normalized =
            str
            .replacingOccurrences(
              of: "[\u{201C}\u{201D}\u{201E}\u{201F}]", with: "\"", options: .regularExpression
            )
            .replacingOccurrences(
              of: "[\u{2018}\u{2019}\u{201A}\u{201B}]", with: "'", options: .regularExpression
            )
            .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
          contents += normalized
        }
      }
      if !contents.isEmpty {
        textView.insertText(contents, replacementRange: textView.selectedRange())
      }
    }

    @objc func handleToggleDashList() {
      guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
      modifySelectedLines(textView) { line in
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\u{2013} ") {
          return String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("- ") {
          return String(trimmed.dropFirst(2))
        } else {
          return "\u{2013} " + line
        }
      }
    }

    @objc func handleToggleNumberedList() {
      guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
      let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\s")
      var counter = 1
      modifySelectedLines(textView) { line in
        if let match = regex?.firstMatch(
          in: line, range: NSRange(location: 0, length: line.utf16.count))
        {
          return (line as NSString).replacingCharacters(in: match.range, with: "")
        } else {
          let res = "\(counter). " + line
          counter += 1
          return res
        }
      }
    }

    @objc func handleToggleComment() {
      guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
      modifySelectedLines(textView) { line in
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("# ") {
          return String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("// ") {
          return String(trimmed.dropFirst(3))
        } else {
          return "# " + line
        }
      }
    }

    private func modifySelectedLines(_ textView: NSTextView, transformer: (String) -> String) {
      let range = textView.selectedRange()
      let string = textView.string as NSString
      let lineRange = string.lineRange(for: range)
      let selectedText = string.substring(with: lineRange)
      let lines = selectedText.components(separatedBy: .newlines)
      let result = lines.map { transformer($0) }.joined(separator: "\n")
      textView.insertText(result, replacementRange: lineRange)
      textView.setSelectedRange(
        NSRange(location: lineRange.location, length: (result as NSString).length))
    }

    func textView(
      _ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange,
      replacementString: String?
    ) -> Bool {
      guard let replacement = replacementString else {
        clearGhost(in: textView)
        return true
      }

      // Overtype: user types the ghost character at the ghost position
      if let currentGhost = ghost, parent.isAutoCloseEnabled,
        replacement == currentGhost.character,
        affectedCharRange.location == currentGhost.position,
        affectedCharRange.length == 0
      {
        clearGhost(in: textView)
        textView.setSelectedRange(
          NSRange(location: currentGhost.position + 1, length: 0))
        return false
      }

      // Auto-close with ghost
      if parent.isAutoCloseEnabled, replacement.count == 1 {
        if let closing = Self.autoClosePairs[replacement] {
          if affectedCharRange.length > 0 {
            // Selection wrapping: no ghost needed
            clearGhost(in: textView)
            let selectedText = (textView.string as NSString).substring(with: affectedCharRange)
            textView.insertText(
              replacement + selectedText + closing, replacementRange: affectedCharRange)
            textView.setSelectedRange(
              NSRange(
                location: affectedCharRange.location + 1 + (selectedText as NSString).length + 1,
                length: 0))
            return false
          } else {
            // No selection: insert pair with ghost on closing char
            clearGhost(in: textView)
            textView.insertText(
              replacement + closing, replacementRange: affectedCharRange)
            let cursorPos = affectedCharRange.location + 1
            textView.setSelectedRange(NSRange(location: cursorPos, length: 0))
            applyGhost(in: textView, at: cursorPos, character: closing)
            return false
          }
        }
      }

      // Ghost position tracking for normal edits
      if let currentGhost = ghost {
        let editEnd = affectedCharRange.location + affectedCharRange.length
        if editEnd <= currentGhost.position {
          let delta = (replacement as NSString).length - affectedCharRange.length
          clearGhost(in: textView)
          ghost = GhostText(
            position: currentGhost.position + delta,
            character: currentGhost.character)
        } else if affectedCharRange.location <= currentGhost.position {
          clearGhost(in: textView)
        }
      }

      return true
    }
  }
}
