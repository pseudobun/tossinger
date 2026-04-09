//
//  tossApp.swift
//  toss
//
//  Created by Urban Vidovič on 7. 10. 25.
//

import SwiftData
import SwiftUI
import TossKit

@main
struct tossApp: App {
  var container: ModelContainer
  @StateObject private var appSettings = AppSettings()
  @StateObject private var updateGate = UpdateGateService()
  #if os(macOS)
    @StateObject private var macGlobalShortcutController = MacGlobalShortcutController()
  #endif
  @Environment(\.scenePhase) private var scenePhase
  private let backfillMigration = TossBackfillMigration()
  private let uuidMigration = TossUUIDMigration()

  init() {
    do {
      container = try TossPersistenceStack.makeContainer()
    } catch {
      fatalError("Failed to configure ModelContainer: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if updateGate.requiresUpdate {
          ForceUpdateView(message: updateGate.updateMessage)
        } else {
          AuthenticationView()
        }
      }
        .environmentObject(appSettings)
        .environmentObject(updateGate)
        .tint(Color.accentColor)  // Apply accent color globally
        .onAppear {
          uuidMigration.startIfNeeded(modelContainer: container)
          backfillMigration.startIfNeeded(modelContainer: container)
          #if os(macOS)
            macGlobalShortcutController.configureIfNeeded(modelContainer: container)
          #endif

          Task(priority: .utility) {
            await TossCreationPipeline.retryPendingMetadata(modelContainer: container)
          }

          Task { await updateGate.checkForRequiredUpdate() }

          // Register for remote notifications on iOS
          #if os(iOS)
            UIApplication.shared.registerForRemoteNotifications()
          #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
          switch newPhase {
          case .active:
            uuidMigration.startIfNeeded(modelContainer: container)
            backfillMigration.startIfNeeded(modelContainer: container)
          case .inactive, .background:
            uuidMigration.cancel()
            backfillMigration.cancel()
          @unknown default:
            break
          }
        }
    }
    .modelContainer(container)
    #if os(macOS)
      .windowToolbarStyle(.unified)
    #endif

    #if os(macOS)
      Settings {
        SettingsView()
          .environmentObject(appSettings)
          .tint(Color.accentColor)  // Apply to Settings window too
      }
    #endif
  }
}
