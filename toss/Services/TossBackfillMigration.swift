import Foundation
import ImageIO
import SwiftData
import TossKit

final class TossBackfillMigration {
  private let migrationCompletionKey = "toss_backfill_v1_completed"
  private let userDefaults = UserDefaults.standard

  private var migrationTask: Task<Void, Never>?

  func startIfNeeded(modelContainer: ModelContainer) {
    guard migrationTask == nil else { return }
    guard !userDefaults.bool(forKey: migrationCompletionKey) else { return }

    migrationTask = Task(priority: .utility) { [weak self] in
      await self?.runMigration(modelContainer: modelContainer)
    }
  }

  func cancel() {
    migrationTask?.cancel()
    migrationTask = nil
  }

  private func runMigration(modelContainer: ModelContainer) async {
    defer { migrationTask = nil }

    let context = ModelContext(modelContainer)
    var offset = 0

    while !Task.isCancelled {
      var descriptor = FetchDescriptor<Toss>()
      descriptor.sortBy = [SortDescriptor(\Toss.createdAt, order: .forward)]
      descriptor.fetchOffset = offset
      descriptor.fetchLimit = 100

      guard let tosses = try? context.fetch(descriptor), !tosses.isEmpty else {
        break
      }

      for toss in tosses {
        if Task.isCancelled {
          break
        }

        enrich(toss)
      }

      try? context.save()
      offset += tosses.count
    }

    if !Task.isCancelled {
      userDefaults.set(true, forKey: migrationCompletionKey)
    }
  }

  private func enrich(_ toss: Toss) {
    if toss.previewPlainText == nil || toss.previewPlainText?.isEmpty == true {
      toss.previewPlainText = CardPreviewText.makePreview(from: toss.content)
    }

    if toss.searchIndex == nil || toss.searchIndex?.isEmpty == true {
      toss.searchIndex = CardPreviewText.makeSearchIndex(
        content: toss.content,
        metadataTitle: toss.metadataTitle,
        metadataDescription: toss.metadataDescription,
        metadataAuthor: toss.metadataAuthor
      )
    }

    if toss.thumbnailDataOptimized == nil,
      let imageData = toss.imageData,
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
    }

    if toss.metadataFetchState == nil {
      toss.metadataFetchState = toss.type == .link ? .success : .pending
    }

    if toss.metadataFetchedAt == nil, toss.metadataFetchState != nil {
      toss.metadataFetchedAt = toss.createdAt
    }
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
}
