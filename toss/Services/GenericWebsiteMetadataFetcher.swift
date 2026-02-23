//
//  GenericWebsiteMetadataFetcher.swift
//  toss
//
//  Created by Urban Vidovič on 3. 11. 25.
//

import Foundation

struct GenericWebsiteMetadata {
  let imageData: Data?
  let title: String?
  let description: String?
  let didSucceed: Bool
}

class GenericWebsiteMetadataFetcher {
  static func fetchMetadata(
    url: URL,
    timeout: TimeInterval = 10
  ) async -> GenericWebsiteMetadata {
    // Create request with custom User-Agent to avoid being blocked
    var request = URLRequest(url: url)
    request.setValue(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
      forHTTPHeaderField: "User-Agent"
    )
    request.timeoutInterval = timeout

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      guard let html = String(data: data, encoding: .utf8) else {
        return GenericWebsiteMetadata(imageData: nil, title: nil, description: nil, didSucceed: false)
      }

      let metaTags = extractAllMetaTags(from: html)

      let title =
        metaTags["og:title"]
        ?? metaTags["twitter:title"]
        ?? extractTitleTag(from: html)

      let description =
        metaTags["og:description"]
        ?? metaTags["twitter:description"]
        ?? metaTags["description"]

      if
        let imageURLString = metaTags["og:image"] ?? metaTags["twitter:image"],
        let imageURL = URL(string: imageURLString, relativeTo: url)?.absoluteURL
      {
        let imageData = await fetchImage(url: imageURL, timeout: timeout)
        return GenericWebsiteMetadata(
          imageData: imageData,
          title: title,
          description: description,
          didSucceed: imageData != nil || title != nil || description != nil
        )
      }

      return GenericWebsiteMetadata(
        imageData: nil,
        title: title,
        description: description,
        didSucceed: title != nil || description != nil
      )
    } catch {
      return GenericWebsiteMetadata(imageData: nil, title: nil, description: nil, didSucceed: false)
    }
  }

  // MARK: - Meta Tag Extraction

  private static func extractAllMetaTags(from html: String) -> [String: String] {
    var tags: [String: String] = [:]

    // Pattern 1: Standard meta tags - property="X" content="Y"
    let propertyPattern =
      #"<meta\s+property=["']([^"']+)["']\s+content=["']([^"']+)["']\s*/?>"#

    // Pattern 2: Standard meta tags - name="X" content="Y"
    let namePattern =
      #"<meta\s+name=["']([^"']+)["']\s+content=["']([^"']+)["']\s*/?>"#

    // Pattern 3: Reverse order - content="Y" property="X"
    let reversePropertyPattern =
      #"<meta\s+content=["']([^"']+)["']\s+property=["']([^"']+)["']\s*/?>"#

    // Pattern 4: Reverse order - content="Y" name="X"
    let reverseNamePattern =
      #"<meta\s+content=["']([^"']+)["']\s+name=["']([^"']+)["']\s*/?>"#

    let patterns = [
      (propertyPattern, 1, 2),  // (key, value)
      (namePattern, 1, 2),
      (reversePropertyPattern, 2, 1),  // (value, key) - reversed
      (reverseNamePattern, 2, 1),
    ]

    for (pattern, keyIndex, valueIndex) in patterns {
      guard
        let regex = try? NSRegularExpression(
          pattern: pattern,
          options: [.caseInsensitive]
        )
      else {
        continue
      }

      let matches = regex.matches(
        in: html,
        range: NSRange(html.startIndex..., in: html)
      )

      for match in matches {
        if let keyRange = Range(match.range(at: keyIndex), in: html),
          let valueRange = Range(
            match.range(at: valueIndex),
            in: html
          )
        {
          let key = String(html[keyRange])
          let value = decodeHTMLEntities(String(html[valueRange]))
          tags[key] = value
        }
      }
    }

    return tags
  }

  private static func extractTitleTag(from html: String) -> String? {
    let pattern = #"<title>([^<]+)</title>"#

    guard
      let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [.caseInsensitive]
      ),
      let match = regex.firstMatch(
        in: html,
        range: NSRange(html.startIndex..., in: html)
      ),
      let range = Range(match.range(at: 1), in: html)
    else {
      return nil
    }

    return decodeHTMLEntities(String(html[range]))
  }

  private static func decodeHTMLEntities(_ text: String) -> String {
    var result = text
    // Common HTML entities
    result = result.replacingOccurrences(of: "&amp;", with: "&")
    result = result.replacingOccurrences(of: "&lt;", with: "<")
    result = result.replacingOccurrences(of: "&gt;", with: ">")
    result = result.replacingOccurrences(of: "&quot;", with: "\"")
    result = result.replacingOccurrences(of: "&#39;", with: "'")
    result = result.replacingOccurrences(of: "&apos;", with: "'")
    return result
  }

  // MARK: - Image Fetching

  private static func fetchImage(
    url: URL,
    timeout: TimeInterval
  ) async -> Data? {
    var request = URLRequest(url: url)
    request.setValue(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
      forHTTPHeaderField: "User-Agent"
    )
    request.timeoutInterval = timeout

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      return data
    } catch {
      return nil
    }
  }
}
