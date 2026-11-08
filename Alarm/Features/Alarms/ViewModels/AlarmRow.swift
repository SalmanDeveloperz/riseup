//
//  AlarmRow.swift
//  RiseUp
//
//  LAYER: ViewModel (display data / "view state")
//  WHAT:  Plain value snapshots of what the Alarm List screen shows: one `AlarmRow`
//         per card, and one `NextAlarmInfo` for the header.
//  DATA:  copies of WakeAlarm values. Nothing here touches the database.
//
//  CONNECTIONS:
//    ← BUILT BY:  AlarmListViewModel.rows / nextAlarm(after:), from AlarmRepository.alarms
//    → SHOWN BY:  AlarmCardView (one AlarmRow) and NextAlarmHeaderView (NextAlarmInfo)
//
//  LEARN: Why not just give the View the `WakeAlarm` object?
//  ─────────────────────────────────────────────────────────
//  `WakeAlarm` is a LIVE database object (a class). If it gets deleted while a card is
//  still on screen, for example during the delete animation, the card reads a dead object
//  and SwiftData crashes the app. We hit exactly this crash while testing.
//
//  An `AlarmRow` is a `struct`: a COPY of the values at one moment. A copy can't "die",
//  so redrawing an old row is always safe. The rule for the whole app:
//      Views receive value snapshots. Only ViewModels touch live @Model objects.
//

import Foundation

/// Everything one alarm card needs to draw itself.
///
/// LEARN: `Equatable` lets SwiftUI compare an old and a new row and skip redrawing
/// cards that didn't change.
nonisolated struct AlarmRow: Identifiable, Equatable {
    /// Same as `WakeAlarm.id`. The ViewModel uses it to find the real alarm when you tap.
    let id: UUID
    let hour: Int
    let minute: Int
    let isEnabled: Bool
    /// e.g. "Gym · Weekdays"
    let subtitle: String
    /// Mission icons to show, in order.
    let missionTypes: [MissionType]
}

/// What the header needs: which alarm rings next, and when.
nonisolated struct NextAlarmInfo: Equatable {
    let title: String
    let fireDate: Date
}
