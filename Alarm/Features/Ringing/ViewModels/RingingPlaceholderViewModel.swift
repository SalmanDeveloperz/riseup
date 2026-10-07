//
//  RingingPlaceholderViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (temporary; Phase 2 replaces it with the real Ringing + Mission flow)
//  WHAT:  Loads the alarm that rang, and lets you finish a (fake) mission.
//  USED BY: RingingPlaceholderView (route: FullScreenRoute.ringing).
//  DATA:  reads WakeAlarm; one-time alarms get `isEnabled = false` after completion.
//

import Foundation
import Observation

@Observable
final class RingingPlaceholderViewModel {
    let alarmID: UUID

    /// The alarm that rang, or `nil` if it no longer exists (e.g. deleted in the Lab).
    private(set) var alarm: WakeAlarm?
    private(set) var errorMessage: String?
    private(set) var isCompleting = false

    private let repository: AlarmRepository
    private let scheduler: any AlarmScheduling
    private let coordinator: AppCoordinator

    init(alarmID: UUID, repository: AlarmRepository, scheduler: any AlarmScheduling, coordinator: AppCoordinator) {
        self.alarmID = alarmID
        self.repository = repository
        self.scheduler = scheduler
        self.coordinator = coordinator
    }

    func load() {
        do {
            alarm = try repository.fetch(id: alarmID)
        } catch {
            errorMessage = "Couldn't load alarm: \(error.localizedDescription)"
        }
    }

    /// Pretends the mission was solved: stops the backup chain and closes the screen.
    func completeMission() async {
        guard let alarm else { return coordinator.dismissFullScreen() }
        isCompleting = true
        defer { isCompleting = false }

        do {
            try await scheduler.missionCompleted(for: alarm)
            // One-time alarms are finished after ringing, like the iOS Clock app.
            if !alarm.isRepeating {
                alarm.isEnabled = false
                try repository.save()
            }
            coordinator.dismissFullScreen()
        } catch {
            errorMessage = "Couldn't finish mission: \(error.localizedDescription)"
        }
    }

    /// Leaves WITHOUT finishing. Backup alarms will keep ringing (by design).
    func closeWithoutFinishing() {
        coordinator.dismissFullScreen()
    }
}
