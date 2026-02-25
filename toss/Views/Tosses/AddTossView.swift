#if os(iOS)
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
      Task {
        await saveTossWithSharedPipeline()
      }
    }

    @MainActor
    private func saveTossWithSharedPipeline() async {
      guard
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        dismiss()
        return
      }

      let isLinkFlow = TossCreationPipeline.linkURLIfSupported(from: content) != nil
      if isLinkFlow {
        isLoadingScreenshot = true
      }
      defer {
        if isLinkFlow {
          isLoadingScreenshot = false
        }
      }

      do {
        let toss = try await TossCreationPipeline.buildToss(from: content)
        modelContext.insert(toss)
        dismiss()
      } catch TossCreationPipelineError.emptyContent {
        dismiss()
      } catch {
        // Keep the sheet open so the user can retry.
      }
    }
  }
#endif

#if os(macOS)
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
      Task {
        await saveTossWithSharedPipeline()
      }
    }

    @MainActor
    private func saveTossWithSharedPipeline() async {
      guard
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        dismiss()
        return
      }

      let isLinkFlow = TossCreationPipeline.linkURLIfSupported(from: content) != nil
      if isLinkFlow {
        isLoadingScreenshot = true
      }
      defer {
        if isLinkFlow {
          isLoadingScreenshot = false
        }
      }

      do {
        let toss = try await TossCreationPipeline.buildToss(from: content)
        modelContext.insert(toss)
        dismiss()
      } catch TossCreationPipelineError.emptyContent {
        dismiss()
      } catch {
        // Keep the sheet open so the user can retry.
      }
    }
  }
#endif
