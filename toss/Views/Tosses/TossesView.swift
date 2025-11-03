//
//  TossesView.swift
//  toss
//
//  Created by Urban Vidovič on 7. 10. 25.
//

import SwiftData
import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

struct TossesView: View {
  @Query(sort: \Toss.createdAt, order: .reverse) private var tosses: [Toss]
  @Environment(\.modelContext) private var modelContext
  @State private var showingAddToss = false
  @State private var editingToss: Toss?
  @State private var selectedToss: Toss?
  @State private var isAddingToss: Bool = false
  @State private var searchText = ""

  private var columns: [GridItem] {
    #if os(macOS)
      [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: spacing)]
    #else
      [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
    #endif
  }

  private var filteredTosses: [Toss] {
    if searchText.isEmpty {
      return tosses
    }

    let lowercasedSearch = searchText.lowercased()
    return tosses.filter { toss in
      toss.content.lowercased().contains(lowercasedSearch)
        || toss.metadataTitle?.lowercased().contains(lowercasedSearch) == true
        || toss.metadataDescription?.lowercased().contains(lowercasedSearch) == true
        || toss.metadataAuthor?.lowercased().contains(lowercasedSearch) == true
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        LazyVGrid(columns: columns, spacing: spacing) {
          #if os(macOS)
            AddTossCard(isEditing: $isAddingToss)
              .onTapGesture {
                // Prevent tap from propagating
              }
          #endif

          ForEach(filteredTosses) { toss in
            TossCard(toss: toss)
              .contextMenu {
                Button {
                  copyToClipboard(toss.content)
                } label: {
                  Label("Copy", systemImage: "doc.on.doc")
                }

                Button(role: .destructive) {
                  deleteToss(toss)
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
              .onTapGesture {
                handleTossTap(toss)
              }
          }
        }
        .padding()
      }
      .scrollIndicators(.hidden, axes: [.vertical, .horizontal])
      .onTapGesture {
        isAddingToss = false
      }
      #if os(iOS)
        .background(Color(UIColor.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
      #else
        .background(.background)
      #endif
      .navigationTitle("Tosses")
      .searchable(text: $searchText, prompt: "Search tosses...")
      .toolbar {
        #if os(macOS)
          ToolbarItem(placement: .primaryAction) {
            Button {
              showingAddToss = true
            } label: {
              Label("New Toss", systemImage: "plus")
            }
          }
        #else
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              showingAddToss = true
            } label: {
              Label("New Toss", systemImage: "plus")
            }
          }
        #endif
      }
      #if os(iOS)
        .sheet(isPresented: $showingAddToss) {
          AddTossView()
        }
        .sheet(item: $editingToss) { toss in
          EditTossView(toss: toss)
        }
      #endif
      #if os(macOS)
        .sheet(isPresented: $showingAddToss) {
          AddTossView()
          .frame(
            minWidth: 700,
            idealWidth: 800,
            minHeight: 400,
            idealHeight: 500,
            maxHeight: 600
          )
        }
        .sheet(item: $selectedToss) { toss in
          TossDetailView(toss: toss)
          .frame(
            minWidth: 700,
            idealWidth: 800,
            minHeight: 400,
            idealHeight: 500,
            maxHeight: 600
          )
        }
      #endif

    }
  }

  private func deleteToss(_ toss: Toss) {
    withAnimation {
      modelContext.delete(toss)
      try? modelContext.save()
    }
  }

  private func copyToClipboard(_ text: String) {
    #if os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    #else
      UIPasteboard.general.string = text
    #endif
  }

  private func handleTossTap(_ toss: Toss) {
    // If the toss is a link, try to open it in the default browser
    if toss.type == .link, let url = URL(string: toss.content) {
      #if os(macOS)
        NSWorkspace.shared.open(url)
      #else
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url)
        } else {
          // If URL is not valid, show edit view
          editingToss = toss
        }
      #endif
    } else {
      // If it's not a valid link, show the edit/detail view as before
      #if os(macOS)
        selectedToss = toss
        isAddingToss = false
      #else
        editingToss = toss
      #endif
    }
  }

  private var spacing: CGFloat {
    #if os(macOS)
      20
    #else
      16
    #endif
  }
}
