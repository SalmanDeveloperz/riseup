//
//  Typography.swift
//  RiseUp
//
//  LAYER: Design System
//  WHAT:  Named text styles, so every screen uses the same fonts.
//  USED BY: every View that shows text.
//
//  LEARN: We use Apple's system font with the `.rounded` design. It looks friendly
//  and modern, and it automatically supports Dynamic Type (the user's text size
//  setting in iOS Settings > Accessibility).
//

import SwiftUI

extension Font {
    /// Big screen titles ("Alarms", "Good morning").
    static let riseLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)

    /// Section and card titles.
    static let riseTitle = Font.system(.title2, design: .rounded, weight: .bold)

    /// Smaller headings inside cards.
    static let riseHeadline = Font.system(.headline, design: .rounded, weight: .semibold)

    /// Normal reading text.
    static let riseBody = Font.system(.body, design: .rounded)

    /// Small helper text under titles.
    static let riseCaption = Font.system(.footnote, design: .rounded, weight: .medium)

    /// Huge clock digits. `size` is a parameter because the clock is used at different sizes.
    ///
    /// WHY: the clock uses a fixed size instead of Dynamic Type because it is
    /// decoration-sized (60–90 pt) and would overflow the screen if it grew even more.
    static func riseClock(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}
