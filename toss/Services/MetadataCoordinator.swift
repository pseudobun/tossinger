//
//  MetadataCoordinator.swift
//  toss
//
//  Created by Urban Vidovič on 3. 11. 25.
//

import Foundation

protocol MetadataFetching {
  func fetchMetadata(for url: URL, timeout: TimeInterval) async -> MetadataResult
}

struct MetadataResult {
  let imageData: Data?
  let title: String?
  let description: String?
  let author: String?
  let platformType: PlatformType
  let fetchState: MetadataFetchState
  let fetchedAt: Date
}

class MetadataCoordinator {
  typealias CompletionHandler = (
    _ imageData: Data?,
    _ title: String?,
    _ description: String?,
    _ author: String?,
    _ platformType: PlatformType
  ) -> Void

  static let defaultMainAppTimeout: TimeInterval = 8
  static let shareExtensionTimeout: TimeInterval = 4

  private static let service: MetadataFetching = DefaultMetadataService()

  static func fetchMetadata(
    url: URL,
    timeout: TimeInterval = defaultMainAppTimeout
  ) async -> MetadataResult {
    let effectiveTimeout: TimeInterval

    if useMetadataTimeoutPolicy {
      effectiveTimeout = timeout
    } else {
      effectiveTimeout = max(timeout, 30)
    }

    return await service.fetchMetadata(for: url, timeout: effectiveTimeout)
  }

  static func fetchMetadata(
    url: URL,
    completion: @escaping CompletionHandler
  ) {
    fetchMetadata(url: url, timeout: defaultMainAppTimeout, completion: completion)
  }

  static func fetchMetadata(
    url: URL,
    timeout: TimeInterval,
    completion: @escaping CompletionHandler
  ) {
    Task {
      let result = await fetchMetadata(url: url, timeout: timeout)
      await MainActor.run {
        completion(
          result.imageData,
          result.title,
          result.description,
          result.author,
          result.platformType
        )
      }
    }
  }

  static func fetchMetadata(
    url: URL,
    timeout: TimeInterval,
    completion: @escaping (MetadataResult) -> Void
  ) {
    Task {
      let result = await fetchMetadata(url: url, timeout: timeout)
      await MainActor.run {
        completion(result)
      }
    }
  }

  static func detectPlatformType(url: URL) -> PlatformType {
    guard let host = url.host?.lowercased() else {
      return .genericWebsite
    }
    if host.contains("youtube.com") || host.contains("youtu.be") {
      return .youtube
    }
    if host.contains("twitter.com") || host.contains("x.com") {
      let pathComponents = url.pathComponents.filter { $0 != "/" }
      if pathComponents.contains("status"), pathComponents.count >= 3 {
        return .xPost
      }
      return .xProfile
    }
    if host.contains("github.com") {
      return .github
    }
    return .genericWebsite
  }

  fileprivate static var useMetadataTimeoutPolicy: Bool {
    let defaults = UserDefaults.standard
    let key = "UseMetadataTimeoutPolicy"
    guard defaults.object(forKey: key) != nil else {
      return true
    }
    return defaults.bool(forKey: key)
  }
}

