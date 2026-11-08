//
//  AlarmKitScheduler.swift
//  RiseUp
//
//  LAYER: Service (real implementation of AlarmScheduling)
//  WHAT:  Turns a `WakeAlarm` from our database into real system alarms using Apple's AlarmKit.
//  USED BY: AppDependencies.live() → every ViewModel that schedules alarms.
//  DATA:  reads WakeAlarm (never saves it; saving is the repository's job).
//
//  HOW RISEUP ALARMS WORK (read this first!)
//  ──────────────────────────────────────────
//  1. MAIN ALARM: one AlarmKit alarm with the SAME id as the WakeAlarm. It repeats
//     on the chosen weekdays and rings even in Silent mode or when the app is closed.
//
//  2. BACKUP CHAIN, the "re-ring chain" (mission alarms, and EVERY alarm while the
//     Wake-up guarantee is on: `isGuarded`):
//     WHY: iOS always shows a "Stop" button on a ringing alarm, and we can't hide it.
//     Worse, the side and volume buttons silence ANY app's alarm (Apple's rule; Salman
//     found it on his iPhone). So we also schedule one-time "backup" alarms right after
//     the main one: +30 s, +1, +1.5, +2, +3, +5, +8, +12 min (`backupOffsets`).
//     • User gets up inside RiseUp ("I'm up" / missions done) → `wakeUpCompleted` cancels them.
//     • User presses Stop or a button → silence for 30 s, then the next backup rings…
//     • While the Ringing screen is open, it keeps pushing the chain ahead (`holdBackupChain`),
//       so iOS's alert never pops over the wallpaper. Leave the app → it rings within a minute.
//     Backups use FIXED dates (just the next ring), so after each wake-up we re-arm them
//     for the following day.
//
//  3. Every ring shows a second button that opens RiseUp: "Start Mission", or "Wake up"
//     for alarms without missions → StartMissionIntent → the Ringing screen, where the
//     alarm's wallpaper and sound take over, full screen.
//
//  4. Backup IDs are calculated from the alarm ID (see `backupID`), so we never need
//     to store them in the database. We can always work out which ones to cancel.
//
//  5. "ONCE + DAYS" (#36): an alarm that repeats (e.g. every Wednesday) can ALSO ring one extra time
//     (e.g. today at 12:00). That extra ring is one more `.fixed` alarm, ID = `onceRingID`, scheduled
//     only while it's still to come and only if it isn't already one of the weekly rings
//     (`WakeAlarm.separateOnceRing`). Once it has rung, iOS removes it and the weekly ones go on.
//
//  6. WAKE-UP CHECK (optional, per alarm): one more `.fixed` alarm a few minutes after the
//     user got up ("Are you up?"), ID = `wakeUpCheckID`. Just stopping it is enough:
//     reacting at all proves you're awake.
//

import ActivityKit
import AlarmKit
import SwiftData            // only to check a WakeAlarm wasn't deleted while we waited (isStillWanted)
import Foundation
import SwiftUI

final class AlarmKitScheduler: AlarmScheduling {

    /// Seconds after a ring when the backup alarms ring (the re-ring chain).
    /// WHY 30 s first: a press on a side button silences only the alarm ringing at that moment;
    /// the next one is never more than 30–60 s away. 8 backups cover 12 minutes.
    /// TRY: `[30, 60]` for a short chain while testing.
    static let backupOffsets: [TimeInterval] = [30, 60, 90, 120, 180, 300, 480, 720]

    /// How far ahead the Ringing screen pushes the chain each time it holds it (every 30 s).
    static let holdSeconds: TimeInterval = 75

    /// Only backups this close to "now" can mean a wake-up is in progress.
    /// 45 min = the longest snooze (30 min) + the whole chain + some room.
    private static let pendingWindow: TimeInterval = 45 * 60

    /// Reads the Wake-up guarantee switch. → AppSettings.guaranteesWakeUp
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    // WHY we always write `AlarmManager.shared.…` instead of keeping it in a property:
    // AlarmKit's async methods run on a background thread, and `AlarmManager` isn't
    // marked thread-safe (`Sendable`). If we stored it in a property of this main-thread
    // class, Swift 6 would refuse to "send" it to that background method (data-race
    // protection). Reading `AlarmManager.shared` fresh at each call avoids that.

