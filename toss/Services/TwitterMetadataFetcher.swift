//
//  TwitterMetadataFetcher.swift
//  toss
//
//  Created by Urban Vidovič on 2. 11. 25.
//

import Foundation

// MARK: - Twitter oEmbed Response

struct TwitterOEmbedResponse: Codable {
  let url: String
  let authorName: String
  let authorURL: String
  let html: String
  let width: Int?
  let height: Int?
  let type: String
  let cacheAge: String
  let providerName: String
  let providerURL: String
  let version: String

  enum CodingKeys: String, CodingKey {
    case url
    case authorName = "author_name"
    case authorURL = "author_url"
    case html
    case width
    case height
    case type
    case cacheAge = "cache_age"
    case providerName = "provider_name"
    case providerURL = "provider_url"
    case version
  }
}

enum TwitterURLType {
  case profile  // x.com/username
  case post  // x.com/username/status/id
}

class TwitterMetadataFetcher {
  typealias CompletionHandler = (
    _ description: String?,
    _ author: String?,
    _ urlType: TwitterURLType
  ) -> Void

  static func fetchMetadata(url: URL, completion: @escaping CompletionHandler) {
    let urlType = detectURLType(url: url)

    switch urlType {
    case .profile:
      // Extract username from URL
      let username = extractUsername(from: url)
      DispatchQueue.main.async {
        completion(nil, username, .profile)
      }

    case .post:
      // Fetch tweet metadata from oEmbed API
      fetchPostMetadata(url: url, completion: completion)
    }
  }

  // MARK: - URL Detection

  private static func detectURLType(url: URL) -> TwitterURLType {
    let pathComponents = url.pathComponents.filter { $0 != "/" }

    // Check if path contains "status" - indicates a post
    if pathComponents.contains("status"), pathComponents.count >= 3 {
      return .post
    }

    return .profile
  }

  static func isTwitterURL(_ url: URL) -> Bool {
    guard let host = url.host?.lowercased() else { return false }
    return host.contains("twitter.com") || host.contains("x.com")
  }

  private static func extractUsername(from url: URL) -> String? {
    let pathComponents = url.pathComponents.filter { $0 != "/" }
    guard let username = pathComponents.first else { return nil }
    return username
  }

  // MARK: - Post Metadata Fetching

  private static func fetchPostMetadata(
    url: URL,
    completion: @escaping CompletionHandler
  ) {
    // Construct oEmbed API URL
    guard
      var components = URLComponents(
        string: "https://publish.twitter.com/oembed"
      )
    else {
      DispatchQueue.main.async { completion(nil, nil, .post) }
      return
    }

    components.queryItems = [
      URLQueryItem(name: "url", value: url.absoluteString)
    ]

    guard let oembedURL = components.url else {
      DispatchQueue.main.async { completion(nil, nil, .post) }
      return
    }

    URLSession.shared.dataTask(with: oembedURL) { data, response, error in
      guard let data = data else {
        DispatchQueue.main.async { completion(nil, nil, .post) }
        return
      }

      do {
        let decoder = JSONDecoder()
        let oembedData = try decoder.decode(
          TwitterOEmbedResponse.self,
          from: data
        )

        // Extract tweet text from HTML
        let tweetText = extractTweetText(from: oembedData.html)

        DispatchQueue.main.async {
          completion(tweetText, oembedData.authorName, .post)
        }

      } catch {
        DispatchQueue.main.async { completion(nil, nil, .post) }
      }
    }.resume()
  }

  // MARK: - Helper Methods

  private static func extractTweetText(from html: String) -> String? {
    // Extract text from <p> tag within blockquote
    let pattern = #"<p[^>]*>(.*?)</p>"#

    guard
      let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [.dotMatchesLineSeparators]
      ),
      let match = regex.firstMatch(
        in: html,
        range: NSRange(html.startIndex..., in: html)
      ),
      let range = Range(match.range(at: 1), in: html)
    else {
      return nil
    }

    var text = String(html[range])

    // Remove HTML tags
    text = text.replacingOccurrences(of: "<br>", with: "\n")
    text = text.replacingOccurrences(
      of: "<[^>]+>",
      with: "",
      options: .regularExpression
    )

    // Decode HTML entities
    text = decodeHTMLEntities(text)

    return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
    result = result.replacingOccurrences(of: "&mdash;", with: "—")
    result = result.replacingOccurrences(of: "&nbsp;", with: " ")

    // Decode Unicode escape sequences like \uD83E\uDDA6
    if let data = result.data(using: .utf8),
      let decoded = String(data: data, encoding: .nonLossyASCII)
        ?? String(data: data, encoding: .utf8)
    {
      result = decoded
    }

    return result
  }
}
