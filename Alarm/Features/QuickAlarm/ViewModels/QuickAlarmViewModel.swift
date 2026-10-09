//
//  QuickAlarmViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel
//  WHAT:  The brain of the Quick Alarm sheet (Screen #7): "ring in N minutes" at an
//         EXACT moment, created in one tap. Perfect for naps.
//  DATA:  creates a WakeAlarm with `fixedFireDate` set (through AlarmRepository).
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .quickAlarm)
//    ← OPENED BY:  AlarmListViewModel.quickAlarmTapped() → AppCoordinator.presentQuickAlarm()
//    → DATA:       AlarmRepository.insert
//    → iOS:        AlarmScheduling.requirePermission / schedule  (→ `.fixed(date)` schedule)
//    → CLOSE:      AppCoordinator.dismissSheet()
//
//  WHY quick alarms are deleted after ringing (AlarmSyncService rule 1): they're
//  throwaway. A list full of old "Quick alarm" cards would be clutter.
//

import Foundation
import Observation

@Observable
final class QuickAlarmViewModel {
    /// Minutes from now. The big number on screen.
    var minutes: Int = 10

    /// The preset chips: 8 = two neat rows of four. TRY: swap 45 for 90.
    static let presets = [1, 5, 10, 15, 20, 30, 45, 60]
    static let range = 1...720  // up to 12 hours

    private(set) var errorMessage: String?
    private(set) var isStarting = false

    private let repository: AlarmRepository
    private let scheduler: any AlarmScheduling
    private let coordinator: AppCoordinator

    init(repository: AlarmRepository, scheduler: any AlarmScheduling, coordinator: AppCoordinator) {
        self.repository = repository
        self.scheduler = scheduler
        self.coordinator = coordinator
    }

    /// When the alarm would ring if started at `now`.
    func fireDate(now: Date) -> Date {
        now.addingTimeInterval(TimeInterval(minutes * 60))
    }

    /// "1 h 30 min" / "10 min"
    var durationText: String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    /// ← CALLED BY: −/+ buttons (step 1 min, or 5 min above 30)
    func adjust(by delta: Int) {
        let step = minutes >= 30 ? 5 : 1
        minutes = min(Self.range.upperBound, max(Self.range.lowerBound, minutes + delta * step))
    }

    /// Creates and schedules the quick alarm, then closes the sheet.
    /// ← CALLED BY: "Start" button
    func start() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        do {
            try await scheduler.requirePermission()      // 1. permission first (same rule as the editor)

            let date = fireDate(now: .now)
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let alarm = WakeAlarm(
                hour: parts.hour ?? 0,
                minute: parts.minute ?? 0,
                label: "Quick alarm",
                soundName: AlarmSound.radar.rawValue,
                fixedFireDate: date                       // ← the exact moment (SchemaV2)
            )
            try repository.insert(alarm)                  // 2. save
            try await scheduler.schedule(alarm)           // 3. → AlarmKitScheduler → `.fixed(date)`
            coordinator.dismissSheet()                    // 4. close; the list shows the new card
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel() {
        coordinator.dismissSheet()
    }

    func dismissError() {
        errorMessage = nil
    }
}
