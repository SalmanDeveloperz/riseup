//
//  AlarmEditorView.swift
//  RiseUp
//
//  LAYER: View (Screen #8)
//  WHAT:  Create or edit an alarm: time wheel, "Rings in…", repeat days, label,
//         mission & sound rows (pickers arrive later), snooze, delete.
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
                timeCard
                repeatCard
                labelCard
                missionAndSoundCard
                snoozeCard
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
                TimelineView(.everyMinute) { context in
                    Text(viewModel.ringsInText(now: context.date))
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

    /// Missions and sound are shown but not editable yet; their pickers come next.
    private var missionAndSoundCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Label("Mission", systemImage: "bolt.fill")
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    if viewModel.draft.missionTypes.isEmpty {
                        Text("None").font(.riseBody).foregroundStyle(Theme.Colors.textSecondary)
                    } else {
                        HStack(spacing: Theme.Spacing.xs) {
                            ForEach(Array(viewModel.draft.missionTypes.enumerated()), id: \.offset) { _, type in
                                Image(systemName: type.systemImage)
                                    .foregroundStyle(Theme.Colors.neonPink)
                                    .accessibilityLabel(type.title)
                            }
                        }
                    }
                }
                comingSoonNote("Mission picker arrives in Phase 2.")

                Divider().overlay(Theme.Colors.hairline)

                HStack {
                    Label("Sound", systemImage: "speaker.wave.3.fill")
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(viewModel.draft.soundName == "default" ? "Default" : viewModel.draft.soundName)
                        .font(.riseBody)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                comingSoonNote("Sound picker is the next Phase 1 step.")
            }
        }
    }

    private var snoozeCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Toggle(isOn: $viewModel.draft.isSnoozeEnabled) {
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
                    comingSoonNote("The snooze limit is enforced by RiseUp's ringing screen (Phase 2).")
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.draft.isSnoozeEnabled)
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
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                isLabelFocused = false
                Task { await viewModel.save() }          // → permission → database → iOS → pop
            }
            .fontWeight(.bold)
            .disabled(viewModel.isSaving)
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
            coordinator: AppCoordinator()
        ))
    }
}