    // MARK: - Permission

    var permission: AlarmPermission {
        Self.map(AlarmManager.shared.authorizationState)
    }

    func requestPermission() async -> AlarmPermission {
        do {
            return Self.map(try await AlarmManager.shared.requestAuthorization())
        } catch {
            // WHY: the request only throws for unexpected system errors. Treat that as "not allowed".
            return .denied
        }
    }

    /// How many `schedule(_:)` calls are still running per alarm.
    /// WHY a count and not a Set (found in the code review): with two calls for the same alarm,
    /// the first one to finish removed the ID while the second was still busy.
    private var alarmIDsBeingScheduled: [UUID: Int] = [:]

    // MARK: - Scheduling

    func schedule(_ alarm: WakeAlarm) async throws {
        // Mark "busy" until this function ends, whether it succeeds or throws.
        // ← READ BY: isScheduling(_:) → AlarmListViewModel's reconcile step skips busy alarms.
        // LEARN: `defer` runs when the function exits, even through an error, so the
        // ID can never get stuck in the set.
        let id = alarm.id                      // copied now: the model could be deleted while we wait
        alarmIDsBeingScheduled[id, default: 0] += 1
        defer {
            alarmIDsBeingScheduled[id, default: 1] -= 1
            if alarmIDsBeingScheduled[id] == 0 { alarmIDsBeingScheduled[id] = nil }
        }

        // Start clean: remove any older version of this alarm (main + backups).
        cancel(alarmID: id)
        guard alarm.isEnabled else { return }
        Trace.log(.scheduler, "schedule(\(Trace.short(id))) \(alarm.hour):\(alarm.minute) → main alarm" +
                  (isGuarded(alarm) ? " + backup chain" : " (no chain)"))

        // WHY all-or-nothing (found in the code review): if a backup failed after the main alarm
        // was scheduled, the caller showed the alarm as OFF but the leftovers still rang.
        do {
            try await scheduleMainAlarm(for: alarm)
            // WHY check again after every `await`: while iOS was busy, the user may have switched
            // the alarm off or deleted it. Then whatever we just scheduled must go.
            guard Self.isStillWanted(alarm) else { cancel(alarmID: id); return }

            // "Once + days" (#36): the extra one-time ring, when it needs its own iOS alarm.
            if let onceDate = alarm.separateOnceRing(after: .now) {
                Trace.log(.scheduler, "schedule(\(Trace.short(id))) + once-ring at \(onceDate.formatted(date: .abbreviated, time: .shortened))")
                try await scheduleOnceRing(for: alarm, at: onceDate)
                guard Self.isStillWanted(alarm) else { cancel(alarmID: id); return }
            }

            if isGuarded(alarm), let ringDate = alarm.nextFireDate(after: .now) {
                try await serially(id) { try await self.scheduleBackupChain(for: alarm, after: ringDate) }
                guard Self.isStillWanted(alarm) else { cancel(alarmID: id); return }
            }
        } catch {
            cancel(alarmID: id)
            throw error
        }
    }

    /// Still in the database (not deleted) and still switched on?
    /// LEARN: a deleted SwiftData object loses its `modelContext`. Reading its other
    /// properties after that can crash, so we check this FIRST.
    private static func isStillWanted(_ alarm: WakeAlarm) -> Bool {
        alarm.modelContext != nil && !alarm.isDeleted && alarm.isEnabled
    }

    func isScheduling(_ alarm: WakeAlarm) -> Bool {
        alarmIDsBeingScheduled[alarm.id] != nil
    }

    func cancel(_ alarm: WakeAlarm) {
        cancel(alarmID: alarm.id)
    }

    /// Removes the main alarm, its snooze, wake-up check, once-ring and backups from iOS.
    private func cancel(alarmID: UUID) {
        // WHY `try?`: `cancel` throws if the alarm isn't scheduled (already fired, never
        // scheduled…). That's fine for us; the goal "make sure it's gone" is reached either way.
        try? AlarmManager.shared.cancel(id: alarmID)
        try? AlarmManager.shared.cancel(id: Self.snoozeID(for: alarmID))
        try? AlarmManager.shared.cancel(id: Self.wakeUpCheckID(for: alarmID))
        try? AlarmManager.shared.cancel(id: Self.onceRingID(for: alarmID))
        cancelBackupChain(alarmID: alarmID)
    }

