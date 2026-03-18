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

    let textView = NSTextView()
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

    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }

    context.coordinator.isUpdating = true
    defer { context.coordinator.isUpdating = false }

    if textView.string != text {
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

    init(_ parent: ScrapTextEditor) {
      self.parent = parent
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    func textDidChange(_ notification: Notification) {
      guard !isUpdating, let textView = notification.object as? NSTextView else { return }
      self.parent.text = textView.string
      textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
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
        if trimmed.hasPrefix("– ") {
          return String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("- ") {
          return String(trimmed.dropFirst(2))
        } else {
          return "– " + line
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
      guard parent.isAutoCloseEnabled, let replacement = replacementString, replacement.count == 1
      else { return true }
      let pairs: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"]
      if let closing = pairs[replacement] {
        if affectedCharRange.length > 0 {
          let selectedText = (textView.string as NSString).substring(with: affectedCharRange)
          textView.insertText(
            replacement + selectedText + closing, replacementRange: affectedCharRange)
          textView.setSelectedRange(
            NSRange(location: affectedCharRange.location + 1 + selectedText.count + 1, length: 0))
          return false
        } else {
          textView.insertText(replacement + closing, replacementRange: affectedCharRange)
          textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: 0))
          return false
        }
      }
      return true
    }
  }
}
