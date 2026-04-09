//
//  CLIError.swift
//  tossinger
//

import Foundation

enum CLIError: Error, CustomStringConvertible {
  case invalidUUID(String)
  case notFound(UUID)

  var description: String {
    switch self {
    case .invalidUUID(let raw):
      return "Not a valid UUID: \(raw)"
    case .notFound(let id):
      return "No toss found with id \(id)"
    }
  }
}
