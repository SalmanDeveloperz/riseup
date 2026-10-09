//
//  AlarmEditorViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel
//  WHAT:  The "brain" of the Alarm Editor (Screen #8). Holds the draft, saves it to the
//         database, schedules it with iOS, deletes alarms, and closes the screen.
//  DATA:  reads WakeAlarm (to fill the draft), writes WakeAlarm on Save/Delete
//         (through AlarmRepository). The View only ever sees the AlarmDraft value.
//
//  CONNECTIONS (follow the arrows):
//    ← CREATED BY:  ScreenFactory.makeScreen(for: .editor(alarmID:))
//    ← OPENED BY:   AlarmListViewModel.addAlarmTapped() / alarmTapped(alarmID:)
//                   → AppCoordinator.showAlarmEditor → alarmsPath.append(.editor(...))
//    ← OWNED BY:    AlarmEditorView (`@State private var viewModel`)
//    → DATA:        AlarmRepository.fetch(id:) / insert / save / delete
//    → iOS:         AlarmScheduling.requirePermission() / schedule() / cancel()
//    → NAVIGATION:  AppCoordinator.popAlarms()  → back to the Alarm List
//    → SHEETS:      AppCoordinator.presentSoundPicker / presentMissionPicker (results come back
//                   through callbacks into `draft`)
//    → DATE MATHS:  AlarmScheduleCalculator.nextOccurrence + countdownText
//
//  THE SAVE FLOW, step by step (see save() below):
//    1. ask for alarm permission (popup the first time)
//    2. copy the draft into a WakeAlarm (new or existing) and write it to the database
//    3. hand it to iOS with scheduler.schedule()
//    4. pop back to the list. The list redraws by itself (repository.alarms changed).
//

import Foundation
import Observation

@Observable
final class AlarmEditorViewModel {

    // MARK: - State the View reads and edits

    /// The form's values. The View binds controls straight to it: `$viewModel.draft.repeatDays`.
    var draft: AlarmDraft

    /// True when editing an existing alarm, false when creating a new one.
    /// The View uses it for the title ("Edit Alarm" / "New Alarm") and the Delete button.
    let isEditing: Bool

    /// Non-nil → the View shows an alert with this message.
    private(set) var errorMessage: String?

    /// True while Save is running, so the button can't be tapped twice.
    private(set) var isSaving = false

    /// Longest label we allow. TRY: change to 20 and type a long name.
    static let maxLabelLength = 30

    /// Most missions one alarm can have. TRY: change to 5.
    static let maxMissions = 3

    /// Choices shown in the snooze pickers.
    static let snoozeMinuteOptions = [1, 3, 5, 10, 15, 20, 30]
    static let snoozeCountOptions = [1, 2, 3, 5, 10]

    // MARK: - Dependencies

    /// The alarm being edited, or `nil` for a new alarm. We keep only its ID, never the
    /// object itself (same rule as the Alarm List: look up the live object when you act).
    private let alarmID: UUID?
    private let repository: AlarmRepository
    private let scheduler: any AlarmScheduling
    private let coordinator: AppCoordinator

    /// WHY: after "saved but switched off" the alert's OK button should also close the editor.
    private var closesAfterError = false

    /// The draft as it was when the editor opened (to know what changed on Save).
    private let originalDraft: AlarmDraft
    /// Set for quick alarms: their exact ring moment, kept only if the time isn't changed.
    private let originalFixedFireDate: Date?

    init(alarmID: UUID?, repository: AlarmRepository, scheduler: any AlarmScheduling, coordinator: AppCoordinator) {
        self.alarmID = alarmID
        self.repository = repository
        self.scheduler = scheduler
        self.coordinator = coordinator

        // Fill the draft. LEARN: in an `init`, every stored property must get a value
        // before we can call methods on `self`, so we use `static` helpers here.
        // LEARN: Swift requires every stored property to be set before `self` is used,
        // so we build the draft in a local constant first and assign it twice.
        let startingDraft: AlarmDraft
        if let alarmID, let existing = try? repository.fetch(id: alarmID) {
            startingDraft = Self.makeDraft(from: existing)
            isEditing = true
            originalFixedFireDate = existing.fixedFireDate
        } else {
            startingDraft = .newAlarm()
            isEditing = false
            originalFixedFireDate = nil
        }
        draft = startingDraft
        originalDraft = startingDraft
    }

    // MARK: - Values derived from the draft (read by the View)

    /// The draft's time as a `Date`, because SwiftUI's time wheel (`DatePicker`) works with Dates.
    ///
    /// LEARN: a computed property with `get` AND `set` can be bound like a stored one:
    /// the View writes `$viewModel.time`. Reading builds a Date from hour/minute; writing
    /// pulls hour/minute back out of the Date the wheel gives us.
    var time: Date {
        get {
            Calendar.current.date(bySettingHour: draft.hour, minute: draft.minute, second: 0, of: .now) ?? .now
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            draft.hour = parts.hour ?? draft.hour
            draft.minute = parts.minute ?? draft.minute
        }
    }

