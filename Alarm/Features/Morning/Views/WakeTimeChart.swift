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
                .foregroundStyle(Theme.Gradients.sunrise)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Up at", time(point.wakeMinuteOfDay ?? 0))
                )
                .foregroundStyle(Theme.Colors.neonPink)
                .symbolSize(60)
            }
        }
        // WHY "+ 1 day": each dot sits in the MIDDLE of its day. Ending the axis at midnight of
        // the last day cut today's dot in half (seen in testing).
        .chartXScale(domain: (points.first?.day ?? .now)...((points.last?.day ?? .now).addingTimeInterval(86_400)))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: labelsEveryDay ? 1 : 5)) { _ in
                AxisValueLabel(format: labelsEveryDay ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
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