    func wakeUpCompleted(for alarm: WakeAlarm) async throws {
        Trace.log(.scheduler, "wakeUpCompleted(\(Trace.short(alarm.id))) → cancel the chain, arm the next ring")
        try await serially(alarm.id) {
            self.cancelBackupChain(alarmID: alarm.id)
            try? AlarmManager.shared.cancel(id: Self.snoozeID(for: alarm.id))

            // Repeating alarms need tomorrow's (or next week's) chain armed right away.
            // One-time alarms are finished; their ViewModel turns them off.
            if alarm.isRepeating && alarm.isEnabled && self.isGuarded(alarm),
               let ringDate = alarm.nextFireDate(after: .now) {
                try await self.scheduleBackupChain(for: alarm, after: ringDate)
            }
        }
    }

    /// Does this alarm get a re-ring chain? Mission alarms always; all others while the
    /// Wake-up guarantee is on (Settings, on by default).
    private func isGuarded(_ alarm: WakeAlarm) -> Bool {
        alarm.hasMissions || settings.guaranteesWakeUp
    }

    func scheduledSystemAlarmIDs() -> Set<UUID> {
        // LEARN: `(try? x) ?? []` means "try to read x; if it throws, use an empty list".
        Set(((try? AlarmManager.shared.alarms) ?? []).map(\.id))
    }

    func systemAlarms() -> [UUID: SystemAlarmInfo] {
        var result: [UUID: SystemAlarmInfo] = [:]
        for alarm in (try? AlarmManager.shared.alarms) ?? [] {
            let state: SystemAlarmState = switch alarm.state {
            case .scheduled: .scheduled
            case .countdown: .countdown
            case .paused: .paused
            case .alerting: .alerting
            @unknown default: .scheduled
            }
            // LEARN: `if case .fixed(let date) = …` pulls the date out of an enum case, if it matches.
            var fixedDate: Date?
            if case .fixed(let date) = alarm.schedule { fixedDate = date }
            result[alarm.id] = SystemAlarmInfo(state: state, fixedDate: fixedDate)
        }
        return result
    }

    func systemAlarmIDs(for alarm: WakeAlarm) -> Set<UUID> {
        ringingSystemAlarmIDs(for: alarm).union([Self.wakeUpCheckID(for: alarm.id)])
    }

    func ringingSystemAlarmIDs(for alarm: WakeAlarm) -> Set<UUID> {
        // The once-ring (#36) is a real wake-up too: ringing → Ringing screen, mission lock, etc.
        backupSystemAlarmIDs(for: alarm).union([alarm.id, Self.snoozeID(for: alarm.id), Self.onceRingID(for: alarm.id)])
    }

    func onceRingSystemAlarmID(for alarm: WakeAlarm) -> UUID {
        Self.onceRingID(for: alarm.id)
    }

    func backupSystemAlarmIDs(for alarm: WakeAlarm) -> Set<UUID> {
        Set(Self.backupOffsets.indices.map { Self.backupID(for: alarm.id, index: $0) })
    }

    func stopRinging(_ alarm: WakeAlarm) {
        let system = systemAlarms()
        for id in ringingSystemAlarmIDs(for: alarm) where system[id]?.state == .alerting {
            // WHY stop and not cancel: for a REPEATING main alarm, `stop` ends today's ring
            // but keeps the schedule for next time; `cancel` would delete it.
            try? AlarmManager.shared.stop(id: id)
        }
    }

    func scheduleSnooze(for alarm: WakeAlarm, minutes: Int) async throws {
        let id = Self.snoozeID(for: alarm.id)
        try? AlarmManager.shared.cancel(id: id)
        let ringDate = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        let guarded = isGuarded(alarm)
        Trace.log(.scheduler, "scheduleSnooze(\(Trace.short(alarm.id)), \(minutes) min)" + (guarded ? " → chain moves behind it" : ""))
        let configuration = AlarmManager.AlarmConfiguration<RiseUpAlarmMetadata>(
            schedule: .fixed(ringDate),
            attributes: makeAttributes(for: alarm, isBackup: false, usesSnooze: false),
            secondaryIntent: guarded ? StartMissionIntent(wakeAlarmID: alarm.id, ringingSystemAlarmID: id) : nil,
            sound: Self.sound(named: alarm.soundName)
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)

        // The chain follows the snooze: a button press on the snooze ring only buys 30 s too.
        if guarded {
            try await serially(alarm.id) {
                self.cancelBackupChain(alarmID: alarm.id)
                try await self.scheduleBackupChain(for: alarm, after: ringDate)
            }
        }
    }

