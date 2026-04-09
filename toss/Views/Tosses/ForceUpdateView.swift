//
//  ForceUpdateView.swift
//  toss
//
//  Blocking screen shown when UpdateGateService decides the installed build
//  is too old. iOS deep-links to the App Store; macOS surfaces the brew
//  upgrade command (the cask is the canonical macOS distribution channel).
//

import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

struct ForceUpdateView: View {
  let message: String

  #if os(macOS)
    @State private var didCopyCommand = false
  #endif

  private static let brewCommand = "brew upgrade --cask tossinger"
  private static let releasesURL = URL(
    string: "https://github.com/pseudobun/tossinger/releases/latest"
  )!
  #if os(iOS)
    private static let appStoreURL = URL(string: "https://apps.apple.com/app/id6754607504")!
  #endif

  var body: some View {
    ZStack {
      #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
          .ignoresSafeArea()
      #else
        Color(uiColor: .systemBackground)
          .ignoresSafeArea()
      #endif

      VStack(spacing: 0) {
        Spacer()

        VStack(spacing: 20) {
          Image(systemName: "arrow.down.circle.fill")
            .font(.system(size: 64))
            .foregroundStyle(.blue)
            .symbolRenderingMode(.hierarchical)

          VStack(spacing: 8) {
            Text("Update Required")
              .font(.title2)
              .fontWeight(.semibold)

            Text(message)
              .font(.body)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(.horizontal, 32)

        Spacer()

        actionSection
          .padding(.horizontal, 32)
          .padding(.bottom, 32)
      }
    }
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 360)
    #endif
    #if os(iOS)
      .interactiveDismissDisabled(true)
    #endif
  }

  // MARK: - Action section

  @ViewBuilder
  private var actionSection: some View {
    #if os(iOS)
      Button {
        UIApplication.shared.open(Self.appStoreURL)
      } label: {
        Label("Update Now", systemImage: "arrow.down.circle.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    #else
      VStack(spacing: 16) {
        Text(Self.brewCommand)
          .font(.system(.callout, design: .monospaced))
          .textSelection(.enabled)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color(nsColor: .textBackgroundColor))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
          )

        Button {
          copyCommand()
        } label: {
          Label(
            didCopyCommand ? "Copied!" : "Copy update command",
            systemImage: didCopyCommand ? "checkmark.circle.fill" : "doc.on.doc"
          )
          .frame(maxWidth: 300)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Button {
          NSWorkspace.shared.open(Self.releasesURL)
        } label: {
          Label("Download from GitHub", systemImage: "arrow.down.circle")
            .frame(maxWidth: 300)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
      }
    #endif
  }

  #if os(macOS)
    private func copyCommand() {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(Self.brewCommand, forType: .string)
      didCopyCommand = true
      Task {
        try? await Task.sleep(for: .seconds(2))
        await MainActor.run { didCopyCommand = false }
      }
    }
  #endif
}

#Preview {
  ForceUpdateView(
    message: "A required update is available. Please update Tossinger to continue."
  )
}
