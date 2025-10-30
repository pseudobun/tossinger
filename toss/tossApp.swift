//
//  tossApp.swift
//  toss
//
//  Created by Urban Vidovič on 7. 10. 25.
//

import SwiftData
import SwiftUI

@main
struct tossApp: App {
    var container: ModelContainer
    @StateObject private var appSettings = AppSettings()

    init() {
        do {
            let schema = Schema([Toss.self])

            // Get the shared container URL
            guard
                let containerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier:
                        "group.lutra-labs.toss"
                )
            else {
                fatalError("Shared container not found")
            }

            let storeURL = containerURL.appendingPathComponent("default.store")

            let configuration = ModelConfiguration(
                url: storeURL,
                cloudKitDatabase: .private("iCloud.lutra-labs.toss")
            )

            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to configure ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationView()
                .environmentObject(appSettings)
                .tint(Color.accentColor)  // Apply accent color globally
                .onAppear {
                    // Register for remote notifications on iOS
                    #if os(iOS)
                        UIApplication.shared.registerForRemoteNotifications()
                    #endif
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
