//
//  ContentView.swift
//  toss
//
//  Created by Urban Vidovič on 8. 10. 25.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    #if os(iOS)
      TabView {
        Tab("Tosses", systemImage: "note.text") {
          TossesView()
        }

        Tab("Settings", systemImage: "gear") {
          SettingsView()
        }
      }
    #else
      macOSNavigationView
    #endif
  }

  #if os(macOS)
    private var macOSNavigationView: some View {
      NavigationSplitView {
        List(NavigationItem.allCases, selection: $selectedItem) {
          item in
          NavigationLink(value: item) {
            Label(item.title, systemImage: item.icon)
          }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
      } detail: {
        Group {
          if let selectedItem = selectedItem {
            switch selectedItem {
            case .tosses:
              TossesView()
            case .settings:
              SettingsView()
            }
          } else {
            Text("Select an item")
              .foregroundStyle(.secondary)
          }
        }
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Spacer()
          }
        }
      }
      .navigationSplitViewStyle(.balanced)
    }

    @State private var selectedItem: NavigationItem? = .tosses

    enum NavigationItem: String, CaseIterable, Identifiable, Hashable {
      case tosses = "Tosses"
      case settings = "Settings"

      var id: String { rawValue }

      var title: String { rawValue }

      var icon: String {
        switch self {
        case .tosses: return "note.text"
        case .settings: return "gear"
        }
      }
    }
  #endif
}

#Preview {
  ContentView()
}
