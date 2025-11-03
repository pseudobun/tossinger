//
//  ScreenshotCapturer.swift
//  toss
//
//  Created by Urban Vidovič on 3. 11. 25.
//

import Foundation
import WebKit

#if os(macOS)
  import AppKit
  typealias PlatformImage = NSImage
#else
  import UIKit
  typealias PlatformImage = UIImage
#endif

// MARK: - Screenshot Capturer

class ScreenshotCapturer: NSObject, WKNavigationDelegate {
  private let url: URL
  private let completion: (PlatformImage?) -> Void
  private var webView: WKWebView!
  private var retainCycle: ScreenshotCapturer?

  init(url: URL, completion: @escaping (PlatformImage?) -> Void) {
    self.url = url
    self.completion = completion
    super.init()
  }

  func start() {
    retainCycle = self
    webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
    webView.navigationDelegate = self
    webView.customUserAgent =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    webView.load(URLRequest(url: url))
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.captureSnapshot()
    }
  }

  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation!,
    withError error: Error
  ) {
    finish(with: nil)
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    finish(with: nil)
  }

  private func captureSnapshot() {
    guard let webView = webView else {
      finish(with: nil)
      return
    }

    let config = WKSnapshotConfiguration()
    config.rect = CGRect(
      x: 0,
      y: 0,
      width: webView.bounds.width,
      height: webView.bounds.height
    )

    #if os(iOS)
      config.afterScreenUpdates = true
    #endif

    webView.takeSnapshot(with: config) { [weak self] image, error in
      if let error = error {
        self?.finish(with: nil)
      } else {
        self?.finish(with: image)
      }
    }
  }

  private func finish(with image: PlatformImage?) {
    DispatchQueue.main.async { [weak self] in
      self?.completion(image)
      self?.retainCycle = nil
    }
  }
}
