//
//  QuickAlarmView.swift
//  RiseUp
//
//  LAYER: View (Screen #7, a half-height sheet)
//  WHAT:  Big "10 min" counter, −/+ buttons, preset chips, "Rings at 4:25 PM", Start.
//  VIEWMODEL: QuickAlarmViewModel.
//
//  CONNECTIONS (the path to this screen):
//    Alarm List ⚡︎ button → AlarmListViewModel.quickAlarmTapped()
//      → AppCoordinator.presentQuickAlarm() → coordinator.sheet = .quickAlarm
//      → RootView `.sheet(item:)` → ScreenFactory.makeScreen(for: SheetRoute) → this view
//

import SwiftUI

struct QuickAlarmView: View {
    @State private var viewModel: QuickAlarmViewModel

    init(viewModel: QuickAlarmViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    counter
                    presets
                }
                .padding(Theme.Spacing.lg)
            }
            // WHY `safeAreaInset`: pins Start to the bottom edge so it's always visible,
            // even when the half-height sheet is too short to show everything.
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await viewModel.start() }      // → permission → save → schedule → close
                } label: {
                    Label("Start", systemImage: "bolt.fill")
                }
                .buttonStyle(.neon)
                .disabled(viewModel.isStarting)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .appBackground()
            .navigationTitle("Quick alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancel() }
                }
            }
            .alert("Quick alarm", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        // LEARN: `.presentationDetents` sets the sheet's heights. `.medium` = half the
        // screen; the user can drag it to `.large` (full height).
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: viewModel.minutes)
    }

    // MARK: - Pieces

    private var counter: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.lg) {
                stepButton("minus") { viewModel.adjust(by: -1) }
                Text(viewModel.durationText)
                    .font(.riseClock(size: 52))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Gradients.sunrise)
                    // LEARN: `.contentTransition(.numericText())` rolls the digits like an
                    // odometer when the number changes.
                    .contentTransition(.numericText())
                    .animation(.snappy, value: viewModel.minutes)
                    .frame(minWidth: 170)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                stepButton("plus") { viewModel.adjust(by: 1) }
            }
            // Refreshes every 15 s so "Rings at" stays right while the sheet is open.
            TimelineView(.periodic(from: .now, by: 15)) { context in
                Text("Rings at \(viewModel.fireDate(now: context.date).formatted(date: .omitted, time: .shortened))")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.top, Theme.Spacing.md)
    }

    private var presets: some View {
        // LEARN: `LazyVGrid` with `.adaptive` fits as many chips per row as the width allows.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
            ForEach(QuickAlarmViewModel.presets, id: \.self) { value in
                let isOn = viewModel.minutes == value
                Button {
                    viewModel.minutes = value
                } label: {
                    Text(value >= 60 && value % 60 == 0 ? "\(value / 60) h" : "\(value) min")
                        .font(.riseHeadline)
                        .foregroundStyle(isOn ? .white : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(isOn ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.surfaceRaised),
                                    in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 52, height: 52)
                .background(Theme.Colors.surfaceRaised, in: .circle)
        }
        .buttonStyle(.plain)
        // LEARN: hold the button to repeat quickly, a nicer feel for big jumps.
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(symbol == "plus" ? "More minutes" : "Fewer minutes")
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    Color.clear.sheet(isPresented: .constant(true)) {
        QuickAlarmView(viewModel: QuickAlarmViewModel(
            repository: dependencies.alarmRepository,
            scheduler: dependencies.alarmScheduler,
            coordinator: AppCoordinator()
        ))
    }
}
