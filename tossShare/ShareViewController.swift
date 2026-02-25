//
//  ShareViewController.swift
//  tossShare
//
//  Created by Urban Vidovič on 8. 10. 25.
//

import ImageIO
import Social
import SwiftData
import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: UIViewController {
  private enum PayloadKind {
    case url
    case text
  }

  private struct PayloadSelection {
    let provider: NSItemProvider
    let kind: PayloadKind
  }

  private static let cloudKitContainerIdentifier = "iCloud.lutra-labs.toss"
  private static let appGroupIdentifier = "group.lutra-labs.toss"
  private static let metadataEnrichmentBudget: TimeInterval = 1.5

  private var container: ModelContainer?
  private let successLabel = UILabel()
  private var didCompleteRequest = false

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    guard setupModelContainer() else {
      showMessageAndClose("Unable to initialize iCloud sync.")
      return
    }
    handleSharedContent()
  }

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // Configure success label
    successLabel.text = "Tossed and syncing..."
    successLabel.font = .systemFont(ofSize: 17, weight: .medium)
    successLabel.textAlignment = .center
    successLabel.textColor = .label
    successLabel.alpha = 0
    successLabel.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(successLabel)

    // Center the label
    NSLayoutConstraint.activate([
      successLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      successLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      successLabel.leadingAnchor.constraint(
        equalTo: view.leadingAnchor,
        constant: 20
      ),
      successLabel.trailingAnchor.constraint(
        equalTo: view.trailingAnchor,
        constant: -20
      ),
    ])
  }

  @discardableResult
  private func setupModelContainer() -> Bool {
    do {
      let schema = Schema([Toss.self])

      guard
        let containerURL = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier:
            Self.appGroupIdentifier
        )
      else {
        return false
      }

      let storeURL = containerURL.appendingPathComponent("default.store")

      let configuration = ModelConfiguration(
        url: storeURL,
        cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
      )

      container = try ModelContainer(
        for: schema,
        configurations: [configuration]
      )
      return true
    } catch {
      return false
    }
  }

  private func handleSharedContent() {
    guard let selection = selectPayload() else {
      closeExtension()
      return
    }

    switch selection.kind {
    case .url:
      selection.provider.loadItem(forTypeIdentifier: UTType.url.identifier) {
        item, _ in
        let parsedURL = Self.extractURL(from: item)
        Task { @MainActor in
          guard let url = parsedURL else {
            self.showMessageAndClose("Unable to read shared URL.")
            return
          }
          await self.saveURLToss(url: url)
        }
      }
    case .text:
      selection.provider.loadItem(
        forTypeIdentifier: UTType.plainText.identifier
      ) { item, _ in
        let parsedText = Self.extractText(from: item)
        Task { @MainActor in
          guard let text = parsedText else {
            self.showMessageAndClose("Unable to read shared text.")
            return
          }
          let didSave = self.saveToss(content: text, type: .text)
          if didSave {
            self.showSuccessAndClose()
          }
        }
      }
    }
  }

  private func selectPayload() -> PayloadSelection? {
    let extensionItems = extensionContext?.inputItems.compactMap {
      $0 as? NSExtensionItem
    } ?? []

    var textProvider: NSItemProvider?

    for item in extensionItems {
      for provider in item.attachments ?? [] {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
          return PayloadSelection(provider: provider, kind: .url)
        }

        if textProvider == nil,
          provider.hasItemConformingToTypeIdentifier(
            UTType.plainText.identifier
          )
        {
          textProvider = provider
        }
      }
    }

    if let textProvider {
      return PayloadSelection(provider: textProvider, kind: .text)
    }

    return nil
  }

  private func saveURLToss(url: URL) async {
    guard let context = makeModelContext() else {
      showMessageAndClose("Unable to access shared database.")
      return
    }

    let toss = Toss(content: url.absoluteString, type: .link, imageData: nil)
    toss.previewPlainText = Self.makePreview(from: url.absoluteString)
    toss.searchIndex = Self.makeSearchIndex(
      content: url.absoluteString,
      metadataTitle: nil,
      metadataDescription: nil,
      metadataAuthor: nil
    )
    toss.metadataFetchState = .pending
    toss.metadataFetchedAt = Date()

    context.insert(toss)

    do {
      try context.save()
      showMessage("Tossed and syncing...")
    } catch {
      showMessageAndClose("Failed to save toss.")
      return
    }

    let result = await MetadataCoordinator.fetchMetadata(
      url: url,
      timeout: min(
        MetadataCoordinator.shareExtensionTimeout,
        Self.metadataEnrichmentBudget
      )
    )

    applyMetadata(result, to: toss)

    do {
      try context.save()
    } catch {
      // Keep the initial save; metadata enrichment is best-effort.
    }

    closeExtension(after: 0.35)
  }

  private func applyMetadata(_ result: MetadataResult, to toss: Toss) {
    toss.imageData = result.imageData
    toss.metadataTitle = result.title
    toss.metadataDescription = result.description
    toss.metadataAuthor = result.author
    toss.platformType = result.platformType
    toss.metadataFetchState = result.fetchState
    toss.metadataFetchedAt = result.fetchedAt

    let previewSeed = result.description ?? result.title ?? toss.content
    toss.previewPlainText = Self.makePreview(from: previewSeed)
    toss.searchIndex = Self.makeSearchIndex(
      content: toss.content,
      metadataTitle: result.title,
      metadataDescription: result.description,
      metadataAuthor: result.author
    )

    if let imageData = result.imageData,
      let optimized = ScreenshotCapturer.optimizedImageData(
        from: imageData,
        maxPixelSize: ScreenshotCapturer.preferredMaxPixelSize,
        maxBytes: ScreenshotCapturer.preferredMaxBytes,
        initialQuality: ScreenshotCapturer.preferredInitialQuality,
        minimumQuality: ScreenshotCapturer.preferredMinimumQuality
      )
    {
      toss.thumbnailDataOptimized = optimized

      if let dimensions = dimensions(for: optimized) {
        toss.thumbnailWidth = dimensions.width
        toss.thumbnailHeight = dimensions.height
      }
    } else {
      toss.thumbnailDataOptimized = nil
      toss.thumbnailWidth = nil
      toss.thumbnailHeight = nil
    }
  }

  @discardableResult
  private func saveToss(content: String, type: TossType) -> Bool {
    guard let context = makeModelContext() else {
      showMessageAndClose("Unable to access shared database.")
      return false
    }

    let toss = Toss(content: content, type: type)
    toss.previewPlainText = Self.makePreview(from: content)
    toss.searchIndex = Self.makeSearchIndex(
      content: content,
      metadataTitle: nil,
      metadataDescription: nil,
      metadataAuthor: nil
    )
    toss.metadataFetchState = .pending
    toss.metadataFetchedAt = Date()

    context.insert(toss)

    do {
      try context.save()
      return true
    } catch {
      showMessageAndClose("Failed to save toss.")
      return false
    }
  }

  private func showSuccessAndClose() {
    showMessageAndClose("Tossed and syncing...")
  }

  private func closeExtension(after delay: TimeInterval = 0) {
    guard !didCompleteRequest else { return }
    didCompleteRequest = true

    if delay <= 0 {
      extensionContext?.completeRequest(returningItems: nil)
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      self.extensionContext?.completeRequest(returningItems: nil)
    }
  }

  private func closeExtension() {
    closeExtension(after: 0)
  }

  private func makeModelContext() -> ModelContext? {
    guard let container else { return nil }
    return ModelContext(container)
  }

  private func showMessage(_ message: String) {
    successLabel.text = message

    UIView.animate(withDuration: 0.2) {
      self.successLabel.alpha = 1
    }
  }

  private func showMessageAndClose(
    _ message: String,
    delay: TimeInterval = 0.35
  ) {
    showMessage(message)
    closeExtension(after: delay)
  }

  private func dimensions(for data: Data) -> (width: Int, height: Int)? {
    guard
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else {
      return nil
    }

    return (width, height)
  }

  private static func makePreview(from markdown: String, maxCharacters: Int = 280) -> String {
    var text = markdown

    text = text.replacingOccurrences(of: "```[\\s\\S]*?```", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "`([^`]*)`", with: "$1", options: .regularExpression)
    text = text.replacingOccurrences(of: "(?m)^#{1,6}\\s*", with: "", options: .regularExpression)
    text = text.replacingOccurrences(of: "(?m)^\\s*([-*+] |\\d+\\. )", with: "", options: .regularExpression)
    text = text.replacingOccurrences(of: "(?m)^>\\s?", with: "", options: .regularExpression)
    text = text.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^\\)]*\\)", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]*\\)", with: "$1", options: .regularExpression)
    text = text.replacingOccurrences(of: "[*_~]{1,3}", with: "", options: .regularExpression)
    text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    text = text.trimmingCharacters(in: .whitespacesAndNewlines)

    guard text.count > maxCharacters else {
      return text
    }

    let index = text.index(text.startIndex, offsetBy: maxCharacters)
    return String(text[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func makeSearchIndex(
    content: String,
    metadataTitle: String?,
    metadataDescription: String?,
    metadataAuthor: String?
  ) -> String {
    [
      content,
      metadataTitle ?? "",
      metadataDescription ?? "",
      metadataAuthor ?? "",
    ]
    .joined(separator: " ")
    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    .lowercased()
  }

  nonisolated private static func extractURL(from item: NSSecureCoding?) -> URL? {
    if let url = item as? URL {
      return url
    }

    if let nsURL = item as? NSURL {
      return nsURL as URL
    }

    if let text = item as? String {
      return URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    if let text = item as? NSString {
      return URL(
        string: (text as String).trimmingCharacters(
          in: .whitespacesAndNewlines
        )
      )
    }

    return nil
  }

  nonisolated private static func extractText(from item: NSSecureCoding?) -> String? {
    if let text = item as? String {
      return text
    }

    if let text = item as? NSString {
      return text as String
    }

    return nil
  }
}
