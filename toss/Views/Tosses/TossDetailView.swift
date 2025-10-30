//
//  TossDetailView.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
//

#if os(macOS)
    import SwiftUI
    import SwiftData

    struct TossDetailView: View {
        let toss: Toss
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext
        @State private var editedContent = ""
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

                ScrollView {
                    TextEditor(text: $editedContent)
                        .font(.body)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .padding()
                        .frame(minHeight: 300)
                        .focusable()
                        .onKeyPress { press in
                            if press.key == .return
                                && press.modifiers.contains(.command)
                            {
                                saveAndClose()
                                return .handled
                            }
                            return .ignored
                        }
                }
                .scrollIndicators(.hidden)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .onAppear {
                editedContent = toss.content
                isFocused = true
            }
        }

        private func saveAndClose() {
            toss.content = editedContent
            try? modelContext.save()
            dismiss()
        }
    }
#endif
