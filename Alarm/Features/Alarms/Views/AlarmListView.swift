//
//  AlarmListView.swift
//  RiseUp
//
//  LAYER: View (Screen #6, the first screen of the Alarms tab)
//  WHAT:  Next-alarm header, one card per alarm, swipe-to-delete, floating "+" button,
//         and an empty state when there are no alarms.
//  VIEWMODEL: AlarmListViewModel (all decisions live there).
//  DATA:  none directly. It only reads `viewModel.rows` (value snapshots) and calls ViewModel methods.
//
//  CONNECTIONS (the full path to this screen):
//    RiseUpApp → RootView → TabView "Alarms" tab → NavigationStack(path: coordinator.alarmsPath)
//      → root = ScreenFactory.makeRoot(for: .alarms) → AlarmListView(viewModel: AlarmListViewModel(...))
//
//    FROM HERE:
//    → "+" / card tap  → viewModel → AppCoordinator.showAlarmEditor → editor is pushed on top
//    → switch          → viewModel.setEnabled → AlarmKitScheduler + AlarmRepository
//    → swipe delete    → viewModel.delete     → AlarmKitScheduler.cancel + AlarmRepository.delete
//    → 🐞 menu (debug) → viewModel.addSampleAlarms
//
//  BUILT FROM: NextAlarmHeaderView, AlarmCardView, FloatingAddButton, GlowCard (Design System)
//

import SwiftUI

struct AlarmListView: View {
    /// LEARN: `@State` keeps the SAME ViewModel alive while this screen exists, even
    /// though SwiftUI re-creates this `struct` many times. See AlarmLabView for more.
    @State private var viewModel: AlarmListViewModel

    init(viewModel: AlarmListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // LEARN: `Group` wraps an `if/else` so we can attach modifiers to whichever
        // branch is showing.
        Group {
            if viewModel.rows.isEmpty {
                emptyState
            } else {
                alarmList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .navigationTitle("Alarms")
        // The floating "+" sits on top of the content, bottom-right, above the tab bar.
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton(accessibilityLabel: "Add alarm") {
                viewModel.addAlarmTapped()          // → coordinator.showAlarmEditor(alarmID: nil)
            }
            .padding(Theme.Spacing.lg)
        }
        .toolbar { debugToolbar }
        // Runs every time this screen becomes visible (first launch, back from the editor,
        // back from another tab) → re-reads alarms and checks them against iOS.
        // LEARN: `.task` is like `.onAppear`, but it can `await` async work, and it's
        // cancelled automatically if the screen disappears before the work finishes.
        .task { await viewModel.load() }
        .alert("Something went wrong", isPresented: isShowingError) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - List

    private var alarmList: some View {
        // LEARN: we use `List` (not ScrollView) because List gives us the native
        // swipe-to-delete gesture for free. The modifiers below remove List's default
        // grey style so our neon cards show through.
        List {
            // Header: re-computed at the start of every minute so the countdown stays correct.
            TimelineView(.everyMinute) { context in
                NextAlarmHeaderView(
                    next: viewModel.nextAlarm(after: context.date),   // → ViewModel finds the soonest alarm
                    now: context.date
                )
            }
            .plainListRow()

            // LEARN: `ForEach(viewModel.rows)` works because AlarmRow is `Identifiable`
            // (it has an `id`), so SwiftUI can tell rows apart and animate inserts/deletes.
            // We pass only `row.id` back to the ViewModel; it finds the real alarm itself.
            ForEach(viewModel.rows) { row in
                AlarmCardView(
                    row: row,
                    onToggle: { isOn in
                        // A switch can't `await`, so we start a Task for the async work.
                        Task { await viewModel.setEnabled(isOn, alarmID: row.id) }
                    },
                    onTap: { viewModel.alarmTapped(alarmID: row.id) }  // → coordinator → editor (edit mode)
                )
                .plainListRow()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.delete(alarmID: row.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)           // hide List's own background
        // WHY: extra space at the bottom so the last card can scroll above the "+" button.
        .contentMargins(.bottom, 96, for: .scrollContent)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(Theme.Gradients.sunrise)
                .symbolEffect(.pulse)

            VStack(spacing: Theme.Spacing.xs) {
                Text("No alarms yet")
                    .font(.riseTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Create an alarm and choose a mission that gets you out of bed.")
                    .font(.riseBody)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Create your first alarm") {
                viewModel.addAlarmTapped()              // → same path as the "+" button
            }
            .buttonStyle(.neon)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: - Toolbar & alert

    /// Debug-only menu (🐞) to add example alarms while the editor doesn't exist yet.
    @ToolbarContentBuilder
    private var debugToolbar: some ToolbarContent {
        #if DEBUG
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Add sample alarms", systemImage: "wand.and.stars") {
                    viewModel.addSampleAlarms()
                }
            } label: {
                Image(systemName: "ladybug.fill")
            }
        }
        #endif
    }

    /// Turns "is there an error message?" into the true/false the alert needs.
    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isShowing in if !isShowing { viewModel.dismissError() } }
        )
    }
}

// MARK: - List row styling

private extension View {
    /// Removes List's default row background, separators and insets, so our cards float freely.
    ///
    /// LEARN: `private extension` = this helper exists only inside this file.
    func plainListRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.lg,
                                      bottom: Theme.Spacing.xs, trailing: Theme.Spacing.lg))
    }
}

// MARK: - Preview

#Preview("With alarms") {
    let dependencies = AppDependencies.preview()
    let gym = WakeAlarm(hour: 6, minute: 30, repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday], label: "Gym")
    gym.missions = [MissionConfig(type: .math)]
    try? dependencies.alarmRepository.insert(gym)
    try? dependencies.alarmRepository.insert(WakeAlarm(hour: 9, minute: 0, repeatDays: [.saturday, .sunday], isEnabled: false))

    return NavigationStack {
        AlarmListView(viewModel: AlarmListViewModel(
            repository: dependencies.alarmRepository,
            scheduler: dependencies.alarmScheduler,
            coordinator: AppCoordinator()
        ))
    }
}

#Preview("Empty") {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        AlarmListView(viewModel: AlarmListViewModel(
            repository: dependencies.alarmRepository,
            scheduler: dependencies.alarmScheduler,
            coordinator: AppCoordinator()
        ))
    }
}
