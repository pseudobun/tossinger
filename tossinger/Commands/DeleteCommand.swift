//
//  DeleteCommand.swift
//  tossinger
//

import ArgumentParser
import Foundation
import TossKit

struct DeleteCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "delete",
    abstract: "Delete a toss by its UUID.",
    aliases: ["rm"]
  )

  @Argument(help: "UUID of the toss to delete (see `toss list`).")
  var id: String

  @Flag(name: .shortAndLong, help: "Skip the confirmation prompt.")
  var force: Bool = false

  func run() async throws {
    guard let uuid = UUID(uuidString: id) else {
      throw CLIError.invalidUUID(id)
    }

    let repo = try TossEnvironment.repository()
    guard let toss = try repo.find(id: uuid) else {
      throw CLIError.notFound(uuid)
    }

    if !force {
      print("About to delete:")
      print("  \(toss.id.uuidString)")
      print("  \(toss.content.prefix(80))")
      print("Type 'yes' to confirm: ", terminator: "")
      guard let answer = readLine()?.lowercased(), answer == "yes" else {
        print("Aborted.")
        throw ExitCode(1)
      }
    }

    try repo.delete(id: uuid)
    print("Deleted \(uuid.uuidString).")
  }
}
