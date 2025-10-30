//  WebsiteScreenshotCaptureService.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
//

import Foundation

#if os(macOS)
    import AppKit
    typealias PlatformImage = NSImage
#else
    import UIKit
    typealias PlatformImage = UIImage
#endif

class WebsiteMetadataFetcher {
    static func fetchOGImage(
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
}
