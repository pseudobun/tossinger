//
//  Toss.swift
//  toss
//
//  Created by Urban Vidovič on 7. 10. 25.
//

import Foundation
import SwiftData
import SwiftUI

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

  init(content: String, type: TossType = .text, imageData: Data? = nil) {
    self.createdAt = Date()
    self.content = content
    self.typeRawValue = type.rawValue
    self.imageData = imageData
  }
}
