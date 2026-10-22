//
//  AlarmListViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel
//  WHAT:  The "brain" of the Alarm List screen (Screen #6): shows alarms, turns them
//         on/off, deletes them, finds the next alarm, guards the wake-up lock, and asks
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
//    → SYSTEM:      AlarmScheduling.schedule() / cancel() / hasPendingWakeUp()
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

    /// The alarm whose wake-up is waiting to be finished right now (ringing or backups due), if any.
    /// The View shows a glowing "Finish waking up" banner for it.
    ///
    /// ← CALLED BY: AlarmListView (TimelineView, once per minute)
    /// → AlarmScheduling.hasPendingWakeUp (the lock rule)
    func pendingWakeUp(now: Date) -> NextAlarmInfo? {
        repository.alarms
            .first { scheduler.hasPendingWakeUp($0, now: now) }
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

        // Wake-up lock: no switching off while its wake-up is pending.
        if !isEnabled && scheduler.hasPendingWakeUp(alarm) {
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
        if scheduler.hasPendingWakeUp(alarm) {
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

    // MARK: - Add a mission without opening the editor (#38)

    /// "+ Add mission" on a card (or a widget's link): the Mission Picker opens, and the chosen mission is
    /// SAVED to the alarm right away. No editor, no Save button: the card shows the mission a moment later.
    /// ← CALLED BY: AlarmCardView's "+ Add mission" pill, handleMissionRequest() (widgets)
    func addMission(toAlarm alarmID: UUID) {
        guard let alarm = liveAlarm(id: alarmID) else { return }
        // Wake-up lock: same rule as the editor (a pending wake-up can't be changed).
        if scheduler.hasPendingWakeUp(alarm) {
            errorMessage = Self.lockedMessage
            return
        }
        guard alarm.missions.count < AlarmEditorViewModel.maxMissions else { return }
        Trace.log(.editor, "AlarmListViewModel.addMission(\(Trace.short(alarmID))) → Mission Picker, then save")
        coordinator.presentMissionPicker(editing: nil) { [weak self] mission in   // → Mission Picker sheet
            Task { await self?.save(mission, toAlarm: alarmID) }
        }
    }

    /// Adds `mission` to the alarm, saves, and re-schedules it (a mission alarm gets its backup chain).
    /// WHY like `applyEnabled`: if iOS refuses, the alarm goes back to how it was. The card never pretends.
    /// ← CALLED BY: addMission's picker callback (and tests)
    func save(_ mission: MissionDraft, toAlarm alarmID: UUID) async {
        guard let alarm = liveAlarm(id: alarmID) else { return }        // deleted while the sheet was open
        if scheduler.hasPendingWakeUp(alarm) {                          // started ringing meanwhile
            errorMessage = Self.lockedMessage
            return
        }
        let before = alarm.sortedMissions.map(MissionDraft.init)        // to roll back
        repository.replaceMissions(of: alarm, with: before + [mission])
        do {
            try repository.save()
            if alarm.isEnabled {
                try await scheduler.schedule(alarm)                     // → now protected by the mission + chain
            }
        } catch {
            // After the `await`: the alarm may be gone; only roll back if it's still there.
            if let alarm = liveAlarm(id: alarmID) {
                repository.replaceMissions(of: alarm, with: before)
                try? repository.save()
            }
            errorMessage = "Couldn't add the mission. \(error.localizedDescription)"
        }
    }

    /// A widget asked for "Add a wake-up mission" (riseup://alarm/<id>/mission → AppCoordinator).
    /// ← CALLED BY: AlarmListView when `coordinator.missionRequestAlarmID` changes, and on appear
    func handleMissionRequest() {
        guard let alarmID = coordinator.takeMissionRequest() else { return }
        addMission(toAlarm: alarmID)
    }

    /// The pending widget request, for the View to watch.
    var missionRequestAlarmID: UUID? { coordinator.missionRequestAlarmID }

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

    /// ← CALLED BY: the "Finish waking up" banner
    func resumeWakeUp() {
        guard let alarm = repository.alarms.first(where: { scheduler.hasPendingWakeUp($0) }) else { return }
        coordinator.presentRinging(alarmID: alarm.id)   // → full-screen Ringing flow
    }

    /// ← CALLED BY: the alert's OK button
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Helpers

    static let lockedMessage = "This alarm is locked until you're up. Tap “Finish waking up” at the top."

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
