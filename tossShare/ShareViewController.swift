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

class ShareViewController: UIViewController {
  private var container: ModelContainer!
  private let successLabel = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    setupModelContainer()
    handleSharedContent()
  }

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // Configure success label
    successLabel.text = "Tossed for later!"
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

  private func setupModelContainer() {
    do {
      let schema = Schema([Toss.self])

      guard
        let containerURL = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier:
            "group.lutra-labs.toss"
        )
      else {
        fatalError("Shared container not found")
      }

      let storeURL = containerURL.appendingPathComponent("default.store")

      // Remove CloudKit configuration for share extension, the main app will handle syncing
      let configuration = ModelConfiguration(
        url: storeURL
      )

      container = try ModelContainer(
        for: schema,
        configurations: [configuration]
      )
    } catch {
      print("Failed to setup ModelContainer: \(error)")
    }
  }

  private func handleSharedContent() {
    guard
      let extensionItem = extensionContext?.inputItems.first
        as? NSExtensionItem,
      let itemProvider = extensionItem.attachments?.first
    else {
      closeExtension()
      return
    }

    // Handle URL
    if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier) {
        (item, _) in
        if let url = item as? URL {
          Task {
            await self.saveTossWithMetadata(url: url)
          }
        } else {
          self.showSuccessAndClose()
        }
      }
    }
    // Handle text
    else if itemProvider.hasItemConformingToTypeIdentifier(
      UTType.plainText.identifier
    ) {
      itemProvider.loadItem(
        forTypeIdentifier: UTType.plainText.identifier
      ) { (item, _) in
        if let text = item as? String {
          self.saveToss(content: text, type: .text)
        }
        self.showSuccessAndClose()
      }
    } else {
      closeExtension()
    }
  }

  private func saveTossWithMetadata(url: URL) async {
    let result = await MetadataCoordinator.fetchMetadata(
      url: url,
      timeout: MetadataCoordinator.shareExtensionTimeout
    )

    let context = ModelContext(container)
    let toss = Toss(
      content: url.absoluteString,
      type: .link,
      imageData: result.imageData
    )

    toss.metadataTitle = result.title
    toss.metadataDescription = result.description
    toss.metadataAuthor = result.author
    toss.platformType = result.platformType
    toss.metadataFetchState = result.fetchState
    toss.metadataFetchedAt = result.fetchedAt

    let previewSeed = result.description ?? result.title ?? url.absoluteString
    toss.previewPlainText = Self.makePreview(from: previewSeed)
    toss.searchIndex = Self.makeSearchIndex(
      content: url.absoluteString,
      metadataTitle: result.title,
      metadataDescription: result.description,
      metadataAuthor: result.author
    )

    if let imageData = result.imageData,
      let optimized = ScreenshotCapturer.optimizedImageData(
        from: imageData,
        maxPixelSize: 1024,
        maxBytes: 350 * 1024,
        initialQuality: 0.75
      )
    {
      toss.thumbnailDataOptimized = optimized

      if let dimensions = dimensions(for: optimized) {
        toss.thumbnailWidth = dimensions.width
        toss.thumbnailHeight = dimensions.height
      }
    }

    context.insert(toss)
    try? context.save()

    await MainActor.run {
      self.showSuccessAndClose()
    }
  }

  private func saveToss(content: String, type: TossType) {
    let context = ModelContext(container)
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
    try? context.save()
  }

  private func showSuccessAndClose() {
    DispatchQueue.main.async {
      // Fade in the success message
      UIView.animate(withDuration: 0.3) {
        self.successLabel.alpha = 1
      } completion: { _ in
        // Wait 1 second, then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          self.closeExtension()
        }
      }
    }
  }

  private func closeExtension() {
    extensionContext?.completeRequest(returningItems: nil)
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
}
