import Foundation

enum CardPreviewText {
  static func makePreview(from markdown: String, maxCharacters: Int = 280) -> String {
    let stripped = stripMarkdown(markdown)
    guard stripped.count > maxCharacters else {
      return stripped
    }

    let index = stripped.index(stripped.startIndex, offsetBy: maxCharacters)
    return String(stripped[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func makeSearchIndex(
    content: String,
    metadataTitle: String?,
    metadataDescription: String?,
    metadataAuthor: String?
  ) -> String {
    [
      content,
      metadataTitle ?? "",
      metadataDescription ?? "",
      metadataAuthor ?? "",
    ]
    .joined(separator: " ")
    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    .lowercased()
  }

  private static func stripMarkdown(_ markdown: String) -> String {
    var text = markdown

    // Block-level normalization
    text = text.replacingOccurrences(of: "```[\\s\\S]*?```", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "`([^`]*)`", with: "$1", options: .regularExpression)
    text = text.replacingOccurrences(of: "(?m)^#{1,6}\\s*", with: "", options: .regularExpression)
    text = text.replacingOccurrences(of: "(?m)^\\s*([-*+] |\\d+\\. )", with: "", options: .regularExpression)
    text = text.replacingOccurrences(of: "(?m)^>\\s?", with: "", options: .regularExpression)

    // Inline markdown
    text = text.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^\\)]*\\)", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]*\\)", with: "$1", options: .regularExpression)
    text = text.replacingOccurrences(of: "[*_~]{1,3}", with: "", options: .regularExpression)

    // Collapse whitespace
    text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
