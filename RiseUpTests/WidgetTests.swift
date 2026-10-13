//
//  WidgetTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for the home & lock screen widgets (#31)
//  WHAT:  • WidgetBridge.plan: which rings the widget knows about (off alarms, one-time, repeating,
//           a week ahead, per-alarm wallpaper vs the default, earliest first)
//         • the snapshot moves on by itself after each ring
//         • riseup:// links from the widget are understood (and bad ones ignored)
//         • the coordinator opens the right screen, but never over a ringing alarm
//  DATA:  in-memory alarms (WakeAlarm objects that are never saved), no App Group.
//
//  CONNECTIONS:
//    → TESTS: WidgetBridge.plan, WidgetSnapshot.upcoming(after:), DeepLink, AppCoordinator.open
//

import Foundation
import Testing
@testable import Alarm

@Suite("Widgets")
struct WidgetTests {
    /// Monday 12 Oct 2026, 20:00. LEARN: tests fix "now", so they give the same answer every day.
    let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 20))!

    // MARK: - Planning

    @Test("Switched-off alarms never appear; a one-time alarm appears once")
    func offAndOneTime() {
        let off = WakeAlarm(hour: 6, minute: 0, isEnabled: false)
        let once = WakeAlarm(hour: 7, minute: 30)
        let planned = WidgetBridge.plan(alarms: [off, once], defaultWallpaper: .standard, now: now)
        #expect(planned.count == 1)
        #expect(planned.first?.event.alarmID == once.id)
    }

    @Test("A weekday alarm appears on each weekday of the coming week, earliest first")
    func repeatingWeek() throws {
        let weekdays = WakeAlarm(hour: 7, minute: 0, repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday])
        let planned = WidgetBridge.plan(alarms: [weekdays], defaultWallpaper: .standard, now: now)
        // 8 days ahead from Monday evening: Tue, Wed, Thu, Fri, Mon, Tue = 6 rings.
        #expect(planned.count == 6)
        let dates = planned.map(\.event.fireDate)
        #expect(dates == dates.sorted(), "earliest first")
        #expect(try #require(dates.first) > now)
    }

    @Test("Each ring shows the alarm's own wallpaper, or the default one")
    func wallpapers() {
        let themed = WakeAlarm(hour: 6, minute: 0)
        themed.wallpaperID = Wallpaper.live(.kyotoBlossoms).rawValue
        let plain = WakeAlarm(hour: 6, minute: 30)
        let planned = WidgetBridge.plan(alarms: [themed, plain], defaultWallpaper: .live(.aurora), now: now)
        #expect(planned.map(\.wallpaper) == [.live(.kyotoBlossoms), .live(.aurora)])
        #expect(planned[0].event.wallpaperFile == WidgetShared.wallpaperFileName(for: "live.kyotoBlossoms"))
        #expect(planned[0].event.wallpaperTitle == "Kyoto Blossoms")
    }

    @Test("The widget moves to the next alarm by itself after a ring")
    func movesOn() {
        let first = WidgetAlarmEvent(alarmID: UUID(), fireDate: now.addingTimeInterval(3600), title: "A",
                                     missionSymbols: [], soundTitle: "", wallpaperTitle: "", wallpaperFile: nil)
        var second = first
        second.alarmID = UUID()
        second.fireDate = now.addingTimeInterval(7200)
        let snapshot = WidgetSnapshot(upcoming: [first, second], writtenAt: now)
        #expect(snapshot.upcoming(after: now).first?.alarmID == first.alarmID)
        #expect(snapshot.upcoming(after: first.fireDate).first?.alarmID == second.alarmID)
        #expect(snapshot.upcoming(after: second.fireDate).isEmpty)
    }

    // MARK: - Links

    @Test("riseup:// links are understood; anything else is ignored")
    func deepLinks() throws {
        let id = UUID()
        #expect(DeepLink(url: WidgetShared.newAlarmURL) == .newAlarm)
        #expect(DeepLink(url: WidgetShared.alarmURL(id)) == .alarm(id))
        #expect(DeepLink(url: WidgetShared.napURL(minutes: 20)) == .nap(minutes: 20))
        #expect(DeepLink(url: try #require(URL(string: "riseup://alarm/not-a-uuid"))) == nil)
        #expect(DeepLink(url: try #require(URL(string: "riseup://nap/0"))) == nil)
        #expect(DeepLink(url: try #require(URL(string: "https://example.com/nap/10"))) == nil)
    }

    @Test("A link opens the right screen, closes an open sheet, and never covers a ringing alarm")
    func coordinatorOpensLinks() {
        let coordinator = AppCoordinator()
        coordinator.presentSleepPlayer()
        coordinator.open(.nap(minutes: 20))
        #expect(coordinator.sheet == .quickAlarm(minutes: 20))

        let id = UUID()
        coordinator.open(.alarm(id))
        #expect(coordinator.sheet == nil, "the old sheet closes")
        #expect(coordinator.alarmsPath == [.editor(alarmID: id)])

        coordinator.presentRinging(alarmID: UUID())
        coordinator.open(.newAlarm)
        #expect(coordinator.alarmsPath == [.editor(alarmID: id)], "nothing changes during a wake-up")
    }
}
