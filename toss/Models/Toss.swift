//
//  Toss.swift
//  toss
//
//  Created by Urban Vidovič on 7. 10. 25.
//
import Foundation
import SwiftData

enum TossType: String, Codable {
  case text = "text"
  case link = "link"
}

enum PlatformType: String, Codable {
  case youtube
  case xProfile
  case xPost
  case github
  case genericWebsite
}

enum MetadataFetchState: String, Codable {
  case pending
  case success
  case failed
  case timeout
}

@Model
final class Toss {
  var createdAt: Date = Date()
  var content: String = ""
  var typeRawValue: String = "text"  // Store enum as String
  @Attribute(.externalStorage) var imageData: Data?

  // Metadata fields
  var metadataTitle: String?
  var metadataDescription: String?
  var metadataAuthor: String?
  var platformTypeRawValue: String?

  // Phase 2 search/render fields
  var previewPlainText: String?
  var searchIndex: String?

  @Attribute(.externalStorage) var thumbnailDataOptimized: Data?
  var thumbnailWidth: Int?
  var thumbnailHeight: Int?

  var metadataFetchStateRawValue: String?
  var metadataFetchedAt: Date?

  // Computed property for type safety
  var type: TossType {
    get { TossType(rawValue: typeRawValue) ?? .text }
    set { typeRawValue = newValue.rawValue }
  }

  var platformType: PlatformType? {
    get {
      guard let raw = platformTypeRawValue else { return nil }
      return PlatformType(rawValue: raw)
    }
    set { platformTypeRawValue = newValue?.rawValue }
  }

  var metadataFetchState: MetadataFetchState? {
    get {
      guard let raw = metadataFetchStateRawValue else { return nil }
      return MetadataFetchState(rawValue: raw)
    }
    set { metadataFetchStateRawValue = newValue?.rawValue }
  }

  init(content: String, type: TossType = .text, imageData: Data? = nil) {
    self.createdAt = Date()
    self.content = content
    self.typeRawValue = type.rawValue
    self.imageData = imageData
  }
}
