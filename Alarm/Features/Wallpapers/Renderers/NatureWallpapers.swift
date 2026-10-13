//
//  NatureWallpapers.swift
//  RiseUp
//
//  LAYER: View (live-wallpaper renderers, category "Nature")
//  WHAT:  Ocean Waves · Firefly Forest · Rainy Window.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← CALLED BY: LiveWallpaperView
//    → USES:      WallpaperMath, GraphicsContext.glow / fillSky, wavyHorizon
//

import SwiftUI

/// Layered waves rolling under a sunrise; glints sparkle where the sun hits the water.
enum OceanRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        let horizon = h * 0.44
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x0B1E3A), location: 0),
            .init(color: Color(hex: 0x3A5FA8), location: 0.3),
            .init(color: Color(hex: 0xF4A27A), location: 0.44),
            .init(color: Color(hex: 0x0A2A55), location: 0.46),
            .init(color: Color(hex: 0x041026), location: 1),
        ])
        let sun = CGPoint(x: w * 0.5, y: horizon - h * 0.02)
        ctx.glow(at: sun, radius: w * 0.55, color: Color(hex: 0xFFC48A), opacity: 0.5 + 0.3 * energy)

        // Glints: short bright dashes on the water below the sun.
        for i in 0..<40 {
            let depth = WallpaperMath.random(i, 1)
            let y = horizon + (h - horizon) * depth * depth
            let spread = w * (0.05 + 0.35 * depth)
            let x = sun.x + (WallpaperMath.random(i, 2) - 0.5) * 2 * spread
            let length = 6 + 26 * depth
            let shine = pow(WallpaperMath.twinkle(t, index: i, speed: 2.5), 3)
            var dash = Path()
            dash.move(to: CGPoint(x: x - length / 2, y: y))
            dash.addLine(to: CGPoint(x: x + length / 2, y: y))
            ctx.stroke(dash, with: .color(Color(hex: 0xFFE2B8, opacity: 0.7 * shine)), lineWidth: 1.5 + 2 * depth)
        }

        // Five wave layers from far (thin, slow) to near (tall, fast).
        let colors: [UInt32] = [0x1E4F8F, 0x17407A, 0x113266, 0x0B2552, 0x061A3E]
        for layer in 0..<5 {
            let d = Double(layer)
            let base = horizon + (h - horizon) * (0.12 + d * 0.19)
            let amplitude = (5 + d * 7) * (1 + 0.7 * energy)
            let speed = 0.3 + d * 0.18
            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: h))
            var crest: [CGPoint] = []
            for x in stride(from: 0.0, through: w + 8, by: 8) {
                let y = base
                    + amplitude * sin(x / (w * (0.16 + d * 0.03)) + t * speed + d)
                    + amplitude * 0.4 * sin(x / (w * 0.05) - t * speed * 1.6)
                crest.append(CGPoint(x: x, y: y))
                wave.addLine(to: CGPoint(x: x, y: y))
            }
            wave.addLine(to: CGPoint(x: w, y: h))
            wave.closeSubpath()
            ctx.fill(wave, with: .color(Color(hex: colors[layer])))
            var foam = Path()
            foam.addLines(crest)
            ctx.stroke(foam, with: .color(.white.opacity(0.08 + 0.05 * d)), lineWidth: 1.2)
        }
    }
}

