//
//  AlarmListViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel
//  WHAT:  The "brain" of the Alarm List screen (Screen #6): shows alarms, turns them
//         on/off, deletes them, finds the next alarm, guards the mission lock, and asks
//         for navigation (editor, quick alarm, ringing screen).
//  DATA:  reads + writes WakeAlarm (through AlarmRepository).
//         Gives the View only value snapshots (AlarmRow, NextAlarmInfo), never WakeAlarm objects.
//
//  CONNECTIONS (follow the arrows to trace the app):
//    ← CREATED BY:  ScreenFactory.makeRoot(for: .alarms)
//    ← OWNED BY:    AlarmListView (`@State private var viewModel`)
//    ← CALLED BY:   AlarmListView (appear, toggle, swipe-delete, taps, banner)
//    → DATA:        AlarmRepository.alarms / save() / delete()        → SwiftData
//    → SYNC:        AlarmSyncService.sync()                           → database ↔ iOS agreement
//    → SYSTEM:      AlarmScheduling.schedule() / cancel() / hasPendingMission()
//    → NAVIGATION:  AppCoordinator.showAlarmEditor / presentQuickAlarm / presentRinging
//
//  LEARN: Why the ViewModel gets its tools from outside
//  ────────────────────────────────────────────────────
//  This class never creates them itself; it receives them ("dependency injection").
//  In the real app ScreenFactory passes the real ones from AppDependencies.
//  In the #Preview it gets an in-memory database + mocks. Same code, different "plugs".
//

import Foundation
import Observation

@Observable
final class AlarmListViewModel {

    // MARK: - State the View reads

    /// One snapshot per alarm, sorted by time of day. The View draws one card per row.
    ///
    /// LEARN: a *computed* property: rebuilt each time the View reads it. Observation follows
    /// View → rows → repository.alarms → each alarm's properties, so ANY change (even from
    /// another screen) redraws the list. WHY snapshots: see AlarmRow.swift.
    var rows: [AlarmRow] {
        repository.alarms.map(Self.makeRow)
    }

    /// Non-nil → the View shows an alert with this message.
    private(set) var errorMessage: String?

    // MARK: - Dependencies (injected, never created here)

    private let repository: AlarmRepository
    private let scheduler: any AlarmScheduling
    private let sync: AlarmSyncService
    private let coordinator: AppCoordinator

    init(repository: AlarmRepository, scheduler: any AlarmScheduling, sync: AlarmSyncService, coordinator: AppCoordinator) {
        self.repository = repository
        self.scheduler = scheduler
        self.sync = sync
        self.coordinator = coordinator
    }

    // MARK: - Loading

    /// Brings the list up to date with the database AND iOS.
    ///
    /// ← CALLED BY: AlarmListView `.task` (every time the screen appears)
    /// → AlarmSyncService.sync() → refresh, fix differences, clean up leftovers
    ///   (the rules are listed at the top of AlarmSyncService.swift)
    func load() async {
        await sync.sync()
    }

    // MARK: - Next alarm (header countdown)

    /// The enabled alarm that will ring soonest after `date`, or `nil` if every alarm is off.
    ///
    /// ← CALLED BY: AlarmListView inside a `TimelineView`, once per minute.
    /// → WakeAlarm.nextFireDate (handles normal AND quick alarms)
    func nextAlarm(after date: Date) -> NextAlarmInfo? {
        repository.nextAlarm(after: date)          // shared with the Morning tab
    }

    /// The alarm whose mission is waiting to be done right now (ringing or backups due), if any.
    /// The View shows a glowing "Finish your mission" banner for it.
    ///
    /// ← CALLED BY: AlarmListView (TimelineView, once per minute)
    /// → AlarmScheduling.hasPendingMission (the "mission lock" rule)
    func pendingMission(now: Date) -> NextAlarmInfo? {
        repository.alarms
            .first { scheduler.hasPendingMission($0, now: now) }
            .map { NextAlarmInfo(title: $0.displayTitle, fireDate: now) }
    }

    // MARK: - Actions (called by the View, always with an alarm ID)

    /// Turns an alarm on or off: updates the database AND the real system alarm.
    ///
    /// ← CALLED BY: the switch on AlarmCardView (via AlarmListView)
    /// → AlarmScheduling.schedule(alarm)  (on = schedule, off = cancel)
    /// → AlarmRepository.save()
    func setEnabled(_ isEnabled: Bool, alarmID: UUID) async {
        // WHY one change at a time per alarm (found in the review): flipping on→off quickly
        // started two iOS calls at once; the slower one could win and leave a system alarm
        // scheduled while the card said "off". Now a tap that arrives mid-change waits its
        // turn, and only the LAST wish is applied.
        guard !togglesInFlight.contains(alarmID) else {
            queuedToggles[alarmID] = isEnabled
            return
        }
        togglesInFlight.insert(alarmID)
        await applyEnabled(isEnabled, alarmID: alarmID)
        togglesInFlight.remove(alarmID)
        if let next = queuedToggles.removeValue(forKey: alarmID), next != liveAlarm(id: alarmID)?.isEnabled {
            await setEnabled(next, alarmID: alarmID)
        }
    }

