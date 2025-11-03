//
//  YouTubeMetadataFetcher.swift
//  toss
//
//  Created by Urban Vidovič on 3. 11. 25.
//

import Foundation

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

class YouTubeMetadataFetcher {
  typealias CompletionHandler = (
    _ imageData: Data?,
    _ title: String?,
    _ author: String?
  ) -> Void

  static func fetchMetadata(url: URL, completion: @escaping CompletionHandler) {
    // Construct oEmbed API URL
    guard
      var components = URLComponents(
        string: "https://www.youtube.com/oembed"
      )
    else {
      DispatchQueue.main.async { completion(nil, nil, nil) }
      return
    }

    components.queryItems = [
      URLQueryItem(name: "url", value: url.absoluteString),
      URLQueryItem(name: "format", value: "json"),
    ]

    guard let oembedURL = components.url else {
      DispatchQueue.main.async { completion(nil, nil, nil) }
      return
    }

    URLSession.shared.dataTask(with: oembedURL) { data, response, error in
      guard let data = data else {
        DispatchQueue.main.async { completion(nil, nil, nil) }
        return
      }

      do {
        let decoder = JSONDecoder()
        let oembedData = try decoder.decode(
          YouTubeOEmbedResponse.self,
          from: data
        )

        // Download thumbnail image
        guard let thumbnailURL = URL(string: oembedData.thumbnailURL)
        else {
          DispatchQueue.main.async {
            completion(nil, oembedData.title, oembedData.authorName)
          }
          return
        }

        fetchImage(url: thumbnailURL) { imageData in
          DispatchQueue.main.async {
            completion(
              imageData,
              oembedData.title,
              oembedData.authorName
            )
          }
        }

      } catch {
        DispatchQueue.main.async { completion(nil, nil, nil) }
      }
    }.resume()
  }

  // MARK: - Helper Methods

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
