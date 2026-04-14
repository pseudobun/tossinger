//
//  TossTableView.swift
//  toss
//
//  Sortable multi-column table presentation of a toss list. macOS only —
//  SwiftUI `Table` collapses to a single column on compact iPhone width,
//  so iOS stays on the card grid.
//

#if os(macOS)

  import SwiftUI
  import TossKit

  struct TossTableView: View {
    let tosses: [Toss]
    let onActivate: (Toss) -> Void
    let onCopy: (Toss) -> Void
    let onDelete: (Toss) -> Void

    @State private var sortOrder: [KeyPathComparator<Toss>] = [
      KeyPathComparator(\.createdAt, order: .reverse)
    ]
    @State private var selection = Set<Toss.ID>()

    private var sortedTosses: [Toss] {
      tosses.sorted(using: sortOrder)
    }

    var body: some View {
      Table(sortedTosses, selection: $selection, sortOrder: $sortOrder) {
        TableColumn("Content", value: \.content) { toss in
          HStack(spacing: 8) {
            Image(systemName: toss.type == .link ? "link" : "text.alignleft")
              .foregroundStyle(.secondary)
            Text(toss.metadataTitle ?? toss.content)
              .lineLimit(1)
              .truncationMode(.tail)
          }
        }
        TableColumn("Type", value: \.typeRawValue) { toss in
          Text(toss.type.rawValue.capitalized)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .width(min: 60, ideal: 80, max: 100)
        TableColumn("Created", value: \.createdAt) { toss in
          Text(toss.createdAt, format: .dateTime.month().day().year().hour().minute())
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .width(min: 140, ideal: 180, max: 220)
      }
      .contextMenu(forSelectionType: Toss.ID.self) { ids in
        if let id = ids.first, let toss = sortedTosses.first(where: { $0.id == id }) {
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
      } primaryAction: { ids in
        if let id = ids.first, let toss = sortedTosses.first(where: { $0.id == id }) {
          onActivate(toss)
        }
      }
    }
  }

#endif
