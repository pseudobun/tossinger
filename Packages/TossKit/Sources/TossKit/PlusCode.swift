//
//  PlusCode.swift
//  TossKit
//
//  Minimal Open Location Code decoder for full global codes
//  (8 chars + "+" + 2-7 grid chars). Short, locality-referenced codes are
//  out of scope. Spec: https://github.com/google/open-location-code
//

import CoreLocation
import Foundation

public enum PlusCode {
  private static let alphabet: [Character] = Array("23456789CFGHJMPQRVWX")
  private static let pairCodeLength = 10
  private static let separatorPosition = 8
  private static let gridRows = 5
  private static let gridCols = 4
  private static let maxDigits = 15
  private static let latMax = 90.0
  private static let lngMax = 180.0

  /// Decodes a full Open Location Code into a coordinate at the center of the
  /// referenced cell. Returns nil for short codes, padded codes, or malformed
  /// input.
  public static func decode(_ raw: String) -> CLLocationCoordinate2D? {
    let upper = raw.uppercased()
    guard let sepIdx = upper.firstIndex(of: "+") else { return nil }
    let prefix = upper[..<sepIdx]
    guard prefix.count == separatorPosition else { return nil }
    guard !prefix.contains("0") else { return nil }

    let suffix = upper[upper.index(after: sepIdx)...]
    let digits = Array(prefix + suffix)
    guard digits.count >= pairCodeLength, digits.count <= maxDigits else {
      return nil
    }
    for ch in digits {
      guard alphabet.contains(ch) else { return nil }
    }

    var lat = -latMax
    var lng = -lngMax
    var pairPrecision = 20.0

    for i in stride(from: 0, to: pairCodeLength, by: 2) {
      let latDigit = alphabet.firstIndex(of: digits[i])!
      let lngDigit = alphabet.firstIndex(of: digits[i + 1])!
      lat += Double(latDigit) * pairPrecision
      lng += Double(lngDigit) * pairPrecision
      if i + 2 < pairCodeLength {
        pairPrecision /= 20.0
      }
    }

    var latCellSize = pairPrecision
    var lngCellSize = pairPrecision

    let gridLen = digits.count - pairCodeLength
    if gridLen > 0 {
      var latStep = latCellSize / Double(gridRows)
      var lngStep = lngCellSize / Double(gridCols)
      for i in pairCodeLength..<digits.count {
        let digit = alphabet.firstIndex(of: digits[i])!
        let row = digit / gridCols
        let col = digit % gridCols
        lat += Double(row) * latStep
        lng += Double(col) * lngStep
        if i + 1 < digits.count {
          latStep /= Double(gridRows)
          lngStep /= Double(gridCols)
        }
      }
      latCellSize = latStep
      lngCellSize = lngStep
    }

    let centerLat = lat + latCellSize / 2.0
    let centerLng = lng + lngCellSize / 2.0
    guard (-latMax...latMax).contains(centerLat),
      (-lngMax...lngMax).contains(centerLng)
    else { return nil }

    return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
  }
}
