//
//  MetadataCoordinator.swift
//  toss
//
//  Created by Urban Vidovič on 3. 11. 25.
//

import Foundation

#if os(iOS)
  import UIKit
#endif

class MetadataCoordinator {
  typealias CompletionHandler = (
    _ imageData: Data?,
    _ title: String?,
    _ description: String?,
    _ author: String?,
    _ platformType: PlatformType
  ) -> Void

  static func fetchMetadata(url: URL, completion: @escaping CompletionHandler) {
    let platformType = detectPlatformType(url: url)

    switch platformType {
    case .youtube:
      fetchYouTubeMetadata(url: url, completion: completion)

    case .xProfile:
      fetchXProfileMetadata(url: url, completion: completion)

    case .xPost:
      fetchXPostMetadata(url: url, completion: completion)

    case .github:
      fetchGenericMetadataWithScreenshot(
        url: url,
        platformType: .github,
        completion: completion
      )

    case .genericWebsite:
      fetchGenericMetadataWithScreenshot(
        url: url,
        platformType: .genericWebsite,
        completion: completion
      )
    }
  }

  // MARK: - Platform Detection

  private static func detectPlatformType(url: URL) -> PlatformType {
    guard let host = url.host?.lowercased() else {
      return .genericWebsite
    }

    // YouTube detection
    if host.contains("youtube.com") || host.contains("youtu.be") {
      return .youtube
    }

    // Twitter/X detection
    if host.contains("twitter.com") || host.contains("x.com") {
      let pathComponents = url.pathComponents.filter { $0 != "/" }
      // Check if it's a post (contains "status")
      if pathComponents.contains("status"), pathComponents.count >= 3 {
        return .xPost
      }
      return .xProfile
    }

    // GitHub detection
    if host.contains("github.com") {
      return .github
    }

    return .genericWebsite
  }

  // MARK: - YouTube Metadata Fetching

  private static func fetchYouTubeMetadata(
    url: URL,
    completion: @escaping CompletionHandler
  ) {
    YouTubeMetadataFetcher.fetchMetadata(url: url) {
      imageData,
      title,
      author in

      // If YouTube oEmbed succeeds, return immediately
      if imageData != nil {
        completion(imageData, title, nil, author, .youtube)
        return
      }

      // Fallback to generic OG tags
      fetchGenericMetadataWithScreenshot(
        url: url,
        platformType: .youtube,
        completion: completion
      )
    }
  }

  // MARK: - X/Twitter Metadata Fetching

  private static func fetchXProfileMetadata(
    url: URL,
    completion: @escaping CompletionHandler
  ) {
    TwitterMetadataFetcher.fetchMetadata(url: url) {
      description,
      author,
      _ in
      // X profiles: no image, just username
      completion(nil, nil, description, author, .xProfile)
    }
  }

  private static func fetchXPostMetadata(
    url: URL,
    completion: @escaping CompletionHandler
  ) {
    TwitterMetadataFetcher.fetchMetadata(url: url) {
      description,
      author,
      _ in
      // X posts: no image, tweet text and author
      completion(nil, nil, description, author, .xPost)
    }
  }

  // MARK: - Generic Website with Screenshot Fallback

  private static func fetchGenericMetadataWithScreenshot(
    url: URL,
    platformType: PlatformType,
    completion: @escaping CompletionHandler
  ) {
    GenericWebsiteMetadataFetcher.fetchMetadata(url: url) {
      imageData,
      title,
      description in

      // If we got an image from OG tags, return it
      if imageData != nil {
        completion(imageData, title, description, nil, platformType)
        return
      }

      // Fallback to screenshot
      takeScreenshot(url: url) { screenshotData in
        completion(
          screenshotData,
          title,
          description,
          nil,
          platformType
        )
      }
    }
  }

  // MARK: - Screenshot Fallback

  private static func takeScreenshot(
    url: URL,
    completion: @escaping (Data?) -> Void
  ) {
    let capturer = ScreenshotCapturer(url: url) { image in
      guard let image = image else {
        completion(nil)
        return
      }

      // Convert platform image to Data
      #if os(macOS)
        let imageData = image.tiffRepresentation
      #else
        let imageData = image.pngData()
      #endif

      completion(imageData)
    }
    capturer.start()
  }
}
