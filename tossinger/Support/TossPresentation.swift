//
//  TossPresentation.swift
//  tossinger
//
//  Output formatting. Both `--json` (for agents/scripts) and a
//  human-readable text mode share the same DTO so the JSON shape stays
//  in sync with what the text mode displays.
//

import Foundation
import TossKit

enum TossPresentation {
  // MARK: - Text

  static func printText(_ tosses: [Toss], total: Int, limit: Int, offset: Int) {
    if tosses.isEmpty {
      print("(no tosses)")
      return
    }

    print("Showing \(offset + 1)\u{2013}\(offset + tosses.count) of \(total)")
    print(String(repeating: "\u{2500}", count: 60))

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    for toss in tosses {
      print(toss.id.uuidString)
      print("  \(formatter.string(from: toss.createdAt))  [\(toss.type.rawValue)]")
      let title = toss.metadataTitle ?? toss.previewPlainText ?? toss.content
      print("  \(title.prefix(120))")
      print()
    }
  }

  static func printAdded(_ toss: Toss) {
    print("Tossed: \(toss.id.uuidString)")
    print("  type: \(toss.type.rawValue)")
    print("  content: \(toss.content)")
    if toss.metadataFetchState == .pending && toss.type == .link {
      print("  (metadata enrichment pending \u{2014} the next app launch will fill it in)")
    }
  }

  // MARK: - JSON

  /// Encodes one or more tosses, optionally with pagination metadata.
  /// Used by both `list --json` and `add --json`.
  static func printJSON(
    _ tosses: [Toss],
    total: Int? = nil,
    limit: Int? = nil,
    offset: Int? = nil
  ) throws {
    let payload = Payload(
      total: total,
      limit: limit,
      offset: offset,
      tosses: tosses.map(TossDTO.init)
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

    let data = try encoder.encode(payload)
    if let text = String(data: data, encoding: .utf8) {
      print(text)
    }
  }

  // MARK: - DTO

  private struct Payload: Encodable {
    let total: Int?
    let limit: Int?
    let offset: Int?
    let tosses: [TossDTO]
  }

  private struct TossDTO: Encodable {
    let id: UUID
    let createdAt: Date
    let type: String
    let content: String
    let title: String?
    let description: String?
    let author: String?
    let platformType: String?
    let metadataFetchState: String?

    init(_ toss: Toss) {
      self.id = toss.id
      self.createdAt = toss.createdAt
      self.type = toss.type.rawValue
      self.content = toss.content
      self.title = toss.metadataTitle
      self.description = toss.metadataDescription
      self.author = toss.metadataAuthor
      self.platformType = toss.platformType?.rawValue
      self.metadataFetchState = toss.metadataFetchState?.rawValue
    }
  }
}
