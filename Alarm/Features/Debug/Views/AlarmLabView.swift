//
//  AlarmLabView.swift
//  RiseUp
//
//  LAYER: View (debug tool, Phase 0 spike)
//  WHAT:  Buttons to run each AlarmKit experiment + a live list of system alarms + a log.
//  USED BY: Settings → Developer → AlarmKit Lab (route: SettingsRoute.alarmKitLab).
//  VIEWMODEL: AlarmLabViewModel (all logic lives there).
//
//  HOW TO USE: see docs/SPIKE_RESULTS.md. Run on your real iPhone, not the Simulator.
//

import SwiftUI

struct AlarmLabView: View {
    /// LEARN: `@State` owns the ViewModel, so it survives when SwiftUI re-creates this
    /// struct (that happens often; View structs are cheap, throwaway descriptions).
    @State private var viewModel: AlarmLabViewModel

    init(viewModel: AlarmLabViewModel) {
        // LEARN: the underscore `_viewModel` is the State wrapper itself.
        // This sets its *initial* value. Later re-inits are ignored by SwiftUI.
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                permissionCard
                experimentsCard
                systemAlarmsCard
                logCard
            }
            .padding(Theme.Spacing.lg)
        }
        .appBackground()
        .navigationTitle("AlarmKit Lab")
        .navigationBarTitleDisplayMode(.inline)
        // LEARN: `.task` starts async work when the view appears and cancels it
        // automatically when the view disappears.
        .task { await viewModel.observeSystemAlarms() }
        .disabled(viewModel.isBusy)
    }

    // MARK: - Sections

    private var permissionCard: some View {
        GlowCard(isGlowing: viewModel.permission == .authorized) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                header("A · Permission", detail: "\(viewModel.permission)")
                if viewModel.permission != .authorized {
                    Button("Request alarm permission") {
                        // LEARN: Buttons are synchronous; `Task { }` starts async work from them.
                        Task { await viewModel.requestPermission() }
                    }
                    .buttonStyle(.neon)
                }
                if viewModel.permission == .denied {
                    Text("Denied: enable it in iOS Settings → RiseUp → Alarms.")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.warning)
                }
            }
        }
    }

    private var experimentsCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header("B · Custom sound (rings in 60 s)", detail: nil)
                ForEach(AlarmLabViewModel.SoundVariant.allCases) { variant in
                    Button(variant.rawValue) {
                        Task { await viewModel.scheduleSoundTest(variant) }
                    }
                    .buttonStyle(.ghost)
                }

                Divider().overlay(Theme.Colors.hairline)

                header("C · Mission alarm + backups", detail: nil)
                Toggle("Repeat on today's weekday", isOn: $viewModel.repeatsToday)
                    .toggleStyle(.neon)
                    .font(.riseBody)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Button("Create mission alarm (next minute)") {
                    Task { await viewModel.createMissionAlarm() }
                }
                .buttonStyle(.neon)

                Divider().overlay(Theme.Colors.hairline)

                header("D · Snooze (1 minute)", detail: nil)
                Button("Create snooze alarm (next minute)") {
                    Task { await viewModel.createSnoozeAlarm() }
                }
                .buttonStyle(.ghost)

                Divider().overlay(Theme.Colors.hairline)

                header("E · How many alarms are allowed?", detail: nil)
                Button("Run limit test") {
                    Task { await viewModel.runLimitTest() }
                }
                .buttonStyle(.ghost)
            }
        }
    }

    private var systemAlarmsCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                header("Scheduled system alarms", detail: "\(viewModel.systemAlarms.count)")
                if viewModel.systemAlarms.isEmpty {
                    Text("None").font(.riseCaption).foregroundStyle(Theme.Colors.textTertiary)
                }
                ForEach(viewModel.systemAlarms) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title).font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                        Text("\(row.schedule) · \(row.state)")
                            .font(.riseCaption)
                            .foregroundStyle(row.isRinging ? Theme.Colors.neonPink : Theme.Colors.textSecondary)
                    }
                }
                Button("Cancel all & delete lab alarms", role: .destructive) {
                    Task { await viewModel.cancelEverything() }
                }
                .buttonStyle(.ghost)
            }
        }
    }

    private var logCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                header("Log", detail: nil)
                ForEach(viewModel.log) { line in
                    Text("\(line.date.formatted(date: .omitted, time: .standard))  \(line.text)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(line.isError ? Theme.Colors.danger : Theme.Colors.textSecondary)
                        // LEARN: lets you long-press to copy log text (handy for SPIKE_RESULTS.md).
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func header(_ title: String, detail: String?) -> some View {
        HStack {
            Text(title).font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if let detail {
                Text(detail).font(.riseCaption).foregroundStyle(Theme.Colors.neonPink)
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        AlarmLabView(viewModel: AlarmLabViewModel(
            repository: dependencies.alarmRepository,
            scheduler: dependencies.alarmScheduler
        ))
    }
}
