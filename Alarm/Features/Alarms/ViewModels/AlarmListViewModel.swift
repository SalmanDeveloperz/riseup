//
//  AlarmListViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel
//  WHAT:  The "brain" of the Alarm List screen (Screen #6): loads alarms, turns them
//         on/off, deletes them, finds the next alarm, and asks for navigation.
//  DATA:  reads + writes WakeAlarm (through AlarmRepository).
//         Gives the View only value snapshots (AlarmRow, NextAlarmInfo), never WakeAlarm objects.
//
//  CONNECTIONS (follow the arrows to trace the app):
//    ← CREATED BY:  ScreenFactory.makeRoot(for: .alarms)
//                   (it passes in the repository, scheduler and coordinator)
//    ← OWNED BY:    AlarmListView (`@State private var viewModel`)
//    ← CALLED BY:   AlarmListView (on appear, toggle, swipe-delete, taps)
//    → READS/WRITES DATA:  AlarmRepository.alarms / refresh() / save() / delete()  → SwiftData
//    → SYSTEM ALARMS:      AlarmScheduling.schedule() / cancel()  → AlarmKitScheduler → AlarmKit
//    → NAVIGATION:         AppCoordinator.showAlarmEditor(alarmID:)  → RootView pushes the editor
//    → DATE MATHS:         AlarmScheduleCalculator.nextOccurrence(...)  (pure function)
//
//  LEARN: Why the ViewModel gets a repository, a scheduler and a coordinator
//  ─────────────────────────────────────────────────────────────────────────
//  This class never creates them itself; it receives them ("dependency injection").
//  In the real app ScreenFactory passes the real ones from AppDependencies.
//  In the #Preview it gets an in-memory database + MockAlarmScheduler.
//  Same ViewModel code, different "plugs".
//

import Foundation
import Observation

@Observable
final class AlarmListViewModel {

    // MARK: - State the View reads

    /// One snapshot per alarm, sorted by time of day. The View draws one card per row.
    ///
    /// → built from AlarmRepository.alarms, the single source of truth.
    ///
    /// LEARN: this is a *computed* property, so it stores nothing and is rebuilt each
    /// time the View reads it. Swift's Observation follows the chain
    /// View → rows → repository.alarms → each alarm's properties. When ANY of those change
    /// (even because another screen edited or deleted an alarm), the list redraws.
    /// WHY snapshots (structs) instead of WakeAlarm objects: see AlarmRow.swift.
    var rows: [AlarmRow] {
        repository.alarms.map(Self.makeRow)
    }

    /// Non-nil → the View shows an alert with this message.
    ///
    /// LEARN: `private(set)` = the View can READ this, but only the ViewModel can CHANGE it.
    private(set) var errorMessage: String?

    // MARK: - Dependencies (injected, never created here)

    private let repository: AlarmRepository
    private let scheduler: any AlarmScheduling
    private let coordinator: AppCoordinator

    init(repository: AlarmRepository, scheduler: any AlarmScheduling, coordinator: AppCoordinator) {
        self.repository = repository
        self.scheduler = scheduler
        self.coordinator = coordinator
    }

    // MARK: - Loading

    /// Reads all alarms from the database and makes sure they match the real system alarms.
    ///
    /// ← CALLED BY: AlarmListView `.task`, so it runs every time the screen shows,
    ///   including when you come back from the editor or from the AlarmKit Lab (other tab).
    /// → AlarmRepository.refresh() → SwiftData FetchDescriptor sorted by hour, minute
    /// → reconcileWithSystemAlarms(_:) → AlarmScheduling.scheduledSystemAlarmIDs() / schedule()
    func load() async {
        do {
            try repository.refresh()
            await reconcileWithSystemAlarms(repository.alarms)
        } catch {
            errorMessage = "Couldn't load your alarms. \(error.localizedDescription)"
        }
    }

