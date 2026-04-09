import Foundation
import SwiftData
import TossKit

/// One-time data migration that fixes the duplicate-UUID problem introduced
/// when the `id: UUID = UUID()` field was added to the `Toss` SwiftData model.
///
/// SwiftData's lightweight migration evaluates a model's default value
/// expression *once* and writes the result to every existing row. So when the
/// `id` field was added, every pre-existing toss got the same UUID — the
/// single value that `UUID()` returned at migration time. Newly-created
/// tosses are unaffected because the model's `init` calls `UUID()` per
/// instance.
///
/// This migration finds any group of tosses sharing the same id and assigns
/// each one a fresh UUID. CloudKit syncs the new ids automatically. If the
/// migration runs on multiple devices in parallel before CloudKit converges,
/// each device generates its own UUIDs and CloudKit's last-writer-wins
/// resolves the conflict — the only invariant we need is "every toss ends
/// up with a unique id," which holds in every ordering.
///
/// Tracked via `UserDefaults` so it only runs once per device.
final class TossUUIDMigration {
  private let migrationCompletionKey = "toss_uuid_migration_v1_completed"
  private let userDefaults = UserDefaults.standard

  private var migrationTask: Task<Void, Never>?

  func startIfNeeded(modelContainer: ModelContainer) {
    guard migrationTask == nil else { return }
    guard !userDefaults.bool(forKey: migrationCompletionKey) else { return }

    migrationTask = Task(priority: .utility) { [weak self] in
      await self?.runMigration(modelContainer: modelContainer)
    }
  }

  func cancel() {
    migrationTask?.cancel()
    migrationTask = nil
  }

  private func runMigration(modelContainer: ModelContainer) async {
    defer { migrationTask = nil }

    let context = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<Toss>()

    guard let allTosses = try? context.fetch(descriptor) else { return }
    if Task.isCancelled { return }

    // Group by id; any group of size > 1 contains duplicates that all need
    // fresh UUIDs. Assigning new UUIDs to *every* member of a duplicate group
    // (rather than all-but-one) avoids having to pick a "winner" — and the
    // pick would race across CloudKit-syncing devices anyway.
    let grouped = Dictionary(grouping: allTosses, by: { $0.id })
    let duplicates = grouped.values.filter { $0.count > 1 }.flatMap { $0 }

    guard !duplicates.isEmpty else {
      userDefaults.set(true, forKey: migrationCompletionKey)
      return
    }

    for toss in duplicates {
      if Task.isCancelled { return }
      toss.id = UUID()
    }

    do {
      try context.save()
    } catch {
      // Don't mark complete on save failure; we'll retry on next launch.
      return
    }

    if !Task.isCancelled {
      userDefaults.set(true, forKey: migrationCompletionKey)
    }
  }
}
