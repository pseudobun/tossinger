//  WebsiteMetadataFetcher.swift
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

// MARK: - Enhanced Metadata Structure

struct WebsiteMetadata {
    var image: PlatformImage?
    var title: String?
    var description: String?
    var author: String?
}

class WebsiteMetadataFetcher {
    static func fetchImageOrScreenshot(
        url: URL,
        completion: @escaping (PlatformImage?) -> Void
    ) {
        fetchMetadata(url: url) { metadata in
            if let image = metadata.image {
                completion(image)
            } else {
                takeWebsiteScreenshot(url: url, completion: completion)
            }
        }
    }

    static func fetchMetadata(
        url: URL,
        completion: @escaping (WebsiteMetadata) -> Void
    ) {
        // Check if it's a Twitter/X URL
        let isTwitter =
            url.host?.contains("twitter.com") == true
            || url.host?.contains("x.com") == true

        if isTwitter {
            // For Twitter, use WKWebView to render JavaScript
            fetchTwitterMetadata(url: url, completion: completion)
        } else {
            // For other sites, use simple HTML parsing
            fetchSimpleMetadata(url: url, completion: completion)
        }
    }

    private static func fetchSimpleMetadata(
        url: URL,
        completion: @escaping (WebsiteMetadata) -> Void
    ) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                let html = String(data: data, encoding: .utf8)
            else {
                DispatchQueue.main.async { completion(WebsiteMetadata()) }
                return
            }

            var metadata = WebsiteMetadata()
            let metaTags = extractAllMetaTags(from: html)

            metadata.title =
                metaTags["og:title"]
                ?? metaTags["twitter:title"]
                ?? extractTitleTag(from: html)

            metadata.description =
                metaTags["og:description"]
                ?? metaTags["twitter:description"]
                ?? metaTags["description"]

            metadata.author =
                metaTags["twitter:creator"]
                ?? metaTags["article:author"]

            if let imageURLString = metaTags["og:image"]
                ?? metaTags["twitter:image"],
                let imageURL = URL(string: imageURLString)
            {
                URLSession.shared.dataTask(with: imageURL) { imageData, _, _ in
                    if let imageData = imageData {
                        metadata.image = PlatformImage(data: imageData)
                    }
                    DispatchQueue.main.async { completion(metadata) }
                }.resume()
            } else {
                DispatchQueue.main.async { completion(metadata) }
            }
        }.resume()
    }

    private static func fetchTwitterMetadata(
        url: URL,
        completion: @escaping (WebsiteMetadata) -> Void
    ) {
        let webView = WKWebView(frame: .zero)
        var metadata = WebsiteMetadata()
        var hasFinished = false

        let navigationDelegate = TwitterMetadataDelegate { html in
            guard !hasFinished else { return }
            hasFinished = true

            let metaTags = extractAllMetaTags(from: html)

            metadata.title =
                metaTags["og:title"]
                ?? metaTags["twitter:title"]
                ?? extractTitleTag(from: html)

            metadata.description =
                metaTags["og:description"]
                ?? metaTags["twitter:description"]
                ?? metaTags["description"]

            metadata.author =
                metaTags["twitter:creator"]
                ?? metaTags["article:author"]

            if let imageURLString = metaTags["og:image"]
                ?? metaTags["twitter:image"],
                let imageURL = URL(string: imageURLString)
            {
                URLSession.shared.dataTask(with: imageURL) { imageData, _, _ in
                    if let imageData = imageData {
                        metadata.image = PlatformImage(data: imageData)
                    }
                    DispatchQueue.main.async { completion(metadata) }
                }.resume()
            } else {
                DispatchQueue.main.async { completion(metadata) }
            }
        }

        webView.navigationDelegate = navigationDelegate
        objc_setAssociatedObject(
            webView,
            "delegate",
            navigationDelegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        webView.load(URLRequest(url: url))
    }

    // MARK: - Meta Tag Extraction

    private static func extractAllMetaTags(from html: String) -> [String:
        String]
    {
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

    // MARK: - Screenshot Capture

    private static func takeWebsiteScreenshot(
        url: URL,
        completion: @escaping (PlatformImage?) -> Void
    ) {
        let capturer = ScreenshotCapturer(url: url, completion: completion)
        capturer.start()
    }
}

// MARK: - Twitter Metadata Delegate

private class TwitterMetadataDelegate: NSObject, WKNavigationDelegate {
    private let onFinish: (String) -> Void
    private var didCallCompletion = false

    init(onFinish: @escaping (String) -> Void) {
        self.onFinish = onFinish
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for JavaScript to render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            [weak self, weak webView] in
            guard let self = self, !self.didCallCompletion,
                let webView = webView
            else { return }
            self.didCallCompletion = true

            webView.evaluateJavaScript("document.documentElement.outerHTML") {
                html,
                _ in
                if let html = html as? String {
                    self.onFinish(html)
                }
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        guard !didCallCompletion else { return }
        didCallCompletion = true
        onFinish("")
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        guard !didCallCompletion else { return }
        didCallCompletion = true
        onFinish("")
    }
}

// MARK: - Screenshot Capturer (Private Implementation)

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
        retainCycle = self
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
        webView.navigationDelegate = self
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
            self?.retainCycle = nil
        }
    }
}
