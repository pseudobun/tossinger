#if os(iOS)
    import SwiftUI
    import SwiftData
    import MarkdownUI

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
                        .frame(maxHeight: .infinity)
                    } else {
                        // Edit mode - text editor
                        TextEditor(text: $content)
                            .font(.system(.body, design: .monospaced))
                            .focused($isFocused)
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

            // Check if it's a URL
            if let url = URL(
                string: content.trimmingCharacters(in: .whitespaces)
            ),
                url.scheme != nil,
                url.scheme == "http" || url.scheme == "https"
            {
                // It's a URL - capture screenshot
                captureWebsiteScreenshot(url: url)
            } else {
                // Plain text
                let toss = Toss(content: content, type: .text)
                modelContext.insert(toss)
                dismiss()
            }
        }

        private func captureWebsiteScreenshot(url: URL) {
            isLoadingScreenshot = true

            WebsiteMetadataFetcher.fetchImageOrScreenshot(url: url) { image in
                if let imageData = image?.pngData() {
                    let toss = Toss(
                        content: url.absoluteString,
                        type: .link,
                        imageData: imageData
                    )
                    modelContext.insert(toss)
                }

                dismiss()
            }
        }
    }
#endif
