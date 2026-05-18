//
//  GoogleMapsShortLinkResolver.swift
//  toss
//
//  Expands `maps.app.goo.gl` and legacy `goo.gl/maps` short URLs to their
//  canonical Google Maps URL. Sets an iOS Safari UA on the request itself
//  (Firebase Dynamic Links gates the 302 on a mobile UA), preseeds a
//  consent cookie to attempt to avoid the EU GDPR `consent.google.com`
//  gate, uses a per-task delegate to log + capture redirect hops, and
//  finally scans hops + final URL + any `continue=` query parameter for
//  the first parser-acceptable Maps URL. Falls back to body-regex scrape
//  if none of the above yields a Maps URL.
//

import Foundation
import os

enum GoogleMapsShortLinkResolver {
  private static let userAgent =
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) "
    + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 "
    + "Mobile/15E148 Safari/604.1"

  private static let shortHosts: Set<String> = ["maps.app.goo.gl", "goo.gl"]

  private static let logger = Logger(subsystem: "lutra-labs.toss", category: "gmaps")

  private static let mapsURLRegex = try! NSRegularExpression(
    pattern: #"https?://(?:www\.|maps\.)?google\.com/maps/(?:place|search|dir|@)[^\s"'<>\\]+"#
  )

  static func resolve(_ url: URL, timeout: TimeInterval) async -> URL? {
    guard let host = url.host?.lowercased(), shortHosts.contains(host) else {
      return url
    }

    logger.debug("resolve start \(url.absoluteString, privacy: .public)")

    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = timeout
    config.timeoutIntervalForResource = timeout
    config.httpAdditionalHeaders = ["Accept-Language": "en-US,en;q=0.9"]
    config.httpCookieAcceptPolicy = .always
    if let consentCookie = HTTPCookie(properties: [
      .domain: ".google.com",
      .path: "/",
      .name: "CONSENT",
      .value: "YES+",
      .expires: Date().addingTimeInterval(60 * 60 * 24 * 365),
    ]) {
      config.httpCookieStorage?.setCookie(consentCookie)
    }
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }

    if let resolved = await attemptResolve(url, session: session) {
      return resolved
    }

    if host == "goo.gl" {
      guard let retryURL = appendingQuery(url, name: "si", value: "1") else {
        logger.debug("goo.gl ?si=1 retry URL build failed")
        return nil
      }
      if let resolved = await attemptResolve(retryURL, session: session) {
        return resolved
      }
    }

    logger.debug("resolve returning nil for \(url.absoluteString, privacy: .public)")
    return nil
  }

  private static func attemptResolve(_ url: URL, session: URLSession) async -> URL? {
    let delegate = RedirectTrackingDelegate(logger: logger)
    let request = makeRequest(url: url)

    do {
      let (data, response) = try await session.data(for: request, delegate: delegate)
      let httpResponse = response as? HTTPURLResponse
      let finalURL = httpResponse?.url ?? response.url ?? url
      let status = httpResponse?.statusCode ?? -1

      logger.debug(
        "fetch done status=\(status, privacy: .public) hops=\(delegate.hops.count, privacy: .public) final=\(finalURL.absoluteString, privacy: .public)"
      )

      var candidates: [URL] = delegate.hops + [finalURL]
      for source in candidates {
        if let cont = extractContinueParam(from: source) {
          candidates.append(cont)
        }
      }

      for (index, candidate) in candidates.enumerated() {
        if isUsableMapsURL(candidate) {
          logger.debug(
            "returning candidate[\(index, privacy: .public)] \(candidate.absoluteString, privacy: .public)"
          )
          return candidate
        }
      }

      if let scraped = scrapeMapsURL(from: data) {
        logger.debug("body fallback found \(scraped.absoluteString, privacy: .public)")
        return scraped
      }

      logger.debug("no usable URL in chain, continue param, or body")
      return nil
    } catch {
      logger.debug("fetch error \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }

  private static func makeRequest(url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue(
      "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      forHTTPHeaderField: "Accept"
    )
    request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    return request
  }

  private static func scrapeMapsURL(from data: Data) -> URL? {
    guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
    else {
      return nil
    }
    let range = NSRange(html.startIndex..., in: html)
    guard let match = mapsURLRegex.firstMatch(in: html, range: range),
      let matched = Range(match.range, in: html)
    else {
      return nil
    }
    let candidate = String(html[matched])
      .replacingOccurrences(of: "&amp;", with: "&")
    return URL(string: candidate)
  }

  private static func isShortHost(_ host: String?) -> Bool {
    guard let host = host?.lowercased() else { return false }
    return shortHosts.contains(host)
  }

  private static func isUsableMapsURL(_ url: URL) -> Bool {
    guard let host = url.host?.lowercased() else { return false }
    if host == "plus.codes" {
      return !url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty
    }
    let mapsHosts: Set<String> = [
      "google.com", "www.google.com", "maps.google.com",
    ]
    return mapsHosts.contains(host) && url.path.hasPrefix("/maps")
  }

  private static func extractContinueParam(from url: URL) -> URL? {
    guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let raw = comps.queryItems?.first(where: { $0.name == "continue" })?.value,
      let decoded = raw.removingPercentEncoding,
      let next = URL(string: decoded)
    else {
      return nil
    }
    return next
  }

  private static func appendingQuery(_ url: URL, name: String, value: String) -> URL? {
    guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return nil
    }
    var items = comps.queryItems ?? []
    items.append(URLQueryItem(name: name, value: value))
    comps.queryItems = items
    return comps.url
  }
}

private final class RedirectTrackingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable
{
  private(set) var hops: [URL] = []
  private let logger: Logger

  init(logger: Logger) {
    self.logger = logger
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    if let url = request.url {
      hops.append(url)
      logger.debug(
        "redirect \(response.statusCode, privacy: .public) → \(url.absoluteString, privacy: .public)"
      )
    }
    completionHandler(request)
  }
}
