//
//  MorningAndSleepTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for Phases 5 and 6
//  WHAT:  • WakeStats: streaks (incl. "today not yet"), daily chart points, success rate
//         • DailyQuote: same day → same line
//         • Records calendar: the colour of a day
//         • Morning check-in: the mood is saved on the wake-up record
//         • Sleep: every sound file is in the app, the 3-sound mix limit, "last mix",
//           the bedtime reminder (allowed / not allowed), sleep timer countdown text
//  DATA:  in-memory database + throwaway UserDefaults.
//
//  CONNECTIONS:
//    → TESTS: WakeStats, DailyQuote, RecordsViewModel, WakeRecordRepository,
//             SleepViewModel, SleepPlayerViewModel, MockSleepSoundPlayer, MockBedtimeReminder
//
//  LEARN: a fixed calendar (Gregorian, UTC) makes date tests give the same answer on
//  every Mac and in every time zone.
//

import Foundation
import SwiftData
import Testing
@testable import Alarm

// MARK: - Helpers

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// 2026-10-13 09:00 UTC, our "now".
private let now = utc.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 9))!

/// A wake-up `daysAgo` days before `now`, ringing at 06:30 (and up at 06:35 when finished).
private func entry(daysAgo: Int, finished: Bool = true, snoozes: Int = 0, mood: Mood? = nil) -> WakeEntry {
    let day = utc.date(byAdding: .day, value: -daysAgo, to: utc.startOfDay(for: now))!
    let rang = day.addingTimeInterval(6.5 * 3600)
    return WakeEntry(id: UUID(), alarmTitle: "Alarm", ringStartedAt: rang,
                     wokeAt: finished ? rang.addingTimeInterval(300) : nil,
                     snoozeCount: snoozes, missionsCompleted: 1, missionSeconds: 40, mood: mood)
}

private func freshSettings() -> AppSettings {
    AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!)
}

// MARK: - Wake statistics

@Suite("Wake statistics")
struct WakeStatsTests {

    @Test("Streak counts days in a row ending today")
    func streakToday() {
        let entries = [entry(daysAgo: 0), entry(daysAgo: 1), entry(daysAgo: 2), entry(daysAgo: 4)]
        #expect(WakeStats.currentStreak(entries, now: now, calendar: utc) == 3)
    }

    @Test("Before today's alarm, yesterday's streak still counts")
    func streakNotBrokenYet() {
        let entries = [entry(daysAgo: 1), entry(daysAgo: 2)]
        #expect(WakeStats.currentStreak(entries, now: now, calendar: utc) == 2)
    }

    @Test("A missed day breaks the streak; unfinished wake-ups don't count")
    func streakBroken() {
        #expect(WakeStats.currentStreak([entry(daysAgo: 2), entry(daysAgo: 3)], now: now, calendar: utc) == 0)
        #expect(WakeStats.currentStreak([entry(daysAgo: 0, finished: false)], now: now, calendar: utc) == 0)
        #expect(WakeStats.currentStreak([], now: now, calendar: utc) == 0)
    }

    @Test("Best streak finds the longest run, even in the past")
    func bestStreak() {
        let entries = [entry(daysAgo: 0), entry(daysAgo: 5), entry(daysAgo: 6), entry(daysAgo: 7), entry(daysAgo: 9)]
        #expect(WakeStats.bestStreak(entries, calendar: utc) == 3)
    }

    @Test("Daily points: one per day, oldest first, empty days included")
    func dailyPoints() {
        let entries = [entry(daysAgo: 0, snoozes: 2, mood: .good), entry(daysAgo: 2)]
        let points = WakeStats.dailyPoints(entries, days: 7, now: now, calendar: utc)

        #expect(points.count == 7)
        #expect(points.last?.day == utc.startOfDay(for: now))
        #expect(points.last?.wakeMinuteOfDay == 6 * 60 + 35)
        #expect(points.last?.snoozes == 2)
        #expect(points.last?.mood == .good)
        #expect(points[points.count - 2].wakeMinuteOfDay == nil, "yesterday had no wake-up")
        #expect(WakeStats.averageWakeMinute(points) == 6 * 60 + 35)
    }

    @Test("Average up time works across midnight")
    func averageAcrossMidnight() {
        func point(_ minute: Int) -> WakeDayPoint {
            WakeDayPoint(day: now, wakeMinuteOfDay: minute, snoozes: 0, missionSeconds: 0, mood: nil)
        }
        #expect(WakeStats.averageWakeMinute([point(23 * 60 + 50), point(10)]) == 0)        // 00:00, not noon
        #expect(WakeStats.averageWakeMinute([point(6 * 60), point(7 * 60)]) == 6 * 60 + 30)
        #expect(WakeStats.averageWakeMinute([]) == nil)
    }

