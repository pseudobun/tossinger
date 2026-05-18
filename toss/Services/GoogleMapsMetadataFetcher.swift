//
//  GoogleMapsMetadataFetcher.swift
//  toss
//
//  Orchestrates: parse → optional short-link resolve → optional geocode →
//  MKMapSnapshotter thumbnail → composed title/description. Returns a flat
//  struct mirroring the YouTube/Twitter/Generic fetchers so
//  `MetadataCoordinator` can wrap it in a `MetadataResult`.
//

import CoreLocation
import Foundation
import os

struct GoogleMapsMetadata {
  let imageData: Data?
  let title: String?
  let description: String?
  let didSucceed: Bool
}

enum GoogleMapsMetadataFetcher {
  private static let geocodeTimeout: TimeInterval = 3
  private static let logger = Logger(subsystem: "lutra-labs.toss", category: "gmaps")

  static func fetchMetadata(url: URL, timeout: TimeInterval = 8) async -> GoogleMapsMetadata {
    logger.debug("fetch start \(url.absoluteString, privacy: .public)")

    guard var parsed = GoogleMapsURLParser.parse(url) else {
      logger.debug("parse returned nil for input url")
      return failure()
    }
    logger.debug(
      "parsed kind=\(String(describing: parsed.kind), privacy: .public) needsResolve=\(parsed.needsResolve, privacy: .public)"
    )

    if parsed.needsResolve {
      guard let resolved = await GoogleMapsShortLinkResolver.resolve(url, timeout: timeout) else {
        logger.debug("resolve failed")
        return failure()
      }
      guard let reparsed = GoogleMapsURLParser.parse(resolved) else {
        logger.debug(
          "reparse failed for \(resolved.absoluteString, privacy: .public)"
        )
        return failure()
      }
      parsed = reparsed
      logger.debug(
        "reparsed kind=\(String(describing: parsed.kind), privacy: .public) coord=\(parsed.coordinate.map { "\($0.latitude),\($0.longitude)" } ?? "nil", privacy: .public)"
      )
    }

    switch parsed.kind {
    case .streetView, .embed:
      logger.debug("skipping kind=\(String(describing: parsed.kind), privacy: .public)")
      return failure()
    case .unknown where parsed.coordinate == nil:
      logger.debug("unknown kind with no coord")
      return failure()
    default:
      break
    }

    var coordinate = parsed.coordinate
    var resolvedName = parsed.title

    if coordinate == nil, let queryText = parsed.title {
      if let forward = await forwardGeocode(queryText) {
        coordinate = forward.coordinate
        if resolvedName == nil || isLikelyAddress(resolvedName) {
          resolvedName = placemarkName(forward) ?? resolvedName
        }
        logger.debug("forward geocode ok")
      } else {
        logger.debug("forward geocode failed")
      }
    }

    var locality: String?
    if let coord = coordinate, resolvedName == nil {
      if let placemark = await reverseGeocode(coord) {
        resolvedName = placemarkName(placemark)
        locality = placemarkLocality(placemark)
        logger.debug("reverse geocode ok (name+locality)")
      } else {
        logger.debug("reverse geocode failed")
      }
    } else if let coord = coordinate {
      if let placemark = await reverseGeocode(coord) {
        locality = placemarkLocality(placemark)
        logger.debug("reverse geocode ok (locality only)")
      }
    }

    var imageData: Data?
    if let coord = coordinate {
      imageData = await GoogleMapsThumbnailRenderer.render(coordinate: coord)
      logger.debug(
        "snapshot \(imageData == nil ? "FAILED" : "ok", privacy: .public) size=\(imageData?.count ?? 0, privacy: .public)"
      )
    }

    let (title, description) = composeDisplayStrings(
      kind: parsed.kind,
      resolvedName: resolvedName,
      coordinate: coordinate,
      locality: locality
    )

    let didSucceed = imageData != nil || title != nil
    logger.debug(
      "fetch done didSucceed=\(didSucceed, privacy: .public) title=\(title ?? "nil", privacy: .public)"
    )
    return GoogleMapsMetadata(
      imageData: imageData,
      title: title,
      description: description,
      didSucceed: didSucceed
    )
  }

  // MARK: - Display string composition

  private static func composeDisplayStrings(
    kind: GoogleMapsParseResult.Kind,
    resolvedName: String?,
    coordinate: CLLocationCoordinate2D?,
    locality: String?
  ) -> (String?, String?) {
    switch kind {
    case .directions:
      let destination = resolvedName ?? coordinate.map(formatCoordinate)
      let title = destination.map { "Directions to \($0)" }
      return (title, locality)

    case .search where coordinate == nil:
      let title = resolvedName.map { "Search: \($0)" }
      return (title, nil)

    case .place, .mapView, .coordinates, .plusCode, .search, .unknown, .streetView, .embed:
      let title = resolvedName ?? coordinate.map { "Pin at \(formatCoordinate($0))" }
      return (title, locality)
    }
  }

  private static func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
    String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
  }

  // MARK: - Geocoding

  private static func reverseGeocode(_ coord: CLLocationCoordinate2D) async -> CLPlacemark? {
    let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
    return await withTimeout(seconds: geocodeTimeout) {
      let geocoder = CLGeocoder()
      let placemarks = try? await geocoder.reverseGeocodeLocation(location)
      return placemarks?.first
    }
  }

  private static func forwardGeocode(_ text: String) async -> CLPlacemark? {
    await withTimeout(seconds: geocodeTimeout) {
      let geocoder = CLGeocoder()
      let placemarks = try? await geocoder.geocodeAddressString(text)
      return placemarks?.first
    }
  }

  private static func placemarkName(_ placemark: CLPlacemark) -> String? {
    if let name = placemark.name, !name.isEmpty {
      return name
    }
    if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
      if let subThoroughfare = placemark.subThoroughfare, !subThoroughfare.isEmpty {
        return "\(subThoroughfare) \(thoroughfare)"
      }
      return thoroughfare
    }
    return placemark.locality
  }

  private static func placemarkLocality(_ placemark: CLPlacemark) -> String? {
    let parts = [placemark.locality, placemark.administrativeArea, placemark.country]
      .compactMap { $0 }
      .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }

  private static func isLikelyAddress(_ text: String?) -> Bool {
    guard let text else { return false }
    return text.contains(",") || text.rangeOfCharacter(from: .decimalDigits) != nil
  }

  private static func failure() -> GoogleMapsMetadata {
    GoogleMapsMetadata(imageData: nil, title: nil, description: nil, didSucceed: false)
  }
}

private extension CLPlacemark {
  var coordinate: CLLocationCoordinate2D {
    location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
  }
}

private func withTimeout<T>(
  seconds: TimeInterval,
  operation: @escaping @Sendable () async -> T?
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
