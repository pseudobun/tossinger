//
//  GoogleMapsURLParser.swift
//  toss
//
//  Pure URL → structural-data parser for Google Maps share links.
//  No network, no MapKit. Classification only; the fetcher composes
//  display strings and renders thumbnails from this result.
//

import CoreLocation
import Foundation
import TossKit

struct GoogleMapsParseResult {
  enum Kind {
    case place
    case mapView
    case directions
    case search
    case streetView
    case embed
    case coordinates
    case plusCode
    case unknown
  }

  let kind: Kind
  let coordinate: CLLocationCoordinate2D?
  let title: String?
  let needsResolve: Bool
  let appleMapsURL: URL?
}

enum GoogleMapsURLParser {
  static func parse(_ url: URL) -> GoogleMapsParseResult? {
    guard let host = url.host?.lowercased() else { return nil }

    if host == "maps.app.goo.gl"
      || (host == "goo.gl" && url.path.hasPrefix("/maps/"))
    {
      return GoogleMapsParseResult(
        kind: .unknown,
        coordinate: nil,
        title: nil,
        needsResolve: true,
        appleMapsURL: nil
      )
    }

    if host == "plus.codes" {
      let code = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      guard !code.isEmpty,
        let coord = PlusCode.decode(code.removingPercentEncoding ?? code)
      else { return nil }
      return GoogleMapsParseResult(
        kind: .plusCode,
        coordinate: coord,
        title: code,
        needsResolve: false,
        appleMapsURL: makeAppleMapsURL(coordinate: coord, label: code)
      )
    }

    guard isGoogleMapsHost(host), url.path.hasPrefix("/maps") else {
      return nil
    }

    let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let queryItems = comps?.queryItems ?? []
    let path = url.path

    let atCoordinate = extractAtCoordinate(from: path)
    let dataCoordinate = extractDataCoordinate(from: path)
    let pathCoordinate = atCoordinate ?? dataCoordinate

    if path.hasPrefix("/maps/embed") {
      return GoogleMapsParseResult(
        kind: .embed,
        coordinate: nil,
        title: nil,
        needsResolve: false,
        appleMapsURL: nil
      )
    }

    if let mapAction = queryItems.value(for: "map_action") {
      switch mapAction.lowercased() {
      case "pano":
        let viewpoint = queryItems.value(for: "viewpoint").flatMap(parseCoordinatePair)
        return GoogleMapsParseResult(
          kind: .streetView,
          coordinate: viewpoint,
          title: nil,
          needsResolve: false,
          appleMapsURL: makeAppleMapsURL(coordinate: viewpoint, label: nil)
        )
      case "map":
        let center = queryItems.value(for: "center").flatMap(parseCoordinatePair)
        return GoogleMapsParseResult(
          kind: .mapView,
          coordinate: center,
          title: nil,
          needsResolve: false,
          appleMapsURL: makeAppleMapsURL(coordinate: center, label: nil)
        )
      default:
        break
      }
    }

    if path.hasPrefix("/maps/place/") {
      let title = extractFirstPathSegment(after: "/maps/place/", in: path)
      let coord = pathCoordinate
      return GoogleMapsParseResult(
        kind: .place,
        coordinate: coord,
        title: title,
        needsResolve: false,
        appleMapsURL: makeAppleMapsURL(coordinate: coord, label: title)
      )
    }

    if path.hasPrefix("/maps/dir") {
      let destination =
        queryItems.value(for: "destination").flatMap(decodeQueryText)
        ?? extractLastPathSegment(after: "/maps/dir/", in: path)
      let destCoord = destination.flatMap(parseCoordinatePair)
      return GoogleMapsParseResult(
        kind: .directions,
        coordinate: destCoord,
        title: destination,
        needsResolve: false,
        appleMapsURL: makeDirectionsAppleMapsURL(destination: destination, coordinate: destCoord)
      )
    }

    if path.hasPrefix("/maps/search") {
      let query =
        queryItems.value(for: "query").flatMap(decodeQueryText)
        ?? extractFirstPathSegment(after: "/maps/search/", in: path)
      let queryCoord = query.flatMap(parseCoordinatePair)
      return GoogleMapsParseResult(
        kind: queryCoord != nil ? .coordinates : .search,
        coordinate: queryCoord,
        title: query,
        needsResolve: false,
        appleMapsURL: queryCoord != nil
          ? makeAppleMapsURL(coordinate: queryCoord, label: query)
          : query.flatMap(makeSearchAppleMapsURL)
      )
    }

    if path.hasPrefix("/maps/@") {
      return GoogleMapsParseResult(
        kind: .mapView,
        coordinate: pathCoordinate,
        title: nil,
        needsResolve: false,
        appleMapsURL: makeAppleMapsURL(coordinate: pathCoordinate, label: nil)
      )
    }

    if path == "/maps" || path == "/maps/" {
      if let rawQ = queryItems.value(for: "q") {
        if let coord = parseCoordinatePair(rawQ) {
          return GoogleMapsParseResult(
            kind: .coordinates,
            coordinate: coord,
            title: nil,
            needsResolve: false,
            appleMapsURL: makeAppleMapsURL(coordinate: coord, label: nil)
          )
        }
        let q = decodeQueryText(rawQ) ?? rawQ
        return GoogleMapsParseResult(
          kind: .search,
          coordinate: nil,
          title: q,
          needsResolve: false,
          appleMapsURL: makeSearchAppleMapsURL(q)
        )
      }
      if let ll = queryItems.value(for: "ll"),
        let coord = parseCoordinatePair(ll)
      {
        return GoogleMapsParseResult(
          kind: .coordinates,
          coordinate: coord,
          title: nil,
          needsResolve: false,
          appleMapsURL: makeAppleMapsURL(coordinate: coord, label: nil)
        )
      }
    }

    return GoogleMapsParseResult(
      kind: .unknown,
      coordinate: pathCoordinate,
      title: nil,
      needsResolve: false,
      appleMapsURL: makeAppleMapsURL(coordinate: pathCoordinate, label: nil)
    )
  }

