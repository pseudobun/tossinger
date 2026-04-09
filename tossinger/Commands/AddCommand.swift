//
//  AddCommand.swift
//  tossinger
//

import ArgumentParser
import Foundation
import TossKit

struct AddCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add",
    abstract: "Create a new toss. URLs become link tosses, anything else is text."
  )

  @Argument(help: "The content of the toss. Use quotes for multi-word text.")
  var content: String

  @Flag(name: .long, help: "Output the created toss as JSON.")
  var json: Bool = false

  func run() async throws {
    let repo = try TossEnvironment.repository()
    let toss = try repo.add(content: content)

    if json {
      try TossPresentation.printJSON([toss])
    } else {
      TossPresentation.printAdded(toss)
    }
  }
}