    @Test("Success rate and average mission time")
    func rates() {
        let entries = [entry(daysAgo: 0), entry(daysAgo: 1), entry(daysAgo: 2), entry(daysAgo: 3, finished: false)]
        #expect(WakeStats.successRate(entries) == 0.75)
        #expect(WakeStats.successRate([]) == nil)
        #expect(WakeStats.averageMissionSeconds(entries) == 40)
    }

    @Test("Daily quote is the same all day and changes the next day")
    func dailyQuote() {
        let later = now.addingTimeInterval(10 * 3600)
        let tomorrow = now.addingTimeInterval(24 * 3600)
        #expect(DailyQuote.forDay(now, calendar: utc) == DailyQuote.forDay(later, calendar: utc))
        #expect(DailyQuote.forDay(now, calendar: utc) != DailyQuote.forDay(tomorrow, calendar: utc))
    }

    @Test("Calendar colour of a day")
    func dayStatus() {
        #expect(RecordsViewModel.status(of: []) == .none)
        #expect(RecordsViewModel.status(of: [entry(daysAgo: 0)]) == .clean)
        #expect(RecordsViewModel.status(of: [entry(daysAgo: 0, snoozes: 1)]) == .snoozed)
        #expect(RecordsViewModel.status(of: [entry(daysAgo: 0, finished: false)]) == .missed)
        // Gave up once, then got up properly: the day still counts as a wake-up.
        #expect(RecordsViewModel.status(of: [entry(daysAgo: 0, finished: false), entry(daysAgo: 0)]) == .clean)
    }
}

// MARK: - Morning check-in

@Suite("Morning check-in")
struct MorningCheckInTests {

    @Test("The mood is saved on the wake-up record and shows in the live entries")
    func moodSaved() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let records = WakeRecordRepository(context: container.mainContext)
        let record = try records.openRecord(alarmID: UUID(), alarmTitle: "Gym")

        try records.setMood(.great, forRecordID: record.id)

        #expect(records.entries.first?.mood == .great)
        try records.setMood(nil, forRecordID: record.id)
        #expect(records.entries.first?.mood == nil, "the user can take the answer back")
    }
}

// MARK: - Sleep sounds

@Suite("Sleep sounds")
struct SleepTests {
    let player = MockSleepSoundPlayer()
    let reminder = MockBedtimeReminder()
    let settings = freshSettings()

    func makeViewModel() -> SleepViewModel {
        SleepViewModel(player: player, settings: settings, reminder: reminder, coordinator: AppCoordinator())
    }

    @Test("Every sleep sound has its audio file in the app", arguments: SleepSound.allCases)
    func fileExists(sound: SleepSound) {
        #expect(Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") != nil)
    }

    @Test("Every sound belongs to exactly one category")
    func categories() {
        let listed = SleepSound.Category.allCases.flatMap(\.sounds)
        #expect(listed.count == SleepSound.allCases.count)
        #expect(Set(listed) == Set(SleepSound.allCases))
    }

    @Test("The mix holds at most 3 sounds and explains why")
    func mixLimit() {
        let viewModel = makeViewModel()
        viewModel.toggle(.rain)
        viewModel.toggle(.fire)
        viewModel.toggle(.fan)
        viewModel.toggle(.ocean)                    // 4th: refused

        #expect(player.activeSounds == [.rain, .fire, .fan])
        #expect(viewModel.message != nil)
        #expect(viewModel.mixTitle == "Rain + Fireplace + Fan")
    }

    @Test("The last mix is remembered and plays again with its volumes")
    func lastMix() {
        let viewModel = makeViewModel()
        viewModel.toggle(.rain)
        viewModel.toggle(.brown)
        let playerScreen = SleepPlayerViewModel(player: player, settings: settings, coordinator: AppCoordinator())
        playerScreen.setVolume(0.3, for: .brown)
        playerScreen.saveVolumes()
        player.stopAll()

        #expect(viewModel.canPlayLastMix)
        viewModel.playLastMix()

        #expect(Set(player.activeSounds) == [.rain, .brown])
        #expect(player.volumes[.brown] == 0.3)
        #expect(!viewModel.canPlayLastMix, "hidden while something plays")
    }

    @Test("Sleep timer: choosing a chip starts it, tapping it again cancels")
    func sleepTimer() {
        let playerScreen = SleepPlayerViewModel(player: player, settings: settings, coordinator: AppCoordinator())
        player.toggle(.rain)

        playerScreen.chooseTimer(30)
        #expect(playerScreen.activeTimerChoice == 30)
        #expect(player.timerEndsAt != nil)

        playerScreen.chooseTimer(30)
        #expect(playerScreen.activeTimerChoice == nil)
        #expect(player.timerEndsAt == nil)
    }

