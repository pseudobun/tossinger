#if os(macOS)
    import SwiftUI
    import SwiftData
    import MarkdownUI

    struct TossDetailView: View {
        let toss: Toss
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext
        @State private var editedContent = ""
        @State private var isPreviewMode = false
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack(spacing: 0) {
                if let imageData = toss.imageData,
                    let nsImage = NSImage(data: imageData)
                {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                        .padding()
                }

                if isPreviewMode {
                    // Preview mode - rendered markdown
                    ScrollView {
                        Markdown(editedContent)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: .infinity)
                } else {
                    // Edit mode - text editor in its own container
                    TextEditor(text: $editedContent)
                        .font(.system(.body, design: .monospaced))
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding()
                        .focusable()
                        .frame(maxHeight: .infinity)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
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
                        saveAndClose()
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
                editedContent = toss.content
                isFocused = true
            }
            .onKeyPress { press in
                if press.key == .escape {
                    saveAndClose()
                    return .handled
                }
                return .ignored
            }
        }

        private func saveAndClose() {
            toss.content = editedContent
            try? modelContext.save()
            dismiss()
        }
    }
#endif
