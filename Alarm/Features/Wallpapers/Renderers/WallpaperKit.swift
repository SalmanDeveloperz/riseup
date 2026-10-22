//
//  WallpaperKit.swift
//  RiseUp
//
//  LAYER: View helpers (shared by every live-wallpaper renderer)
//  WHAT:  Small drawing tools: repeatable "random" numbers, gentle waves, gradient shortcuts.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: SunriseWallpapers, NatureWallpapers, SpaceWallpapers, EnergyWallpapers, CalmWallpapers
//
//  LEARN: how our live wallpapers work
//  ───────────────────────────────────
//  Each wallpaper is ONE function: draw(context, size, time, energy). SwiftUI's `Canvas` calls it
//  up to 60 times a second (TimelineView, see LiveWallpaperView) with a slightly bigger `time`.
//  Nothing is stored between frames: every star, firefly or wave position is calculated from
//  `time` and its own index. That's why it's cheap, smooth and can't "drift" or leak memory.
//
//  `energy` goes from 0 (calm) to 1 (wide awake). The Ringing screen raises it the longer the
//  alarm rings, so the wallpaper itself wakes up with you: brighter, bigger, busier.
//
//  RULE: renderers use `energy` for LOOKS (brightness, size, count), never to multiply `time`.
//  WHY: `time × speed(energy)` jumps whenever energy changes (time is large, so a tiny speed change
//  moves everything a lot). Speeding up is done by `EnergyRamp.clock`, which bends time smoothly.
//
//  WHY raw colours (hex numbers) in the renderer files: wallpapers are artwork, each with its own
//  palette. App UI still uses Theme tokens only.
//

import SwiftUI

/// Pseudo-random numbers and waves. Pure maths: same input → same output, every frame.
enum WallpaperMath {
    /// A number 0..<1 that looks random but is always the same for the same (index, salt).
    /// LEARN: the classic "sin hash": a big multiplier makes neighbouring inputs land far apart.
    static func random(_ index: Int, _ salt: Int = 0) -> Double {
        let x = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43_758.5453
        return x - floor(x)
    }

    /// -1…1, one full swing every `period` seconds.
    static func wave(_ time: Double, period: Double, phase: Double = 0) -> Double {
        sin(2 * .pi * (time / period + phase))
    }

    /// 0…1 that slowly blinks (stars, fireflies).
    static func twinkle(_ time: Double, index: Int, speed: Double = 1) -> Double {
        let phase = random(index, 7) * 2 * .pi
        let rate = 0.6 + random(index, 8) * 1.4
        return 0.5 + 0.5 * sin(time * rate * speed + phase)
    }

    /// The fractional part: 3.75 → 0.75. Used to loop things (falling rain, rings).
    static func fract(_ x: Double) -> Double { x - floor(x) }
}

extension GraphicsContext {
    /// A soft glowing dot: bright centre fading to nothing (fireflies, stars, bokeh, sun glow).
    /// WHY a gradient instead of a blur filter: blurring the whole screen 60× a second is
    /// expensive; a radial gradient looks the same and costs almost nothing.
    func glow(at point: CGPoint, radius: Double, color: Color, opacity: Double = 1) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), color.opacity(0)]),
            center: point, startRadius: 0, endRadius: radius
        ))
    }

    /// Fills the whole canvas with a top-to-bottom gradient.
    func fillSky(_ size: CGSize, stops: [Gradient.Stop]) {
        fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(stops: stops), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))
    }
}

/// Builds a soft, wavy horizon (hills, mountains, waves) from left to right, closed at the bottom.
func wavyHorizon(in size: CGSize, baseY: Double, amplitude: Double, waves: [(length: Double, offset: Double)]) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 0, y: size.height))
    let step = max(4, size.width / 60)
    for x in stride(from: 0.0, through: size.width + step, by: step) {
        var y = baseY
        for wave in waves {
            y += amplitude * sin(x / wave.length + wave.offset) / Double(waves.count)
        }
        path.addLine(to: CGPoint(x: x, y: y))
    }
    path.addLine(to: CGPoint(x: size.width, y: size.height))
    path.closeSubpath()
    return path
}
