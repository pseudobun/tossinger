//
//  TossRepository.swift
//  TossKit
//
//  The single chokepoint for CRUD against the shared SwiftData store.
//  The CLI uses this exclusively. The app's existing call sites still talk
//  to `ModelContext` directly via `@Query` / `modelContext.insert(...)` —
//  they may migrate to this repository over time, but it isn't required.
//

import Foundation
import SwiftData

public struct TossRepository {
  public enum RepositoryError: Error, CustomStringConvertible {
    case notFound(id: UUID)
    case emptyContent

    public var description: String {
      switch self {
      case .notFound(let id):
        return "No toss found with id \(id)"
      case .emptyContent:
        return "Toss content cannot be empty."
      }
    }
  }

  private let context: ModelContext

  public init(context: ModelContext) {
    self.context = context
  }

  /// Convenience: build a fresh `ModelContext` from the shared container.
  public init(container: ModelContainer) {
    self.init(context: ModelContext(container))
  }

  // MARK: - Read

  /// Fetches tosses ordered newest-first, with optional pagination.
  public func list(limit: Int? = nil, offset: Int = 0) throws -> [Toss] {
    var descriptor = FetchDescriptor<Toss>(
      sortBy: [SortDescriptor(\Toss.createdAt, order: .reverse)]
    )
    descriptor.fetchOffset = offset
    if let limit {
      descriptor.fetchLimit = limit
    }
    return try context.fetch(descriptor)
  }

  public func find(id: UUID) throws -> Toss? {
    let descriptor = FetchDescriptor<Toss>(
      predicate: #Predicate { $0.id == id }
    )
    return try context.fetch(descriptor).first
  }

  public func count() throws -> Int {
    try context.fetchCount(FetchDescriptor<Toss>())
  }

  // MARK: - Write

  /// Creates a toss from a string. URLs become skeleton link tosses with
  /// `metadataFetchState = .pending`; the next app launch enriches them via
  /// the existing `TossCreationPipeline.retryPendingMetadata` flow. Plain
  /// text becomes a text toss directly. Saves immediately.
  @discardableResult
  public func add(content: String) throws -> Toss {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw RepositoryError.emptyContent
    }

    let toss: Toss
    if let url = Self.linkURLIfSupported(from: trimmed) {
      toss = Self.makeSkeletonLinkToss(url: url)
    } else {
      toss = Self.makeTextToss(content: trimmed)
    }

    context.insert(toss)
    try context.save()
    return toss
  }

  public func delete(id: UUID) throws {
    guard let toss = try find(id: id) else {
      throw RepositoryError.notFound(id: id)
    }
    context.delete(toss)
    try context.save()
  }

  // MARK: - CLI-safe builders
  // Mirror the data-only subset of the app's `TossCreationPipeline`. We
  // intentionally avoid pulling in `CardPreviewText`, `MetadataCoordinator`,
  // and `ScreenshotCapturer` so the CLI doesn't need WebKit / UIView at
  // build time. The app's `retryPendingMetadata` flow rewrites the
  // preview/search fields with full enrichment on next launch.

  static func linkURLIfSupported(from content: String) -> URL? {
    guard let url = URL(string: content) else { return nil }
    guard let scheme = url.scheme?.lowercased() else { return nil }
    return (scheme == "http" || scheme == "https") ? url : nil
  }

  static func makeTextToss(content: String) -> Toss {
    let toss = Toss(content: content, type: .text)
    toss.previewPlainText = String(content.prefix(280))
    toss.searchIndex = content.lowercased()
    toss.metadataFetchState = .pending
    toss.metadataFetchedAt = Date()
    return toss
  }

  static func makeSkeletonLinkToss(url: URL) -> Toss {
    let toss = Toss(content: url.absoluteString, type: .link)
    toss.metadataTitle = url.host
    toss.metadataFetchState = .pending
    toss.metadataFetchedAt = Date()
    toss.previewPlainText = url.absoluteString
    toss.searchIndex = url.absoluteString.lowercased()
    return toss
  }
}
