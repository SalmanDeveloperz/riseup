//
//  AlarmDraft.swift
//  RiseUp
//
//  LAYER: ViewModel (editable value copy / "form state")
//  WHAT:  Everything the Alarm Editor lets you change, as a plain struct.
//  DATA:  a COPY of a WakeAlarm's settings. It never touches the database by itself.
//
//  CONNECTIONS:
//    ← CREATED BY: AlarmEditorViewModel.init (from an existing WakeAlarm, or `.newAlarm(...)`)
//    ← EDITED BY:  AlarmEditorView through bindings like `$viewModel.draft.repeatDays`
//    → WRITTEN TO THE DATABASE ONLY BY: AlarmEditorViewModel.save()
//
//  LEARN: Why edit a draft and not the WakeAlarm directly?
//  ───────────────────────────────────────────────────────
//  If the editor changed the live WakeAlarm while you type, those changes would already
//  be in memory, the Alarm List behind it would show them, and "Cancel" would need to
//  undo each one. With a draft:
//    • Cancel = just throw the draft away. Nothing else changed.
//    • Save   = copy the draft into the WakeAlarm in ONE step, then schedule.
//  It's the same idea as AlarmRow (a value snapshot), but this one is editable.
//

import Foundation

nonisolated struct AlarmDraft: Equatable {
    /// 0...23
    var hour: Int
    /// 0...59
    var minute: Int
    /// Empty = rings once.
    var repeatDays: Set<Weekday>
    /// Optional name, e.g. "Gym".
    var label: String
    /// The alarm sound (→ AlarmSound.swift). Chosen in the Sound Picker.
    var sound: AlarmSound
    var isSnoozeEnabled: Bool
    var snoozeMinutes: Int
    var maxSnoozeCount: Int
    /// Missions in the order they run. Edited through the Mission Picker sheet.
    var missions: [MissionDraft]

    /// Settings for a brand-new alarm: the current time, rings once, Radar sound, snooze 5 min × 3.
    ///
    /// TRY: change `snoozeMinutes: 5` to `10` and create a new alarm: the picker starts at 10.
    static func newAlarm(now: Date = .now, calendar: Calendar = .current) -> AlarmDraft {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        return AlarmDraft(
            hour: parts.hour ?? 7,
            minute: parts.minute ?? 0,
            repeatDays: [],
            label: "",
            sound: .radar,
            isSnoozeEnabled: true,
            snoozeMinutes: 5,
            maxSnoozeCount: 3,
            missions: []
        )
    }
}
