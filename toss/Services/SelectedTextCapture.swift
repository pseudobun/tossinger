#if os(macOS)
  import ApplicationServices
  import Foundation

  enum SelectedTextCapture {
    static func selectedText(promptForPermission: Bool) -> String? {
      let hasPermission =
        promptForPermission
        ? AccessibilityPermissionManager.requestSystemPrompt()
        : AccessibilityPermissionManager.isTrusted()

      guard hasPermission else {
        return nil
      }

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
