#if os(macOS)
  import AppKit
  import ApplicationServices
  import Carbon.HIToolbox
  import Foundation

  enum SelectedTextCapture {
    static func selectedText(promptForPermission: Bool) async -> String? {
      let hasPermission =
        promptForPermission
        ? AccessibilityPermissionManager.requestSystemPrompt()
        : AccessibilityPermissionManager.isTrusted()

      guard hasPermission else {
        return nil
      }

      if let text = axSelectedText() {
        return text
      }

      return await clipboardFallback()
    }

    private static func axSelectedText() -> String? {
      let systemWideElement = AXUIElementCreateSystemWide()

      if let focusedElement = axElement(
        attribute: kAXFocusedUIElementAttribute as CFString,
        of: systemWideElement
      ),
        let text = selectedText(from: focusedElement)
      {
        return text
      }

      if let focusedApplication = axElement(
        attribute: kAXFocusedApplicationAttribute as CFString,
        of: systemWideElement
      ),
        let focusedElement = axElement(
          attribute: kAXFocusedUIElementAttribute as CFString,
          of: focusedApplication
        ),
        let text = selectedText(from: focusedElement)
      {
        return text
      }

      return nil
    }

    /// Fallback used when the Accessibility API does not expose the current
    /// selection (common in Electron apps, Java/Qt/Flutter apps, custom views).
    /// Snapshots the clipboard, synthesizes ⌘C, reads the string, and restores
    /// the original clipboard contents. Requires Accessibility trust for
    /// `CGEventPost`, which the caller has already verified.
    private static func clipboardFallback() async -> String? {
      let pasteboard = NSPasteboard.general
      let snapshot = PasteboardSnapshot.capture(from: pasteboard)
      let baselineChangeCount = pasteboard.changeCount

      guard postCommandC() else {
        snapshot.restore(to: pasteboard)
        return nil
      }

      // Poll for the target app to write its selection to the clipboard.
      // ~210 ms worst case (14 × 15 ms).
      var captured: String?
      for _ in 0..<14 {
        try? await Task.sleep(nanoseconds: 15_000_000)
        if pasteboard.changeCount != baselineChangeCount {
          captured = pasteboard.string(forType: .string)
          break
        }
      }

      // Small safety margin so a slow app doesn't race our restore.
      try? await Task.sleep(nanoseconds: 50_000_000)
      snapshot.restore(to: pasteboard)

      guard let captured else { return nil }
      let cleaned = captured.trimmingCharacters(in: .whitespacesAndNewlines)
      return cleaned.isEmpty ? nil : cleaned
    }

    private static func postCommandC() -> Bool {
      guard let source = CGEventSource(stateID: .combinedSessionState) else {
        return false
      }

      let keyCode = CGKeyCode(kVK_ANSI_C)
      guard
        let keyDown = CGEvent(
          keyboardEventSource: source,
          virtualKey: keyCode,
          keyDown: true
        ),
        let keyUp = CGEvent(
          keyboardEventSource: source,
          virtualKey: keyCode,
          keyDown: false
        )
      else {
        return false
      }

      // Force exactly Command down; strip any stale modifiers that might still
      // be held from the global shortcut, so apps see a clean ⌘C.
      keyDown.flags = .maskCommand
      keyUp.flags = .maskCommand

      keyDown.post(tap: .cghidEventTap)
      keyUp.post(tap: .cghidEventTap)
      return true
    }

    private struct PasteboardSnapshot {
      private let items: [[NSPasteboard.PasteboardType: Data]]

      static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let snapshots: [[NSPasteboard.PasteboardType: Data]] =
          pasteboard.pasteboardItems?.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
              if let data = item.data(forType: type) {
                dict[type] = data
              }
            }
            return dict
          } ?? []
        return PasteboardSnapshot(items: snapshots)
      }

      func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let rebuilt: [NSPasteboardItem] = items.compactMap { typeMap in
          guard !typeMap.isEmpty else { return nil }
          let item = NSPasteboardItem()
          for (type, data) in typeMap {
            item.setData(data, forType: type)
          }
          return item
        }
        if !rebuilt.isEmpty {
          pasteboard.writeObjects(rebuilt)
        }
      }
    }

    private static func selectedText(from element: AXUIElement) -> String? {
      if let directSelectedText = axString(
        attribute: kAXSelectedTextAttribute as CFString,
        of: element
      ) {
        let cleaned = directSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
          return cleaned
        }
      }

      guard let selectedRange = axValue(
        attribute: kAXSelectedTextRangeAttribute as CFString,
        of: element
      ) else {
        return nil
      }

      var resolvedValue: CFTypeRef?
      let rangeTextError = AXUIElementCopyParameterizedAttributeValue(
        element,
        kAXStringForRangeParameterizedAttribute as CFString,
        selectedRange,
        &resolvedValue
      )

      guard rangeTextError == .success, let rangeText = resolvedValue as? String else {
        return nil
      }

      let cleaned = rangeText.trimmingCharacters(in: .whitespacesAndNewlines)
      return cleaned.isEmpty ? nil : cleaned
    }

    private static func axElement(
      attribute: CFString,
      of element: AXUIElement
    ) -> AXUIElement? {
      var value: CFTypeRef?
      let error = AXUIElementCopyAttributeValue(element, attribute, &value)
      guard
        error == .success,
        let value,
        CFGetTypeID(value) == AXUIElementGetTypeID()
      else {
        return nil
      }

      return (value as! AXUIElement)
    }

    private static func axString(
      attribute: CFString,
      of element: AXUIElement
    ) -> String? {
      var value: CFTypeRef?
      let error = AXUIElementCopyAttributeValue(element, attribute, &value)
      guard error == .success, let stringValue = value as? String else {
        return nil
      }

      return stringValue
    }

    private static func axValue(
      attribute: CFString,
      of element: AXUIElement
    ) -> AXValue? {
      var value: CFTypeRef?
      let error = AXUIElementCopyAttributeValue(element, attribute, &value)
      guard error == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else {
        return nil
      }

      return (value as! AXValue)
    }
  }
#endif
