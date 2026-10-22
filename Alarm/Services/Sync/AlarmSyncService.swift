//
//  AlarmSyncService.swift
//  RiseUp
//
//  LAYER: Service (coordinates two other parts: the database and iOS)
//  WHAT:  Keeps our database and iOS's alarms in agreement, and tells the app when an
//         alarm is ringing right now.
//  DATA:  reads + writes WakeAlarm (through AlarmRepository); reads/cancels system alarms
//         (through AlarmScheduling).
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (one shared instance)
//    ← CALLED BY:  RootView (app launch + every time the app comes back to the foreground),
//                  AlarmListViewModel.load() (each time the list appears)
//    → AlarmRepository: alarms / save / delete
//    → AlarmScheduling: systemAlarms / schedule / ensureBackupChain / cancelSystemAlarms
//
//  WHY a separate service (it used to live inside AlarmListViewModel):
//  syncing isn't about one screen. It must also run on launch (so the Ringing screen
//  can open automatically) even if the Alarm List is never shown. A service that two
//  others coordinate is a common design: "repository + scheduler → sync service".
//
//  THE RULES, for every alarm:
//   1. ON in database, NOT in iOS (and not mid-scheduling):
//        • quick alarm  → it already rang → delete it (quick alarms are throwaway)
//        • one-time     → it already rang → switch it off
//        • repeating    → iOS lost it (reinstall, restore) → schedule it again
//   2. Repeating guarded alarm with NO backups → re-arm the chain for the next ring.
//      (Happens when yesterday's wake-up was never finished in the app.)
//   3. System alarms that belong to no alarm (or the main alarm of a switched-off one)
//      → cancel them. Backups of existing alarms are kept: a mission may be pending.
//   4. A wake-up check ringing while the user opens RiseUp → stop it (they're clearly awake).
//   5. "Once + days" (#36):
//        • the extra ring is still to come but iOS lost it → schedule the alarm again (part of rule 1)
//        • the extra ring's moment has passed → forget it (`extraOnceDate = nil`): the editor then shows
//          plain repeat days again. This also covers "pressed Stop and never opened the app".
//

import Foundation

final class AlarmSyncService {
    private let repository: AlarmRepository
    private let scheduler: any AlarmScheduling

    /// WHY: launch, foreground and the Alarm List can all ask for a sync at nearly the
    /// same moment. Running two at once could double-schedule, so the second one waits its turn
    /// by simply skipping (the first one does the work).
    private var isSyncing = false

    init(repository: AlarmRepository, scheduler: any AlarmScheduling) {
        self.repository = repository
        self.scheduler = scheduler
    }

    // MARK: - Sync

    /// Re-schedules every switched-on alarm (main ring, buttons and backup chain) from scratch.
    /// ← CALLED BY: SettingsViewModel when the Wake-up guarantee is switched on or off.
    /// Alarms whose wake-up is in progress are left alone (their chain is busy).
    func rescheduleAll() async {
        try? repository.refresh()
        for alarmID in repository.alarms.map(\.id) {
            // Same "look it up fresh after every await" rule as in sync().
            guard let alarm = repository.alarms.first(where: { $0.id == alarmID }),
                  alarm.isEnabled, !scheduler.isScheduling(alarm), !scheduler.hasPendingWakeUp(alarm) else { continue }
            try? await scheduler.schedule(alarm)
        }
    }

    /// Runs all the rules above. Safe to call often.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        Trace.log(.sync, "AlarmSyncService.sync() → compare the database with iOS's alarms")

        try? repository.refresh()
        let system = scheduler.systemAlarms()            // → what iOS really has
        var didChange = false
        var finishedQuickAlarms: [WakeAlarm] = []