    @Test("Countdown text")
    func countdownText() {
        #expect(SleepPlayerViewModel.remainingText(until: now.addingTimeInterval(125), now: now) == "2:05")
        #expect(SleepPlayerViewModel.remainingText(until: now.addingTimeInterval(-5), now: now) == "0:00")
        #expect(SleepPlayerViewModel.remainingText(until: now.addingTimeInterval(3_725), now: now) == "1:02:05")
    }

    @Test("Bedtime reminder: on → scheduled at the saved time; off → cancelled")
    func reminderOnOff() async {
        let viewModel = makeViewModel()
        #expect(!viewModel.reminderOn, "off by default")

        await viewModel.setReminder(true)
        #expect(viewModel.reminderOn)
        #expect(reminder.scheduledTime?.hour == 22)
        #expect(reminder.scheduledTime?.minute == 30)

        await viewModel.setReminder(false)
        #expect(!viewModel.reminderOn)
        #expect(reminder.scheduledTime == nil)
    }

    @Test("Switching the reminder OFF while the permission popup is open wins")
    func reminderRace() async throws {
        let slow = SlowPermissionReminder()
        let viewModel = SleepViewModel(player: player, settings: settings, reminder: slow, coordinator: AppCoordinator())

        let turnOn = Task { await viewModel.setReminder(true) }   // the "popup" is open for 0.3 s…
        try await Task.sleep(for: .milliseconds(50))
        await viewModel.setReminder(false)                         // …and the user changes their mind
        await turnOn.value

        #expect(!viewModel.reminderOn)
        #expect(!slow.didSchedule, "the old ON tap must not schedule anything")
    }

    @Test("Bedtime reminder stays off when notifications aren't allowed")
    func reminderDenied() async {
        reminder.allowsNotifications = false
        let viewModel = makeViewModel()

        await viewModel.setReminder(true)

        #expect(!viewModel.reminderOn)
        #expect(reminder.scheduledTime == nil)
        #expect(viewModel.message != nil, "the user is told how to fix it")
    }
}

/// A reminder whose permission popup takes a moment to answer (to test the ON → OFF race).
private final class SlowPermissionReminder: BedtimeReminding {
    private(set) var didSchedule = false
    func requestPermission() async -> Bool {
        try? await Task.sleep(for: .milliseconds(300))
        return true
    }
    func schedule(hour: Int, minute: Int) async throws { didSchedule = true }
    func cancel() {}
}

@Suite("Sleep mini player on the tab bar (#39)")
struct SleepMiniPlayerTests {
    let player = MockSleepSoundPlayer()
    let coordinator = AppCoordinator()

    func makeMiniPlayer() -> SleepMiniPlayerViewModel {
        SleepMiniPlayerViewModel(player: player, coordinator: coordinator)
    }

    @Test("Shown on every tab while sounds are on (even paused), but not on the Sleep tab itself")
    func visibility() {
        #expect(!SleepMiniPlayerViewModel.isVisible(activeSounds: [], selectedTab: .alarms), "nothing playing")
        #expect(SleepMiniPlayerViewModel.isVisible(activeSounds: [.rain], selectedTab: .alarms))
        #expect(SleepMiniPlayerViewModel.isVisible(activeSounds: [.rain], selectedTab: .morning))
        #expect(SleepMiniPlayerViewModel.isVisible(activeSounds: [.rain], selectedTab: .settings))
        #expect(!SleepMiniPlayerViewModel.isVisible(activeSounds: [.rain], selectedTab: .sleep),
                "the Sleep tab has its own bigger card")
    }

    @Test("Title: one, two, or 'Rain + 2 more'")
    func titles() {
        let mini = makeMiniPlayer()
        player.toggle(.rain)
        #expect(mini.title == "Rain")
        player.toggle(.ocean)
        #expect(mini.title == "Rain + Ocean")
        player.toggle(.wind)
        #expect(mini.title == "Rain + 2 more")
        #expect(mini.systemImage == SleepSound.rain.systemImage)
    }

    @Test("Pause / play, stop everything, and open the mixer")
    func actions() {
        let mini = makeMiniPlayer()
        player.toggle(.rain)
        #expect(mini.isPlaying)
        mini.togglePause()
        #expect(!mini.isPlaying && player.isPaused)
        mini.togglePause()
        #expect(mini.isPlaying)

        mini.open()
        #expect(coordinator.sheet == .sleepPlayer)

        mini.stop()
        #expect(player.activeSounds.isEmpty)
        #expect(!SleepMiniPlayerViewModel.isVisible(activeSounds: player.activeSounds, selectedTab: .alarms),
                "after ✕ the bar goes away")
    }
}