    /// The label, trimmed to `maxLabelLength` characters as the user types.
    var label: String {
        get { draft.label }
        set { draft.label = String(newValue.prefix(Self.maxLabelLength)) }
    }

    /// "Weekdays", "Once", "Mon, Wed"… shown under the day chips.
    /// → Weekday.summary(for:) in Weekday+Summary.swift
    var repeatSummary: String {
        Weekday.summary(for: draft.repeatDays)
    }

    /// "Rings in 7h 20m": recomputed by the View once a minute (TimelineView).
    /// → AlarmScheduleCalculator.nextOccurrence + countdownText (the same maths as the list header)
    func ringsInText(now: Date) -> String {
        guard let fireDate = AlarmScheduleCalculator.nextOccurrence(
            hour: draft.hour, minute: draft.minute, weekdays: draft.repeatDays, after: now
        ) else { return "" }
        return "Rings in " + AlarmScheduleCalculator.countdownText(from: now, to: fireDate)
    }

    /// Mission alarms use "Start Mission" instead of the system Snooze button
    /// (see AlarmKitScheduler.makeAttributes), so the snooze settings don't apply to them.
    var snoozeAppliesToThisAlarm: Bool {
        draft.missions.isEmpty
    }

    var canAddMission: Bool {
        draft.missions.count < Self.maxMissions
    }

    // MARK: - Sheets (sound & missions)

    /// Opens the Sound Picker; the chosen sound comes back into `draft.sound`.
    /// ← CALLED BY: the Sound row
    /// → AppCoordinator.presentSoundPicker → SoundPickerViewModel → completeSoundPicker → this closure
    ///
    /// LEARN: `[weak self]` stops a "retain cycle": the coordinator holds this closure,
    /// and the closure would otherwise hold this ViewModel forever.
    func chooseSound() {
        coordinator.presentSoundPicker(selected: draft.sound) { [weak self] sound in
            self?.draft.sound = sound
        }
    }

    /// Opens the Mission Picker to add a new mission at the end.
    /// ← CALLED BY: "Add mission"
    func addMission() {
        guard canAddMission else { return }
        coordinator.presentMissionPicker(editing: nil) { [weak self] mission in
            self?.draft.missions.append(mission)
        }
    }

    /// Opens the Mission Picker to change an existing mission (matched by its id).
    /// ← CALLED BY: tapping a mission row
    func editMission(_ mission: MissionDraft) {
        coordinator.presentMissionPicker(editing: mission) { [weak self] updated in
            guard let self, let index = self.draft.missions.firstIndex(where: { $0.id == updated.id }) else { return }
            self.draft.missions[index] = updated
        }
    }

    /// ← CALLED BY: the remove (−) button on a mission row
    func removeMission(_ mission: MissionDraft) {
        draft.missions.removeAll { $0.id == mission.id }
    }

    // MARK: - Actions

    /// Saves the draft to the database and schedules it with iOS, then closes the editor.
    ///
    /// ← CALLED BY: the "Save" toolbar button in AlarmEditorView
    func save() async {
        guard !isSaving else { return }
        if isLocked {
            errorMessage = AlarmListViewModel.lockedMessage
            return
        }
        isSaving = true
        defer { isSaving = false }

        // 1. Permission FIRST, before anything is written.
        // WHY first: if we saved the alarm as "on" and then waited for the popup, the
        // database would say "on" while iOS has nothing scheduled.
        let isAllowed: Bool
        do {
            try await scheduler.requirePermission()
            isAllowed = true
        } catch {
            isAllowed = false
        }

        // 2. Copy the draft into a WakeAlarm and write it to disk.
        let alarm: WakeAlarm
        do {
            if let alarmID, let existing = try repository.fetch(id: alarmID) {
                alarm = existing
                Self.apply(draft, to: alarm)
                // A quick alarm stays "exact" only if its time wasn't changed; otherwise
                // it becomes a normal hour:minute alarm.
                let timeChanged = draft.hour != originalDraft.hour || draft.minute != originalDraft.minute
                    || !draft.repeatDays.isEmpty
                alarm.fixedFireDate = timeChanged ? nil : originalFixedFireDate
                repository.replaceMissions(of: alarm, with: draft.missions)
                // WHY: like the iOS Clock app, saving an alarm switches it on.
                alarm.isEnabled = isAllowed
                try repository.save()                  // → refreshes repository.alarms
            } else {
                alarm = Self.makeAlarm(from: draft)
                alarm.isEnabled = isAllowed
                try repository.insert(alarm)           // → refreshes repository.alarms
                repository.replaceMissions(of: alarm, with: draft.missions)
                try repository.save()
            }
        } catch {
            errorMessage = "Couldn't save the alarm. \(error.localizedDescription)"
            return
        }

        // 3. Hand it to iOS. `schedule` replaces any older version (main + backups).
        guard isAllowed else {
            scheduler.cancel(alarm)  // make sure an older version of it can't ring
            showErrorThenClose("Your alarm was saved but is switched off. \(AlarmPermissionError.denied.localizedDescription)")
            return
        }
        do {
            try await scheduler.schedule(alarm)        // → AlarmKitScheduler → AlarmManager
        } catch {
            alarm.isEnabled = false
            try? repository.save()
            showErrorThenClose("Your alarm was saved but couldn't be switched on. \(error.localizedDescription)")
            return
        }

        // 4. Done → back to the list.
        coordinator.popAlarms()                        // → alarmsPath.removeLast → list shows again
    }

