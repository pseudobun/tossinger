//
//  AppSettings.swift
//  toss
//
//  Created by Urban Vidovič on 30. 10. 25.
//

import Foundation
import SwiftUI
import TossKit

@MainActor
class AppSettings: ObservableObject {
  // Shared with the iOS share extension via the app group so both processes
  // see the same value for `autoOpenAfterSharing`. Existing single-process
  // preferences below continue to live in UserDefaults.standard so they
  // aren't wiped on upgrade.
  static let sharedDefaults = UserDefaults(suiteName: TossPersistenceStack.appGroupIdentifier)!

  @AppStorage("biometric_enabled") var isBiometricEnabled: Bool = false

  @AppStorage("layout_mode") private var layoutModeRaw: String = TossLayoutMode.grid.rawValue

  var layoutMode: TossLayoutMode {
    get { TossLayoutMode(rawValue: layoutModeRaw) ?? .grid }
    set { layoutModeRaw = newValue.rawValue }
  }

  @AppStorage("auto_open_after_share", store: AppSettings.sharedDefaults)
  var autoOpenAfterSharing: Bool = false
}
