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

  /// Selects how the resulting `ModelContainer` participates in CloudKit.
  /// The app and share extension want full sync; the CLI wants to opt out
  /// because instantiating `NSPersistentCloudKitContainer` from a
  /// sub-bundled `.app` helper triggers a PushKit assertion at dealloc.
  public enum CloudKitMode {
    /// Wires the store to the private CloudKit database. Used by the
    /// app and share extension — they own sync.
    case automatic
    /// Disables CloudKit entirely for this process. The CLI uses this
    /// so `NSPersistentCloudKitContainer` never spins up `PKPushRegistry`,
    /// which would otherwise SIGABRT during dealloc inside the
    /// `Tossinger.app/Contents/Helpers/toss.app` helper bundle.
    case disabled
  }

  /// Builds the shared `ModelContainer`. Call once per process and reuse.
  /// The default mode (`.automatic`) keeps the existing app + share
  /// extension behavior; the CLI passes `.disabled`.
  public static func makeContainer(cloudKit: CloudKitMode = .automatic) throws -> ModelContainer {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      )
    else {
      throw StackError.appGroupContainerUnavailable
    }

    let storeURL = containerURL.appendingPathComponent(storeFilename)
    let cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    switch cloudKit {
    case .automatic:
      cloudKitDatabase = .private(cloudKitContainerIdentifier)
    case .disabled:
      cloudKitDatabase = .none
    }
    let configuration = ModelConfiguration(
      url: storeURL,
      cloudKitDatabase: cloudKitDatabase
    )

    return try ModelContainer(
      for: Schema([Toss.self]),
      configurations: [configuration]
    )
  }
}