    @ObservationIgnored private var togglesInFlight: Set<UUID> = []
    @ObservationIgnored private var queuedToggles: [UUID: Bool] = [:]

    private func applyEnabled(_ isEnabled: Bool, alarmID: UUID) async {
        guard let alarm = liveAlarm(id: alarmID) else { return }

        // Mission lock: no switching off while its mission is pending.
        if !isEnabled && scheduler.hasPendingMission(alarm) {
            errorMessage = Self.lockedMessage
            return
        }

        // 1. Change the model right away, so the switch and glow react instantly.
        alarm.isEnabled = isEnabled
        do {
            // 2. Turning ON needs alarm permission (asks the first time).
            if isEnabled {
                try await scheduler.requirePermission()   // → shared helper in AlarmScheduling.swift
                // A quick alarm whose moment has passed can't ring again; ask for a new one.
                if alarm.isQuickAlarm && alarm.nextFireDate(after: .now) == nil {
                    throw AlarmListError.quickAlarmExpired
                }
            }
            // 3. Tell iOS. `schedule` re-creates the system alarm, or cancels it when disabled.
            try await scheduler.schedule(alarm)
            // 4. Write the new value to disk.
            try repository.save()
        } catch {
            // WHY roll back: the switch must never pretend. The screen always shows the truth.
            alarm.isEnabled = !isEnabled
            try? repository.save()
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes an alarm everywhere: system alarms first, then the database row.
    ///
    /// ← CALLED BY: swipe-to-delete on a card
    func delete(alarmID: UUID) {
        guard let alarm = liveAlarm(id: alarmID) else { return }
        if scheduler.hasPendingMission(alarm) {
            errorMessage = Self.lockedMessage
            return
        }
        // WHY cancel FIRST: reading a deleted SwiftData object crashes, and cancel needs `alarm.id`.
        scheduler.cancel(alarm)
        do {
            try repository.delete(alarm)
        } catch {
            errorMessage = "Couldn't delete the alarm. \(error.localizedDescription)"
        }
    }

    /// ← CALLED BY: the "+" floating button and the empty-state button
    func addAlarmTapped() {
        coordinator.showAlarmEditor(alarmID: nil)       // → editor in "create" mode
    }

    /// ← CALLED BY: the ⚡︎ toolbar button and the empty-state "Quick alarm" button
    func quickAlarmTapped() {
        coordinator.presentQuickAlarm()                 // → Quick Alarm sheet
    }

    /// ← CALLED BY: tapping a card
    func alarmTapped(alarmID: UUID) {
        coordinator.showAlarmEditor(alarmID: alarmID)   // → editor in "edit" mode
    }

    /// ← CALLED BY: the "Finish your mission" banner
    func resumeMission() {
        guard let alarm = repository.alarms.first(where: { scheduler.hasPendingMission($0) }) else { return }
        coordinator.presentRinging(alarmID: alarm.id)   // → full-screen Ringing flow
    }

    /// ← CALLED BY: the alert's OK button
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Helpers

    static let lockedMessage = "This alarm is locked until you finish its mission. Tap “Finish your mission” at the top."

    private func liveAlarm(id: UUID) -> WakeAlarm? {
        repository.alarms.first { $0.id == id }
    }

    /// Copies the values the card needs out of a live alarm.
    private static func makeRow(from alarm: WakeAlarm) -> AlarmRow {
        let when = alarm.isQuickAlarm ? "Quick alarm" : alarm.repeatSummary
        return AlarmRow(
            id: alarm.id,
            hour: alarm.hour,
            minute: alarm.minute,
            isEnabled: alarm.isEnabled,
            subtitle: alarm.label.isEmpty || alarm.isQuickAlarm ? when : "\(alarm.label) · \(when)",
            missionTypes: alarm.sortedMissions.map(\.type)
        )
    }

    // MARK: - Debug helpers

    // LEARN: `#if DEBUG` code exists only in builds run from Xcode. App Store builds never contain it.
    #if DEBUG
    /// Adds a few example alarms (switched OFF) so you can try the list quickly.
    func addSampleAlarms() {
        let gym = WakeAlarm(hour: 6, minute: 30,
                            repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
                            label: "Gym", isEnabled: false, soundName: AlarmSound.radar.rawValue)
        gym.missions = [MissionConfig(type: .math), MissionConfig(type: .shake, repetitions: 30, sortOrder: 1)]
        let weekend = WakeAlarm(hour: 9, minute: 0, repeatDays: [.saturday, .sunday],
                                label: "Lazy weekend", isEnabled: false, soundName: AlarmSound.sunrise.rawValue)
        let nap = WakeAlarm(hour: 14, minute: 15, label: "Power nap", isEnabled: false)
        do {
            for alarm in [gym, weekend, nap] { try repository.insert(alarm) }
        } catch {
            errorMessage = "Couldn't add samples. \(error.localizedDescription)"
        }
    }
    #endif
}

/// Errors only this screen produces.
nonisolated enum AlarmListError: LocalizedError {
    case quickAlarmExpired

    var errorDescription: String? {
        switch self {
        case .quickAlarmExpired: "This quick alarm has already rung. Create a new one with ⚡︎."
        }
    }
}
