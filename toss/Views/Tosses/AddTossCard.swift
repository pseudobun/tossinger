//
//  AddTossCard.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
//

#if os(macOS)
import ImageIO
import SwiftData
import SwiftUI
import TossKit

struct AddTossCard: View {
  @Environment(\.modelContext) private var modelContext
  @State private var content = ""
  @State private var isLoadingScreenshot = false
  @Binding var isEditing: Bool
  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if isEditing {
        HStack {
          Text("Quick toss")
            .font(.caption)
            .foregroundStyle(.secondary)

          Spacer()

          Button {
            clearEditingState()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.body)
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)

        ZStack {
          TextEditor(text: $content)
            .font(.body)
            .focused($isFocused)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .frame(
              maxWidth: .infinity,
              maxHeight: .infinity,
              alignment: .topLeading
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .focusable()
            .onKeyPress { press in
              if press.key == .return
                && press.modifiers.contains(.command)
              {
                saveToss()
                return .handled
              }
              return .ignored
            }

          if isLoadingScreenshot {
            ProgressView()
              .scaleEffect(1.3)
              .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
              )
              .background(.ultraThinMaterial)
          }
        }
      } else {
        Text("Add a quick toss...")
          .font(.body)
          .foregroundStyle(.secondary)
          .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
          )
          .padding(12)
          .contentShape(Rectangle())
          .onTapGesture {
            isEditing = true
            isFocused = true
          }
      }
    }
    .frame(minHeight: 150, maxHeight: 300)
    .background(cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          isEditing ? Color.accentColor : Color.clear,
          lineWidth: 2
        )
    )
  }

  private var cardBackground: Color {
    #if os(macOS)
      return Color(nsColor: .controlBackgroundColor)
    #else
      return Color(uiColor: .secondarySystemBackground)
    #endif
  }

  private func saveToss() {
    guard
      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      clearEditingState()
      return
    }

    if let url = URL(
      string: content.trimmingCharacters(in: .whitespaces)
    ),
      url.scheme != nil,
      url.scheme == "http" || url.scheme == "https"
    {
      Task {
        await persistLinkToss(url: url)
      }
    } else {
      persistTextToss()
    }
  }

  @MainActor
  private func persistTextToss() {
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

    modelContext.insert(toss)
    clearEditingState()
  }

  @MainActor
  private func persistLinkToss(url: URL) async {
    isLoadingScreenshot = true
    defer { isLoadingScreenshot = false }

    let result = await MetadataCoordinator.fetchMetadata(
      url: url,
      timeout: MetadataCoordinator.defaultMainAppTimeout
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

    modelContext.insert(toss)
    clearEditingState()
  }

  @MainActor
  private func clearEditingState() {
    withAnimation {
      content = ""
      isEditing = false
      isFocused = false
      isLoadingScreenshot = false
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

#Preview("Not Editing") {

    AddTossCard(isEditing: .constant(false))
      .modelContainer(for: Toss.self, inMemory: true)
      .frame(width: 400, height: 300)
      .padding(40)
      .background(.black)

}

#Preview("Editing") {

    AddTossCard(isEditing: .constant(true))
      .modelContainer(for: Toss.self, inMemory: true)
      .frame(width: 400, height: 300)
      .padding(40)
      .background(.black)
}
#endif