  // MARK: - Host detection

  static func isGoogleMapsHost(_ host: String) -> Bool {
    if host == "google.com" || host == "www.google.com" || host == "maps.google.com" {
      return true
    }
    if host.hasPrefix("maps.google.") || host.hasPrefix("www.google.") || host.hasPrefix("google.")
    {
      return true
    }
    return host.hasSuffix(".google.com") && host.hasPrefix("maps.")
  }

  // MARK: - Path / coordinate extraction

  private static let atCoordinateRegex = try! NSRegularExpression(
    pattern: #"/@(-?\d+\.\d+),(-?\d+\.\d+)"#
  )
  private static let dataCoordinateRegex = try! NSRegularExpression(
    pattern: #"!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)"#
  )
  private static let coordinatePairRegex = try! NSRegularExpression(
    pattern: #"^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$"#
  )

  private static func extractAtCoordinate(from path: String) -> CLLocationCoordinate2D? {
    matchCoordinate(in: path, regex: atCoordinateRegex)
  }

  private static func extractDataCoordinate(from path: String) -> CLLocationCoordinate2D? {
    matchCoordinate(in: path, regex: dataCoordinateRegex)
  }

  private static func matchCoordinate(
    in string: String,
    regex: NSRegularExpression
  ) -> CLLocationCoordinate2D? {
    let range = NSRange(string.startIndex..., in: string)
    guard let match = regex.firstMatch(in: string, range: range),
      match.numberOfRanges == 3,
      let latRange = Range(match.range(at: 1), in: string),
      let lngRange = Range(match.range(at: 2), in: string),
      let lat = Double(string[latRange]),
      let lng = Double(string[lngRange]),
      isValidCoordinate(lat: lat, lng: lng)
    else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lng)
  }

  static func parseCoordinatePair(_ value: String) -> CLLocationCoordinate2D? {
    let decoded = value.removingPercentEncoding ?? value
    let range = NSRange(decoded.startIndex..., in: decoded)
    guard let match = coordinatePairRegex.firstMatch(in: decoded, range: range),
      match.numberOfRanges == 3,
      let latRange = Range(match.range(at: 1), in: decoded),
      let lngRange = Range(match.range(at: 2), in: decoded),
      let lat = Double(decoded[latRange]),
      let lng = Double(decoded[lngRange]),
      isValidCoordinate(lat: lat, lng: lng)
    else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lng)
  }

  private static func isValidCoordinate(lat: Double, lng: Double) -> Bool {
    (-90.0...90.0).contains(lat) && (-180.0...180.0).contains(lng)
  }

  private static func extractFirstPathSegment(after prefix: String, in path: String) -> String? {
    guard path.hasPrefix(prefix) else { return nil }
    let tail = String(path.dropFirst(prefix.count))
    let segment = tail.split(separator: "/", maxSplits: 1).first.map(String.init) ?? tail
    return decodePlaceSlug(segment)
  }

  private static func extractLastPathSegment(after prefix: String, in path: String) -> String? {
    guard path.hasPrefix(prefix) else { return nil }
    let tail = String(path.dropFirst(prefix.count))
    let segments = tail.split(separator: "/").map(String.init)
    guard let last = segments.last else { return nil }
    return decodePlaceSlug(last)
  }

  private static func decodePlaceSlug(_ raw: String) -> String? {
    decodeQueryText(raw)
  }

  static func decodeQueryText(_ raw: String) -> String? {
    let withSpaces = raw.replacingOccurrences(of: "+", with: " ")
    let decoded = withSpaces.removingPercentEncoding ?? withSpaces
    let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  // MARK: - Apple Maps URL composition

  static func makeAppleMapsURL(
    coordinate: CLLocationCoordinate2D?,
    label: String?
  ) -> URL? {
    var comps = URLComponents()
    comps.scheme = "http"
    comps.host = "maps.apple.com"
    comps.path = "/"
    var items: [URLQueryItem] = []
    if let coordinate {
      items.append(
        URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)")
      )
    }
    if let label, !label.isEmpty {
      items.append(URLQueryItem(name: "q", value: label))
    }
    guard !items.isEmpty else { return nil }
    comps.queryItems = items
    return comps.url
  }

  static func makeSearchAppleMapsURL(_ query: String) -> URL? {
    var comps = URLComponents()
    comps.scheme = "http"
    comps.host = "maps.apple.com"
    comps.path = "/"
    comps.queryItems = [URLQueryItem(name: "q", value: query)]
    return comps.url
  }

  static func makeDirectionsAppleMapsURL(
    destination: String?,
    coordinate: CLLocationCoordinate2D?
  ) -> URL? {
    var comps = URLComponents()
    comps.scheme = "http"
    comps.host = "maps.apple.com"
    comps.path = "/"
    var items: [URLQueryItem] = [URLQueryItem(name: "dirflg", value: "d")]
    if let coordinate {
      items.append(
        URLQueryItem(name: "daddr", value: "\(coordinate.latitude),\(coordinate.longitude)")
      )
    } else if let destination, !destination.isEmpty {
      items.append(URLQueryItem(name: "daddr", value: destination))
    } else {
      return nil
    }
    comps.queryItems = items
    return comps.url
  }
}

private extension Array where Element == URLQueryItem {
  func value(for name: String) -> String? {
    first(where: { $0.name == name })?.value
  }
}
