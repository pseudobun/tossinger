//
//  YouTubeMetadataFetcher.swift
//  toss
//
//  Created by Urban Vidovič on 3. 11. 25.
//

import Foundation
import ImageIO

// MARK: - YouTube oEmbed Response

struct YouTubeOEmbedResponse: Codable {
  let title: String
  let authorName: String
  let authorURL: String
  let type: String
  let height: Int?
  let width: Int?
  let version: String
  let providerName: String
  let providerURL: String
  let thumbnailHeight: Int
  let thumbnailWidth: Int
  let thumbnailURL: String
  let html: String

  enum CodingKeys: String, CodingKey {
    case title
    case authorName = "author_name"
    case authorURL = "author_url"
    case type
    case height
    case width
    case version
    case providerName = "provider_name"
    case providerURL = "provider_url"
    case thumbnailHeight = "thumbnail_height"
    case thumbnailWidth = "thumbnail_width"
    case thumbnailURL = "thumbnail_url"
    case html
  }
}

struct YouTubeMetadata {
  let imageData: Data?
  let title: String?
  let author: String?
  let didSucceed: Bool
}

class YouTubeMetadataFetcher {
  static func fetchMetadata(
    url: URL,
    timeout: TimeInterval = 10
  ) async -> YouTubeMetadata {
    // Construct oEmbed API URL
    guard
      var components = URLComponents(
        string: "https://www.youtube.com/oembed"
      )
    else {
      return YouTubeMetadata(imageData: nil, title: nil, author: nil, didSucceed: false)
    }

    components.queryItems = [
      URLQueryItem(name: "url", value: url.absoluteString),
      URLQueryItem(name: "format", value: "json"),
    ]

    guard let oembedURL = components.url else {
      return YouTubeMetadata(imageData: nil, title: nil, author: nil, didSucceed: false)
    }

    var request = URLRequest(url: oembedURL)
    request.timeoutInterval = timeout

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      let decoder = JSONDecoder()
      let oembedData = try decoder.decode(YouTubeOEmbedResponse.self, from: data)

      guard let thumbnailURL = URL(string: oembedData.thumbnailURL) else {
        return YouTubeMetadata(
          imageData: nil,
          title: oembedData.title,
          author: oembedData.authorName,
          didSucceed: !oembedData.title.isEmpty || !oembedData.authorName.isEmpty
        )
      }

      let imageData = await fetchBestThumbnailData(
        videoURL: url,
        providedThumbnailURL: thumbnailURL,
        timeout: timeout
      )
      return YouTubeMetadata(
        imageData: imageData,
        title: oembedData.title,
        author: oembedData.authorName,
        didSucceed: imageData != nil || !oembedData.title.isEmpty || !oembedData.authorName.isEmpty
      )
    } catch {
      return YouTubeMetadata(imageData: nil, title: nil, author: nil, didSucceed: false)
    }
  }

  // MARK: - Helper Methods

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
      guard
        let http = response as? HTTPURLResponse,
        (200...299).contains(http.statusCode)
      else {
        return nil
      }
      return data
    } catch {
      return nil
    }
  }

  private static func fetchBestThumbnailData(
    videoURL: URL,
    providedThumbnailURL: URL,
    timeout: TimeInterval
  ) async -> Data? {
    let candidates = thumbnailCandidates(
      videoURL: videoURL,
      providedThumbnailURL: providedThumbnailURL
    )

    var bestData: Data?
    var bestArea = 0

    for candidate in candidates {
      guard let data = await fetchImage(url: candidate, timeout: timeout) else {
        continue
      }

      guard let dimensions = imageDimensions(for: data) else {
        if bestData == nil {
          bestData = data
        }
        continue
      }

      let area = dimensions.width * dimensions.height
      if area >= 1280 * 720 {
        return data
      }

      if area > bestArea {
        bestArea = area
        bestData = data
      }
    }

    return bestData
  }

  private static func thumbnailCandidates(
    videoURL: URL,
    providedThumbnailURL: URL
  ) -> [URL] {
    var urls: [URL] = []

    if let videoID = extractVideoID(from: videoURL) {
      let paths = [
        "maxresdefault.jpg",
        "sddefault.jpg",
        "hqdefault.jpg",
        "mqdefault.jpg",
        "default.jpg",
      ]

      for path in paths {
        if let url = URL(string: "https://i.ytimg.com/vi/\(videoID)/\(path)") {
          urls.append(url)
        }
      }
    }

    urls.append(providedThumbnailURL)

    var seen: Set<String> = []
    return urls.filter { seen.insert($0.absoluteString).inserted }
  }

  private static func imageDimensions(for data: Data) -> (width: Int, height: Int)? {
    guard
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else {
      return nil
    }

    return (width, height)
  }

  static func isYouTubeURL(_ url: URL) -> Bool {
    guard let host = url.host?.lowercased() else { return false }
    return host.contains("youtube.com") || host.contains("youtu.be")
  }

  static func extractVideoID(from url: URL) -> String? {
    let host = url.host?.lowercased()

    // Handle youtu.be short links
    if host?.contains("youtu.be") == true {
      let pathComponents = url.pathComponents.filter { $0 != "/" }
      return pathComponents.first
    }

    // Handle youtube.com/watch?v= links
    if let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ),
      let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value
    {
      return videoId
    }

    // Handle youtube.com/embed/ links
    if url.pathComponents.contains("embed"),
      let videoId = url.pathComponents.last
    {
      return videoId
    }

    return nil
  }
}
