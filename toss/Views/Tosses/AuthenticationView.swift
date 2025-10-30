//
//  AuthenticationView.swift
//  toss
//
//  Created by Urban Vidovič on 30. 10. 25.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct AuthenticationView: View {
    @StateObject private var biometricManager = BiometricAuthManager()
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked = false
    @State private var shouldShowError = false

    var body: some View {
        Group {
            if !appSettings.isBiometricEnabled || isUnlocked {
                // Show main app content
                ContentView()
            } else {
                // Show authentication screen
                authenticationScreen
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    // MARK: - Authentication Screen

    private var authenticationScreen: some View {
        ZStack {
            // Background color matching app
            #if os(macOS)
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
            #else
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
            #endif

            VStack(spacing: 0) {
                Spacer()

                // Icon and text content
                VStack(spacing: 20) {
                    Image(systemName: biometricManager.biometricIcon)
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 8) {
                        Text("Authentication Required")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(
                            "Use \(biometricManager.biometricTypeString) to access your tosses"
                        )
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Bottom section with button and error
                VStack(spacing: 16) {
                    Button(action: {
                        shouldShowError = true
                        authenticateUser()
                    }) {
                        Label(
                            "Authenticate with \(biometricManager.biometricTypeString)",
                            systemImage: biometricManager.biometricIcon
                        )
                        .frame(maxWidth: platformMaxWidth)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    // Error message
                    if shouldShowError,
                        let error = biometricManager.authenticationError
                    {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        #if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
        #endif
        .onAppear {
            shouldShowError = false
            authenticateUser()
        }
    }

    // MARK: - Helpers

    private var platformMaxWidth: CGFloat? {
        #if os(macOS)
            return 300
        #else
            return .infinity
        #endif
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard appSettings.isBiometricEnabled else { return }

        switch newPhase {
        case .inactive:
            isUnlocked = false
            biometricManager.logout()
            shouldShowError = false

        case .background:
            isUnlocked = false
            biometricManager.logout()
            shouldShowError = false

        case .active:
            if !isUnlocked {
                shouldShowError = false
                authenticateUser()
            }

        @unknown default:
            break
        }
    }

    private func authenticateUser() {
        Task {
            await biometricManager.authenticateUser()
            if biometricManager.isAuthenticated {
                isUnlocked = true
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AppSettings())
}
