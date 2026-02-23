#if os(iOS)
  import ImageIO
  import MarkdownUI
  import SwiftData
  import SwiftUI

  struct AddTossView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var content = ""
    @State private var isLoadingScreenshot = false
    @State private var isPreviewMode = false
    @FocusState private var isFocused: Bool

    var body: some View {
      NavigationStack {
        ZStack {
          if isPreviewMode {
            // Preview mode - rendered markdown
            ScrollView {
              Markdown(content)
                .padding()
                .frame(
                  maxWidth: .infinity,
                  alignment: .topLeading
                )
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
          } else {
            // Edit mode - text editor
            TextEditor(text: $content)
              .font(.system(.body, design: .monospaced))
              .focused($isFocused)
              .scrollIndicators(.hidden)
              .padding()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }

          if isLoadingScreenshot {
            ProgressView()
              .scaleEffect(1.5)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(.ultraThinMaterial)
          }
        }
        .navigationTitle("New Toss")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") {
              dismiss()
            }
          }

          ToolbarItem(placement: .principal) {
            Toggle(isOn: $isPreviewMode) {
              Label(
                "Preview",
                systemImage: isPreviewMode ? "eye.fill" : "eye"
              )
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
          }

          ToolbarItem(placement: .topBarTrailing) {
            Button {
              saveToss()
            } label: {
              Image(systemName: "checkmark")
            }
          }
        }
        .onAppear {
          isFocused = true
        }
      }
    }

    private func saveToss() {
      guard
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        dismiss()
        return
      }

      if let url = URL(
        string: content.trimmingCharacters(in: .whitespaces)
      ),
        url.scheme != nil,
        url.scheme == "http" || url.scheme == "https"
      {
        Task {
          await captureWebsiteScreenshot(url: url)
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
      dismiss()
    }

    @MainActor
    private func captureWebsiteScreenshot(url: URL) async {
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

      modelContext.insert(toss)
      dismiss()
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
#endif

#if os(macOS)
  import ImageIO
  import MarkdownUI
  import SwiftData
  import SwiftUI

  struct AddTossView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var content = ""
    @State private var isPreviewMode = false
    @State private var isLoadingScreenshot = false
    @FocusState private var isFocused: Bool

    var body: some View {
      ZStack {
        VStack(spacing: 0) {
          if isPreviewMode {
            // Preview mode - rendered markdown
            ScrollView {
              Markdown(content)
                .padding()
                .frame(
                  maxWidth: .infinity,
                  alignment: .topLeading
                )
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
          } else {
            // Edit mode - text editor
            TextEditor(text: $content)
              .font(.system(.body, design: .monospaced))
              .focused($isFocused)
              .scrollContentBackground(.hidden)
              .scrollIndicators(.hidden)
              .padding()
              .focusable()
              .frame(maxHeight: .infinity)
          }
        }
        .background(Color(NSColor.windowBackgroundColor))

        if isLoadingScreenshot {
          ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
        }
      }
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Toggle(isOn: $isPreviewMode) {
            Label(
              "Preview",
              systemImage: isPreviewMode ? "eye.fill" : "eye"
            )
          }
          .toggleStyle(.button)
          .buttonStyle(.borderless)
          .help("Toggle markdown preview")
        }

        ToolbarItem(placement: .confirmationAction) {
          Button {
            saveToss()
          } label: {
            Image(systemName: "checkmark")
              .font(.system(size: 14, weight: .semibold))
          }
          .buttonStyle(.plain)
          .frame(width: 28, height: 28)
          .background(.ultraThinMaterial, in: Circle())
          .keyboardShortcut(.return, modifiers: .command)
        }
      }
      .onAppear {
        isFocused = true
      }
      .onKeyPress { press in
        if press.key == .escape {
          dismiss()
          return .handled
        }
        return .ignored
      }
    }

    private func saveToss() {
      guard
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        dismiss()
        return
      }

      if let url = URL(
        string: content.trimmingCharacters(in: .whitespaces)
      ),
        url.scheme != nil,
        url.scheme == "http" || url.scheme == "https"
      {
        Task {
          await captureWebsiteScreenshot(url: url)
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
      dismiss()
    }

    @MainActor
    private func captureWebsiteScreenshot(url: URL) async {
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

      modelContext.insert(toss)
      dismiss()
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
#endif
