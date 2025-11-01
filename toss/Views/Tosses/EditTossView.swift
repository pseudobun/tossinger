//
//  EditTossView.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
//

#if os(iOS)
    import SwiftUI
    import SwiftData
    import MarkdownUI

    struct EditTossView: View {
        let toss: Toss
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext
        @State private var editedContent = ""
        @State private var isPreviewMode = false
        @FocusState private var isFocused: Bool

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    if let imageData = toss.imageData,
                        let uiImage = UIImage(data: imageData)
                    {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                            .padding()
                    }

                    if isPreviewMode {
                        // Preview mode - rendered markdown
                        ScrollView {
                            Markdown(editedContent)
                                .padding()
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .topLeading
                                )
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // Edit mode - text editor
                        TextEditor(text: $editedContent)
                            .font(.system(.body, design: .monospaced))
                            .focused($isFocused)
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationTitle("Edit Toss")
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
                            saveAndClose()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .onAppear {
                    editedContent = toss.content
                    isFocused = true
                }
            }
        }

        private func saveAndClose() {
            toss.content = editedContent
            try? modelContext.save()
            dismiss()
        }
    }
#endif