        // WHY loop over IDs (found in the code review): this loop `await`s. Meanwhile other code
        // (e.g. finishing a quick alarm) may DELETE a later alarm; touching a deleted SwiftData
        // object crashes. So each round looks the alarm up fresh in the live list (which drops
        // deleted alarms the moment they're deleted) and skips it if it's gone.
        for alarmID in repository.alarms.map(\.id) {
            guard let alarm = repository.alarms.first(where: { $0.id == alarmID }) else { continue }
            // Race-condition guard (see HOW_IT_WORKS.md, Bug 3).
            if scheduler.isScheduling(alarm) { continue }

            // Rule 5a ("Once + days"): its extra ring should be in iOS but isn't.
            // WHY also check hasPendingWakeUp: never re-schedule (which resets the chain) mid-wake-up.
            let onceRingMissing = alarm.isEnabled && alarm.separateOnceRing(after: .now) != nil
                && system[scheduler.onceRingSystemAlarmID(for: alarm)] == nil
                && !scheduler.hasPendingWakeUp(alarm)

            // Rule 1: on in our database but missing in iOS.
            if alarm.isEnabled && (system[alarm.id] == nil || onceRingMissing) {
                if alarm.isQuickAlarm {
                    if !scheduler.hasPendingWakeUp(alarm) { finishedQuickAlarms.append(alarm) }
                } else if alarm.isRepeating {
                    do {
                        try await scheduler.schedule(alarm)
                    } catch {
                        alarm.isEnabled = false          // couldn't re-create it → show the truth: off
                        didChange = true
                    }
                } else {
                    alarm.isEnabled = false              // one-time alarm that already rang
                    didChange = true
                }
            }

            // Rule 2: repeating alarms need their backup chain armed (the scheduler decides
            // which alarms have one: mission alarms, and all while the Wake-up guarantee is on).
            if alarm.isEnabled && alarm.isRepeating {
                try? await scheduler.ensureBackupChain(for: alarm)
            }

            // Rule 4: opening RiseUp answers "are you up?".
            scheduler.stopWakeUpCheckIfRinging(for: alarm)

            // Rule 5b ("Once + days"): the extra ring's moment has passed → it's done, forget it.
            // (Harmless even mid-wake-up: the backups in iOS don't depend on this date.)
            if let once = alarm.extraOnceDate, once <= .now {
                Trace.log(.sync, "sync: once-ring of \(Trace.short(alarm.id)) has passed → cleared")
                alarm.extraOnceDate = nil
                didChange = true
            }
        }

        for alarm in finishedQuickAlarms {
            scheduler.cancel(alarm)
            try? repository.delete(alarm)                 // delete() saves by itself
        }
        if didChange {
            try? repository.save()
        }

        // Rule 3: remove leftovers. The "keep" list is built and used WITHOUT any `await`
        // in between, so no other code can add an alarm in the middle (no race).
        scheduler.cancelSystemAlarms(notIn: systemAlarmIDsToKeep())
    }

    /// The ID of the alarm that is ringing right now (main, backup or snooze), if any.
    ///
    /// ← CALLED BY: RootView after a sync → opens the Ringing screen automatically.
    /// WHY: an unanswered AlarmKit alarm keeps "ringing" forever (spike finding). If the
    /// user simply opens RiseUp, we take over with the Ringing screen.
    func ringingAlarmID() -> UUID? {
        let system = scheduler.systemAlarms()
        return repository.alarms.first { alarm in
            // ringing IDs only: a ringing wake-up CHECK must not restart the missions.
            scheduler.ringingSystemAlarmIDs(for: alarm).contains { system[$0]?.state == .alerting }
        }?.id
    }

    // MARK: - Helpers

    private func systemAlarmIDsToKeep() -> Set<UUID> {
        var keep: Set<UUID> = []
        for alarm in repository.alarms {
            var ids = scheduler.systemAlarmIDs(for: alarm)
            if !alarm.isEnabled {
                ids.remove(alarm.id)   // a switched-off alarm's MAIN ring must not happen
                // Its backups may only stay while its mission is really pending (it rang, the
                // user hasn't finished). Otherwise they're leftovers that would ring for an
                // alarm that is off (found in the code review).
                if !scheduler.hasPendingWakeUp(alarm) {
                    ids.subtract(scheduler.backupSystemAlarmIDs(for: alarm))
                }
            }
            keep.formUnion(ids)
        }
        return keep
    }
}