    /// Fixes alarms whose database state no longer matches what iOS has scheduled.
    ///
    /// WHY this is needed: a ONE-TIME alarm is used up by iOS after it rings, but our
    /// database still says `isEnabled = true`, because the app may not even have been
    /// running at that moment. Without this check the list would show the alarm as on,
    /// and the header would count down to a ring that will never happen.
    ///
    /// Rules, for each alarm that is ON in our database but NOT scheduled in iOS:
    ///  • one-time alarm → it already rang → turn it off (like the iOS Clock app does)
    ///  • repeating alarm → iOS lost it (e.g. app reinstalled) → schedule it again
    ///
    /// WHY we only flip `isEnabled` and DON'T call `scheduler.cancel`: if a mission alarm
    /// rang and the user pressed Stop, its backup alarms must keep ringing until the
    /// mission is done. Cancelling them here would let anyone skip the mission just by
    /// opening the app.
    ///
    /// TODO(Phase 2): move this to app launch (shared AlarmSyncService), so the Ringing
    /// flow and widgets also see the corrected state.
    private func reconcileWithSystemAlarms(_ alarms: [WakeAlarm]) async {
        let scheduledIDs = scheduler.scheduledSystemAlarmIDs()  // → AlarmKit's current list
        var didChange = false

        // WHY skip `isScheduling` alarms (a race condition we actually hit while testing):
        // another screen (Lab, later the Editor) saves an alarm as "on" and THEN schedules
        // it, which takes ~0.1 s. If this check runs in between, the alarm is "on" in
        // the database but not yet in iOS's list, and we'd wrongly switch it off.
        for alarm in alarms where alarm.isEnabled
                                && !scheduledIDs.contains(alarm.id)
                                && !scheduler.isScheduling(alarm) {
            if alarm.isRepeating {
                do {
                    try await scheduler.schedule(alarm)
                } catch {
                    // Couldn't re-create it (e.g. permission was turned off) → show the truth: off.
                    alarm.isEnabled = false
                    didChange = true
                }
            } else {
                alarm.isEnabled = false
                didChange = true
            }
        }

        if didChange {
            try? repository.save()
        }
    }

    // MARK: - Next alarm (header countdown)

    /// The enabled alarm that will ring soonest after `date`, or `nil` if every alarm is off.
    ///
    /// ← CALLED BY: AlarmListView inside a `TimelineView`, once per minute, with the current time.
    /// → AlarmScheduleCalculator.nextOccurrence for each enabled alarm, then the earliest wins.
    func nextAlarm(after date: Date) -> NextAlarmInfo? {
        repository.alarms
            .filter(\.isEnabled)
            .compactMap { alarm in
                // LEARN: `.map` on an optional: if a date exists, turn it into a NextAlarmInfo;
                // if it's nil, the result stays nil and `compactMap` drops it.
                AlarmScheduleCalculator.nextOccurrence(
                    hour: alarm.hour,
                    minute: alarm.minute,
                    weekdays: alarm.repeatDays,
                    after: date
                ).map { NextAlarmInfo(title: alarm.displayTitle, fireDate: $0) }
            }
            .min { $0.fireDate < $1.fireDate }
    }

    // MARK: - Actions (called by the View, always with an alarm ID)

