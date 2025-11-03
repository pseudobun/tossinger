//
//  GenericWebsiteMetadataFetcher.swift
//  toss
//
//  Created by Urban Vidovič on 3. 11. 25.
//

import Foundation

class GenericWebsiteMetadataFetcher {
  typealias CompletionHandler = (
    _ imageData: Data?,
    _ title: String?,
    _ description: String?
  ) -> Void

  static func fetchMetadata(url: URL, completion: @escaping CompletionHandler) {
    // Create request with custom User-Agent to avoid being blocked
    var request = URLRequest(url: url)
    request.setValue(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
      forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 10

    URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data,
        let html = String(data: data, encoding: .utf8)
      else {
        DispatchQueue.main.async { completion(nil, nil, nil) }
        return
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

      // Try to fetch OG image
      if let imageURLString = metaTags["og:image"]
        ?? metaTags["twitter:image"],
        let imageURL = URL(string: imageURLString)
      {
        fetchImage(url: imageURL) { imageData in
          DispatchQueue.main.async {
            completion(imageData, title, description)
          }
        }
      } else {
        DispatchQueue.main.async {
          completion(nil, title, description)
        }
      }
    }.resume()
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
    completion: @escaping (Data?) -> Void
  ) {
    var request = URLRequest(url: url)
    request.setValue(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
      forHTTPHeaderField: "User-Agent")

    URLSession.shared.dataTask(with: request) { data, _, _ in
      completion(data)
    }.resume()
  }
}