    func holdBackupChain(for alarm: WakeAlarm) async {
        // LEARN: a deleted SwiftData object has no `modelContext`; never read it further.
        guard alarm.modelContext != nil, !alarm.isDeleted, isGuarded(alarm) else { return }
        Trace.log(.scheduler, "holdBackupChain(\(Trace.short(alarm.id))) → first backup moved to +\(Int(Self.holdSeconds)) s")
        // The chain's FIRST backup lands `holdSeconds` from now; the others follow it.
        let ringDate = Date.now.addingTimeInterval(Self.holdSeconds - Self.backupOffsets[0])
        try? await serially(alarm.id) {
            self.cancelBackupChain(alarmID: alarm.id)
            try await self.scheduleBackupChain(for: alarm, after: ringDate)
        }
    }

    func ensureBackupChain(for alarm: WakeAlarm) async throws {
        guard alarm.isEnabled, isGuarded(alarm) else { return }
        try await serially(alarm.id) { try await self.ensureBackupChainNow(for: alarm) }
    }

    /// The body of `ensureBackupChain`, run in line with the other chain jobs (see `serially`).
    private func ensureBackupChainNow(for alarm: WakeAlarm) async throws {
        // A wake-up is in progress: its chain is doing its job, don't touch it.
        if hasPendingWakeUp(alarm) { return }
        let system = systemAlarms()
        let firstBackup = system[Self.backupID(for: alarm.id, index: 0)]?.fixedDate
        let hasAnyBackup = Self.backupOffsets.indices.contains {
            system[Self.backupID(for: alarm.id, index: $0)] != nil
        }

        // WHY compare the DATE too (found in the code review): backups are fixed moments, the
        // main alarm is a clock time. After flying to another time zone (or changing the clock),
        // the main alarm moves but the backups didn't, and rang "Mission not finished!" before
        // the real alarm. If backup 1 isn't exactly where it should be, re-arm the chain.
        var isOnTime = false
        let mainDate = alarm.nextFireDate(after: .now)
        if let firstBackup, let mainDate {
            isOnTime = abs(firstBackup.timeIntervalSince(mainDate.addingTimeInterval(Self.backupOffsets[0]))) < 5
        }
        if !hasAnyBackup || !isOnTime, let mainDate {
            cancelBackupChain(alarmID: alarm.id)
            try await scheduleBackupChain(for: alarm, after: mainDate)
        }
    }

    func hasPendingWakeUp(_ alarm: WakeAlarm, now: Date) -> Bool {
        let system = systemAlarms()
        // 1. Is one of its system alarms ringing right now? (Only guarded alarms lock: a plain
        //    alarm without the guarantee may simply be stopped.)
        if isGuarded(alarm), ringingSystemAlarmIDs(for: alarm).contains(where: { system[$0]?.state == .alerting }) {
            return true
        }
        // 2. Did it already ring while its chain is still waiting?
        // WHY not "a backup is due soon": that's also true in the minute BEFORE the ring,
        // which locked the alarm too early (we saw this while testing). The rule compares the
        // backups with the NEXT ring's chain instead (see AlarmScheduleCalculator.isWakeUpPending).
        let backupDates = backupSystemAlarmIDs(for: alarm).compactMap { system[$0]?.fixedDate }
        return AlarmScheduleCalculator.isWakeUpPending(
            backupDates: backupDates, nextRing: alarm.nextFireDate(after: now), now: now,
            firstOffset: Self.backupOffsets[0], window: Self.pendingWindow
        )
    }

