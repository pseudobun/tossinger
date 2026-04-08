//
//  SettingsView.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
//

import SwiftData
import SwiftUI
#if os(macOS)
  import AppKit
  import KeyboardShortcuts
#endif

struct SettingsView: View {
  @EnvironmentObject var appSettings: AppSettings
  @StateObject private var biometricManager = BiometricAuthManager()
  #if os(macOS)
    @State private var hasAccessibilityPermission = AccessibilityPermissionManager.isTrusted()
  #endif

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
        VStack(spacing: 0) {
          Form {
            Section {
              Toggle(isOn: $appSettings.isBiometricEnabled) {
                HStack(spacing: 12) {
                  Image(
                    systemName: biometricManager
                      .biometricIcon
                  )
                  .foregroundStyle(.blue)
                  .font(.title3)
                  .frame(width: 24)

                  VStack(alignment: .leading, spacing: 2) {
                    Text(
                      "Require \(biometricManager.biometricTypeString)"
                    )
                    .font(.body)

                    if !biometricManager
                      .isBiometricAvailable()
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
              KeyboardShortcuts.Recorder(
                "Add selected text to toss",
                name: .addSelectedTextToToss
              )

              VStack(alignment: .leading, spacing: 4) {
                Text("Default: Hyper + T")
                Text("Works while Tossinger is running.")
                Text("Grant Accessibility permission so Tossinger can read selected text in other apps.")
              }
              .font(.caption)
              .foregroundStyle(.secondary)

              HStack(spacing: 8) {
                Circle()
                  .fill(hasAccessibilityPermission ? Color.green : Color.orange)
                  .frame(width: 8, height: 8)

                Text(hasAccessibilityPermission ? "Accessibility permission granted" : "Accessibility permission required")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Button(hasAccessibilityPermission ? "Permission Granted" : "Request Accessibility Permission") {
                requestAccessibilityPermission()
              }
              .disabled(hasAccessibilityPermission)

              Button("Open Accessibility Settings") {
                openAccessibilitySettings()
              }
              .buttonStyle(.link)
            } header: {
              Text("Global Shortcut (Experimental)")
            }

            Section {
              LabeledContent("Version", value: appVersion)
              LabeledContent("Build", value: buildNumber)
            } header: {
              Text("About")
            }
          }
          .formStyle(.grouped)

          // Developer footer
          VStack(spacing: 16) {
            Divider()
              .padding(.horizontal)

            VStack(spacing: 12) {
              Text("Made with ❤️ by")
                .font(.caption)
                .foregroundStyle(.secondary)

              Text("pseudobun")
                .font(.headline)

              HStack(spacing: 20) {
                Link(
                  destination: URL(
                    string: "https://pseudobun.dev"
                  )!
                ) {
                  Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("Website")

                Link(
                  destination: URL(
                    string: "https://github.com/pseudobun"
                  )!
                ) {
                  Image("github-mark")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("GitHub")

                Link(
                  destination: URL(
                    string: "https://x.com/pseudourban"
                  )!
                ) {
                  Image("x-logo")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("X (Twitter)")

                Link(
                  destination: URL(
                    string: "mailto:urbanfoundit@gmail.com"
                  )!
                ) {
                  Image(systemName: "envelope")
                    .font(.title3)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("Email")
              }

              Divider()
                .padding(.horizontal, 40)
                .padding(.top, 4)

              Link(
                destination: URL(
                  string:
                    "https://github.com/pseudobun/tossinger"
                )!
              ) {
                HStack(spacing: 6) {
                  Image(
                    systemName:
                      "chevron.left.forwardslash.chevron.right"
                  )
                  .font(.caption)
                  Text(
                    "Tossinger is and will remain open source"
                  )
                  .font(.caption)
                }
                .foregroundStyle(.secondary)
              }
              .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
          }
          .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity,
        alignment: .topLeading
      )
      .onAppear {
        refreshAccessibilityPermissionStatus()
      }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
        refreshAccessibilityPermissionStatus()
      }
    }

    private func refreshAccessibilityPermissionStatus() {
      hasAccessibilityPermission = AccessibilityPermissionManager.isTrusted()
    }

    private func requestAccessibilityPermission() {
      _ = AccessibilityPermissionManager.requestSystemPrompt()
      refreshAccessibilityPermissionStatus()
    }

    private func openAccessibilitySettings() {
      guard
        let url = URL(
          string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
      else {
        return
      }

      NSWorkspace.shared.open(url)
    }
  #endif

  // MARK: - iOS Settings
  #if os(iOS)
    private var iOSSettingsView: some View {
      NavigationStack {
        Form {
          securitySection
          aboutSection

          Section {
            VStack(spacing: 12) {
              Text("Made with ❤️ by")
                .font(.caption)
                .foregroundStyle(.secondary)

              Text("pseudobun")
                .font(.headline)

              HStack(spacing: 24) {
                Link(
                  destination: URL(
                    string: "https://pseudobun.dev"
                  )!
                ) {
                  Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Link(
                  destination: URL(
                    string: "https://github.com/pseudobun"
                  )!
                ) {
                  Image("github-mark")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Link(
                  destination: URL(
                    string: "https://x.com/pseudourban"
                  )!
                ) {
                  Image("x-logo")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Link(
                  destination: URL(
                    string: "mailto:urbanfoundit@gmail.com"
                  )!
                ) {
                  Image(systemName: "envelope")
                    .font(.title3)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
              }

              Divider()
                .padding(.horizontal, 40)
                .padding(.top, 4)

              Link(
                destination: URL(
                  string:
                    "https://github.com/pseudobun/tossinger"
                )!
              ) {
                HStack(spacing: 6) {
                  Image(
                    systemName:
                      "chevron.left.forwardslash.chevron.right"
                  )
                  .font(.caption)
                  Text(
                    "Tossinger is and will remain open source"
                  )
                  .font(.caption)
                }
                .foregroundStyle(.secondary)
              }
              .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
          }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
      }
    }
  #endif

  // MARK: - Shared Sections

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
