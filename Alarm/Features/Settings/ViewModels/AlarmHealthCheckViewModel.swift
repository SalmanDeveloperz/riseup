//
//  AlarmHealthCheckViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #28 "Why didn't my alarm ring?")
//  WHAT:  Runs a list of checks and offers a fix for each problem:
//           1. Alarm permission            → Allow / Open Settings
//           2. Any alarm switched on?      → (info)
//           3. Alarms really scheduled in iOS (compares database ↔ iOS) → Repair
//           4. Mission backups armed        → Repair
//           5. Camera allowed (only if a Photo/Barcode mission exists)   → Open Settings
//           6. Motion allowed (only if a Steps mission exists)           → Open Settings
//           7. Tips: Silent mode, volume, closing the app
//  DATA:  reads WakeAlarm (AlarmRepository), system alarms (AlarmScheduling). "Repair" runs a sync.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .alarmCheck)
//    ← OPENED BY:  SettingsViewModel.open(.alarmCheck)
//    → READS:      AlarmRepository.alarms, AlarmScheduling (permission, systemAlarms, …),
//                  CameraAccess.permission, StepCounting.isAvailable
//    → FIXES:      AlarmScheduling.requestPermission, AlarmSyncService.sync, AppCoordinator.presentQuickAlarm
//
//  WHY this screen exists: when an alarm doesn't ring, the cause is almost always outside
//  RiseUp (a permission switched off, a camera blocked…). Showing the exact cause, with a
//  button to fix it, saves the user a 1-star review and us a support email.
//

import Foundation
import Observation

@Observable
final class AlarmHealthCheckViewModel {

    /// LEARN: the raw values give the ORDER: problems first (3) … tips last (0). `Comparable`
    /// lets us sort with `>` and pick the worst with `max()`.
    /// WHY tips are lowest (we saw this while testing): if `.info` ranked above `.ok`, tips
    /// were listed before the green checks and the header showed a lightbulb instead of ✓.
    enum Status: Int, Comparable {
        case info = 0, ok, warning, problem
        static func < (a: Status, b: Status) -> Bool { a.rawValue < b.rawValue }
    }

    /// What tapping a check's button does.
    enum Fix: Equatable {
        case allowAlarms        // shows the system popup
        case openSettings       // the View opens RiseUp's page in the Settings app
        case repairSchedule     // runs a full sync
        case testAlarm          // opens the Quick Alarm sheet
    }

    struct Check: Identifiable {
        let id: String
        let title: String
        let detail: String
        let status: Status
        var fix: Fix? = nil
        var fixTitle: String? = nil
    }

    // MARK: - State the View reads

    private(set) var checks: [Check] = []
    private(set) var isWorking = false

    /// The worst status of all checks, for the big header (tips never count).
    var overallStatus: Status { max(.ok, checks.map(\.status).max() ?? .ok) }

    var headline: String {
        switch overallStatus {
        case .ok, .info: "Everything looks good"
        case .warning: "Almost there"
        case .problem: "Something needs fixing"
        }
    }

    // MARK: - Dependencies

    private let repository: AlarmRepository
    private let scheduler: any AlarmScheduling
    private let sync: AlarmSyncService
    private let stepCounter: any StepCounting
    private let coordinator: AppCoordinator

    init(repository: AlarmRepository, scheduler: any AlarmScheduling, sync: AlarmSyncService,
         stepCounter: any StepCounting, coordinator: AppCoordinator) {
        self.repository = repository
        self.scheduler = scheduler
        self.sync = sync
        self.stepCounter = stepCounter
        self.coordinator = coordinator
    }

    // MARK: - Actions

