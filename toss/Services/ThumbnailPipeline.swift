import Foundation
import ImageIO
import SwiftData

#if os(macOS)
  import AppKit
  typealias ThumbnailImage = NSImage
#else
  import UIKit
  typealias ThumbnailImage = UIImage
#endif

actor ThumbnailPipeline {
  static let shared = ThumbnailPipeline()

  private let cache = NSCache<NSString, ThumbnailImage>()
  private let minimumLongestEdgePixels: Int
  private let decodeOversampleFactor: CGFloat

  private init() {
    #if os(macOS)
      cache.totalCostLimit = 256 * 1024 * 1024
      minimumLongestEdgePixels = 720
    #else
      cache.totalCostLimit = 96 * 1024 * 1024
      minimumLongestEdgePixels = 640
    #endif
    decodeOversampleFactor = 1.25
  }

  func thumbnail(
    for tossID: PersistentIdentifier,
    rawData: Data?,
    targetPixels: CGSize
  ) async -> ThumbnailImage? {
    guard let rawData else { return nil }

    let requestedLongestEdge = Int(
      max(targetPixels.width, targetPixels.height).rounded(.up)
    )
    let oversampledLongestEdge = Int(
      (CGFloat(requestedLongestEdge) * decodeOversampleFactor).rounded(.up)
    )
    let maxDimension = max(
      requestedLongestEdge,
      oversampledLongestEdge,
      minimumLongestEdgePixels,
      1
    )

    let cacheKey = "\(tossID)-\(maxDimension)" as NSString

    if let cached = cache.object(forKey: cacheKey) {
      return cached
    }

    guard
      let thumbnail = Self.downsample(
        data: rawData,
        maxPixelSize: maxDimension
      )
    else {
      return nil
    }

    cache.setObject(thumbnail, forKey: cacheKey, cost: Self.pixelCost(of: thumbnail))
    return thumbnail
  }

  private static func downsample(
    data: Data,
    maxPixelSize: Int
  ) -> ThumbnailImage? {
    let sourceOptions: [CFString: Any] = [
      kCGImageSourceShouldCache: false,
    ]

    guard
      let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary)
    else {
      return nil
    }

    let downsampleOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]

    guard
      let cgImage = CGImageSourceCreateThumbnailAtIndex(
        source,
        0,
        downsampleOptions as CFDictionary
      )
    else {
      return nil
    }

    #if os(macOS)
      return NSImage(cgImage: cgImage, size: .zero)
    #else
      return UIImage(cgImage: cgImage)
    #endif
  }

  private static func pixelCost(of image: ThumbnailImage) -> Int {
    #if os(macOS)
      guard
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
      else {
        return 1
      }
      return max(1, cgImage.width * cgImage.height * 4)
    #else
      let pixelWidth = Int((image.size.width * image.scale).rounded(.up))
      let pixelHeight = Int((image.size.height * image.scale).rounded(.up))
      return max(1, pixelWidth * pixelHeight * 4)
    #endif
  }
}
