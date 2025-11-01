//  WebsiteScreenshotCaptureService.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
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

class WebsiteMetadataFetcher {
    static func fetchImageOrScreenshot(
        url: URL,
        completion: @escaping (PlatformImage?) -> Void
    ) {
        // First, try to fetch the OG image
        fetchOGImage(url: url) { ogImage in
            if let ogImage = ogImage {
                // OG image found, return it
                completion(ogImage)
            } else {
                // OG image not available, take screenshot
                takeWebsiteScreenshot(url: url, completion: completion)
            }
        }
    }

    private static func fetchOGImage(
        url: URL,
        completion: @escaping (PlatformImage?) -> Void
    ) {
        // First, fetch the HTML
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                let html = String(data: data, encoding: .utf8)
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Find og:image URL
            if let ogImageURL = extractOGImage(from: html) {
                // Download the image
                URLSession.shared.dataTask(with: ogImageURL) {
                    imageData,
                    _,
                    _ in
                    guard let imageData = imageData else {
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }

                    let image = PlatformImage(data: imageData)
                    DispatchQueue.main.async { completion(image) }
                }.resume()
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    private static func extractOGImage(from html: String) -> URL? {
        // Look for og:image meta tag
        let pattern =
            #"<meta\s+property=["\']og:image["\']\s+content=["\'](.*?)["\']\s*/?>"#

        if let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ),
            let match = regex.firstMatch(
                in: html,
                range: NSRange(html.startIndex..., in: html)
            ),
            let range = Range(match.range(at: 1), in: html)
        {
            let urlString = String(html[range])
            return URL(string: urlString)
        }

        return nil
    }

    // MARK: - Screenshot Capture

    private static func takeWebsiteScreenshot(
        url: URL,
        completion: @escaping (PlatformImage?) -> Void
    ) {
        // Create a container that retains itself until completion
        let capturer = ScreenshotCapturer(url: url, completion: completion)
        capturer.start()
    }
}

// MARK: - Screenshot Capturer

/// Self-retaining class that captures a screenshot and deallocates when done
private class ScreenshotCapturer: NSObject, WKNavigationDelegate {
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
        // Create self-retaining cycle - prevents deallocation
        retainCycle = self

        // Create WKWebView
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
        webView.navigationDelegate = self

        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for content to render (especially dynamic content)
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

    // MARK: - Private Methods

    private func captureSnapshot() {
        guard let webView = webView else {
            finish(with: nil)
            return
        }

        // Create snapshot configuration
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

        // Take snapshot
        webView.takeSnapshot(with: config) { [weak self] image, error in
            if let error = error {
                print("Screenshot error: \(error.localizedDescription)")
                self?.finish(with: nil)
            } else {
                self?.finish(with: image)
            }
        }
    }

    private func finish(with image: PlatformImage?) {
        DispatchQueue.main.async { [weak self] in
            self?.completion(image)
            // Break the retain cycle - allows deallocation
            self?.retainCycle = nil
        }
    }
}
