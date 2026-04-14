//
//  CloudSyncMonitor.swift
//  TossKit
//
//  Observes NSPersistentCloudKitContainer.eventChangedNotification and exposes
//  a coarse idle/syncing/failed state for SwiftUI. SwiftData's ModelContainer
//  is built on NSPersistentCloudKitContainer, which posts this notification on
//  the default NotificationCenter regardless of how the store was configured.
//

import CoreData
import Foundation

@MainActor
public final class CloudSyncMonitor: ObservableObject {
  public enum State: Equatable {
    case idle
    case syncing
    case failed(message: String)
  }

  @Published public private(set) var state: State = .idle

  private var task: Task<Void, Never>?

  public init() {}

  public func start() {
    guard task == nil else { return }
    task = Task { @MainActor [weak self] in
      let name = NSPersistentCloudKitContainer.eventChangedNotification
      for await notification in NotificationCenter.default.notifications(named: name) {
        guard let self else { return }
        guard
          let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
          ] as? NSPersistentCloudKitContainer.Event,
          event.type != .setup
        else { continue }

        if event.endDate == nil {
          self.state = .syncing
        } else if let error = event.error {
          self.state = .failed(message: error.localizedDescription)
        } else {
          self.state = .idle
        }
      }
    }
  }

  deinit {
    task?.cancel()
  }
}
