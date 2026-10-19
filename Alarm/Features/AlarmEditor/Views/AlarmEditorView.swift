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
//    → Wallpaper row  → viewModel.chooseWallpaper() → Wallpaper Picker sheet → result into draft.wallpaper
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
                        .foregroundStyle(Theme.Colors.onAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Gradients.brand, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
                }
                timeCard
                // WHY second (lead's UX review, #38): the mission is what makes RiseUp different; it must
                // be seen without scrolling, right after "when".
                MissionCard(viewModel: viewModel)          // → MissionCard.swift
                repeatCard
                labelCard
                soundCard
                wallpaperCard
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
        .task { await viewModel.loadWallpaperPhoto() }
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
                        .foregroundStyle(Theme.Gradients.brand)
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
                    alsoOnce: $viewModel.draft.alsoOnce,             // "Once + days" (#36)
                    onPreset: { viewModel.applyRepeatPreset($0) }    // → ViewModel
                )
                // "Once + days": say exactly what will happen ("Rings once today at 12:00 PM, then every Wed.").
                // Re-read every minute: at midnight "today" becomes "tomorrow".
                TimelineView(.everyMinute) { _ in
                    if let detail = viewModel.onceAndDaysDetail(now: .now) {
                        Label(detail, systemImage: "1.circle.fill")
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.hasOnceAndDays)
            }
        }
    }

    private var labelCard: some View {
        GlowCard {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(Theme.Gradients.brand)
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

    /// Sound: tap to open the Sound Picker. → viewModel.chooseSound()
    private var soundCard: some View {
        Button {
            viewModel.chooseSound()                       // → coordinator → Sound Picker sheet
        } label: {
            GlowCard {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: viewModel.draft.sound.systemImage)
                        .font(.title3)
                        .foregroundStyle(Theme.Gradients.brand)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sound").font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                        Text(viewModel.draft.sound.subtitle).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Text(viewModel.draft.sound.title)
                        .font(.riseBody)
                        .foregroundStyle(Theme.Colors.accent)
                    Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// The Ringing screen's wallpaper, with a tiny live preview.
    private var wallpaperCard: some View {
        Button {
            viewModel.chooseWallpaper()                   // → coordinator → Wallpaper Picker sheet
        } label: {
            GlowCard {
                HStack(spacing: Theme.Spacing.md) {
                    WallpaperView(wallpaper: viewModel.effectiveWallpaper, photo: viewModel.wallpaperPhoto, isThumbnail: true)
                        .frame(width: 32, height: 52)
                        .clipShape(.rect(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wallpaper").font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                        Text(viewModel.wallpaperSubtitle).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Text(viewModel.wallpaperTitle)
                        .font(.riseBody)
                        .foregroundStyle(Theme.Colors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
                        .tint(Theme.Colors.accent)
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
                        .tint(Theme.Colors.accent)
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
                    Label("Wake-up check", systemImage: "eyes") 
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Picker("Wake-up check", selection: viewModel.offersWakeUpCheck ? $viewModel.draft.wakeUpCheckMinutes : .constant(0)) {
                        ForEach(AlarmEditorViewModel.wakeUpCheckOptions, id: \.self) { minutes in
                            Text(minutes == 0 ? "Off" : "After \(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Colors.accent)
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
                .foregroundStyle(Theme.Colors.accent)
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
            wallpaperStore: dependencies.wallpaperStore,
            customSounds: dependencies.customSounds,
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
            wallpaperStore: dependencies.wallpaperStore,
            customSounds: dependencies.customSounds,
            coordinator: AppCoordinator()
        ))
    }
}