    /// Re-runs every check. ← CALLED BY: `.onAppear`, after each fix, and when the app returns
    /// from the Settings app (the user may have just switched a permission on).
    func refresh(now: Date = .now) {
        var result: [Check] = []
        let alarms = repository.alarms
        let enabled = alarms.filter(\.isEnabled)
        let system = scheduler.systemAlarms()

        // 1. Permission
        switch scheduler.permission {
        case .authorized:
            result.append(Check(id: "permission", title: "RiseUp may schedule alarms",
                                detail: "Alarms ring even in Silent mode, during Focus and when the app is closed.", status: .ok))
        case .notDetermined:
            result.append(Check(id: "permission", title: "Alarm permission not asked yet",
                                detail: "Without it, nothing can ring.", status: .problem,
                                fix: .allowAlarms, fixTitle: "Allow alarms"))
        case .denied:
            result.append(Check(id: "permission", title: "Alarms are switched off for RiseUp",
                                detail: "Settings → RiseUp → Alarms must be on, or no alarm can ring.", status: .problem,
                                fix: .openSettings, fixTitle: "Open Settings"))
        }

        // 2. Anything switched on?
        if enabled.isEmpty {
            result.append(Check(id: "enabled", title: "No alarm is switched on",
                                detail: "Switch an alarm on in the Alarms tab, or create one.", status: .warning))
        }

        // 3. Every enabled alarm really exists in iOS (skip ones being scheduled right now: race guard).
        let missing = enabled.filter { alarm in
            guard !scheduler.isScheduling(alarm) else { return false }
            if let fixed = alarm.fixedFireDate, fixed <= now { return false }   // a quick alarm that already rang
            return system[alarm.id] == nil
        }
        if !enabled.isEmpty {
            result.append(missing.isEmpty
                ? Check(id: "scheduled", title: "All \(enabled.count) alarms are scheduled",
                        detail: "iOS has every switched-on alarm.", status: .ok)
                : Check(id: "scheduled", title: "\(missing.count) alarm(s) missing in iOS",
                        detail: "This can happen after restoring a backup or reinstalling.", status: .problem,
                        fix: .repairSchedule, fixTitle: "Repair now"))
        }

        // 4. Mission backups armed for repeating mission alarms.
        let unprotected = enabled.filter { alarm in
            alarm.isRepeating && alarm.hasMissions &&
                !scheduler.ringingSystemAlarmIDs(for: alarm).subtracting([alarm.id]).contains { system[$0] != nil }
        }
        if !unprotected.isEmpty {
            result.append(Check(id: "backups", title: "Mission backups missing",
                                detail: "Backups ring again if you press Stop without doing the mission.", status: .warning,
                                fix: .repairSchedule, fixTitle: "Repair now"))
        }

        // 5. Camera (only matters if a Photo/Barcode mission is in use).
        let missionTypes = Set(enabled.flatMap { $0.missions.map(\.type) })
        if missionTypes.contains(.photo) || missionTypes.contains(.barcode) {
            switch CameraAccess.permission {
            case .allowed:
                result.append(Check(id: "camera", title: "Camera allowed", detail: "Needed for your Photo/Barcode missions.", status: .ok))
            case .notDetermined:
                result.append(Check(id: "camera", title: "Camera not allowed yet",
                                    detail: "iOS will ask during the mission. Better to allow it now: try the mission in the editor.", status: .warning))
            case .denied:
                result.append(Check(id: "camera", title: "Camera is blocked",
                                    detail: "Your Photo/Barcode missions will switch to Math until you allow the camera.", status: .problem,
                                    fix: .openSettings, fixTitle: "Open Settings"))
            }
        }

        // 6. Motion & Fitness (only matters if a Steps mission is in use).
        if missionTypes.contains(.steps) && !stepCounter.isAvailable {
            result.append(Check(id: "motion", title: "Step counting unavailable",
                                detail: "Motion & Fitness may be off for RiseUp. Steps missions switch to Math until it's on.", status: .problem,
                                fix: .openSettings, fixTitle: "Open Settings"))
        }

        // 7. Good-to-know tips.
        result.append(Check(id: "tip-volume", title: "Check the volume",
                            detail: "Alarm volume follows Settings → Sounds & Haptics → Ringtone and Alerts. Silent mode doesn't mute RiseUp.", status: .info))
        result.append(Check(id: "tip-close", title: "You can close RiseUp",
                            detail: "Alarms are kept by iOS and ring even if the app is closed or the phone restarted.", status: .info))
        result.append(Check(id: "tip-test", title: "Try a test alarm",
                            detail: "Ring a quick alarm in 1 minute to hear it for yourself.", status: .info,
                            fix: .testAlarm, fixTitle: "Test alarm"))

        // Problems first, then warnings, then the rest (stable for equal statuses).
        checks = result.enumerated()
            .sorted { ($0.element.status, -$0.offset) > ($1.element.status, -$1.offset) }
            .map(\.element)
    }

    /// ← CALLED BY: a check's button. `.openSettings` is handled by the View (it opens a URL).
    func perform(_ fix: Fix) async {
        isWorking = true
        defer { isWorking = false }
        switch fix {
        case .allowAlarms:
            _ = await scheduler.requestPermission()          // → the system popup
        case .repairSchedule:
            await sync.sync()                                // → reschedules missing alarms + backups
        case .testAlarm:
            coordinator.presentQuickAlarm()                  // → Quick Alarm sheet
        case .openSettings:
            break
        }
        refresh()
    }
}
