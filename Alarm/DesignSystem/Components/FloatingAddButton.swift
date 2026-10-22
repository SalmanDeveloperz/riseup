//
//  FloatingAddButton.swift
//  RiseUp
//
//  LAYER: Design System (component)
//  WHAT:  The round glowing "+" button that floats in the bottom-right corner.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: AlarmListView (`.overlay(alignment: .bottomTrailing)`)
//    → ACTION:  whatever closure the screen passes in (Alarm List → viewModel.addAlarmTapped())
//
//  LEARN: Reusable components take an `action` closure instead of knowing what to do.
//  The button only knows how to LOOK; each screen decides what it DOES.
//

import SwiftUI

struct FloatingAddButton: View {
    /// Text read by VoiceOver, e.g. "Add alarm".
    var accessibilityLabel: String = "Add"
    let action: () -> Void

    /// LEARN: a counter that changes on every tap. `.sensoryFeedback` watches it
    /// and plays a haptic each time it changes.
    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.Colors.onAccent)
                .frame(width: 64, height: 64)
                .background(Theme.Gradients.brand, in: .circle)
                .shadow(color: Theme.Colors.accent.opacity(0.6), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    FloatingAddButton(accessibilityLabel: "Add alarm") {}
        .padding()
        .appBackground()
}
