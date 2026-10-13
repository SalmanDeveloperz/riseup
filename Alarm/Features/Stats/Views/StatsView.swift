//
//  StatsView.swift
//  RiseUp
//
//  LAYER: View (Screen #25 Stats)
//  WHAT:  7 / 30 day switch · four number tiles · charts: wake-up time, snoozes, mood.
//  VIEWMODEL: StatsViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeScreen(for: MorningRoute.stats)
//    → USES:     WakeTimeChart (shared with the Morning tab), Swift Charts (BarMark)
//

import Charts
import SwiftUI

struct StatsView: View {
    @State private var viewModel: StatsViewModel
    /// Developer mode (Debug builds only) → shows the debug buttons. → DeveloperTools.swift
    @Environment(\.showsDeveloperTools) private var showsDeveloperTools

    init(viewModel: StatsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let now = Date.now
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // LEARN: a `.segmented` Picker is the iOS "two or three tabs in a pill" control.
                Picker("Range", selection: $viewModel.range) {
                    ForEach(StatsViewModel.Range.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.hasHistory {
                    tiles(now: now)
                    chartCard("Wake-up time", systemImage: "sunrise.fill") {
                        WakeTimeChart(points: viewModel.points(now: now), labelsEveryDay: viewModel.range == .week)
                    }
                    chartCard("Snoozes", systemImage: "zzz") { snoozeChart(now: now) }
                    chartCard("Mood", systemImage: "face.smiling") { moodChart(now: now) }
                } else {
                    emptyState
                }
            }
            .padding(Theme.Spacing.lg)
            .animation(.easeInOut, value: viewModel.range)
        }
        .appBackground()
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Tiles

    private func tiles(now: Date) -> some View {
        Grid(horizontalSpacing: Theme.Spacing.sm, verticalSpacing: Theme.Spacing.sm) {
            GridRow {
                tile(viewModel.averageWakeText(now: now), "average up time", "sun.max.fill")
                tile(viewModel.successText(now: now), "finished", "checkmark.seal.fill")
            }
            GridRow {
                tile("\(viewModel.totalSnoozes(now: now))", "snoozes", "zzz")
                tile(viewModel.averageMissionText(now: now), "avg. mission", "bolt.fill")
            }
        }
    }

    private func tile(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: icon).foregroundStyle(Theme.Gradients.sunrise)
            Text(value)
                .font(.riseTitle)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: - Charts

    private func chartCard(_ title: String, systemImage: String, @ViewBuilder chart: () -> some View) -> some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label(title, systemImage: systemImage)
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                chart()
                    .frame(height: 170)
            }
        }
    }

    private func snoozeChart(now: Date) -> some View {
        Chart(viewModel.points(now: now)) { point in
            BarMark(
                x: .value("Day", point.day, unit: .day),
                y: .value("Snoozes", point.snoozes)
            )
            .foregroundStyle(Theme.Gradients.sunrise)
            .cornerRadius(4)
        }
        .chartXScale(domain: ChartDays.domain(for: viewModel.points(now: now)))
        .chartXAxis { dayAxis(now: now) }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Theme.Colors.hairline)
                AxisValueLabel().foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    /// Mood per day as bars from 1 (😫) to 5 (🤩). Days without a mood have no bar.
    private func moodChart(now: Date) -> some View {
        let points = viewModel.points(now: now).filter { $0.mood != nil }
        return Chart(points) { point in
            BarMark(
                x: .value("Day", point.day, unit: .day),
                y: .value("Mood", point.mood?.rawValue ?? 0)
            )
            .foregroundStyle(Theme.Gradients.success)
            .cornerRadius(4)
        }
        // Whole range, even if only one day has a mood (so one bar doesn't fill the chart).
        .chartXScale(domain: ChartDays.domain(for: viewModel.points(now: now)))
        .chartXAxis { dayAxis(now: now) }
        .chartYScale(domain: 0...5)
        .chartYAxis {
            AxisMarks(position: .leading, values: [1, 3, 5]) { value in
                AxisGridLine().foregroundStyle(Theme.Colors.hairline)
                AxisValueLabel {
                    if let raw = value.as(Int.self), let mood = Mood(rawValue: raw) { Text(mood.emoji) }
                }
            }
        }
        .overlay {
            if points.isEmpty {
                Text("Pick a mood after waking up to see it here")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    /// Same day labels as the wake-up chart, so all three charts line up (see `ChartDays`).
    private func dayAxis(now: Date) -> some AxisContent {
        ChartDays.axis(for: viewModel.points(now: now), everyDay: viewModel.range == .week)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Theme.Gradients.sunrise)
            Text("Your stats appear after your first wake-ups with RiseUp.")
                .font(.riseBody)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            #if DEBUG
            if showsDeveloperTools {
                Button("Add sample data (Debug)") { viewModel.addSampleData() }
                    .buttonStyle(.ghost)
            }
            #endif
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xxl)
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    #if DEBUG
    try? dependencies.wakeRecordRepository.addSampleHistory(days: 45)
    #endif
    return NavigationStack {
        StatsView(viewModel: StatsViewModel(records: dependencies.wakeRecordRepository))
    }
}
