import Foundation
import ImageIO

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
