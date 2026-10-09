//
//  ConfettiView.swift
//  RiseUp
//
//  LAYER: Design System (component)
//  WHAT:  A burst of neon confetti that falls once, for celebrations.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: SuccessView (after a completed wake-up)
//
//  LEARN: `Canvas` draws many shapes very fast (one drawing pass instead of hundreds of
//  views). `TimelineView(.animation)` redraws it every frame, and each piece's position
//  is simple physics: start point + velocity × time + gravity × time².
//

import SwiftUI

struct ConfettiView: View {
    /// TRY: change to 300 for a bigger party.
    var pieceCount = 120
    var duration: TimeInterval = 3.5

    @State private var startDate = Date.now
    @State private var pieces: [Piece] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Piece {
        let x: Double          // start, 0…1 of the width
        let speedX: Double     // points per second
        let speedY: Double
        let spin: Double
        let size: Double
        let color: Color
    }

    var body: some View {
        // WHY: respect "Reduce Motion" in iOS Settings; no flying confetti for those users.
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSince(startDate)
                    guard t < duration else { return }
                    for piece in pieces {
                        let x = piece.x * size.width + piece.speedX * t
                        let y = -20 + piece.speedY * t + 260 * t * t   // gravity
                        let fade = max(0, 1 - t / duration)
                        var copy = context
                        copy.opacity = fade
                        copy.translateBy(x: x, y: y)
                        copy.rotate(by: .radians(piece.spin * t))
                        copy.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)),
                                  with: .color(piece.color))
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                startDate = .now
                let colors = [Theme.Colors.neonPink, Theme.Colors.neonPurple, Theme.Colors.neonOrange,
                              Theme.Colors.neonBlue, Theme.Colors.success, Theme.Colors.warning]
                pieces = (0..<pieceCount).map { _ in
                    Piece(x: .random(in: 0...1),
                          speedX: .random(in: -60...60),
                          speedY: .random(in: 40...220),
                          spin: .random(in: -8...8),
                          size: .random(in: 8...14),
                          color: colors.randomElement()!)
                }
            }
        }
    }
}

#Preview {
    ConfettiView().appBackground()
}
