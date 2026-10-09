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
//   2. Repeating mission alarm with NO backups → re-arm the chain for the next ring.
//      (Happens when yesterday's mission was never completed.)
//   3. System alarms that belong to no alarm (or the main alarm of a switched-off one)
//      → cancel them. Backups of existing alarms are kept: a mission may be pending.
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

    /// Runs all the rules above. Safe to call often.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        try? repository.refresh()
        let system = scheduler.systemAlarms()            // → what iOS really has
        var didChange = false
        var finishedQuickAlarms: [WakeAlarm] = []

        for alarm in repository.alarms {
            // Race-condition guard (see HOW_IT_WORKS.md, Bug 3).
            if scheduler.isScheduling(alarm) { continue }

            // Rule 1: on in our database but missing in iOS.
            if alarm.isEnabled && system[alarm.id] == nil {
                if alarm.isQuickAlarm {
                    if !scheduler.hasPendingMission(alarm) { finishedQuickAlarms.append(alarm) }
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

            // Rule 2: repeating mission alarms always need their backup chain armed.
            if alarm.isEnabled && alarm.isRepeating && alarm.hasMissions {
                try? await scheduler.ensureBackupChain(for: alarm)
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
            scheduler.systemAlarmIDs(for: alarm).contains { system[$0]?.state == .alerting }
        }?.id
    }

    // MARK: - Helpers

    private func systemAlarmIDsToKeep() -> Set<UUID> {
        var keep: Set<UUID> = []
        for alarm in repository.alarms {
            var ids = scheduler.systemAlarmIDs(for: alarm)
            if !alarm.isEnabled {
                ids.remove(alarm.id)   // a switched-off alarm's MAIN ring must not happen
            }
            keep.formUnion(ids)
        }
        return keep
    }
}
