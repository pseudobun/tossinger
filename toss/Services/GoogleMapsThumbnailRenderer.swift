//
//  GoogleMapsThumbnailRenderer.swift
//  toss
//
//  Generates a static map thumbnail centered on a coordinate using
//  `MKMapSnapshotter`. No API keys, no network beyond Apple's own tile
//  fetch. Draws a single SF Symbol pin at the snapshot's center.
//

import CoreLocation
import Foundation
import MapKit

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

@MainActor
enum GoogleMapsThumbnailRenderer {
  private static let outputSize = CGSize(width: 640, height: 400)
  private static let regionSpanMeters: CLLocationDistance = 500

  static func render(coordinate: CLLocationCoordinate2D) async -> Data? {
    let options = MKMapSnapshotter.Options()
    options.region = MKCoordinateRegion(
      center: coordinate,
      latitudinalMeters: regionSpanMeters,
      longitudinalMeters: regionSpanMeters
    )
    options.size = outputSize
    options.showsBuildings = true
    options.pointOfInterestFilter = .includingAll

    let snapshotter = MKMapSnapshotter(options: options)
    let snapshot: MKMapSnapshotter.Snapshot
    do {
      snapshot = try await snapshotter.start()
    } catch {
      return nil
    }

    return drawPin(on: snapshot, at: coordinate)
  }

  #if os(macOS)
    private static func drawPin(
      on snapshot: MKMapSnapshotter.Snapshot,
      at coordinate: CLLocationCoordinate2D
    ) -> Data? {
      let size = snapshot.image.size
      let pixelWidth = Int(size.width.rounded())
      let pixelHeight = Int(size.height.rounded())

      guard
        let rep = NSBitmapImageRep(
          bitmapDataPlanes: nil,
          pixelsWide: pixelWidth,
          pixelsHigh: pixelHeight,
          bitsPerSample: 8,
          samplesPerPixel: 4,
          hasAlpha: true,
          isPlanar: false,
          colorSpaceName: .deviceRGB,
          bytesPerRow: 0,
          bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: rep)
      else {
        return nil
      }

      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = context

      snapshot.image.draw(
        in: NSRect(origin: .zero, size: size),
        from: .zero,
        operation: .copy,
        fraction: 1.0
      )

      let point = snapshot.point(for: coordinate)
      let pinSize: CGFloat = 40
      let pinRect = NSRect(
        x: point.x - pinSize / 2,
        y: size.height - point.y - pinSize / 2,
        width: pinSize,
        height: pinSize
      )

      if let pin = NSImage(
        systemSymbolName: "mappin.circle.fill",
        accessibilityDescription: nil
      ) {
        let config = NSImage.SymbolConfiguration(
          pointSize: pinSize,
          weight: .bold
        ).applying(.init(paletteColors: [.white, .systemRed]))
        let configured = pin.withSymbolConfiguration(config) ?? pin
        configured.draw(
          in: pinRect,
          from: .zero,
          operation: .sourceOver,
          fraction: 1.0
        )
      }

      NSGraphicsContext.restoreGraphicsState()

      return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }
  #else
    private static func drawPin(
      on snapshot: MKMapSnapshotter.Snapshot,
      at coordinate: CLLocationCoordinate2D
    ) -> Data? {
      let format = UIGraphicsImageRendererFormat()
      format.scale = snapshot.image.scale
      let renderer = UIGraphicsImageRenderer(size: snapshot.image.size, format: format)
      let composed = renderer.image { _ in
        snapshot.image.draw(at: .zero)

        let point = snapshot.point(for: coordinate)
        let pinSize: CGFloat = 32
        let pinRect = CGRect(
          x: point.x - pinSize / 2,
          y: point.y - pinSize,
          width: pinSize,
          height: pinSize
        )

        let symbolConfig = UIImage.SymbolConfiguration(
          pointSize: pinSize,
          weight: .bold
        )
        let paletteConfig = UIImage.SymbolConfiguration(
          paletteColors: [.white, .systemRed]
        )
        if let pin = UIImage(
          systemName: "mappin.circle.fill",
          withConfiguration: symbolConfig.applying(paletteConfig)
        ) {
          pin.draw(in: pinRect)
        }
      }
      return composed.jpegData(compressionQuality: 0.9)
    }
  #endif
}
