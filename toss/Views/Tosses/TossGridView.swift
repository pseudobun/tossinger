//
//  TossGridView.swift
//  toss
//
//  Card-grid presentation of a toss list. Extracted from TossesView so the
//  parent can dispatch between this and TossTableView based on the user's
//  preferred layout mode.
//

import SwiftUI
import TossKit

struct TossGridView: View {
  let tosses: [Toss]
  let onTap: (Toss) -> Void
  let onCopy: (Toss) -> Void
  let onDelete: (Toss) -> Void
  #if os(macOS)
    @Binding var isAddingToss: Bool
  #endif

  private var columns: [GridItem] {
    #if os(macOS)
      [GridItem(.adaptive(minimum: 220, maximum: 330), spacing: spacing)]
    #else
      [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
    #endif
  }

  private var spacing: CGFloat {
    #if os(macOS)
      20
    #else
      16
    #endif
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: spacing) {
      #if os(macOS)
        AddTossCard(isEditing: $isAddingToss)
      #endif

      ForEach(tosses) { toss in
        TossCard(toss: toss)
          .contextMenu {
            Button {
              onCopy(toss)
            } label: {
              Label("Copy", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
              onDelete(toss)
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
          .onTapGesture {
            onTap(toss)
          }
      }
    }
    .padding()
  }
}
