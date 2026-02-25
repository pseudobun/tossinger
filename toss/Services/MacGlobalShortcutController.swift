#if os(macOS)
  import AppKit
  import Foundation
  import KeyboardShortcuts
  import SwiftData

  @MainActor
  final class MacGlobalShortcutController: ObservableObject {
    @Published private(set) var lastErrorMessage: String?

    private var modelContainer: ModelContainer?
    private var isConfigured = false
    private var didRequestAccessibilityPromptThisSession = false
    private var didRequestStartupAccessibilityPrompt = false
    private var appBecameActiveObserver: NSObjectProtocol?

    func configureIfNeeded(modelContainer: ModelContainer) {
      guard !isConfigured else { return }
      isConfigured = true
      self.modelContainer = modelContainer

      requestStartupAccessibilityPromptIfNeeded()

      KeyboardShortcuts.onKeyUp(for: .addSelectedTextToToss) { [weak self] in
        Task { @MainActor [weak self] in
          await self?.handleGlobalShortcut()
        }
      }
    }

    private func requestStartupAccessibilityPromptIfNeeded() {
      guard !didRequestStartupAccessibilityPrompt else { return }

      if NSApplication.shared.isActive {
        requestStartupAccessibilityPromptNowIfNeeded()
        return
      }

      appBecameActiveObserver = NotificationCenter.default.addObserver(
        forName: NSApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.requestStartupAccessibilityPromptNowIfNeeded()
        }
      }
    }

    private func requestStartupAccessibilityPromptNowIfNeeded() {
      guard !didRequestStartupAccessibilityPrompt else { return }
      didRequestStartupAccessibilityPrompt = true
      removeAppBecameActiveObserver()

      guard !AccessibilityPermissionManager.isTrusted() else {
        didRequestAccessibilityPromptThisSession = false
        return
      }

      _ = AccessibilityPermissionManager.requestSystemPrompt()
      didRequestAccessibilityPromptThisSession = false
    }

    private func removeAppBecameActiveObserver() {
      guard let appBecameActiveObserver else { return }
      NotificationCenter.default.removeObserver(appBecameActiveObserver)
      self.appBecameActiveObserver = nil
    }

    private func handleGlobalShortcut() async {
      guard let modelContainer else { return }

      guard AccessibilityPermissionManager.isTrusted() else {
        if !didRequestAccessibilityPromptThisSession {
          _ = AccessibilityPermissionManager.requestSystemPrompt()
          didRequestAccessibilityPromptThisSession = true
        }
        lastErrorMessage = "Enable Accessibility permission for Tossinger, then press the shortcut again."
        return
      }
      didRequestAccessibilityPromptThisSession = false

      guard let selectedText = SelectedTextCapture.selectedText(promptForPermission: false) else {
        lastErrorMessage = "Unable to read selected text. Check Accessibility permissions."
        return
      }

      let content = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !content.isEmpty else {
        lastErrorMessage = "No selected text found."
        return
      }

      let context = ModelContext(modelContainer)

      do {
        let toss = try await TossCreationPipeline.buildToss(from: content)
        context.insert(toss)
        try context.save()
        lastErrorMessage = nil
      } catch TossCreationPipelineError.emptyContent {
        lastErrorMessage = "No selected text found."
      } catch {
        lastErrorMessage = "Failed to save selected text toss."
      }
    }
  }
#endif
