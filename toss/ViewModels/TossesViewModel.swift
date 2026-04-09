import Foundation
import SwiftData
import TossKit

@MainActor
final class TossesViewModel: ObservableObject {
  @Published private(set) var debouncedSearchText: String = ""

  private var searchTask: Task<Void, Never>?
  private var inMemorySearchIndex: [PersistentIdentifier: String] = [:]

  func scheduleSearchDebounce(_ query: String) {
    searchTask?.cancel()
    searchTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(180))
      guard !Task.isCancelled else { return }
      self?.setDebouncedSearchText(query)
    }
  }

  func filteredTosses(from tosses: [Toss]) -> [Toss] {
    guard !debouncedSearchText.isEmpty else {
      return tosses
    }

    let needle = debouncedSearchText
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .lowercased()

    return tosses.filter { toss in
      searchIndex(for: toss).contains(needle)
    }
  }

  private func searchIndex(for toss: Toss) -> String {
    if let persisted = toss.searchIndex, !persisted.isEmpty {
      return persisted
    }

    if let cached = inMemorySearchIndex[toss.persistentModelID] {
      return cached
    }

    let index = CardPreviewText.makeSearchIndex(
      content: toss.content,
      metadataTitle: toss.metadataTitle,
      metadataDescription: toss.metadataDescription,
      metadataAuthor: toss.metadataAuthor
    )
    inMemorySearchIndex[toss.persistentModelID] = index
    return index
  }

  private func setDebouncedSearchText(_ query: String) {
    debouncedSearchText = query
  }
}
