//
//  Toss.swift
//  TossKit
//
//  The shared SwiftData model used by the app, share extension, and CLI.
//

import Foundation
import SwiftData

public enum TossType: String, Codable, Sendable {
  case text = "text"
  case link = "link"
}

public enum PlatformType: String, Codable, Sendable {
  case youtube
  case xProfile
  case xPost
  case github
  case genericWebsite
}

public enum MetadataFetchState: String, Codable, Sendable {
  case pending
  case success
  case failed
  case timeout
}

@Model
public final class Toss {
  /// Stable, user-visible identifier. Surfaced by the CLI so it can be
  /// referenced from `toss delete <uuid>`.
  ///
  /// Migration note: this field was added after the app shipped without an id.
  /// SwiftData lightweight-migrates existing rows by assigning a fresh UUID
  /// per device. On a multi-device user, two devices may briefly assign
  /// different UUIDs to the same record before CloudKit converges on one
  /// (last-writer-wins). For a single-user app this window is small and
  /// invisible in normal use, but a CLI-shown id may change exactly once
  /// shortly after the upgrade.
  public var id: UUID = UUID()

  public var createdAt: Date = Date()
  public var content: String = ""
  public var typeRawValue: String = "text"  // Store enum as String
  @Attribute(.externalStorage) public var imageData: Data?

  // Metadata fields
  public var metadataTitle: String?
  public var metadataDescription: String?
  public var metadataAuthor: String?
  public var platformTypeRawValue: String?

  // Phase 2 search/render fields
  public var previewPlainText: String?
  public var searchIndex: String?

  @Attribute(.externalStorage) public var thumbnailDataOptimized: Data?
  public var thumbnailWidth: Int?
  public var thumbnailHeight: Int?

  public var metadataFetchStateRawValue: String?
  public var metadataFetchedAt: Date?

  // Computed property for type safety
  public var type: TossType {
    get { TossType(rawValue: typeRawValue) ?? .text }
    set { typeRawValue = newValue.rawValue }
  }

  public var platformType: PlatformType? {
    get {
      guard let raw = platformTypeRawValue else { return nil }
      return PlatformType(rawValue: raw)
    }
    set { platformTypeRawValue = newValue?.rawValue }
  }

  public var metadataFetchState: MetadataFetchState? {
    get {
      guard let raw = metadataFetchStateRawValue else { return nil }
      return MetadataFetchState(rawValue: raw)
    }
    set { metadataFetchStateRawValue = newValue?.rawValue }
  }

  public init(content: String, type: TossType = .text, imageData: Data? = nil) {
    self.id = UUID()
    self.createdAt = Date()
    self.content = content
    self.typeRawValue = type.rawValue
    self.imageData = imageData
  }
}
