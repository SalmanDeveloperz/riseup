//
//  WakeTimeChart.swift
//  RiseUp
//
//  LAYER: View (reusable chart, Swift Charts)
//  WHAT:  "What time were you up?" per day: gradient line + dots. Empty days have no dot.
//  DATA:  [WakeDayPoint] values (from WakeStats.dailyPoints).
//
//  CONNECTIONS:
//    ← USED BY: MorningView ("This week"), StatsView ("Wake-up time")
//
//  LEARN: Swift Charts
//  ───────────────────
//  A chart is a list of "marks". `LineMark(x:y:)` connects points, `PointMark` draws dots.
//  The y value here is a TIME OF DAY. Charts can't plot "minutes after midnight" as a time
//  label, so we turn each value into a Date on one shared day (reference day + minutes).
//  Then the axis can format it as "6:30" in the user's own 12/24-hour style.
//

import Charts
import SwiftUI

struct WakeTimeChart: View {
    let points: [WakeDayPoint]
    /// Show a label under every day ("Mon") or only some (for 30-day charts).
    var labelsEveryDay = true

    /// One fixed day; only its hour/minute part matters.
    private static let referenceDay = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))

    private func time(_ minutes: Int) -> Date {
        Self.referenceDay.addingTimeInterval(TimeInterval(minutes * 60))
    }

    var body: some View {
        let measured = points.filter { $0.wakeMinuteOfDay != nil }
        Chart {
            ForEach(measured) { point in
                LineMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Up at", time(point.wakeMinuteOfDay ?? 0))
                )
                .foregroundStyle(Theme.Gradients.brand)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Up at", time(point.wakeMinuteOfDay ?? 0))
                )
                .foregroundStyle(Theme.Colors.accent)
                .symbolSize(60)
            }
        }
        .chartXScale(domain: ChartDays.domain(for: points))
        .chartXAxis { ChartDays.axis(for: points, everyDay: labelsEveryDay) }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Theme.Colors.hairline)
                AxisValueLabel(format: .dateTime.hour().minute())
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        // WHY no flipping: Swift Charts draws Date values top-down (earlier times HIGHER), which
        // is exactly what a wake-up chart wants: the line going UP means waking up earlier.
        .chartYScale(domain: .automatic(includesZero: false))
        .overlay {
            if measured.isEmpty {
                Text("No wake-ups yet")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .accessibilityLabel("Wake-up times per day")
    }
}

// MARK: - Day axis shared by every day-by-day chart

/// Keeps the day labels ("M", "T", "W"…) exactly under their dots and bars.
/// ← USED BY: WakeTimeChart, StatsView (snooze + mood charts), so all charts line up the same way.
///
/// WHY (Salman spotted it): a mark with `unit: .day` is drawn in the MIDDLE of its day (at noon),
/// but `.stride(by: .day)` puts labels at MIDNIGHT, the START of the day. Every letter sat half a
/// day to the left of its dot. Now the labels are placed at noon too.
enum ChartDays {
    /// From midnight of the first day to midnight AFTER the last day.
    /// WHY "+ 1 day": ending at midnight of the last day cut today's dot in half (seen in testing).
    static func domain(for points: [WakeDayPoint], calendar: Calendar = .current) -> ClosedRange<Date> {
        let first = points.first?.day ?? calendar.startOfDay(for: .now)
        let last = points.last?.day ?? first
        let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last.addingTimeInterval(86_400)
        return first...end
    }

    /// Noon of every `step`-th day, counted back from the LAST day so today always has a label.
    static func labelDates(for points: [WakeDayPoint], step: Int, calendar: Calendar = .current) -> [Date] {
        guard !points.isEmpty else { return [] }
        let step = max(step, 1)
        return stride(from: (points.count - 1) % step, to: points.count, by: step).map { index in
            calendar.date(byAdding: .hour, value: 12, to: points[index].day) ?? points[index].day
        }
    }

    /// The x-axis: one label per day (7-day charts) or every 5th day (30-day charts).
    /// LEARN: `AxisContentBuilder` works like `@ViewBuilder`, but for chart axes.
    @AxisContentBuilder
    static func axis(for points: [WakeDayPoint], everyDay: Bool) -> some AxisContent {
        AxisMarks(values: labelDates(for: points, step: everyDay ? 1 : 5)) { _ in
            AxisValueLabel(format: everyDay ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated),
                           anchor: .top)                     // centred under the noon position
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}
