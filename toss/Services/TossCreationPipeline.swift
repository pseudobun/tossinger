import Foundation
import ImageIO
import SwiftData

enum TossCreationPipelineError: Error {
  case emptyContent
}

enum TossCreationPipeline {
  static func linkURLIfSupported(from content: String) -> URL? {
    guard let url = URL(string: content.trimmingCharacters(in: .whitespaces)) else {
      return nil
    }

    guard let scheme = url.scheme?.lowercased() else {
      return nil
    }

    guard scheme == "http" || scheme == "https" else {
      return nil
    }

    return url
  }

  static func buildToss(
    from content: String,
    timeout: TimeInterval = MetadataCoordinator.defaultMainAppTimeout
  ) async throws -> Toss {
    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw TossCreationPipelineError.emptyContent
    }

    if let url = linkURLIfSupported(from: content) {
      return await buildLinkToss(url: url, timeout: timeout)
    }

    return buildTextToss(content: content)
  }

  private static func buildTextToss(content: String) -> Toss {
    let toss = Toss(content: content, type: .text)
    toss.previewPlainText = CardPreviewText.makePreview(from: content)
    toss.searchIndex = CardPreviewText.makeSearchIndex(
      content: content,
      metadataTitle: nil,
      metadataDescription: nil,
      metadataAuthor: nil
    )
    toss.metadataFetchState = .pending
    toss.metadataFetchedAt = Date()
    return toss
  }

  private static func buildLinkToss(
    url: URL,
    timeout: TimeInterval
  ) async -> Toss {
    let result = await MetadataCoordinator.fetchMetadata(
      url: url,
      timeout: timeout
    )

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
    toss.previewPlainText = CardPreviewText.makePreview(from: previewSeed)
    toss.searchIndex = CardPreviewText.makeSearchIndex(
      content: url.absoluteString,
      metadataTitle: result.title,
      metadataDescription: result.description,
      metadataAuthor: result.author
    )

    if let imageData = result.imageData,
      let optimized = await ScreenshotCapturer.optimizedImageData(
        from: imageData,
        maxPixelSize: await ScreenshotCapturer.preferredMaxPixelSize,
        maxBytes: await ScreenshotCapturer.preferredMaxBytes,
        initialQuality: await ScreenshotCapturer.preferredInitialQuality,
        minimumQuality: await ScreenshotCapturer.preferredMinimumQuality
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

    return toss
  }

  static func buildSkeletonLinkToss(url: URL) -> Toss {
    let toss = Toss(content: url.absoluteString, type: .link)
    toss.platformType = MetadataCoordinator.detectPlatformType(url: url)
    toss.metadataFetchState = .pending
    toss.metadataFetchedAt = Date()
    toss.previewPlainText = CardPreviewText.makePreview(from: url.absoluteString)
    toss.searchIndex = CardPreviewText.makeSearchIndex(
      content: url.absoluteString,
      metadataTitle: nil,
      metadataDescription: nil,
      metadataAuthor: nil
    )
    return toss
  }

  @MainActor
  static func enrichLinkToss(
    _ toss: Toss,
    in context: ModelContext,
    timeout: TimeInterval = MetadataCoordinator.defaultMainAppTimeout
  ) async {
    guard let url = URL(string: toss.content) else { return }

    let result = await MetadataCoordinator.fetchMetadata(url: url, timeout: timeout)

    toss.metadataTitle = result.title
    toss.metadataDescription = result.description
    toss.metadataAuthor = result.author
    toss.platformType = result.platformType
    toss.metadataFetchState = result.fetchState
    toss.metadataFetchedAt = result.fetchedAt
    toss.imageData = result.imageData

    let previewSeed = result.description ?? result.title ?? url.absoluteString
    toss.previewPlainText = CardPreviewText.makePreview(from: previewSeed)
    toss.searchIndex = CardPreviewText.makeSearchIndex(
      content: url.absoluteString,
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

    try? context.save()
  }

  @MainActor
  static func retryPendingMetadata(modelContainer: ModelContainer) async {
    let context = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<Toss>(
      predicate: #Predicate<Toss> { $0.metadataFetchStateRawValue == "pending" && $0.typeRawValue == "link" },
      sortBy: [SortDescriptor(\Toss.createdAt, order: .reverse)]
    )

    guard let pending = try? context.fetch(descriptor) else { return }

    for toss in pending.prefix(20) {
      guard !Task.isCancelled else { break }
      await enrichLinkToss(toss, in: context)
    }
  }

  private static func dimensions(for data: Data) -> (width: Int, height: Int)? {
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