    /// Turns an alarm on or off: updates the database AND the real system alarm.
    ///
    /// ← CALLED BY: the switch on AlarmCardView (via AlarmListView)
    /// → AlarmScheduling.schedule(alarm)  (on = schedule with AlarmKit, off = cancel; see AlarmKitScheduler)
    /// → AlarmRepository.save()
    func setEnabled(_ isEnabled: Bool, alarmID: UUID) async {
        guard let alarm = liveAlarm(id: alarmID) else { return }

        // 1. Change the model right away, so the switch and the card glow react instantly.
        // LEARN: `rows` reads `alarm.isEnabled`, so this change makes the list redraw
        // with a fresh AlarmRow for this card.
        alarm.isEnabled = isEnabled

        do {
            // 2. Turning ON needs alarm permission (asks the first time).
            if isEnabled {
                try await requireAlarmPermission()
            }
            // 3. Tell iOS. `schedule` re-creates the system alarm, or cancels it when disabled.
            try await scheduler.schedule(alarm)
            // 4. Write the new value to disk.
            try repository.save()
        } catch {
            // WHY roll back: if iOS refused, the switch must not pretend the alarm is on.
            // The screen should always show the truth.
            alarm.isEnabled = !isEnabled
            try? repository.save()
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes an alarm everywhere: system alarms first, then the database row.
    ///
    /// ← CALLED BY: swipe-to-delete on a card (AlarmListView `.swipeActions`)
    /// → AlarmScheduling.cancel(alarm) → removes main alarm + backup chain from AlarmKit
    /// → AlarmRepository.delete(alarm) → SwiftData deletes it (and its missions, cascade rule)
    ///   and refreshes `repository.alarms` → the row disappears from `rows`
    func delete(alarmID: UUID) {
        guard let alarm = liveAlarm(id: alarmID) else { return }
        // WHY cancel FIRST: once SwiftData deletes an object, reading its properties
        // (like `alarm.id`, which cancel needs) crashes. So we use it before deleting it.
        scheduler.cancel(alarm)
        do {
            try repository.delete(alarm)
        } catch {
            errorMessage = "Couldn't delete the alarm. \(error.localizedDescription)"
        }
    }

    /// ← CALLED BY: the "+" floating button and the empty-state button
    /// → AppCoordinator.showAlarmEditor(alarmID: nil) → pushes the editor in "create" mode
    func addAlarmTapped() {
        coordinator.showAlarmEditor(alarmID: nil)
    }

    /// ← CALLED BY: tapping a card
    /// → AppCoordinator.showAlarmEditor(alarmID:) → pushes the editor in "edit" mode
    ///
    /// WHY pass the ID and not the alarm object: routes must be simple `Hashable` values.
    /// The editor will load the alarm by ID from the repository itself.
    func alarmTapped(alarmID: UUID) {
        coordinator.showAlarmEditor(alarmID: alarmID)
    }

    /// ← CALLED BY: the alert's OK button in AlarmListView
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Helpers

    /// Finds the real, live alarm object for an ID coming from the View.
    /// Returns `nil` if it was deleted in the meantime; then the action is simply ignored.
    private func liveAlarm(id: UUID) -> WakeAlarm? {
        repository.alarms.first { $0.id == id }
    }

    /// Copies the values the card needs out of a live alarm.
    ///
    /// LEARN: `static` because it doesn't use any ViewModel state; it only turns input into output.
    private static func makeRow(from alarm: WakeAlarm) -> AlarmRow {
        AlarmRow(
            id: alarm.id,
            hour: alarm.hour,
            minute: alarm.minute,
            isEnabled: alarm.isEnabled,
            subtitle: alarm.label.isEmpty ? alarm.repeatSummary : "\(alarm.label) · \(alarm.repeatSummary)",
            missionTypes: alarm.sortedMissions.map(\.type)
        )
    }

    /// Makes sure RiseUp may schedule alarms; asks the user the first time.
    /// Throws `AlarmListError.permissionDenied` if they said no.
    private func requireAlarmPermission() async throws {
        if scheduler.permission == .authorized { return }
        let answer = await scheduler.requestPermission()   // shows the system popup if never asked
        guard answer == .authorized else { throw AlarmListError.permissionDenied }
    }

    // MARK: - Debug helpers

    // LEARN: `#if DEBUG` code exists only in builds run from Xcode. App Store builds never contain it.
    #if DEBUG
    /// Adds a few example alarms so you can try the list before the editor exists.
    /// They start OFF, so nothing rings until you switch one on.
    ///
    /// ← CALLED BY: the 🐞 menu in AlarmListView's toolbar
    func addSampleAlarms() {
        let gym = WakeAlarm(hour: 6, minute: 30,
                            repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
                            label: "Gym", isEnabled: false)
        gym.missions = [MissionConfig(type: .math), MissionConfig(type: .shake, sortOrder: 1)]

        let weekend = WakeAlarm(hour: 9, minute: 0, repeatDays: [.saturday, .sunday],
                                label: "Lazy weekend", isEnabled: false)
        let nap = WakeAlarm(hour: 14, minute: 15, label: "Power nap", isEnabled: false)

        do {
            // Each insert refreshes `repository.alarms`, so the cards appear right away.
            for alarm in [gym, weekend, nap] {
                try repository.insert(alarm)
            }
        } catch {
            errorMessage = "Couldn't add samples. \(error.localizedDescription)"
        }
    }
    #endif
}

// MARK: - Errors

/// Errors this screen can show to the user.
///
/// LEARN: conforming to `LocalizedError` and providing `errorDescription` makes
/// `error.localizedDescription` return OUR friendly text instead of a technical one.
nonisolated enum AlarmListError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "RiseUp isn't allowed to schedule alarms. Turn it on in Settings → RiseUp → Alarms."
        }
    }
}
