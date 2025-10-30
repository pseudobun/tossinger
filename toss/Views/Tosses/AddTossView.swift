//
//  AddTossView.swift
//  toss
//
//  Created by Urban Vidovič on 7. 10. 25.
//

#if os(iOS)
    import SwiftUI
    import SwiftData

    struct AddTossView: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext
        @State private var content = ""
        @State private var isLoadingScreenshot = false
        @FocusState private var isFocused: Bool

        var body: some View {
            NavigationStack {
                ZStack {
                    TextEditor(text: $content)
                        .font(.body)
                        .focused($isFocused)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveToss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
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

            WebsiteMetadataFetcher.fetchOGImage(url: url) { image in
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
