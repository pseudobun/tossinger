#if os(macOS)
  import ApplicationServices
  import Foundation

  enum AccessibilityPermissionManager {
    static func isTrusted() -> Bool {
      AXIsProcessTrusted()
    }

    @discardableResult
    static func requestSystemPrompt() -> Bool {
      let options = [
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
      ] as CFDictionary

      return AXIsProcessTrustedWithOptions(options)
    }
  }
#endif
