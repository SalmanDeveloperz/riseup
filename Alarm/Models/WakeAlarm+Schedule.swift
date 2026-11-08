//
//  WakeAlarm+Schedule.swift
//  RiseUp
//
//  LAYER: Model (computed helpers, nothing stored)
//  WHAT:  "When does this alarm ring next?" for EVERY kind of alarm:
//           • normal alarms ring at hour:minute (optionally on repeat days)
//           • quick alarms ring at one exact moment (`fixedFireDate`)
//           • "Once + days" (#36): repeat days PLUS one extra ring (`extraOnceDate`), e.g. today 12:00
//             and then every Wednesday 12:00
//  DATA:  reads WakeAlarm.
//
//  CONNECTIONS:
//    ← USED BY: AlarmListViewModel (header countdown), AlarmKitScheduler (backup chain dates,
//               main schedule), AlarmSyncService (quick-alarm cleanup), QuickAlarmViewModel
//    → USES:    AlarmScheduleCalculator.nextOccurrence (pure date maths)
//
//  WHY one function for both: every place that asks "when does it ring?" now gets the
//  right answer without needing to know which kind of alarm it is.
//

import Foundation

extension WakeAlarm {
    /// True for alarms made with Quick Alarm ("ring in 10 minutes").
    var isQuickAlarm: Bool { fixedFireDate != nil }

    /// The next moment this alarm will ring, strictly after `date`, or `nil` if never again
    /// (a quick alarm whose moment has passed).
    func nextFireDate(after date: Date) -> Date? {
        if let fixedFireDate {
            return fixedFireDate > date ? fixedFireDate : nil
        }
        let weekly = AlarmScheduleCalculator.nextOccurrence(
            hour: hour,
            minute: minute,
            weekdays: repeatDays,
            after: date
        )
        // "Once + days": the extra ring counts too, whichever comes first.
        // LEARN: `[a, b].compactMap { $0 }.min()` = "the earliest of the two, ignoring a missing one".
        return [weekly, upcomingOnceRing(after: date)].compactMap { $0 }.min()
    }

    // MARK: - "Once + days" (#36)

    /// The extra one-time ring, if it's still to come after `date`. `nil` when there is none, when it
    /// already rang (its moment has passed), or when the alarm doesn't repeat (a one-time alarm is
    /// already "once"; quick alarms never have one).
    func upcomingOnceRing(after date: Date) -> Date? {
        guard fixedFireDate == nil, isRepeating, let extraOnceDate, extraOnceDate > date else { return nil }
        return extraOnceDate
    }

    /// The extra ring, but only when it needs its OWN iOS alarm: when it isn't also one of the weekly
    /// rings. (Once + Wednesday, saved on a Wednesday morning: today IS this Wednesday → `nil`, so it
    /// rings once, not twice.)
    /// ← USED BY: AlarmKitScheduler.schedule (the extra `.fixed` alarm, id = onceRingID)
    func separateOnceRing(after date: Date, calendar: Calendar = .current) -> Date? {
        guard let once = upcomingOnceRing(after: date),
              !AlarmScheduleCalculator.isCoveredByWeekly(once, hour: hour, minute: minute,
                                                         weekdays: repeatDays, calendar: calendar)
        else { return nil }
        return once
    }
}