    func scheduleWakeUpCheck(for alarm: WakeAlarm, minutes: Int) async throws {
        let id = Self.wakeUpCheckID(for: alarm.id)
        try? AlarmManager.shared.cancel(id: id)
        guard minutes > 0 else { return }
        let alert = AlarmPresentation.Alert(
            title: "Wake-up check: are you up?",
            stopButton: AlarmButton(text: "I'm up", textColor: .white, systemImageName: "sun.max.fill")
        )
        let configuration = AlarmManager.AlarmConfiguration<RiseUpAlarmMetadata>(
            schedule: .fixed(Date.now.addingTimeInterval(TimeInterval(minutes * 60))),
            attributes: AlarmAttributes(
                presentation: AlarmPresentation(alert: alert),
                metadata: RiseUpAlarmMetadata(wakeAlarmID: alarm.id, isBackup: false),
                tintColor: Theme.Colors.accentWarm
            ),
            sound: Self.sound(named: alarm.soundName)
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }

    func stopWakeUpCheckIfRinging(for alarm: WakeAlarm) -> Bool {
        let id = Self.wakeUpCheckID(for: alarm.id)
        guard systemAlarms()[id]?.state == .alerting else { return false }
        try? AlarmManager.shared.stop(id: id)
        return true
    }

    func cancelSystemAlarms(notIn keeping: Set<UUID>) {
        // WHY skip lab IDs: the AlarmKit Lab schedules test alarms that belong to no
        // WakeAlarm. Without this, a sync would delete them before they ring.
        for id in systemAlarms().keys where !keeping.contains(id) && !Self.isDebugLabAlarm(id) {
            try? AlarmManager.shared.cancel(id: id)
        }
    }

    /// WHY Debug only (found in the code review): "first byte is 0x1A" is also true for about
    /// 1 in 256 RANDOM IDs. In the App Store version (no Lab) such a real alarm's leftovers
    /// would never be cleaned up, so the exception only exists where the Lab exists.
    private static func isDebugLabAlarm(_ id: UUID) -> Bool {
        #if DEBUG
        return isLabTestID(id)
        #else
        return false
        #endif
    }

    // MARK: - Main alarm

    private func scheduleMainAlarm(for alarm: WakeAlarm) async throws {
        // LEARN: `.relative` = "at this clock time" (follows time-zone changes), with
        // optional weekly repetition. `.fixed` = one exact moment (backups, quick alarms).
        let schedule: Alarm.Schedule
        if let fixedFireDate = alarm.fixedFireDate {
            // Quick Alarm: ring at one exact moment ("in 10 minutes").
            schedule = .fixed(fixedFireDate)
        } else {
            let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.isRepeating
                ? .weekly(alarm.repeatDays.map(\.localeWeekday))
                : .never
            schedule = .relative(.init(
                time: .init(hour: alarm.hour, minute: alarm.minute),
                repeats: recurrence
            ))
        }

        let configuration = ringConfiguration(for: alarm, schedule: schedule, systemAlarmID: alarm.id)
        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: configuration) //sAve the alarm in iOS
    }

    /// "Once + days" (#36): the extra one-time ring, at one exact moment. Same title, sound and buttons
    /// as the main alarm; only the WHEN and the ID differ.
    private func scheduleOnceRing(for alarm: WakeAlarm, at date: Date) async throws {
        let id = Self.onceRingID(for: alarm.id)
        let configuration = ringConfiguration(for: alarm, schedule: .fixed(date), systemAlarmID: id)
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }

    /// The package iOS gets for a "real" ring of this alarm (the main one or its once-ring):
    /// snooze countdown (if any), WHEN, what it looks like, the second button and the sound.
    /// `systemAlarmID` = the iOS alarm that will be ringing, so "Wake up" can silence exactly that one.
    ///
    /// LEARN: `sending` (Swift 6) promises the compiler that the returned box is brand new and nobody
    /// else holds it, so it may safely be handed to AlarmKit, which works on another thread. Without it,
    /// Swift refuses ("sending 'configuration' risks causing data races").
    private func ringConfiguration(for alarm: WakeAlarm, schedule: Alarm.Schedule,
                                   systemAlarmID: UUID) -> sending AlarmManager.AlarmConfiguration<RiseUpAlarmMetadata> {
        // iOS's own Snooze button only for alarms WITHOUT a chain: with one, the backups would ring
        // in the middle of the snooze. Guarded alarms snooze inside RiseUp (Ringing screen), and
        // get "Start Mission" / "Wake up" here instead.
        let guarded = isGuarded(alarm)
        let usesSnooze = !guarded && alarm.isSnoozeEnabled
        let countdown = usesSnooze
            ? Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(alarm.snoozeMinutes * 60))
            : nil

