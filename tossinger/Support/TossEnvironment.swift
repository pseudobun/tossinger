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
  static func repository() throws -> TossRepository {
    let container = try TossPersistenceStack.makeContainer()
    return TossRepository(container: container)
  }
}
