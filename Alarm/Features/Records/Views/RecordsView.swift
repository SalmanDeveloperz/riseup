//
//  RecordsView.swift
//  RiseUp
//
//  LAYER: View (Screen #24 Records calendar)
//  WHAT:  Month header with arrows, a colour key, the day grid, and the selected day's wake-ups.
//  VIEWMODEL: RecordsViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeScreen(for: MorningRoute.records)
//

import SwiftUI

struct RecordsView: View {
    @State private var viewModel: RecordsViewModel

    init(viewModel: RecordsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xs), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                GlowCard(isGlowing: true) {
                    VStack(spacing: Theme.Spacing.md) {
                        monthHeader
                        weekdayRow
                        LazyVGrid(columns: columns, spacing: Theme.Spacing.xs) {
                            ForEach(viewModel.cells()) { cell in
                                dayCell(cell)
                            }
                        }
                        legend
                    }
                }
                .animation(.spring(duration: 0.35), value: viewModel.month)

                Text(viewModel.monthSummary)
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                dayDetails

                #if DEBUG
                if !viewModel.hasHistory {
                    Button("Add sample data (Debug)") { viewModel.addSampleData() }
                        .buttonStyle(.ghost)
                }
                #endif
            }
            .padding(Theme.Spacing.lg)
        }
        .appBackground()
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: viewModel.selectedDay)
    }

    // MARK: - Pieces

    private var monthHeader: some View {
        HStack {
            Button { viewModel.showPreviousMonth() } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(viewModel.monthTitle)
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
            Spacer()
            Button { viewModel.showNextMonth() } label: {
                Image(systemName: "chevron.right").font(.headline)
            }
            .disabled(!viewModel.canGoForward())
            // WHY: our explicit pink colour (below) hides SwiftUI's grey "disabled" look,
            // so we dim it ourselves. Otherwise the arrow looks tappable but does nothing.
            .opacity(viewModel.canGoForward() ? 1 : 0.3)
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(Theme.Colors.neonPink)
    }

    private var weekdayRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ cell: RecordsViewModel.DayCell) -> some View {
        if cell.date == nil {
            Color.clear.frame(height: 40)
        } else {
            let isSelected = cell.date == viewModel.selectedDay
            Button {
                viewModel.select(cell)
            } label: {
                Text("\(cell.dayNumber)")
                    .font(.riseBody.weight(cell.isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(cell.status == .none ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(fill(for: cell.status), in: .circle)
                    .overlay {
                        Circle().strokeBorder(isSelected ? Theme.Colors.textPrimary : (cell.isToday ? Theme.Colors.neonPink : .clear),
                                              lineWidth: isSelected ? 2 : 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(cell.date?.formatted(date: .complete, time: .omitted) ?? ""), \(label(for: cell.status))")
        }
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.md) {
            legendItem(.clean)
            legendItem(.snoozed)
            legendItem(.missed)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(_ status: RecordsViewModel.DayStatus) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Circle().fill(fill(for: status)).frame(width: 10, height: 10)
            Text(label(for: status)).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    /// The tapped day's wake-ups, as small cards.
    @ViewBuilder
    private var dayDetails: some View {
        if let day = viewModel.selectedDay {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.textPrimary)
            if viewModel.selectedEntries.isEmpty {
                Text("No alarm rang this day.")
                    .font(.riseBody)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            ForEach(viewModel.selectedEntries) { entry in
                GlowCard {
                    HStack(spacing: Theme.Spacing.md) {
                        Text(entry.mood?.emoji ?? (entry.isFinished ? "✅" : "❌"))
                            .font(.title)
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(entry.alarmTitle)
                                .font(.riseHeadline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(detail(of: entry))
                                .font(.riseCaption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func detail(of entry: WakeEntry) -> String {
        let rang = entry.ringStartedAt.formatted(date: .omitted, time: .shortened)
        guard let wokeAt = entry.wokeAt else { return "Rang at \(rang) · not finished" }
        var text = "Rang \(rang) · up \(wokeAt.formatted(date: .omitted, time: .shortened))"
        if entry.snoozeCount > 0 { text += " · \(entry.snoozeCount) snooze\(entry.snoozeCount == 1 ? "" : "s")" }
        return text
    }

    private func fill(for status: RecordsViewModel.DayStatus) -> AnyShapeStyle {
        switch status {
        case .none: AnyShapeStyle(Theme.Colors.surfaceRaised.opacity(0.5))
        case .clean: AnyShapeStyle(Theme.Gradients.sunrise)
        case .snoozed: AnyShapeStyle(Theme.Colors.warning.opacity(0.7))
        case .missed: AnyShapeStyle(Theme.Colors.danger.opacity(0.6))
        }
    }

    private func label(for status: RecordsViewModel.DayStatus) -> String {
        switch status {
        case .none: "No alarm"
        case .clean: "Up first time"
        case .snoozed: "Snoozed"
        case .missed: "Not finished"
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    #if DEBUG
    try? dependencies.wakeRecordRepository.addSampleHistory(days: 45)
    #endif
    return NavigationStack {
        RecordsView(viewModel: RecordsViewModel(records: dependencies.wakeRecordRepository))
    }
}