private actor DefaultMetadataService: MetadataFetching {
  private let networkSemaphore = AsyncSemaphore(value: 4)
  private let screenshotSemaphore = AsyncSemaphore(value: screenshotConcurrency)

  private static var screenshotConcurrency: Int {
    #if os(iOS)
      return 1
    #else
      return 2
    #endif
  }

  func fetchMetadata(for url: URL, timeout: TimeInterval) async -> MetadataResult {
    let platformType = detectPlatformType(url: url)

    let operation: @Sendable () async -> MetadataResult = { [weak self] in
      guard let self else {
        return MetadataResult(
          imageData: nil,
          title: nil,
          description: nil,
          author: nil,
          platformType: platformType,
          fetchState: .failed,
          fetchedAt: Date()
        )
      }
      return await self.fetchWithRetry(url: url, platformType: platformType, timeout: timeout)
    }

    guard MetadataCoordinator.useMetadataTimeoutPolicy else {
      return await operation()
    }

    if let result = await withTimeout(seconds: timeout, operation: operation) {
      return result
    }

    return MetadataResult(
      imageData: nil,
      title: nil,
      description: nil,
      author: nil,
      platformType: platformType,
      fetchState: .timeout,
      fetchedAt: Date()
    )
  }

  // MARK: - Platform Detection

  private func detectPlatformType(url: URL) -> PlatformType {
    MetadataCoordinator.detectPlatformType(url: url)
  }

  // MARK: - Retry

  private func fetchWithRetry(
    url: URL,
    platformType: PlatformType,
    timeout: TimeInterval
  ) async -> MetadataResult {
    var finalResult = MetadataResult(
      imageData: nil,
      title: nil,
      description: nil,
      author: nil,
      platformType: platformType,
      fetchState: .failed,
      fetchedAt: Date()
    )

    for attempt in 1...2 {
      finalResult = await fetchWithoutRetry(
        url: url,
        platformType: platformType,
        timeout: timeout
      )

      if finalResult.fetchState == .success || attempt == 2 {
        return finalResult
      }
    }

    return finalResult
  }

  // MARK: - Routing

  private func fetchWithoutRetry(
    url: URL,
    platformType: PlatformType,
    timeout: TimeInterval
  ) async -> MetadataResult {
    switch platformType {
    case .youtube:
      return await fetchYouTubeMetadata(url: url, timeout: timeout)

    case .xProfile:
      return await fetchXProfileMetadata(url: url, timeout: timeout)

    case .xPost:
      return await fetchXPostMetadata(url: url, timeout: timeout)

    case .github:
      return await fetchGenericMetadataWithScreenshot(
        url: url,
        platformType: .github,
        timeout: timeout
      )

    case .genericWebsite:
      return await fetchGenericMetadataWithScreenshot(
        url: url,
        platformType: .genericWebsite,
        timeout: timeout
      )
    }
  }

  // MARK: - YouTube Metadata Fetching

  private func fetchYouTubeMetadata(
    url: URL,
    timeout: TimeInterval
  ) async -> MetadataResult {
    let youtubeMetadata = await networkSemaphore.withPermit {
      await YouTubeMetadataFetcher.fetchMetadata(url: url, timeout: timeout)
    }

    if youtubeMetadata.imageData != nil || youtubeMetadata.didSucceed {
      return MetadataResult(
        imageData: youtubeMetadata.imageData,
        title: youtubeMetadata.title,
        description: nil,
        author: youtubeMetadata.author,
        platformType: .youtube,
        fetchState: .success,
        fetchedAt: Date()
      )
    }

    return await fetchGenericMetadataWithScreenshot(
      url: url,
      platformType: .youtube,
      timeout: timeout
    )
  }

  // MARK: - X/Twitter Metadata Fetching

  private func fetchXProfileMetadata(
    url: URL,
    timeout: TimeInterval
  ) async -> MetadataResult {
    let metadata = await networkSemaphore.withPermit {
      await TwitterMetadataFetcher.fetchMetadata(url: url, timeout: timeout)
    }

    let fetchState: MetadataFetchState = metadata.didSucceed ? .success : .failed
    return MetadataResult(
      imageData: nil,
      title: nil,
      description: metadata.description,
      author: metadata.author,
      platformType: .xProfile,
      fetchState: fetchState,
      fetchedAt: Date()
    )
  }

  private func fetchXPostMetadata(
    url: URL,
    timeout: TimeInterval
  ) async -> MetadataResult {
    let metadata = await networkSemaphore.withPermit {
      await TwitterMetadataFetcher.fetchMetadata(url: url, timeout: timeout)
    }

    let fetchState: MetadataFetchState = metadata.didSucceed ? .success : .failed
    return MetadataResult(
      imageData: nil,
      title: nil,
      description: metadata.description,
      author: metadata.author,
      platformType: .xPost,
      fetchState: fetchState,
      fetchedAt: Date()
    )
  }

  // MARK: - Generic Website with Screenshot Fallback

  private func fetchGenericMetadataWithScreenshot(
    url: URL,
    platformType: PlatformType,
    timeout: TimeInterval
  ) async -> MetadataResult {
    let metadata = await networkSemaphore.withPermit {
      await GenericWebsiteMetadataFetcher.fetchMetadata(url: url, timeout: timeout)
    }

    if let imageData = metadata.imageData {
      return MetadataResult(
        imageData: imageData,
        title: metadata.title,
        description: metadata.description,
        author: nil,
        platformType: platformType,
        fetchState: .success,
        fetchedAt: Date()
      )
    }

    let screenshotData = await screenshotSemaphore.withPermit {
      await ScreenshotCapturer.capture(url: url, timeout: min(timeout, 6))
    }

    if screenshotData != nil || metadata.didSucceed {
      return MetadataResult(
        imageData: screenshotData,
        title: metadata.title,
        description: metadata.description,
        author: nil,
        platformType: platformType,
        fetchState: .success,
        fetchedAt: Date()
      )
    }

    return MetadataResult(
      imageData: nil,
      title: nil,
      description: nil,
      author: nil,
      platformType: platformType,
      fetchState: .failed,
      fetchedAt: Date()
    )
  }
}

private actor AsyncSemaphore {
  private var availablePermits: Int
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init(value: Int) {
    availablePermits = max(1, value)
  }

  func withPermit<T>(
    _ operation: @escaping @Sendable () async -> T
  ) async -> T {
    await wait()
    defer { signal() }
    return await operation()
  }

  private func wait() async {
    if availablePermits > 0 {
      availablePermits -= 1
      return
    }

    await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  private func signal() {
    if let continuation = waiters.first {
      waiters.removeFirst()
      continuation.resume()
    } else {
      availablePermits += 1
    }
  }
}

private func withTimeout<T>(
  seconds: TimeInterval,
  operation: @escaping @Sendable () async -> T
) async -> T? {
  await withTaskGroup(of: T?.self) { group in
    group.addTask {
      await operation()
    }

    group.addTask {
      try? await Task.sleep(nanoseconds: UInt64(max(0.1, seconds) * 1_000_000_000))
      return nil
    }

    let value = await group.next() ?? nil
    group.cancelAll()
    return value
  }
}
