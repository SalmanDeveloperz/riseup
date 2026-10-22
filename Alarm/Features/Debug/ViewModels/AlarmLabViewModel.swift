//
//  AlarmLabViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (debug tool, Phase 0 "spike")
//  WHAT:  Runs experiments that prove AlarmKit behaves the way our design needs,
//         on a REAL iPhone, before we build the real screens on top of it.
//  USED BY: AlarmLabView.
//  DATA:  creates/deletes WakeAlarms whose label starts with "Lab" (through AlarmRepository).
//
//  The experiments (results go in docs/SPIKE_RESULTS.md):
//   A. Permission popup works.
//   B. Custom sound: does `.named("spike_beep.caf")` play our tone, or the default?
//   C. Mission alarm: "Start Mission" opens the app on the Ringing screen;
//      completing the mission cancels the backup chain; pressing Stop lets backups ring.
//   D. Snooze: the system "Snooze" button re-rings after 1 minute.
//   E. Limit: how many alarms can one app schedule?
//
//  WHY this ViewModel imports AlarmKit directly: it's a test bench that needs raw
//  access (e.g. listing every system alarm). Real feature ViewModels must ONLY use
//  the `AlarmScheduling` protocol. This file is deleted once the spike is done.
//

import AlarmKit
import Foundation
import Observation
import SwiftUI

@Observable
final class AlarmLabViewModel {

    // MARK: - Types

    /// One line in the on-screen log.
    struct LogLine: Identifiable {
        let id = UUID()
        let date = Date()
        let text: String
        let isError: Bool
    }

    /// One system alarm, prepared for display.
    struct SystemAlarmRow: Identifiable {
        let id: UUID
        let title: String
        let schedule: String
        let state: String
        let isRinging: Bool
    }

    enum SoundVariant: String, CaseIterable, Identifiable {
        case fileWithExtension = "spike_beep.caf"
        case fileWithoutExtension = "spike_beep"
        case systemDefault = "default"
        var id: String { rawValue }
    }

    // MARK: - State the View reads

    private(set) var permission: AlarmPermission
    private(set) var log: [LogLine] = []
    private(set) var systemAlarms: [SystemAlarmRow] = []
    private(set) var isBusy = false

    /// Experiment C option: also repeat the test alarm on today's weekday,
    /// to see how Stop behaves on repeating alarms.
    var repeatsToday = false

    // MARK: - Dependencies

    private let repository: AlarmRepository
    private let scheduler: any AlarmScheduling
    // (We use `AlarmManager.shared` directly; see the WHY note in AlarmKitScheduler.swift.)

    init(repository: AlarmRepository, scheduler: any AlarmScheduling) {
        self.repository = repository
        self.scheduler = scheduler
        self.permission = scheduler.permission
    }

    // MARK: - A. Permission

    func requestPermission() async {
        permission = await scheduler.requestPermission()
        write("Permission is now: \(permission)")
    }

    // MARK: - B. Custom sound

    /// One-time alarm in ~60 seconds with the chosen sound. Listen to what actually plays.
    func scheduleSoundTest(_ variant: SoundVariant) async {
        await run("Sound test (\(variant.rawValue))") {
            let fireDate = Date.now.addingTimeInterval(60) // what it would exactly look like when alarm ring, when should the alarm ring
            let attributes = AlarmAttributes<RiseUpAlarmMetadata>(      //what should the user see
                presentation: AlarmPresentation(alert: .init(
                    title: LocalizedStringResource(stringLiteral: "Lab · \(variant.rawValue)"),
                    stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
                )),
                metadata: RiseUpAlarmMetadata(wakeAlarmID: UUID(), isBackup: false),
                tintColor: Theme.Colors.accent
            )
            let configuration = AlarmManager.AlarmConfiguration<RiseUpAlarmMetadata>(   //how do we combine the alarm settings
                schedule: .fixed(fireDate),
                attributes: attributes,
                sound: AlarmKitScheduler.sound(named: variant.rawValue)
            )
            _ = try await AlarmManager.shared.schedule(id: AlarmKitScheduler.makeLabTestID(), configuration: configuration) //who actually schedule the alarm
            write("Rings at \(fireDate.formatted(date: .omitted, time: .standard)). Lock the phone and listen.")
        }
    }

    // MARK: - C. Mission alarm + backup chain

    /// Creates a real WakeAlarm with a Math mission for the next minute, through the
    /// SAME code path the real app will use (repository + scheduler).
    func createMissionAlarm() async {
        await run("Mission alarm") {
            let (hour, minute) = nextTestMinute()
            let alarm = WakeAlarm(
                hour: hour,
                minute: minute,
                repeatDays: repeatsToday ? [Weekday.of(.now)] : [],
                label: "Lab · Mission test",
                soundName: SoundVariant.fileWithExtension.rawValue
            )
            alarm.missions = [MissionConfig(type: .math)]
            try repository.insert(alarm)
            try await scheduler.schedule(alarm)

            let backups = AlarmKitScheduler.backupOffsets.map { "+\(Int($0)) s" }.joined(separator: ", ")
            write("Main alarm at \(String(format: "%02d:%02d", hour, minute)), backups at \(backups).")
            write("Try 1: tap “Start Mission” → app should open on the Ringing screen.")
            write("Try 2: tap “Stop” instead → backups should keep ringing.")
        }
    }

    // MARK: - D. Snooze

    func createSnoozeAlarm() async {
        await run("Snooze alarm") {
            let (hour, minute) = nextTestMinute()
            let alarm = WakeAlarm(
                hour: hour,
                minute: minute,
                label: "Lab · Snooze test",
                soundName: SoundVariant.fileWithExtension.rawValue,
                isSnoozeEnabled: true,
                snoozeMinutes: 1
            )
            try repository.insert(alarm)
            try await scheduler.schedule(alarm)
            write("Rings at \(String(format: "%02d:%02d", hour, minute)). Tap “Snooze” → should ring again ~1 min later.")
        }
    }

