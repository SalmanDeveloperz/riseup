//
//  NextAlarmWidget.swift
//  RiseUpWidgets (widget extension)
//
//  LAYER: Widget extension (Screen #31: home screen + lock screen widgets)
//  WHAT:  "Next alarm", in six sizes:
//           Home screen  • small:  the next alarm on its own wallpaper, with a live countdown
//                        • medium: + the next two alarms and quick-nap buttons (+10/+20/+30 min)
//                        • large:  + sound, wallpaper, missions and more alarms
//           Lock screen  • circle, rectangle and one line above the clock
//         Tapping opens RiseUp on that alarm; nap buttons open Quick Alarm preset (riseup://…).
//  DATA:  reads WidgetSnapshot + wallpaper pictures from the App Group. No database, no AlarmKit.
//
//  CONNECTIONS:
//    ← LISTED IN:  RiseUpWidgetsBundle
//    ← DATA FROM:  WidgetBridge (app) → Shared/WidgetSnapshot.swift → App Group
//    → LINKS:      WidgetShared.alarmURL / napURL / newAlarmURL → app RootView .onOpenURL → DeepLink
//
//  HOW A WIDGET WORKS (read this first!)
//  ─────────────────────────────────────
//  A widget isn't a running app. iOS asks our "provider" for a TIMELINE: a list of entries
//  ("at 7:00:01 show this, at 7:30:01 show that"). iOS draws each entry as a picture at its
//  time, even when RiseUp is closed. So after an alarm rings, the widget moves to the next one
//  by itself. Only the countdown text keeps ticking, because iOS animates `Text(date, style:)`.
//

import SwiftUI
import WidgetKit

// MARK: - The widget

