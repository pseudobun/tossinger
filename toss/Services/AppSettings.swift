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
  @AppStorage("biometric_enabled") var isBiometricEnabled: Bool = false

  @AppStorage("layout_mode") private var layoutModeRaw: String = TossLayoutMode.grid.rawValue

  var layoutMode: TossLayoutMode {
    get { TossLayoutMode(rawValue: layoutModeRaw) ?? .grid }
    set { layoutModeRaw = newValue.rawValue }
  }
}