    // MARK: - E. Limit

    /// Schedules far-future alarms until AlarmKit refuses, then removes them all.
    func runLimitTest() async {
        await run("Limit test") {
            var createdIDs: [UUID] = []
            // WHY `defer`: no matter how this ends (success or error), clean up the test alarms.
            defer {
                for id in createdIDs { try? AlarmManager.shared.cancel(id: id) }
            }
            let farFuture = Date.now.addingTimeInterval(60 * 60 * 24 * 30) // 30 days from now
            for index in 0..<300 {
                let configuration = AlarmManager.AlarmConfiguration<RiseUpAlarmMetadata>(
                    schedule: .fixed(farFuture.addingTimeInterval(TimeInterval(index * 60))),
                    attributes: AlarmAttributes(
                        presentation: AlarmPresentation(alert: .init(
                            title: "Lab · limit",
                            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
                        )),
                        metadata: RiseUpAlarmMetadata(wakeAlarmID: UUID(), isBackup: false),
                        tintColor: Theme.Colors.accent
                    )
                )
                do {
                    let id = AlarmKitScheduler.makeLabTestID()
                    _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
                    createdIDs.append(id)
                } catch {
                    let existing = scheduler.scheduledSystemAlarmIDs().count - createdIDs.count
                    write("Stopped after \(createdIDs.count) new alarms (+\(existing) already existing). Error: \(error)",
                          isError: true)
                    return
                }
            }
            write("No limit hit after 300 alarms.")
        }
    }

    // MARK: - System alarm list

    /// Keeps `systemAlarms` up to date for as long as the screen is visible.
    ///
    /// LEARN: `alarmUpdates` is an *AsyncSequence*: a stream that delivers a new
    /// value every time any of our alarms changes. `for await` waits for each new
    /// value. The loop ends automatically when the View's `.task` is cancelled
    /// (the user leaves the screen).
    func observeSystemAlarms() async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            systemAlarms = makeRows(from: alarms)
        }
    }

    /// Cancels EVERY RiseUp system alarm and deletes all "Lab" alarms from the database.
    func cancelEverything() async {
        await run("Clean up") {
            for alarm in (try? AlarmManager.shared.alarms) ?? [] {
                try? AlarmManager.shared.cancel(id: alarm.id)
            }
            let labAlarms = try repository.fetchAll().filter { $0.label.hasPrefix("Lab") }
            for alarm in labAlarms {
                try repository.delete(alarm)
            }
            write("Cancelled all system alarms and deleted \(labAlarms.count) lab alarm(s).")
        }
    }

    // MARK: - Helpers

    /// Runs an experiment with a busy flag and error logging.
    ///
    /// LEARN: `operation` is a closure parameter. Callers pass the experiment's code
    /// in `{ }`, and this function wraps it with the shared "busy + catch errors" logic.
    /// `@MainActor` promises Swift the closure runs on the main thread, like the rest of this class.
    private func run(_ name: String, _ operation: @MainActor () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await operation()
        } catch {
            write("\(name) failed: \(error)", isError: true)
        }
    }

    private func write(_ text: String, isError: Bool = false) {
        log.insert(LogLine(text: text, isError: isError), at: 0)
    }

    /// The next whole minute, at least 15 seconds away, so there's time to lock the phone.
    private func nextTestMinute() -> (hour: Int, minute: Int) {
        let seconds = Calendar.current.component(.second, from: .now)
        let target = Date.now.addingTimeInterval(seconds > 45 ? 120 : 60)
        let parts = Calendar.current.dateComponents([.hour, .minute], from: target)
        return (parts.hour ?? 0, parts.minute ?? 0)
    }

    private func makeRows(from alarms: [Alarm]) -> [SystemAlarmRow] {
        let wakeAlarms = (try? repository.fetchAll()) ?? []

        return alarms.map { alarm in
            // Work out which WakeAlarm this system alarm belongs to (main or backup N).
            var title = "Lab test alarm"
            for wakeAlarm in wakeAlarms {
                if wakeAlarm.id == alarm.id {
                    title = "\(wakeAlarm.displayTitle) (main)"
                } else if let index = AlarmKitScheduler.backupOffsets.indices.first(where: {
                    AlarmKitScheduler.backupID(for: wakeAlarm.id, index: $0) == alarm.id
                }) {
                    title = "\(wakeAlarm.displayTitle) (backup \(index + 1))"
                }
            }

            let state: String = switch alarm.state {
            case .scheduled: "Scheduled"
            case .countdown: "Snoozing"
            case .paused: "Paused"
            case .alerting: "RINGING"
            @unknown default: "Unknown"
            }

            return SystemAlarmRow(
                id: alarm.id,
                title: title,
                schedule: describe(alarm.schedule),
                state: state,
                isRinging: alarm.state == .alerting
            )
        }
        .sorted { $0.schedule < $1.schedule }
    }

    private func describe(_ schedule: Alarm.Schedule?) -> String {
        switch schedule {
        case .fixed(let date):
            return date.formatted(date: .abbreviated, time: .shortened)
        case .relative(let relative):
            let time = String(format: "%02d:%02d", relative.time.hour, relative.time.minute)
            switch relative.repeats {
            case .never: return "\(time) once"
            case .weekly(let days): return "\(time) weekly (\(days.count) days)"
            @unknown default: return time
            }
        case nil:
            return "—"
        @unknown default:
            return "?"
        }
    }
}
