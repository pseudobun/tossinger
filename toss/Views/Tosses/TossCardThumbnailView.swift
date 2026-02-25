import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

struct TossCardThumbnailView: View {
  let toss: Toss

  @Environment(\.displayScale) private var displayScale
  @State private var image: Image?

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        if let image {
          image
            .interpolation(.high)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          Rectangle()
            .fill(.clear)
        }
      }
      .task(id: taskKey(for: proxy.size)) {
        await loadImage(for: proxy.size)
      }
    }
  }

  private func loadImage(for size: CGSize) async {
    guard FeatureFlags.useThumbnailPipeline else {
      await MainActor.run {
        image = fallbackImage
      }
      return
    }

    let effectiveScale = resolvedDisplayScale
    let targetPixels = CGSize(
      width: max(1, size.width * effectiveScale),
      height: max(1, size.height * effectiveScale)
    )

    let rawData = preferredSourceData

    guard
      let platformImage = await ThumbnailPipeline.shared.thumbnail(
        for: toss.persistentModelID,
        rawData: rawData,
        targetPixels: targetPixels
      )
    else {
      await MainActor.run {
        image = nil
      }
      return
    }

    await MainActor.run {
      #if os(macOS)
        image = Image(nsImage: platformImage)
      #else
        image = Image(uiImage: platformImage)
      #endif
    }
  }

  private var fallbackImage: Image? {
    guard let data = preferredSourceData else {
      return nil
    }

    #if os(macOS)
      guard let nsImage = NSImage(data: data) else { return nil }
      return Image(nsImage: nsImage)
    #else
      guard let uiImage = UIImage(data: data) else { return nil }
      return Image(uiImage: uiImage)
    #endif
  }

  private func taskKey(for size: CGSize) -> String {
    let effectiveScale = resolvedDisplayScale
    let widthBucket = Int((size.width * effectiveScale).rounded(.up))
    let heightBucket = Int((size.height * effectiveScale).rounded(.up))
    return "\(toss.persistentModelID)-\(widthBucket)x\(heightBucket)-\(preferredSourceData?.count ?? 0)"
  }

  private var preferredSourceData: Data? {
    toss.imageData ?? toss.thumbnailDataOptimized
  }

  private var resolvedDisplayScale: CGFloat {
    #if os(macOS)
      let screenScale = NSScreen.main?.backingScaleFactor ?? 1
      return max(displayScale, screenScale)
    #else
      return max(displayScale, UIScreen.main.scale)
    #endif
  }
}
