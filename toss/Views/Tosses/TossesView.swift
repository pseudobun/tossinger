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

    #if os(macOS)
        private let columns = [
            GridItem(.adaptive(minimum: 180, maximum: 280), spacing: 16)
        ]
    #else
        private let columns = [
            GridItem(.adaptive(minimum: 150, maximum: 250), spacing: 12)
        ]
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    #if os(macOS)
                        AddTossCard(isEditing: $isAddingToss)
                            .zIndex(1)  // Ensure it's above other cards
                            .onTapGesture {
                                // Prevent tap from propagating to cards below
                            }
                    #endif

                    ForEach(tosses) { toss in
                        TossCard(toss: toss)
                            .zIndex(0)  // Regular cards below
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteToss(toss)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            #if os(macOS)
                                .onTapGesture {
                                    handleTossTap(toss)
                                }
                            #else
                                .onTapGesture {
                                    handleTossTap(toss)
                                }
                            #endif
                    }
                }
                .padding()
            }
            #if os(iOS)
                .background(Color(UIColor.systemBackground))
                .navigationBarTitleDisplayMode(.inline)
            #else
                .background(.background)
            #endif
            .onTapGesture {
                isAddingToss = false
            }

            .navigationTitle("Tosses")
            .toolbar {
                #if os(iOS)
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
            16
        #else
            12
        #endif
    }
}
