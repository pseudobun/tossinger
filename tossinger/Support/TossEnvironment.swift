//
//  TossEnvironment.swift
//  tossinger
//
//  Per-process bootstrap. Each CLI invocation is a separate process, so
//  building a fresh container per command is fine — it's the same pattern
//  the share extension uses.
//

import Foundation
import SwiftData
import TossKit

enum TossEnvironment {
  /// Builds a `TossRepository` backed by a fresh `ModelContext` over the
  /// shared SwiftData store. Throws `TossPersistenceStack.StackError` if
  /// the app group container is missing (i.e., the binary is not signed
  /// with the App Groups entitlement).
  ///
  /// CloudKit is explicitly disabled for the CLI for two reasons:
  ///   1. A one-shot CLI invocation has no time to await async push
  ///      delivery anyway — the main app owns sync.
  ///   2. Instantiating `NSPersistentCloudKitContainer` from a
  ///      sub-bundled `.app` helper triggers a `PKPushRegistry` assertion
  ///      ("Invalid parameter not satisfying: bundleIdentifier") during
  ///      dealloc, SIGABRTing the CLI at process exit. Opting out via
  ///      `.disabled` skips that code path entirely.
  static func repository() throws -> TossRepository {
    let container = try TossPersistenceStack.makeContainer(cloudKit: .disabled)
    return TossRepository(container: container)
  }
}