struct NextAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        // LEARN: `kind` is the widget's ID. The app reloads it with the same string (WidgetBridge).
        StaticConfiguration(kind: WidgetShared.nextAlarmKind, provider: NextAlarmProvider()) { entry in
            NextAlarmWidgetView(entry: entry)
        }
        .configurationDisplayName("Next alarm")
        .description("Your next alarm on its wallpaper, with a live countdown and quick naps.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Timeline

/// One moment of the widget: what to show from `date` on.
struct NextAlarmEntry: TimelineEntry {
    enum Content {
        /// The coming rings (first = the next alarm).
        case alarms([WidgetAlarmEvent])
        /// The app wrote a snapshot, but no alarm is switched on.
        case noAlarms
        /// RiseUp never wrote a snapshot (not opened since installing, or no App Group).
        case notSetUp
    }

    let date: Date
    let content: Content

    /// Shown in the widget gallery and while iOS loads the real one.
    static let sample = NextAlarmEntry(date: .now, content: .alarms([
        WidgetAlarmEvent(alarmID: UUID(), fireDate: .now.addingTimeInterval(7 * 3600 + 12 * 60), title: "Wake up",
                         missionSymbols: ["function", "figure.walk"], soundTitle: "Koto Morning",
                         wallpaperTitle: "Kyoto Blossoms", wallpaperFile: nil),
        WidgetAlarmEvent(alarmID: UUID(), fireDate: .now.addingTimeInterval(31 * 3600), title: "Gym",
                         missionSymbols: [], soundTitle: "Epic Strings", wallpaperTitle: "Synthwave", wallpaperFile: nil),
    ]))
}

/// Builds the timeline from the snapshot the app wrote.
struct NextAlarmProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextAlarmEntry { .sample }

    /// The widget gallery preview: the real alarms if there are any, otherwise the sample.
    func getSnapshot(in context: Context, completion: @escaping (NextAlarmEntry) -> Void) {
        let entry = Self.entries(from: WidgetSnapshot.load(), now: .now).first ?? .sample
        if case .alarms = entry.content {
            completion(entry)
        } else {
            // No alarms yet: the gallery shows the sample, so people see what they're adding.
            completion(context.isPreview ? .sample : entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let entries = Self.entries(from: snapshot, now: .now)
        // `.atEnd`: when the last entry is reached, iOS asks again. The app also reloads us after changes.
        // Without data, look again in an hour (maybe RiseUp has been opened by then).
        let policy: TimelineReloadPolicy = snapshot == nil ? .after(.now.addingTimeInterval(3600)) : .atEnd
        completion(Timeline(entries: entries, policy: policy))
    }

    /// One entry now, and one just after each coming ring (so the widget moves to the next alarm).
    /// LEARN: `static` + inputs only = easy to read and to reason about, like a pure function.
    static func entries(from snapshot: WidgetSnapshot?, now: Date) -> [NextAlarmEntry] {
        guard let snapshot else { return [NextAlarmEntry(date: now, content: .notSetUp)] }
        let moments = [now] + snapshot.upcoming(after: now).prefix(12).map { $0.fireDate.addingTimeInterval(1) }
        return moments.map { moment in
            let coming = Array(snapshot.upcoming(after: moment).prefix(4))
            return NextAlarmEntry(date: moment, content: coming.isEmpty ? .noAlarms : .alarms(coming))
        }
    }
}

// MARK: - Views

struct NextAlarmWidgetView: View {
    let entry: NextAlarmEntry
    /// LEARN: which size iOS is drawing right now (small, medium, lock screen circle…).
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.content {
        case .alarms(let events):
            alarmsView(events)
        case .noAlarms:
            message(icon: "alarm", title: "No alarms set", detail: "Tap to set one", link: WidgetShared.newAlarmURL)
        case .notSetUp:
            message(icon: "sun.max.fill", title: "RiseUp", detail: "Open RiseUp once to see your next alarm here",
                    link: WidgetShared.newAlarmURL)
        }
    }

    @ViewBuilder
    private func alarmsView(_ events: [WidgetAlarmEvent]) -> some View {
        let next = events[0]
        switch family {
        case .accessoryCircular: CircularView(event: next)
        case .accessoryRectangular: RectangularView(event: next, now: entry.date)
        case .accessoryInline: InlineView(event: next, now: entry.date)
        case .systemMedium: MediumView(events: events, now: entry.date)
        case .systemLarge, .systemExtraLarge: LargeView(events: events, now: entry.date)
        default: SmallView(event: next, now: entry.date)
        }
    }

    /// Empty states: same look in every size (short text on the lock screen).
    @ViewBuilder
    private func message(icon: String, title: String, detail: String, link: URL) -> some View {
        switch family {
        case .accessoryInline:
            Label(title, systemImage: icon)
                .widgetURL(link)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryCircular, .accessoryRectangular:
            VStack(spacing: 2) {
                RoosterGlyph(height: 16)
                Text(title).font(.caption).lineLimit(1)
            }
            .widgetURL(link)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default:
            VStack(spacing: Theme.Spacing.xs) {
                RoosterMark(height: 40)
                Text(title).font(.headline).foregroundStyle(Theme.Colors.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .widgetURL(link)
            .containerBackground(for: .widget) { Theme.Gradients.night }
        }
    }
}

// MARK: - Home screen sizes

/// Small: the next alarm, big, on its own wallpaper.
private struct SmallView: View {
    let event: WidgetAlarmEvent
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HeaderRow(event: event, now: now)
            Spacer(minLength: 0)
            BigTime(date: event.fireDate, size: 44)
            Text(event.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Countdown(date: event.fireDate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(WidgetShared.alarmURL(event.alarmID))
        .containerBackground(for: .widget) { WallpaperBackground(file: event.wallpaperFile) }
    }
}

/// Medium: the next alarm on the left; the next two and quick naps on the right.
private struct MediumView: View {
    let events: [WidgetAlarmEvent]
    let now: Date

    var body: some View {
        let next = events[0]
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // LEARN: in medium and large widgets, `Link` makes just this part tappable.
            Link(destination: WidgetShared.alarmURL(next.alarmID)) {
                VStack(alignment: .leading, spacing: 2) {
                    HeaderRow(event: next, now: now)
                    Spacer(minLength: 0)
                    BigTime(date: next.fireDate, size: 44)
                    Text(next.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Countdown(date: next.fireDate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(events.dropFirst().prefix(2)) { event in
                    Link(destination: WidgetShared.alarmURL(event.alarmID)) {
                        UpcomingRow(event: event, now: now)
                    }
                }
                if events.count == 1 {
                    Text("No other alarms this week")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                NapButtons()
            }
            .frame(width: 128)
        }
        .containerBackground(for: .widget) { WallpaperBackground(file: next.wallpaperFile) }
    }
}

/// Large: everything about the next alarm, the ones after it, and quick naps.
private struct LargeView: View {
    let events: [WidgetAlarmEvent]
    let now: Date

    var body: some View {
        let next = events[0]
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Link(destination: WidgetShared.alarmURL(next.alarmID)) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    HeaderRow(event: next, now: now)
                    BigTime(date: next.fireDate, size: 60)
                    Text(next.title)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Countdown(date: next.fireDate)
                    HStack(spacing: Theme.Spacing.sm) {
                        Label(next.soundTitle, systemImage: "music.note")
                        Label(next.wallpaperTitle, systemImage: "photo.artframe")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            // WHY one line each (found in the Simulator): three two-line rows pushed the header off
            // the top and the nap buttons off the bottom of the large widget.
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                ForEach(events.dropFirst().prefix(3)) { event in
                    Link(destination: WidgetShared.alarmURL(event.alarmID)) {
                        UpcomingRow(event: event, now: now, isCompact: true)
                    }
                }
            }
            NapButtons()
        }
        .containerBackground(for: .widget) { WallpaperBackground(file: next.wallpaperFile) }
    }
}

// MARK: - Lock screen sizes
// LEARN: the lock screen draws widgets in ONE tint chosen by the user, so colours and pictures
// are ignored there. Shapes, symbols and text are what count.

private struct CircularView: View {
    let event: WidgetAlarmEvent

    var body: some View {
        let time = TimeText.parts(event.fireDate)
        VStack(spacing: 0) {
            RoosterGlyph(height: 11)
            Text(time.main)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !time.suffix.isEmpty {
                Text(time.suffix).font(.system(size: 9, weight: .semibold))
            }
        }
        .widgetURL(WidgetShared.alarmURL(event.alarmID))
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }
}

private struct RectangularView: View {
    let event: WidgetAlarmEvent
    let now: Date

    var body: some View {
        let time = TimeText.parts(event.fireDate)
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text("\(time.main) \(time.suffix)")
            } icon: {
                RoosterGlyph(height: 14)
            }
            .font(.headline)
            Text("\(TimeText.dayLabel(event.fireDate, now: now)) · \(event.title)")
                .font(.caption)
                .lineLimit(1)
            Text("in \(Text(event.fireDate, style: .relative))")
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(WidgetShared.alarmURL(event.alarmID))
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct InlineView: View {
    let event: WidgetAlarmEvent
    let now: Date

    var body: some View {
        let time = TimeText.parts(event.fireDate)
        Label("\(time.main)\(time.suffix.isEmpty ? "" : " \(time.suffix)") · \(TimeText.dayLabel(event.fireDate, now: now))",
              systemImage: "alarm.fill")
            .widgetURL(WidgetShared.alarmURL(event.alarmID))
            .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Pieces

/// "🐓 Tomorrow ······ ∑ 🚶": our rooster, the day of the next ring and its missions.
private struct HeaderRow: View {
    let event: WidgetAlarmEvent
    let now: Date

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            RoosterMark(height: 16)                       // our logo, like a signature on every widget
            Text(TimeText.dayLabel(event.fireDate, now: now).uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.Colors.textPrimary)
                // WHY (found in the Simulator): "TOMORROW" next to two mission icons wrapped onto 2 lines.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            ForEach(event.missionSymbols.prefix(3), id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .font(.caption)
    }
}

/// "7:00 AM" in the sunrise gradient, like the Ringing screen's clock.
private struct BigTime: View {
    let date: Date
    let size: CGFloat

    var body: some View {
        let time = TimeText.parts(date)
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(time.main)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Gradients.sunrise)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !time.suffix.isEmpty {
                Text(time.suffix)
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        // WHY a dark glow (found in the Simulator): on Golden Hour the time sat right on the bright
        // sun and was hard to read. Same idea as the Ringing screen's `clockHalo()`.
        .shadow(color: .black.opacity(0.55), radius: 10)
        .shadow(color: .black.opacity(0.35), radius: 2)
    }
}

/// "in 7 hr, 12 min", kept up to date by iOS without waking the widget.
private struct Countdown: View {
    let date: Date

    var body: some View {
        // LEARN: `Text(date, style: .relative)` is special: iOS updates it live on the home screen.
        Text("in \(Text(date, style: .relative))")
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.Colors.textSecondary)
            .lineLimit(1)
    }
}

/// A later alarm: "7:00 AM / Thu · Wake up" (two lines), or one line when `isCompact`.
private struct UpcomingRow: View {
    let event: WidgetAlarmEvent
    let now: Date
    var isCompact = false

    var body: some View {
        let time = TimeText.parts(event.fireDate)
        // LEARN: `AnyLayout` switches between a vertical and a horizontal stack with the same children.
        let layout = isCompact ? AnyLayout(HStackLayout(spacing: Theme.Spacing.xs)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
        HStack(spacing: Theme.Spacing.xs) {
            layout {
                Text("\(time.main) \(time.suffix)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(TimeText.dayLabel(event.fireDate, now: now)) · \(event.title)")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(.black.opacity(0.35), in: .rect(cornerRadius: Theme.Radius.chip))
    }
}

/// "+10 · +20 · +30 min": opens Quick Alarm preset to that nap (riseup://nap/N).
private struct NapButtons: View {
    /// TRY: [5, 15, 45] for different naps.
    private let naps = [10, 20, 30]

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "zzz")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.Colors.textSecondary)
            ForEach(naps, id: \.self) { minutes in
                Link(destination: WidgetShared.napURL(minutes: minutes)) {
                    Text("+\(minutes)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(Theme.Gradients.sunrise.opacity(0.85), in: .capsule)
                }
            }
        }
    }
}

/// The alarm's wallpaper picture (made by the app), darkened at the bottom so text stays readable.
/// Falls back to the night gradient if the picture is missing.
private struct WallpaperBackground: View {
    let file: String?

    var body: some View {
        ZStack {
            if let image = picture {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Theme.Gradients.night
            }
            // Darker at the top (day + missions) and bottom (time + title), so text is readable on any picture.
            LinearGradient(colors: [.black.opacity(0.4), .black.opacity(0.25), .black.opacity(0.72)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private var picture: UIImage? {
        guard let file, let folder = WidgetShared.wallpaperFolder else { return nil }
        return UIImage(contentsOfFile: folder.appending(path: file).path())
    }
}

/// The RiseUp rooster in colour (home-screen widgets). Made by Tools/generate_app_icon.swift.
private struct RoosterMark: View {
    let height: CGFloat
    var body: some View {
        Image("RoosterMark")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

/// The rooster as a one-colour silhouette (lock-screen widgets).
/// LEARN: the image is marked "template" in its asset catalog, so iOS ignores its colour and paints it
/// in the lock screen's tint, exactly like an SF Symbol. A colour picture there would become a grey blob.
private struct RoosterGlyph: View {
    let height: CGFloat
    var body: some View {
        Image("RoosterGlyph")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

/// Time formatting that follows the iPhone's 12/24-hour setting.
private enum TimeText {
    /// "7:00" + "AM" (12-hour iPhones) or "07:00" + "" (24-hour).
    static func parts(_ date: Date) -> (main: String, suffix: String) {
        // LEARN: the template "j" asks iOS for the user's preferred hour style; "a" in the
        // result means AM/PM is shown.
        let uses12Hours = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") ?? false
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = uses12Hours ? "h:mm" : "HH:mm"
        let main = formatter.string(from: date)
        guard uses12Hours else { return (main, "") }
        formatter.dateFormat = "a"
        return (main, formatter.string(from: date))
    }

    /// "Today", "Tomorrow" or "Wed".
    static func dayLabel(_ date: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) { NextAlarmWidget() } timeline: { NextAlarmEntry.sample }
#Preview("Medium", as: .systemMedium) { NextAlarmWidget() } timeline: { NextAlarmEntry.sample }
#Preview("Large", as: .systemLarge) { NextAlarmWidget() } timeline: { NextAlarmEntry.sample }
#Preview("Lock: rectangle", as: .accessoryRectangular) { NextAlarmWidget() } timeline: { NextAlarmEntry.sample }
