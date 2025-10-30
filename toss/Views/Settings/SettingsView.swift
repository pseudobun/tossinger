//
//  SettingsView.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var biometricManager = BiometricAuthManager()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        #if os(macOS)
            macOSSettingsView
        #else
            iOSSettingsView
        #endif
    }

    // MARK: - macOS Settings
    #if os(macOS)
        private var macOSSettingsView: some View {
            ScrollView {
                Form {
                    Section {
                        Toggle(isOn: $appSettings.isBiometricEnabled) {
                            HStack(spacing: 12) {
                                Image(
                                    systemName: biometricManager.biometricIcon
                                )
                                .foregroundStyle(.blue)
                                .font(.title3)
                                .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(
                                        "Require \(biometricManager.biometricTypeString)"
                                    )
                                    .font(.body)

                                    if !biometricManager.isBiometricAvailable()
                                    {
                                        Text("Not available on this device")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .disabled(!biometricManager.isBiometricAvailable())
                    } header: {
                        Text("Security")
                    } footer: {
                        if appSettings.isBiometricEnabled {
                            Text(
                                "You'll need to authenticate with \(biometricManager.biometricTypeString) each time you open the app."
                            )
                        } else {
                            Text(
                                "Enable \(biometricManager.biometricTypeString) to secure your tosses."
                            )
                        }
                    }

                    Section {
                        LabeledContent("Version", value: appVersion)
                        LabeledContent("Build", value: buildNumber)
                    } header: {
                        Text("About")
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
    #endif

    // MARK: - iOS Settings
    #if os(iOS)
        private var iOSSettingsView: some View {
            NavigationStack {
                Form {
                    securitySection
                    aboutSection
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    #endif

    // MARK: - Shared Sections (for iOS)

    private var securitySection: some View {
        Section {
            Toggle(isOn: $appSettings.isBiometricEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: biometricManager.biometricIcon)
                        .foregroundStyle(.blue)
                        .font(.title3)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Require \(biometricManager.biometricTypeString)")
                            .font(.body)

                        if !biometricManager.isBiometricAvailable() {
                            Text("Not available on this device")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .disabled(!biometricManager.isBiometricAvailable())
        } header: {
            Text("Security")
        } footer: {
            if appSettings.isBiometricEnabled {
                Text(
                    "You'll need to authenticate with \(biometricManager.biometricTypeString) each time you open the app."
                )
            } else {
                Text(
                    "Enable \(biometricManager.biometricTypeString) to secure your tosses."
                )
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Build") {
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
