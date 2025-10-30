//
//  EditTossView.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
//

#if os(iOS)
    import SwiftUI
    import SwiftData

    struct EditTossView: View {
        let toss: Toss
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext
        @State private var editedContent = ""
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

                    TextEditor(text: $editedContent)
                        .font(.body)
                        .focused($isFocused)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle("Edit Toss")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveAndClose()
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