/// A dark pine forest at night with fireflies drifting and blinking.
enum FirefliesRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x03100D), location: 0),
            .init(color: Color(hex: 0x0A2A24), location: 0.65),
            .init(color: Color(hex: 0x0F3B30), location: 1),
        ])
        // The moon.
        let moon = CGPoint(x: w * 0.76, y: h * 0.16)
        ctx.glow(at: moon, radius: w * 0.35, color: Color(hex: 0xBFFFE5), opacity: 0.25)
        ctx.fill(Path(ellipseIn: CGRect(x: moon.x - w * 0.06, y: moon.y - w * 0.06, width: w * 0.12, height: w * 0.12)),
                 with: .color(Color(hex: 0xEFFFF6)))

        // Two rows of pine trees (back row lighter, front row almost black).
        drawPines(&ctx, size: size, rowY: h * 0.74, count: 9, height: h * 0.22, color: Color(hex: 0x0D3329), salt: 1)
        // Fireflies: some behind the front trees, most in front.
        drawFireflies(&ctx, size: size, time: t, energy: energy, range: 0..<18)
        drawPines(&ctx, size: size, rowY: h * 0.86, count: 7, height: h * 0.3, color: Color(hex: 0x020A07), salt: 2)
        drawFireflies(&ctx, size: size, time: t, energy: energy, range: 18..<(42 + Int(14 * energy)))
    }

    private static func drawPines(_ ctx: inout GraphicsContext, size: CGSize, rowY: Double, count: Int,
                                  height: Double, color: Color, salt: Int) {
        var forest = Path()
        forest.addRect(CGRect(x: 0, y: rowY, width: size.width, height: size.height - rowY))
        for i in 0..<count {
            let x = size.width * (Double(i) + WallpaperMath.random(i, salt)) / Double(count)
            let treeHeight = height * (0.7 + 0.5 * WallpaperMath.random(i, salt + 10))
            let width = treeHeight * 0.42
            for tier in 0..<3 {                       // three stacked triangles = a pine
                let tierTop = rowY - treeHeight + Double(tier) * treeHeight * 0.25
                let tierWidth = width * (0.55 + 0.22 * Double(tier))
                forest.move(to: CGPoint(x: x, y: tierTop))
                forest.addLine(to: CGPoint(x: x + tierWidth / 2, y: tierTop + treeHeight * 0.45))
                forest.addLine(to: CGPoint(x: x - tierWidth / 2, y: tierTop + treeHeight * 0.45))
                forest.closeSubpath()
            }
        }
        ctx.fill(forest, with: .color(color))
    }

    private static func drawFireflies(_ ctx: inout GraphicsContext, size: CGSize, time t: Double,
                                      energy: Double, range: Range<Int>) {
        for i in range {
            let x = size.width * WallpaperMath.random(i, 21) + 40 * WallpaperMath.wave(t, period: 9 + 6 * WallpaperMath.random(i, 22), phase: WallpaperMath.random(i, 23))
            let y = size.height * (0.3 + 0.62 * WallpaperMath.random(i, 24)) + 30 * WallpaperMath.wave(t, period: 7 + 5 * WallpaperMath.random(i, 25), phase: WallpaperMath.random(i, 26))
            let blink = pow(WallpaperMath.twinkle(t, index: i, speed: 1.2), 2)
            let point = CGPoint(x: x, y: y)
            ctx.glow(at: point, radius: 16 + 10 * energy, color: Color(hex: 0xD4FF6B), opacity: 0.55 * blink)
            ctx.glow(at: point, radius: 2.5, color: .white, opacity: blink)
        }
    }
}

/// City lights blurred behind a window, rain streaking down and drops sliding on the glass.
enum RainyWindowRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x070B1A), location: 0),
            .init(color: Color(hex: 0x141D38), location: 0.6),
            .init(color: Color(hex: 0x1E2244), location: 1),
        ])
        // Out-of-focus city lights.
        let palette: [UInt32] = [0xFFB347, 0xFF6F91, 0x7AD7FF, 0xFFE08A, 0xB28DFF]
        for i in 0..<26 {
            let x = w * WallpaperMath.random(i, 31) + 8 * WallpaperMath.wave(t, period: 20, phase: WallpaperMath.random(i, 32))
            let y = h * (0.35 + 0.6 * WallpaperMath.random(i, 33))
            ctx.glow(at: CGPoint(x: x, y: y), radius: 24 + 46 * WallpaperMath.random(i, 34),
                     color: Color(hex: palette[i % palette.count]), opacity: 0.22 + 0.14 * WallpaperMath.twinkle(t, index: i, speed: 0.4))
        }
        // Rain streaks (falling outside).
        let speed = 1.3
        let streaks = 80 + Int(60 * energy)
        for i in 0..<streaks {
            let length = 18 + 30 * WallpaperMath.random(i, 41)
            let y = WallpaperMath.fract(WallpaperMath.random(i, 42) + t * speed * (0.6 + 0.4 * WallpaperMath.random(i, 43))) * (h + length) - length
            let x = w * WallpaperMath.random(i, 44) + (y / h) * 18
            var line = Path()
            line.move(to: CGPoint(x: x, y: y))
            line.addLine(to: CGPoint(x: x + 4, y: y + length))
            ctx.stroke(line, with: .color(.white.opacity(0.1 + 0.18 * WallpaperMath.random(i, 45))), lineWidth: 1)
        }
        // Drops on the glass: they sit, then slowly slide down.
        for i in 0..<28 {
            let slide = WallpaperMath.fract(WallpaperMath.random(i, 51) + t * 0.015 * (1 + WallpaperMath.random(i, 52)))
            let point = CGPoint(x: w * WallpaperMath.random(i, 53), y: h * slide)
            let r = 3 + 6 * WallpaperMath.random(i, 54)
            ctx.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r * 1.15, width: r * 2, height: r * 2.3)),
                     with: .color(.white.opacity(0.08)))
            ctx.stroke(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r * 1.15, width: r * 2, height: r * 2.3)),
                       with: .color(.white.opacity(0.2)), lineWidth: 0.8)
            ctx.glow(at: CGPoint(x: point.x - r * 0.3, y: point.y - r * 0.5), radius: r * 0.5, color: .white, opacity: 0.6)
        }
    }
}
