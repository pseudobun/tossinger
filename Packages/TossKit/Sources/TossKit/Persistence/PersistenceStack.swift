//
//  PersistenceStack.swift
//  TossKit
//
//  Single source of truth for the SwiftData + CloudKit container used by
//  every Tossinger target (app, share extension, CLI). Extracted from the
//  duplicated setup that previously lived in `tossApp.swift` and
//  `ShareViewController.swift`.
//

import Foundation
import SwiftData

public enum TossPersistenceStack {
  public static let appGroupIdentifier = "group.lutra-labs.toss"
  public static let cloudKitContainerIdentifier = "iCloud.lutra-labs.toss"
  public static let storeFilename = "default.store"

  public enum StackError: Error, CustomStringConvertible {
    case appGroupContainerUnavailable

    public var description: String {
      switch self {
      case .appGroupContainerUnavailable:
        return
          "Shared app group container '\(TossPersistenceStack.appGroupIdentifier)' is unavailable. "
          + "Confirm the calling target is signed with the App Groups entitlement."
      }
    }
  }

  /// Builds the shared `ModelContainer`. Call once per process and reuse.
  public static func makeContainer() throws -> ModelContainer {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      )
    else {
      throw StackError.appGroupContainerUnavailable
    }

    let storeURL = containerURL.appendingPathComponent(storeFilename)
    let configuration = ModelConfiguration(
      url: storeURL,
      cloudKitDatabase: .private(cloudKitContainerIdentifier)
    )

    return try ModelContainer(
      for: Schema([Toss.self]),
      configurations: [configuration]
    )
  }
}
