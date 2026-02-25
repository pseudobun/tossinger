#if os(macOS)
  import KeyboardShortcuts

  extension KeyboardShortcuts.Name {
    static let addSelectedTextToToss = Self(
      "addSelectedTextToToss",
      default: .init(.t, modifiers: [.command, .control, .option, .shift])
    )
  }
#endif
