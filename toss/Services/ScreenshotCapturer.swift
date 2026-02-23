//
//  ScreenshotCapturer.swift
//  toss
//
//  Created by Urban Vidovič on 3. 11. 25.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers
import WebKit

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

// MARK: - Screenshot Capturer

class ScreenshotCapturer: NSObject, WKNavigationDelegate {
  private let url: URL
  private var webView: WKWebView?
  private var continuation: CheckedContinuation<Data?, Never>?
  private var retainCycle: ScreenshotCapturer?
  private var didFinishCapture = false
  private var timeoutTask: Task<Void, Never>?
  private var delayedCaptureTask: Task<Void, Never>?

  init(url: URL) {
    self.url = url
    super.init()
  }

  static func capture(
    url: URL,
    timeout: TimeInterval = 6
  ) async -> Data? {
    await withCheckedContinuation { continuation in
      Task { @MainActor in
        let capturer = ScreenshotCapturer(url: url)
        capturer.start(timeout: timeout, continuation: continuation)
      }
    }
  }

  static func optimizedImageData(
    from data: Data,
    maxPixelSize: Int = 1024,
    maxBytes: Int = 350 * 1024,
    initialQuality: CGFloat = 0.75
  ) -> Data? {
    guard
      let source = CGImageSourceCreateWithData(data as CFData, nil)
    else {
      return nil
    }

    var currentPixelSize = max(256, maxPixelSize)

    while currentPixelSize >= 256 {
      guard
        let cgImage = downsampledCGImage(
          from: source,
          maxPixelSize: currentPixelSize
        )
      else {
        return nil
      }

      var quality = initialQuality
      while quality >= 0.35 {
        guard let jpegData = jpegData(from: cgImage, quality: quality)
        else {
          return nil
        }

        if jpegData.count <= maxBytes {
          return jpegData
        }

        quality -= 0.1
      }

      currentPixelSize = Int(Double(currentPixelSize) * 0.85)
    }

    guard let fallbackCGImage = downsampledCGImage(from: source, maxPixelSize: 256)
    else {
      return nil
    }

    return jpegData(from: fallbackCGImage, quality: 0.35)
  }

  @MainActor
  private func start(
    timeout: TimeInterval,
    continuation: CheckedContinuation<Data?, Never>
  ) {
    retainCycle = self
    self.continuation = continuation

    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()

    let frame = CGRect(x: 0, y: 0, width: 1024, height: 683)
    webView = WKWebView(frame: frame, configuration: configuration)
    webView?.navigationDelegate = self
    webView?.customUserAgent =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    timeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
      self?.finish(with: nil)
    }

    webView?.load(URLRequest(url: url))
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    delayedCaptureTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 600_000_000)
      self?.captureSnapshot()
    }
  }

  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation!,
    withError error: Error
  ) {
    Task { @MainActor [weak self] in
      self?.finish(with: nil)
    }
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    Task { @MainActor [weak self] in
      self?.finish(with: nil)
    }
  }

  @MainActor
  private func captureSnapshot() {
    guard let webView else {
      finish(with: nil)
      return
    }

    let configuration = WKSnapshotConfiguration()
    configuration.rect = CGRect(
      x: 0,
      y: 0,
      width: webView.bounds.width,
      height: webView.bounds.height
    )

    #if os(iOS)
      configuration.afterScreenUpdates = true
    #endif

    webView.takeSnapshot(with: configuration) { [weak self] image, _ in
      guard let self else { return }
      guard let image else {
        self.finish(with: nil)
        return
      }

      guard let rawData = Self.platformImageData(from: image) else {
        self.finish(with: nil)
        return
      }

      let optimizedData = Self.optimizedImageData(
        from: rawData,
        maxPixelSize: 1024,
        maxBytes: 350 * 1024,
        initialQuality: 0.75
      )

      self.finish(with: optimizedData)
    }
  }

  @MainActor
  private func finish(with imageData: Data?) {
    guard !didFinishCapture else { return }
    didFinishCapture = true

    timeoutTask?.cancel()
    delayedCaptureTask?.cancel()
    webView?.navigationDelegate = nil
    webView = nil

    continuation?.resume(returning: imageData)
    continuation = nil
    retainCycle = nil
  }

  private static func platformImageData(from image: PlatformImage) -> Data? {
    #if os(macOS)
      guard let tiffData = image.tiffRepresentation else {
        return nil
      }
      return tiffData
    #else
      return image.pngData()
    #endif
  }

  private static func downsampledCGImage(
    from source: CGImageSource,
    maxPixelSize: Int
  ) -> CGImage? {
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]

    return CGImageSourceCreateThumbnailAtIndex(
      source,
      0,
      options as CFDictionary
    )
  }

  private static func jpegData(from cgImage: CGImage, quality: CGFloat) -> Data? {
    let data = NSMutableData()

    guard
      let destination = CGImageDestinationCreateWithData(
        data,
        UTType.jpeg.identifier as CFString,
        1,
        nil
      )
    else {
      return nil
    }

    let options: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: quality,
    ]

    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

    guard CGImageDestinationFinalize(destination) else {
      return nil
    }

    return data as Data
  }
}

#if os(macOS)
  typealias PlatformImage = NSImage
#else
  typealias PlatformImage = UIImage
#endif
