//
//  UpdateGateService.swift
//  toss
//
//  Fetches a remote JSON config on launch and decides whether the installed
//  build is too old to keep running. Toggle is flipped by editing
//  config/update-gate.json on main — no app release needed to enforce.
//
//  Fail-open by design: any network or decoding failure leaves the gate
//  closed so a broken config can never lock users out.
//

import Foundation

private struct UpdateGateConfig: Decodable {
  let minimumRequiredVersion: String
  let isForceUpdateEnabled: Bool
  let updateMessage: String
}

@MainActor
final class UpdateGateService: ObservableObject {
  @Published private(set) var requiresUpdate = false
  @Published private(set) var updateMessage = ""

  private let configURL = URL(
    string: "https://raw.githubusercontent.com/pseudobun/tossinger/main/config/update-gate.json"
  )!

  func checkForRequiredUpdate() async {
    // Local override short-circuits the network entirely so the screen can be
    // exercised without touching the remote config:
    //   defaults write lutra-labs.toss ForceUpdateOverride -bool YES
    if FeatureFlags.forceUpdateOverride {
      updateMessage =
        "Force-update override is enabled. Disable ForceUpdateOverride in UserDefaults to dismiss."
      requiresUpdate = true
      return
    }

    guard let config = await fetchRemoteConfig() else { return }
    guard config.isForceUpdateEnabled else { return }

    let installed = installedVersion()
    guard isVersion(installed, lessThan: config.minimumRequiredVersion) else { return }

    updateMessage = config.updateMessage
    requiresUpdate = true
  }

  private func fetchRemoteConfig() async -> UpdateGateConfig? {
    var request = URLRequest(url: configURL)
    // Bypass URLCache and any CDN edge cache so toggles take effect on the
    // very next launch instead of the launch after.
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    request.timeoutInterval = 10

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard
        let httpResponse = response as? HTTPURLResponse,
        (200..<300).contains(httpResponse.statusCode)
      else {
        return nil
      }
      return try JSONDecoder().decode(UpdateGateConfig.self, from: data)
    } catch {
      return nil
    }
  }

  private func installedVersion() -> String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
  }

  private func isVersion(_ lhs: String, lessThan rhs: String) -> Bool {
    lhs.compare(rhs, options: .numeric) == .orderedAscending
  }
}
