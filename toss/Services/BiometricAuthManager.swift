//
//  BiometricAuthManager.swift
//  toss
//
//  Created by Urban Vidovič on 30. 10. 25.
//

import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
class BiometricAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var biometricType: LABiometryType = .none
    @Published var authenticationError: String?

    init() {
        getBiometricType()
    }

    func getBiometricType() {
        // Create a temporary context just to check biometric type
        let context = LAContext()
        let _ = context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: nil
        )
        biometricType = context.biometryType
    }

    func isBiometricAvailable() -> Bool {
        // Create a temporary context to check availability
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func authenticateUser() async {
        // Create a fresh context for each authentication attempt
        // This ensures biometric prompt appears every time
        let context = LAContext()
        let reason = "Authenticate to access your tosses"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            if success {
                isAuthenticated = true
                authenticationError = nil
            }

            // Invalidate the context after use (good practice)
            context.invalidate()
        } catch let error as LAError {
            // Handle specific LAError cases for better user feedback
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                authenticationError = "Authentication cancelled"
            case .userFallback:
                authenticationError = "User chose to enter password"
            case .biometryNotAvailable:
                authenticationError = "Biometric authentication not available"
            case .biometryNotEnrolled:
                authenticationError = "No biometric data enrolled"
            case .biometryLockout:
                authenticationError =
                    "Too many failed attempts. Please try again later."
            default:
                authenticationError = error.localizedDescription
            }
            isAuthenticated = false
        } catch {
            authenticationError = error.localizedDescription
            isAuthenticated = false
        }
    }

    func logout() {
        isAuthenticated = false
        authenticationError = nil
    }

    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Biometric Authentication"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "lock.shield"
        }
    }
}
