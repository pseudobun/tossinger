//
//  AddTossCard.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
//

import SwiftData
import SwiftUI

struct AddTossCard: View {
  @Environment(\.modelContext) private var modelContext
  @State private var content = ""
  @State private var isLoadingScreenshot = false  // Add this
  @Binding var isEditing: Bool
  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      if isEditing {
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
            .padding(12)
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
              .scaleEffect(1.5)
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
    .background(AnyShapeStyle(.thinMaterial))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          isEditing ? Color.accentColor : Color.clear,
          lineWidth: 2
        )
    )
  }

  private func saveToss() {
    guard
      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      content = ""
      isEditing = false
      isFocused = false
      return
    }

    // Check if it's a URL
    if let url = URL(
      string: content.trimmingCharacters(in: .whitespaces)
    ),
      url.scheme != nil,
      url.scheme == "http" || url.scheme == "https"
    {
      // Fetch metadata for URL
      isLoadingScreenshot = true

      MetadataCoordinator.fetchMetadata(url: url) {
        imageData,
        title,
        description,
        author,
        platformType in
        let toss = Toss(
          content: url.absoluteString,
          type: .link,
          imageData: imageData
        )
        toss.metadataTitle = title
        toss.metadataDescription = description
        toss.metadataAuthor = author
        toss.platformType = platformType
        modelContext.insert(toss)

        withAnimation {
          content = ""
          isEditing = false
          isFocused = false
          isLoadingScreenshot = false
        }
      }
    } else {
      // Plain text
      let toss = Toss(content: content, type: .text)
      modelContext.insert(toss)

      withAnimation {
        content = ""
        isEditing = false
        isFocused = false
      }
    }
  }
}

#if os(macOS)
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
