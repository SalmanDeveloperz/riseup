//
//  AlarmEditorView.swift
//  RiseUp
//
//  LAYER: View (Screen #8)
//  WHAT:  Create or edit an alarm: time wheel, "Rings in…", repeat days, label,
//         missions (add/edit/remove), sound, snooze, delete.
//  VIEWMODEL: AlarmEditorViewModel (all decisions live there).
//  DATA:  none directly. Controls are bound to `viewModel.draft` (a value copy).
//
//  CONNECTIONS (the full path to this screen):
//    Alarm List "+" or card tap → AlarmListViewModel → AppCoordinator.showAlarmEditor(alarmID:)
//      → alarmsPath.append(.editor(alarmID:)) → RootView's Alarms NavigationStack pushes
//      → ScreenFactory.makeScreen(for: .editor) → AlarmEditorView(viewModel: AlarmEditorViewModel(...))
//
//    FROM HERE:
//    → Save   → viewModel.save()   → permission → AlarmRepository → AlarmKitScheduler → pop
//    → Sound row      → viewModel.chooseSound()  → Sound Picker sheet → result into draft.sound
//    → Add mission    → viewModel.addMission()   → Mission Picker sheet → result into draft.missions
//    → Cancel → viewModel.cancel() → pop (draft thrown away)
//    → Delete → viewModel.delete() → AlarmKitScheduler.cancel + AlarmRepository.delete → pop
//
//  BUILT FROM: RepeatDaysPicker, GlowCard, NeonToggleStyle, NeonButtonStyle (Design System)
//

import SwiftUI

struct AlarmEditorView: View {
    @State private var viewModel: AlarmEditorViewModel
    @State private var isConfirmingDelete = false

    /// LEARN: `@FocusState` tracks which text field has the keyboard. We use it to hide
    /// the keyboard when the user taps "Done".
    @FocusState private var isLabelFocused: Bool

    init(viewModel: AlarmEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if viewModel.isLocked {
                    Label("This alarm's mission is pending. Finish it before editing.", systemImage: "lock.fill")
                        .font(.riseHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Gradients.sunrise, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
                }
                timeCard
                repeatCard
                labelCard
                missionCard
                soundCard
                snoozeCard
                wakeUpCheckCard
                if viewModel.isEditing {
                    deleteButton
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        // LEARN: drag the list down to hide the keyboard.
        .scrollDismissesKeyboard(.interactively)
        .appBackground()
        .navigationTitle(viewModel.isEditing ? "Edit Alarm" : "New Alarm")
        .navigationBarTitleDisplayMode(.inline)
        // WHY hide the back button: we show "Cancel" and "Save" instead, so it's clear
        // whether leaving keeps your changes.
        .navigationBarBackButtonHidden()
        // WHY hide the tab bar: the editor is a focused task; tabs would invite leaving mid-edit.
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbarContent }
        .onAppear { viewModel.refreshLock() }
        .alert("Alarm", isPresented: isShowingError) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("Delete this alarm?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Alarm", role: .destructive) { viewModel.delete() }
        }
    }

    // MARK: - Cards

    /// The big time wheel with "Rings in 7h 20m" under it.
    private var timeCard: some View {
        GlowCard(isGlowing: true) {
            VStack(spacing: Theme.Spacing.xs) {
                // LEARN: `DatePicker` with `.wheel` style is the classic iOS spinning wheel.
                // `displayedComponents: .hourAndMinute` hides the date part.
                // It respects 12/24-hour from the user's settings automatically.
                DatePicker("Alarm time", selection: $viewModel.time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                // Re-computed each minute AND whenever the draft changes (it reads viewModel).
                TimelineView(.everyMinute) { _ in
                    Text(viewModel.ringsInText(now: .now))     // `.now`: see AlarmListView's WHY
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Gradients.sunrise)
                        .contentTransition(.numericText())
                }
            }
        }
    }