        return AlarmManager.AlarmConfiguration<RiseUpAlarmMetadata>(
            countdownDuration: countdown,
            schedule: schedule,
            attributes: makeAttributes(for: alarm, isBackup: false, usesSnooze: usesSnooze),
            secondaryIntent: guarded
                ? StartMissionIntent(wakeAlarmID: alarm.id, ringingSystemAlarmID: systemAlarmID)
                : nil,
            sound: Self.sound(named: alarm.soundName)
        )
    }

    // MARK: - Backup chain

    /// Schedules the backups for one ring: `ringDate` + each offset.
    /// Call it inside `serially` (it assumes no other chain job runs for this alarm meanwhile).
    private func scheduleBackupChain(for alarm: WakeAlarm, after ringDate: Date) async throws {
        let dates = AlarmScheduleCalculator.backupDates(after: ringDate, offsets: Self.backupOffsets)
        let alarmID = alarm.id
        let version = chainVersions[alarmID, default: 0]

        // LEARN: `enumerated()` gives us (index, element) pairs: 0, 1, 2…
        for (index, date) in dates.enumerated() where date > .now {
            let backupID = Self.backupID(for: alarmID, index: index)
            let configuration = AlarmManager.AlarmConfiguration<RiseUpAlarmMetadata>(
                schedule: .fixed(date),
                attributes: makeAttributes(for: alarm, isBackup: true, usesSnooze: false),
                secondaryIntent: StartMissionIntent(wakeAlarmID: alarmID, ringingSystemAlarmID: backupID),
                sound: Self.sound(named: alarm.soundName)
            )
            _ = try await AlarmManager.shared.schedule(id: backupID, configuration: configuration)
            // WHY check after every `await`: while iOS was busy, the chain may have been cancelled
            // ("I'm up", alarm switched off or deleted). Then this backup must not survive.
            guard chainVersions[alarmID, default: 0] == version else {
                try? AlarmManager.shared.cancel(id: backupID)
                return
            }
        }
    }

    /// Goes up by one on every chain cancel, so a chain job that is still busy can notice.
    private var chainVersions: [UUID: Int] = [:]

    private func cancelBackupChain(alarmID: UUID) {
        chainVersions[alarmID, default: 0] += 1
        for index in Self.backupOffsets.indices {
            try? AlarmManager.shared.cancel(id: Self.backupID(for: alarmID, index: index))
        }
    }

    /// The last chain job of each alarm (the "line" that `serially` adds to).
    private var chainJobs: [UUID: Task<Void, Never>] = [:]

    /// Runs `job` after every earlier chain job of the same alarm has finished.
    ///
    /// WHY: the Ringing screen re-arms the chain every 30 s, while the sync, a snooze or "I'm up"
    /// may change it at the same moment. Jobs that mix their cancel and schedule steps could leave
    /// a chain for the wrong ring, or none. In a line, each job sees the finished work of the last.
    /// LEARN: each job waits for the previous Task (`await previous?.value`), like people in a queue.
    private func serially(_ alarmID: UUID, _ job: @escaping () async throws -> Void) async throws {
        let previous = chainJobs[alarmID]
        let task = Task<Result<Void, any Error>, Never> {
            await previous?.value
            do {
                try await job()
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        chainJobs[alarmID] = Task { _ = await task.value }
        try await task.value.get()
    }

    /// Calculates the ID of backup alarm number `index` for a given alarm.
    ///
    /// WHY: we derive backup IDs from the alarm's own ID (changing its last two bytes)
    /// instead of storing random ones. Any time later, even after an app restart, we
    /// can recompute exactly which system alarms to cancel. Collisions with other random
    /// UUIDs are practically impossible (2¹²² possibilities).
    static func backupID(for alarmID: UUID, index: Int) -> UUID {
        // LEARN: `UUID.uuid` exposes the 16 raw bytes as a tuple (.0 … .15).
        var bytes = alarmID.uuid
        bytes.14 ^= 0xB0                       // "B" for backup: marks the family
        bytes.15 = bytes.15 &+ UInt8(index + 1) // &+ wraps around instead of crashing on overflow
        return UUID(uuid: bytes)
    }

    /// A random ID marked as "AlarmKit Lab test" (first byte 0x1A), so sync leaves it alone.
    /// ← USED BY: AlarmLabViewModel (sound and limit tests)
    static func makeLabTestID() -> UUID {
        var bytes = UUID().uuid
        bytes.0 = 0x1A
        return UUID(uuid: bytes)
    }

    static func isLabTestID(_ id: UUID) -> Bool {
        id.uuid.0 == 0x1A
    }

    /// The ID of this alarm's in-app snooze ring (see `scheduleSnooze`). Derived like backups.
    static func snoozeID(for alarmID: UUID) -> UUID {
        var bytes = alarmID.uuid
        bytes.14 ^= 0x5E                       // "S" for snooze: a different family than backups
        return UUID(uuid: bytes)
    }

    /// The ID of this alarm's wake-up check (see `scheduleWakeUpCheck`). Derived like backups.
    static func wakeUpCheckID(for alarmID: UUID) -> UUID {
        var bytes = alarmID.uuid
        bytes.14 ^= 0xC4                       // "C" for check: yet another family
        return UUID(uuid: bytes)
    }

    /// The ID of this alarm's extra one-time ring ("Once + days", #36). Derived like backups.
    static func onceRingID(for alarmID: UUID) -> UUID {
        var bytes = alarmID.uuid
        bytes.14 ^= 0x0E                       // "O" for once: its own family again
        return UUID(uuid: bytes)
    }

    // MARK: - Presentation (what the system shows)

    private func makeAttributes(for alarm: WakeAlarm, isBackup: Bool, usesSnooze: Bool) -> AlarmAttributes<RiseUpAlarmMetadata> {
        let title: LocalizedStringResource = switch (isBackup, alarm.hasMissions) {
        case (true, true): "Mission not finished!"
        case (true, false): "Still in bed? Tap Wake up"
        case (false, _): LocalizedStringResource(stringLiteral: alarm.displayTitle)
        }

        // The second button: "Start Mission" / "Wake up" (open the app), "Snooze" (system countdown), or none.
        let secondaryButton: AlarmButton?
        let secondaryBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior?
        if alarm.hasMissions {
            secondaryButton = AlarmButton(text: "Start Mission", textColor: .white, systemImageName: "bolt.fill")
            secondaryBehavior = .custom      // runs our StartMissionIntent
        } else if isGuarded(alarm) {
            // → StartMissionIntent too: opens the Ringing screen (wallpaper + sound, "I'm up")
            secondaryButton = AlarmButton(text: "Wake up", textColor: .white, systemImageName: "sun.max.fill")
            secondaryBehavior = .custom
        } else if usesSnooze {
            secondaryButton = AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")
            secondaryBehavior = .countdown   // AlarmKit counts down `postAlert` seconds, then rings again
        } else {
            secondaryButton = nil
            secondaryBehavior = nil
        }

        // WHY the `stopButton:` version: our minimum is iOS 26.0, where this initializer is
        // required. iOS 26.1+ ignores the stop button style and always shows its own.
        let alert = AlarmPresentation.Alert(
            title: title,
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryBehavior
        )

        let presentation = AlarmPresentation(
            alert: alert,
            countdown: usesSnooze ? AlarmPresentation.Countdown(title: "Snoozing") : nil
        )

        return AlarmAttributes(
            presentation: presentation,
            metadata: RiseUpAlarmMetadata(wakeAlarmID: alarm.id, isBackup: isBackup),
            tintColor: Theme.Colors.accent
        )
    }

    // MARK: - Helpers

    /// "default" → the system alarm sound; anything else → a sound file in the app bundle, or
    /// (the user's own sounds) in Library/Sounds.
    ///
    /// WHY the file check for custom sounds: a user can delete their sound while an alarm still
    /// uses it. Handing iOS the name of a file that doesn't exist risks an error beep instead of an
    /// alarm (reported on Apple's forums), so a missing custom file becomes iOS's own alarm sound.
    static func sound(named name: String) -> AlertConfiguration.AlertSound {
        AlarmSoundRule.usesSystemSound(name, fileExists: { FileManager.default.fileExists(atPath: $0) })
            ? .default : .named(name)
    }

    private static func map(_ state: AlarmManager.AuthorizationState) -> AlarmPermission {
        switch state {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        @unknown default: .denied
        }
    }
}
