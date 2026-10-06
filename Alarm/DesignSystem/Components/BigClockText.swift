//
//  BigClockText.swift
//  RiseUp
//
//  LAYER: Design System (component)
//  WHAT:  Large gradient time display like "6:30 AM", the hero of alarm screens.
//  USED BY: alarm cards, ringing screen, home placeholder.
//

import SwiftUI

/// Shows an hour and minute as big gradient digits, respecting the user's 12/24-hour preference.
struct BigClockText: View {
    let hour: Int       // 0...23
    let minute: Int     // 0...59
    var size: CGFloat = 72
    var isActive: Bool = true

    var body: some View {
        // LEARN: `.firstTextBaseline` lines the small "AM" up with the bottom of the big digits.
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
            Text(digits)
                .font(.riseClock(size: size))
                // LEARN: `.monospacedDigit()` gives every digit the same width, so the
                // clock doesn't "jump" sideways when 1 changes to 8.
                .monospacedDigit()

            if let period {
                Text(period)
                    .font(.riseClock(size: size * 0.32))
            }
        }
        .foregroundStyle(isActive ? AnyShapeStyle(Theme.Gradients.sunrise)
                                  : AnyShapeStyle(Theme.Colors.textTertiary))
        // WHY: VoiceOver should read "6:30 AM", not "six, colon, thirty".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibleTime)
    }

    // MARK: - Formatting

    /// True when the user's region uses 24-hour time (e.g. 18:30 instead of 6:30 PM).
    ///
    /// LEARN: `Locale.current.hourCycle` reflects iOS Settings > General > Date & Time.
    private var uses24Hour: Bool {
        switch Locale.current.hourCycle {
        case .zeroToTwentyThree, .oneToTwentyFour: true
        case .zeroToEleven, .oneToTwelve: false
        @unknown default: false
        }
    }

    /// "6:30" or "18:30".
    private var digits: String {
        let displayHour: Int
        if uses24Hour {
            displayHour = hour
        } else {
            // 0 → 12 (midnight), 13 → 1, 12 → 12 (noon).
            displayHour = hour % 12 == 0 ? 12 : hour % 12
        }
        // LEARN: `String(format: "%02d")` pads with a zero: 5 → "05".
        let hourText = uses24Hour ? String(format: "%02d", displayHour) : "\(displayHour)"
        return "\(hourText):\(String(format: "%02d", minute))"
    }

    /// "AM" / "PM", or nil in 24-hour mode.
    private var period: String? {
        guard !uses24Hour else { return nil }
        let calendar = Calendar.current
        return hour < 12 ? calendar.amSymbol : calendar.pmSymbol
    }

    private var accessibleTime: String {
        let components = DateComponents(hour: hour, minute: minute)
        guard let date = Calendar.current.date(from: components) else { return digits }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        BigClockText(hour: 6, minute: 30)
        BigClockText(hour: 18, minute: 5, size: 48)
        BigClockText(hour: 0, minute: 0, size: 48, isActive: false)
    }
    .padding()
    .appBackground()
}
