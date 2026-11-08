//
//  MorningView.swift
//  RiseUp
//
//  LAYER: View (Screen #23 Morning panel)
//  WHAT:  Greeting · streak flame · today's wake-up (+ mood) · next alarm · this week ·
//         line of the day · links to Records and Stats.
//  VIEWMODEL: MorningViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeRoot(for: .morning) (replaces the Phase 0 "coming soon")
//    → Records / Stats rows → viewModel.open(...) → AppCoordinator → morningPath
//

import SwiftUI

struct MorningView: View {
    @State private var viewModel: MorningViewModel

    init(viewModel: MorningViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // LEARN: one TimelineView at the top gives every card the same "now", refreshed each minute.
        TimelineView(.everyMinute) { _ in
            let now = Date.now
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    header(now: now)
                    streakCard(now: now)
                    todayCard(now: now)
                    if viewModel.hasHistory {
                        weekCard(now: now)
                    }
                    quoteCard(now: now)

                    SettingsSectionHeader(title: "Your history")
                    SettingsRow(title: "Records", subtitle: "Every wake-up on a calendar",
                                systemImage: "calendar") { viewModel.open(.records) }
                    SettingsRow(title: "Stats", subtitle: "Wake-up times, snoozes and mood",
                                systemImage: "chart.xyaxis.line") { viewModel.open(.stats) }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .appBackground()
        .navigationTitle("Morning")
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    // MARK: - Cards

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(viewModel.greeting(now: now))
                .font(.riseTitle)
                .foregroundStyle(Theme.Gradients.brand)
            Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.riseBody)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func streakCard(now: Date) -> some View {
        let streak = viewModel.currentStreak(now: now)
        return GlowCard(isGlowing: streak > 0) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(streak > 0 ? AnyShapeStyle(Theme.Gradients.brand) : AnyShapeStyle(Theme.Colors.textTertiary))
                    .symbolEffect(.bounce, value: streak)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(streak == 1 ? "1 day streak" : "\(streak) day streak")
                        .font(.riseTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .contentTransition(.numericText())
                    Text(streak == 0
                         ? "Wake up with RiseUp tomorrow to start a streak."
                         : "Best ever: \(viewModel.bestStreak) days. Keep it going!")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func todayCard(now: Date) -> some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label("Today", systemImage: "sun.max.fill")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let entry = viewModel.todayEntry(now: now) {
                    Text(viewModel.summary(of: entry))
                        .font(.riseBody)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if entry.isFinished {
                        moodRow(entry)
                    }
                } else {
                    Text("No wake-up yet today.")
                        .font(.riseBody)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                if let next = viewModel.nextAlarm(now: now) {
                    Divider().overlay(Theme.Colors.hairline)
                    Label("Next alarm: \(next.fireDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())) · \(next.title)",
                          systemImage: "alarm.fill")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
    }

    /// Morning check-in (#17) for today's wake-up: tap a mood (or change it).
    private func moodRow(_ entry: WakeEntry) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(entry.mood == nil ? "How do you feel?" : "Feeling:")
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textTertiary)
            ForEach(Mood.allCases) { mood in
                Button {
                    viewModel.setMood(mood, for: entry)        // → saved with today's wake-up
                } label: {
                    Text(mood.emoji)
                        .font(.title3)
                        .padding(4)
                        .background(entry.mood == mood ? AnyShapeStyle(Theme.Gradients.brand) : AnyShapeStyle(Color.clear), in: .circle)
                        .opacity(entry.mood == nil || entry.mood == mood ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mood.title)
            }
        }
        .sensoryFeedback(.selection, trigger: entry.mood)
    }

    /// "This week": up-at times as gradient dots (Swift Charts). Taller = later.
    private func weekCard(now: Date) -> some View {
        let points = viewModel.weekPoints(now: now)
        return GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label("This week", systemImage: "chart.dots.scatter")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                WakeTimeChart(points: points)
                    .frame(height: 140)
            }
        }
    }

    private func quoteCard(now: Date) -> some View {
        GlowCard(isGlowing: true) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("LINE OF THE DAY")
                    .font(.riseCaption)
                    .tracking(1)
                    .foregroundStyle(Theme.Colors.accent)
                Text(viewModel.quote(now: now))
                    .font(.riseTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    #if DEBUG
    try? dependencies.wakeRecordRepository.addSampleHistory(days: 14)
    #endif
    return NavigationStack {
        MorningView(viewModel: MorningViewModel(
            records: dependencies.wakeRecordRepository,
            alarms: dependencies.alarmRepository,
            coordinator: AppCoordinator()
        ))
    }
}
