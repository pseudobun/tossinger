//
//  ShareViewController.swift
//  tossShare
//
//  Created by Urban Vidovič on 8. 10. 25.
//

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
          // cloudKitDatabase: .private("iCloud.lutra-labs.toss") // Remove this!
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
        (item, error) in
        if let url = item as? URL {
          self.saveToss(content: url.absoluteString, type: .link)
        }
        self.showSuccessAndClose()
      }
    }
    // Handle text
    else if itemProvider.hasItemConformingToTypeIdentifier(
      UTType.plainText.identifier
    ) {
      itemProvider.loadItem(
        forTypeIdentifier: UTType.plainText.identifier
      ) { (item, error) in
        if let text = item as? String {
          self.saveToss(content: text, type: .text)
        }
        self.showSuccessAndClose()
      }
    } else {
      closeExtension()
    }
  }

  private func saveToss(content: String, type: TossType) {
    let context = ModelContext(container)
    let toss = Toss(content: content, type: type)
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
}