    private var repeatCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                sectionHeader("Repeat", value: viewModel.repeatSummary)
                RepeatDaysPicker(
                    selection: $viewModel.draft.repeatDays,          // two-way binding into the draft
                    onPreset: { viewModel.applyRepeatPreset($0) }    // → ViewModel
                )
            }
        }
    }

    private var labelCard: some View {
        GlowCard {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(Theme.Gradients.sunrise)
                // `$viewModel.label` goes through the ViewModel's computed property,
                // which trims it to maxLabelLength characters.
                TextField("Label (e.g. Gym)", text: $viewModel.label)
                    .font(.riseBody)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .focused($isLabelFocused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.sentences)
                Text("\(viewModel.draft.label.count)/\(AlarmEditorViewModel.maxLabelLength)")
                    .font(.riseCaption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    /// Missions: a list of rows (tap = edit, − = remove) and "Add mission".
    /// → viewModel.addMission / editMission / removeMission → Mission Picker sheet
    private var missionCard: some View {
        GlowCard(isGlowing: !viewModel.draft.missions.isEmpty) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                sectionHeader("Wake-up mission", value: viewModel.draft.missions.isEmpty ? "None" : "\(viewModel.draft.missions.count) of \(AlarmEditorViewModel.maxMissions)")

                if viewModel.draft.missions.isEmpty {
                    Text("Without a mission, the alarm stops with one tap. Add one to make sure you really get up.")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                ForEach(viewModel.draft.missions) { mission in
                    missionRow(mission)
                }

                if viewModel.canAddMission {
                    Button {
                        viewModel.addMission()            // → coordinator → Mission Picker sheet
                    } label: {
                        Label("Add mission", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.ghost)
                }
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.draft.missions)
    }

    private func missionRow(_ mission: MissionDraft) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                viewModel.editMission(mission)            // → Mission Picker in edit mode
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: mission.type.systemImage)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Theme.Gradients.sunrise, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.type.title).font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                        Text(mission.summary).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.removeMission(mission)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.danger)
                    .frame(width: 44, height: 44)        // a comfortable finger-sized target
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(mission.type.title) mission")
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    /// Sound: tap to open the Sound Picker. → viewModel.chooseSound()
    private var soundCard: some View {
        Button {
            viewModel.chooseSound()                       // → coordinator → Sound Picker sheet
        } label: {
            GlowCard {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: viewModel.draft.sound.systemImage)
                        .font(.title3)
                        .foregroundStyle(Theme.Gradients.sunrise)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sound").font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                        Text(viewModel.draft.sound.subtitle).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Text(viewModel.draft.sound.title)
                        .font(.riseBody)
                        .foregroundStyle(Theme.Colors.neonPink)
                    Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var snoozeCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // WHY `.constant(false)` for mission alarms: they can't snooze, so the switch must
                // LOOK off too (it used to show "on" while greyed out, which was confusing).
                Toggle(isOn: viewModel.snoozeAppliesToThisAlarm ? $viewModel.draft.isSnoozeEnabled : .constant(false)) {
                    Label("Snooze", systemImage: "zzz")
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .toggleStyle(.neon)
                .disabled(!viewModel.snoozeAppliesToThisAlarm)

                if !viewModel.snoozeAppliesToThisAlarm {
                    comingSoonNote("Mission alarms show “Start Mission” instead of Snooze.")
                } else if viewModel.draft.isSnoozeEnabled {
                    HStack {
                        Text("Length").foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        // LEARN: `Picker` with `.menu` style shows a compact pop-up list.
                        // `tag(...)` is the value each row stands for.
                        Picker("Snooze length", selection: $viewModel.draft.snoozeMinutes) {
                            ForEach(AlarmEditorViewModel.snoozeMinuteOptions, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.Colors.neonPink)
                    }
                    .font(.riseBody)

                    HStack {
                        Text("Times").foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Picker("Snooze limit", selection: $viewModel.draft.maxSnoozeCount) {
                            ForEach(AlarmEditorViewModel.snoozeCountOptions, id: \.self) { count in
                                Text("\(count)×").tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.Colors.neonPink)
                    }
                    .font(.riseBody)

                    // WHY this note: AlarmKit's lock-screen Snooze button can't be limited by apps.
                    // Our limit will be enforced by RiseUp's own ringing screen (Phase 2).
                    comingSoonNote("When the alarm rings inside RiseUp, Snooze disappears after this many times.")
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.draft.isSnoozeEnabled)
    }

    /// Wake-Up Check (#18): one more "are you up?" ring a few minutes after getting up.
    /// Bound straight to the draft; AlarmEditorViewModel.save() copies it into the WakeAlarm.
    private var wakeUpCheckCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Label("Wake-up check", systemImage: "eye.fill")
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Picker("Wake-up check", selection: viewModel.offersWakeUpCheck ? $viewModel.draft.wakeUpCheckMinutes : .constant(0)) {
                        ForEach(AlarmEditorViewModel.wakeUpCheckOptions, id: \.self) { minutes in
                            Text(minutes == 0 ? "Off" : "After \(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Colors.neonPink)
                    .disabled(!viewModel.offersWakeUpCheck)
                }
                if !viewModel.offersWakeUpCheck {
                    comingSoonNote("Not available for quick alarms: they disappear right after ringing. Change the time to make this a normal alarm.")
                } else {
                    comingSoonNote(viewModel.draft.wakeUpCheckMinutes == 0
                        ? "Rings once more a few minutes after you're up, in case you went back to bed."
                        : "\(viewModel.draft.wakeUpCheckMinutes) minutes after you're up, RiseUp asks “Are you up?” with one more ring. Stop it (or open RiseUp) to answer.")
                }
            }
        }
    }

    private var deleteButton: some View {
        Button("Delete Alarm", role: .destructive) {
            isConfirmingDelete = true
        }
        .buttonStyle(.ghost)              // role: .destructive → GhostButtonStyle makes it red
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { viewModel.cancel() }      // → pop, draft discarded
                .disabled(viewModel.isSaving)            // don't leave halfway through saving
        }
        ToolbarItem(placement: .confirmationAction) {
            if viewModel.isSaving {
                ProgressView()                           // visible feedback while iOS schedules the alarm
            } else {
                Button("Save") {
                    isLabelFocused = false
                    Task { await viewModel.save() }      // → permission → database → iOS → pop
                }
                .fontWeight(.bold)
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { isLabelFocused = false }
        }
    }

    // MARK: - Small building blocks

    private func sectionHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.neonPink)
        }
    }

    private func comingSoonNote(_ text: String) -> some View {
        Text(text)
            .font(.riseCaption)
            .foregroundStyle(Theme.Colors.textTertiary)
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isShowing in if !isShowing { viewModel.dismissError() } }
        )
    }
}

// MARK: - Previews

#Preview("New alarm") {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        AlarmEditorView(viewModel: AlarmEditorViewModel(
            alarmID: nil,
            repository: dependencies.alarmRepository,
            scheduler: dependencies.alarmScheduler,
            settings: dependencies.settings,
            coordinator: AppCoordinator()
        ))
    }
}

#Preview("Edit alarm") {
    let dependencies = AppDependencies.preview()
    let gym = WakeAlarm(hour: 6, minute: 30, repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday], label: "Gym")
    gym.missions = [MissionConfig(type: .math)]
    try? dependencies.alarmRepository.insert(gym)

    return NavigationStack {
        AlarmEditorView(viewModel: AlarmEditorViewModel(
            alarmID: gym.id,
            repository: dependencies.alarmRepository,
            scheduler: dependencies.alarmScheduler,
            settings: dependencies.settings,
            coordinator: AppCoordinator()
        ))
    }
}
