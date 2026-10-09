//
//  WakeAlarm+Schedule.swift
//  RiseUp
//
//  LAYER: Model (computed helpers, nothing stored)
//  WHAT:  "When does this alarm ring next?" for BOTH kinds of alarm:
//           • normal alarms ring at hour:minute (optionally on repeat days)
//           • quick alarms ring at one exact moment (`fixedFireDate`)
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
        return AlarmScheduleCalculator.nextOccurrence(
            hour: hour,
            minute: minute,
            weekdays: repeatDays,
            after: date
        )
    }
}
