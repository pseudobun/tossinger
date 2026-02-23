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

    let targetPixels = CGSize(
      width: max(1, size.width * displayScale),
      height: max(1, size.height * displayScale)
    )

    let rawData = toss.thumbnailDataOptimized ?? toss.imageData

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
    guard let data = toss.thumbnailDataOptimized ?? toss.imageData else {
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
    let widthBucket = Int((size.width * displayScale).rounded(.up))
    let heightBucket = Int((size.height * displayScale).rounded(.up))
    return "\(toss.persistentModelID)-\(widthBucket)x\(heightBucket)-\((toss.thumbnailDataOptimized ?? toss.imageData)?.count ?? 0)"
  }
}