    /// Deletes the alarm being edited: system alarms first, then the database row.
    ///
    /// ← CALLED BY: "Delete Alarm" in the confirmation dialog (edit mode only)
    func delete() {
        guard let alarmID, let alarm = try? repository.fetch(id: alarmID) else {
            coordinator.popAlarms()
            return
        }
        if scheduler.hasPendingMission(alarm) {
            errorMessage = AlarmListViewModel.lockedMessage
            return
        }
        // WHY cancel first: reading a deleted SwiftData object crashes, and cancel needs `alarm.id`.
        scheduler.cancel(alarm)
        do {
            try repository.delete(alarm)
            coordinator.popAlarms()
        } catch {
            errorMessage = "Couldn't delete the alarm. \(error.localizedDescription)"
        }
    }

    /// Leaves without saving. The draft is simply dropped; the database never changed.
    ///
    /// ← CALLED BY: the "Cancel" toolbar button
    func cancel() {
        coordinator.popAlarms()
    }

    /// ← CALLED BY: the alert's OK button
    func dismissError() {
        errorMessage = nil
        if closesAfterError {
            closesAfterError = false
            coordinator.popAlarms()
        }
    }

    /// Fills in "Weekdays" / "Weekends" / "Every day" / clears the days.
    /// ← CALLED BY: the preset buttons under the day chips (RepeatDaysPicker)
    func applyRepeatPreset(_ days: Set<Weekday>) {
        draft.repeatDays = days
    }

    // MARK: - Helpers

    /// True while this alarm's mission is pending (see AlarmScheduling.hasPendingMission).
    /// Editing it then could cancel the backups and let the user dodge the mission.
    var isLocked: Bool {
        guard let alarmID, let alarm = try? repository.fetch(id: alarmID) else { return false }
        return scheduler.hasPendingMission(alarm)
    }

    private func showErrorThenClose(_ message: String) {
        closesAfterError = true
        errorMessage = message
    }

    /// Live WakeAlarm → editable draft (copying values out).
    private static func makeDraft(from alarm: WakeAlarm) -> AlarmDraft {
        AlarmDraft(
            hour: alarm.hour,
            minute: alarm.minute,
            repeatDays: alarm.repeatDays,
            label: alarm.label,
            sound: AlarmSound.from(alarm.soundName),
            isSnoozeEnabled: alarm.isSnoozeEnabled,
            snoozeMinutes: alarm.snoozeMinutes,
            maxSnoozeCount: alarm.maxSnoozeCount,
            missions: alarm.sortedMissions.map {
                MissionDraft(id: $0.id, type: $0.type, difficulty: $0.difficulty, repetitions: $0.repetitions)
            }
        )
    }

    /// Draft → existing WakeAlarm (copying values in). Missions are handled by
    /// AlarmRepository.replaceMissions in save().
    private static func apply(_ draft: AlarmDraft, to alarm: WakeAlarm) {
        alarm.hour = draft.hour
        alarm.minute = draft.minute
        alarm.repeatDays = draft.repeatDays
        alarm.label = draft.label.trimmingCharacters(in: .whitespaces)
        alarm.soundName = draft.sound.rawValue
        alarm.isSnoozeEnabled = draft.isSnoozeEnabled
        alarm.snoozeMinutes = draft.snoozeMinutes
        alarm.maxSnoozeCount = draft.maxSnoozeCount
    }

    /// Draft → brand-new WakeAlarm.
    private static func makeAlarm(from draft: AlarmDraft) -> WakeAlarm {
        WakeAlarm(
            hour: draft.hour,
            minute: draft.minute,
            repeatDays: draft.repeatDays,
            label: draft.label.trimmingCharacters(in: .whitespaces),
            soundName: draft.sound.rawValue,
            isSnoozeEnabled: draft.isSnoozeEnabled,
            snoozeMinutes: draft.snoozeMinutes,
            maxSnoozeCount: draft.maxSnoozeCount
        )
    }
}
