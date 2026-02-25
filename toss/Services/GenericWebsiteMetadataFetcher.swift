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
      let (data, response) = try await URLSession.shared.data(for: request)
      guard isSuccessfulHTTPResponse(response) else {
        return GenericWebsiteMetadata(imageData: nil, title: nil, description: nil, didSucceed: false)
      }

      guard
        let html = String(data: data, encoding: .utf8)
          ?? String(data: data, encoding: .unicode)
      else {
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

      var imageData: Data?

      if let imageURL = preferredImageURL(from: metaTags, baseURL: url) {
        imageData = await fetchImage(url: imageURL, timeout: timeout)
      }

      if imageData == nil, let githubFallbackImageURL = githubRepositoryOGURL(for: url) {
        imageData = await fetchImage(url: githubFallbackImageURL, timeout: timeout)
      }

      return GenericWebsiteMetadata(
        imageData: imageData,
        title: title,
        description: description,
        didSucceed: imageData != nil || title != nil || description != nil
      )
    } catch {
      return GenericWebsiteMetadata(imageData: nil, title: nil, description: nil, didSucceed: false)
    }
  }

  // MARK: - Meta Tag Extraction

  private static func extractAllMetaTags(from html: String) -> [String: String] {
    var tags: [String: String] = [:]

    guard
      let metaTagRegex = try? NSRegularExpression(
        pattern: #"<meta\b[^>]*>"#,
        options: [.caseInsensitive]
      )
    else {
      return tags
    }

    let matches = metaTagRegex.matches(
      in: html,
      range: NSRange(html.startIndex..., in: html)
    )

    for match in matches {
      guard let range = Range(match.range, in: html) else {
        continue
      }

      let tag = String(html[range])
      let attributes = extractAttributes(from: tag)
      let key = (attributes["property"] ?? attributes["name"])?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

      let value = attributes["content"]?
        .trimmingCharacters(in: .whitespacesAndNewlines)

      guard let key, !key.isEmpty, let value, !value.isEmpty else {
        continue
      }

      tags[key] = decodeHTMLEntities(value)
    }

    return tags
  }

  private static func extractAttributes(from tag: String) -> [String: String] {
    var attributes: [String: String] = [:]

    guard
      let attributeRegex = try? NSRegularExpression(
        pattern: #"([a-zA-Z_:][a-zA-Z0-9_:\-\.]*)\s*=\s*(['"])(.*?)\2"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
      )
    else {
      return attributes
    }

    let matches = attributeRegex.matches(
      in: tag,
      range: NSRange(tag.startIndex..., in: tag)
    )

    for match in matches {
      guard
        let keyRange = Range(match.range(at: 1), in: tag),
        let valueRange = Range(match.range(at: 3), in: tag)
      else {
        continue
      }

      let key = String(tag[keyRange]).lowercased()
      let value = String(tag[valueRange])
      attributes[key] = value
    }

    return attributes
  }

  private static func preferredImageURL(
    from metaTags: [String: String],
    baseURL: URL
  ) -> URL? {
    let preferredImageKeys = [
      "og:image:secure_url",
      "og:image:url",
      "og:image",
      "twitter:image",
      "twitter:image:src",
    ]

    for key in preferredImageKeys {
      guard let value = metaTags[key] else {
        continue
      }

      guard
        let resolvedURL = resolveImageURL(
          rawValue: value,
          baseURL: baseURL
        )
      else {
        continue
      }

      return resolvedURL
    }

    return nil
  }

  private static func resolveImageURL(rawValue: String, baseURL: URL) -> URL? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if trimmed.hasPrefix("//") {
      let scheme = baseURL.scheme ?? "https"
      return URL(string: "\(scheme):\(trimmed)")
    }

    return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
  }

  private static func githubRepositoryOGURL(for url: URL) -> URL? {
    guard let host = url.host?.lowercased(), host.contains("github.com")
    else {
      return nil
    }

    let components = url.pathComponents.filter { $0 != "/" }
    guard components.count >= 2 else {
      return nil
    }

    let owner = components[0]
    var repo = components[1]

    if repo.hasSuffix(".git") {
      repo = String(repo.dropLast(4))
    }

    guard !owner.isEmpty, !repo.isEmpty else {
      return nil
    }

    return URL(string: "https://opengraph.githubassets.com/1/\(owner)/\(repo)")
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
      let (data, response) = try await URLSession.shared.data(for: request)
      guard isSuccessfulHTTPResponse(response) else {
        return nil
      }

      if let mimeType = response.mimeType?.lowercased(),
        !mimeType.hasPrefix("image/")
      {
        return nil
      }

      return data
    } catch {
      return nil
    }
  }

  private static func isSuccessfulHTTPResponse(_ response: URLResponse) -> Bool {
    guard let httpResponse = response as? HTTPURLResponse else {
      return false
    }

    return (200..<300).contains(httpResponse.statusCode)
  }
}
