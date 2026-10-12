//
//  OnboardingViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screens #1 Welcome, #2 Goal, #3 Permission, #4 First alarm)
//  WHAT:  Walks a new user through 4 pages and (optionally) creates their first alarm,
//         with a mission suggested by their goal.
//  DATA:  writes AppSettings (goal, onboarding done), creates one WakeAlarm (+ mission)
//         through AlarmRepository and schedules it with AlarmScheduling.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .onboarding)
//    ← OPENED BY:  RootView when AppSettings.hasCompletedOnboarding == false
//                  → AppCoordinator.presentOnboarding() → fullScreen = .onboarding
//    → DATA:       AlarmRepository.insert / replaceMissions / save
//    → iOS:        AlarmScheduling.requestPermission / schedule
//    → CLOSE:      AppSettings.hasCompletedOnboarding = true + AppCoordinator.dismissFullScreen()
//
//  WHY explain BEFORE the system popup ("pre-permission"): iOS shows its "Allow alarms?"
//  popup only ONCE. If the user taps "Don't Allow" without knowing why we need it, the
//  only way back is the Settings app. A friendly page first means far more "Allow"s.
//

import Foundation
import Observation

@Observable
final class OnboardingViewModel {

    enum Page: Int, CaseIterable {
        case welcome, goal, permission, firstAlarm
    }

    // MARK: - State the View reads / binds

    private(set) var page: Page = .welcome
    /// Which way we moved last, so the View can slide pages the right way.
    private(set) var movedForward = true
    private(set) var goal: WakeGoal?
    private(set) var permission: AlarmPermission
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    /// First alarm time (the wheel binds to this). Starts at 7:00.
    var time: Date
    /// First alarm repeat days (RepeatDaysPicker binds to this). Starts on weekdays.
    var repeatDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    /// "Add the suggested mission" switch.
    var addsMission = true

    /// The mission we suggest, based on the goal (Math if no goal was picked).
    var suggestedMission: MissionDraft {
        MissionDraft.defaults(for: goal?.suggestedMission ?? .math)
    }

    // MARK: - Dependencies

    private let repository: AlarmRepository
    private let scheduler: any AlarmScheduling
    private let settings: AppSettings
    private let coordinator: AppCoordinator

    init(repository: AlarmRepository, scheduler: any AlarmScheduling, settings: AppSettings,
         coordinator: AppCoordinator, calendar: Calendar = .current) {
        self.repository = repository
        self.scheduler = scheduler
        self.settings = settings
        self.coordinator = coordinator
        self.permission = scheduler.permission
        self.goal = settings.wakeGoal
        self.time = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
    }

    // MARK: - Navigation between pages

    func next() {
        guard let nextPage = Page(rawValue: page.rawValue + 1) else { return }
        movedForward = true
        page = nextPage
    }

    func back() {
        guard let previous = Page(rawValue: page.rawValue - 1) else { return }
        movedForward = false
        page = previous
    }

    // MARK: - Page 2: goal

    func choose(_ goal: WakeGoal) {
        self.goal = goal
        settings.wakeGoal = goal                 // remembered (Settings could show it later)
    }

    // MARK: - Page 3: permission

    /// ← CALLED BY: "Allow alarms" → the system popup (only the first time).
    func allowAlarms() async {
        isWorking = true
        defer { isWorking = false }
        permission = await scheduler.requestPermission()
        if permission == .authorized { next() }  // straight on to the first alarm
    }

    // MARK: - Page 4: first alarm

    /// "Rings in 9h 12m" under the wheel.
    func ringsInText(now: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        guard let fire = AlarmScheduleCalculator.nextOccurrence(
            hour: parts.hour ?? 7, minute: parts.minute ?? 0, weekdays: repeatDays, after: now) else { return "" }
        return "Rings in " + AlarmScheduleCalculator.countdownText(from: now, to: fire)
    }

    /// Creates, saves and schedules the first alarm, then closes onboarding.
    /// ← CALLED BY: "Create my alarm"
    func createAlarm() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let alarm = WakeAlarm(
            hour: parts.hour ?? 7,
            minute: parts.minute ?? 0,
            repeatDays: repeatDays,
            label: "Wake up",
            isEnabled: permission == .authorized,
            soundName: settings.defaultSound.rawValue,
            snoozeMinutes: settings.defaultSnoozeMinutes
        )
        do {
            try repository.insert(alarm)                                     // 1. save
            if addsMission {
                repository.replaceMissions(of: alarm, with: [suggestedMission])
                try repository.save()
            }
            if alarm.isEnabled {
                try await scheduler.schedule(alarm)                          // 2. → AlarmKit
            }
            finish()
        } catch {
            errorMessage = "Your alarm was saved but couldn't be switched on. You can fix it in the Alarms tab. (\(error.localizedDescription))"
        }
    }

    /// ← CALLED BY: "Skip for now" (any page), "Create my alarm" (after success), the error alert's OK
    func finish() {
        settings.hasCompletedOnboarding = true
        coordinator.dismissFullScreen()          // → onboarding slides away, Alarms tab shows
    }

    func dismissError() {
        errorMessage = nil
        finish()
    }
}
