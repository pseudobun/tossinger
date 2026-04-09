import Foundation

enum FeatureFlags {
  private static let defaults = UserDefaults.standard

  static var useLightweightCardText: Bool {
    value(for: "UseLightweightCardText", default: true)
  }

  static var useThumbnailPipeline: Bool {
    value(for: "UseThumbnailPipeline", default: true)
  }

  static var useMetadataTimeoutPolicy: Bool {
    value(for: "UseMetadataTimeoutPolicy", default: true)
  }

  /// Local-only escape hatch for the force-update gate. When true, the gate
  /// triggers regardless of remote config or installed version. Flip via:
  ///   defaults write lutra-labs.toss ForceUpdateOverride -bool YES
  static var forceUpdateOverride: Bool {
    value(for: "ForceUpdateOverride", default: false)
  }

  private static func value(for key: String, default defaultValue: Bool) -> Bool {
    guard defaults.object(forKey: key) != nil else {
      return defaultValue
    }
    return defaults.bool(forKey: key)
  }
}
