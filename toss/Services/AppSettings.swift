//
//  AppSettings.swift
//  toss
//
//  Created by Urban Vidovič on 30. 10. 25.
//

import Foundation
import SwiftUI

@MainActor
class AppSettings: ObservableObject {
  @AppStorage("biometric_enabled") var isBiometricEnabled: Bool = false
}
