//
//  TossCLI.swift
//  tossinger
//
//  Entry point for the `toss` command-line tool. Subcommands live in
//  Commands/, shared infrastructure (environment, errors, presentation)
//  in Support/.
//

import ArgumentParser
import Foundation

@main
struct TossCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "toss",
    abstract: "Read, create, and delete tosses from the terminal.",
    discussion: """
      Talks to the same SwiftData + CloudKit store as the macOS app.
      Writes are picked up by the app live; the next app launch will
      enrich any link tosses created via `toss add`.
      """,
    version: "0.1.0",
    subcommands: [
      ListCommand.self,
      AddCommand.self,
      DeleteCommand.self,
    ],
    defaultSubcommand: ListCommand.self
  )
}
