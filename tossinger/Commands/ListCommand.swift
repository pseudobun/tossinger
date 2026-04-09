//
//  ListCommand.swift
//  tossinger
//

import ArgumentParser
import Foundation
import TossKit

struct ListCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List tosses, newest first.",
    aliases: ["ls"]
  )

  @Option(name: .shortAndLong, help: "Maximum number of tosses to return.")
  var limit: Int = 50

  @Option(name: .shortAndLong, help: "Number of tosses to skip from the start.")
  var offset: Int = 0

  @Flag(name: .long, help: "Output as JSON instead of human-readable text.")
  var json: Bool = false

  func run() async throws {
    let repo = try TossEnvironment.repository()
    let tosses = try repo.list(limit: limit, offset: offset)
    let total = try repo.count()

    if json {
      try TossPresentation.printJSON(
        tosses,
        total: total,
        limit: limit,
        offset: offset
      )
    } else {
      TossPresentation.printText(
        tosses,
        total: total,
        limit: limit,
        offset: offset
      )
    }
  }
}
