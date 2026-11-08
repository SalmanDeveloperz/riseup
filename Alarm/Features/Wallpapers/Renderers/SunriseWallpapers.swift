//
//  SunriseWallpapers.swift
//  RiseUp
//
//  LAYER: View (live-wallpaper renderers, category "Sunrise")
//  WHAT:  Golden Hour · Aurora · Dawn Drift. Each is one `draw` function (see WallpaperKit's LEARN).
//  DATA:  none.
//
//  CONNECTIONS:
//    ← CALLED BY: LiveWallpaperView (60× a second inside a Canvas)
//    → USES:      WallpaperMath, GraphicsContext.glow / fillSky, wavyHorizon
//

import SwiftUI

/// A big sun rising over purple hills, slowly turning rays and floating golden dust.
enum GoldenHourRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x1B0B3D), location: 0),
            .init(color: Color(hex: 0x7A2A6B), location: 0.38),
            .init(color: Color(hex: 0xFF8A3D), location: 0.62),
            .init(color: Color(hex: 0x2A0F2E), location: 1),
        ])

        // The sun gently bobs; with more energy it climbs a little higher.
        let sun = CGPoint(x: w / 2, y: h * (0.6 - 0.04 * energy) + h * 0.012 * WallpaperMath.wave(t, period: 7))
        let radius = w * 0.2
        ctx.glow(at: sun, radius: w * (0.75 + 0.15 * energy), color: Color(hex: 0xFF6A5B), opacity: 0.45 + 0.25 * energy)

        // Rays: thin wedges turning slowly around the sun.
        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            let rays = 14
            let spin = t * 0.05
            for i in 0..<rays {
                let angle = spin + Double(i) / Double(rays) * 2 * .pi
                var wedge = Path()
                wedge.move(to: sun)
                wedge.addLine(to: CGPoint(x: sun.x + cos(angle - 0.05) * h, y: sun.y + sin(angle - 0.05) * h))
                wedge.addLine(to: CGPoint(x: sun.x + cos(angle + 0.05) * h, y: sun.y + sin(angle + 0.05) * h))
                wedge.closeSubpath()
                layer.fill(wedge, with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xFFD9A0, opacity: 0.18 + 0.12 * energy), .clear]),
                    center: sun, startRadius: radius, endRadius: h * 0.7
                ))
            }
        }

        // The sun disc.
        let disc = Path(ellipseIn: CGRect(x: sun.x - radius, y: sun.y - radius, width: radius * 2, height: radius * 2))
        ctx.fill(disc, with: .radialGradient(
            Gradient(colors: [Color(hex: 0xFFF3C4), Color(hex: 0xFFC46B), Color(hex: 0xFF7A45)]),
            center: CGPoint(x: sun.x, y: sun.y - radius * 0.3), startRadius: 0, endRadius: radius * 1.1
        ))

        // Two layers of hills in front of the sun (the far one is lighter).
        ctx.fill(wavyHorizon(in: size, baseY: h * 0.66, amplitude: h * 0.05,
                             waves: [(w * 0.18, t * 0.02), (w * 0.07, 1.3)]),
                 with: .color(Color(hex: 0x4A1B4F)))
        ctx.fill(wavyHorizon(in: size, baseY: h * 0.74, amplitude: h * 0.06,
                             waves: [(w * 0.23, 2.1), (w * 0.09, 0.4 + t * 0.015)]),
                 with: .color(Color(hex: 0x1A0A26)))

        // Golden dust rising slowly.
        for i in 0..<34 {
            let speed = 0.012 + WallpaperMath.random(i, 1) * 0.02
            let y = h * (1 - WallpaperMath.fract(WallpaperMath.random(i, 2) + t * speed))
            let x = w * WallpaperMath.random(i, 3) + 14 * WallpaperMath.wave(t, period: 5 + Double(i % 5), phase: WallpaperMath.random(i, 4))
            ctx.glow(at: CGPoint(x: x, y: y), radius: 3 + 4 * WallpaperMath.random(i, 5),
                     color: Color(hex: 0xFFE2A8), opacity: 0.6 * WallpaperMath.twinkle(t, index: i))
        }
    }
}

/// Northern lights: glowing curtains of green, cyan and purple waving over a starry sky.
enum AuroraRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x020617), location: 0),
            .init(color: Color(hex: 0x0A1A36), location: 0.6),
            .init(color: Color(hex: 0x0E2E3E), location: 1),
        ])
        StarField.draw(&ctx, size: size, time: t, count: 130, maxY: 0.75)

        // The curtains: soft wavy bands, blurred and added together ("plus lighter" = light adds up).
        let speed = 0.35
        let colors = [Color(hex: 0x3DFFA2), Color(hex: 0x3DD6FF), Color(hex: 0x8B5CFF)]
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 10))
            layer.blendMode = .plusLighter
            for band in 0..<3 {
                let base = h * (0.36 + Double(band) * 0.1)
                let amplitude = h * (0.06 + 0.04 * energy)
                let height = h * (0.26 + 0.05 * Double(band))
                var top: [CGPoint] = []
                var bottom: [CGPoint] = []
                for x in stride(from: -20.0, through: w + 20, by: w / 40) {
                    let y = base
                        + amplitude * sin(x / (w * 0.35) + t * speed * (1 + 0.3 * Double(band)) + Double(band))
                        + amplitude * 0.5 * sin(x / (w * 0.12) - t * speed * 1.7)
                    bottom.append(CGPoint(x: x, y: y))
                    top.append(CGPoint(x: x, y: y - height * (0.7 + 0.3 * sin(x / (w * 0.2) + t * 0.6))))
                }
                var curtain = Path()
                curtain.addLines(bottom)
                curtain.addLines(top.reversed())
                curtain.closeSubpath()
                layer.fill(curtain, with: .linearGradient(
                    Gradient(colors: [.clear, colors[band].opacity(0.35), colors[band].opacity(0.85 + 0.15 * energy), colors[band].opacity(0.1)]),
                    startPoint: CGPoint(x: 0, y: base - height), endPoint: CGPoint(x: 0, y: base + amplitude)
                ))
            }
        }

        // Jagged mountains at the bottom.
        var mountains = Path()
        mountains.move(to: CGPoint(x: 0, y: h))
        for i in 0...12 {
            let x = w * Double(i) / 12
            let y = h * (i % 2 == 0 ? 0.84 + 0.04 * WallpaperMath.random(i, 5) : 0.74 + 0.06 * WallpaperMath.random(i, 6))
            mountains.addLine(to: CGPoint(x: x, y: y))
        }
        mountains.addLine(to: CGPoint(x: w, y: h))
        mountains.closeSubpath()
        ctx.fill(mountains, with: .linearGradient(Gradient(colors: [Color(hex: 0x0B2A3A), Color(hex: 0x02070F)]),
                                                  startPoint: CGPoint(x: 0, y: h * 0.74), endPoint: CGPoint(x: 0, y: h)))
    }
}

/// Soft pink clouds drifting across a dawn sky.
enum DawnDriftRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x2B1055), location: 0),
            .init(color: Color(hex: 0x9E4D9B), location: 0.4),
            .init(color: Color(hex: 0xF08A8A), location: 0.7),
            .init(color: Color(hex: 0xFFD6A5), location: 1),
        ])
        ctx.glow(at: CGPoint(x: w * 0.5, y: h * 0.82), radius: w * (0.7 + 0.2 * energy),
                 color: Color(hex: 0xFFF0C8), opacity: 0.55 + 0.3 * energy)

        // Three layers of clouds; the closer ones are bigger and faster (parallax).
        for layerIndex in 0..<3 {
            let depth = Double(layerIndex + 1)
            let speed = 6 + depth * 7
            for c in 0..<4 {
                let seed = layerIndex * 10 + c
                let cloudWidth = w * (0.35 + 0.15 * depth)
                let span = w + cloudWidth
                let x = WallpaperMath.fract(WallpaperMath.random(seed, 1) + t * speed / span) * span - cloudWidth / 2
                let y = h * (0.12 + 0.22 * Double(layerIndex) + 0.12 * WallpaperMath.random(seed, 2))
                let tint = layerIndex == 2 ? Color(hex: 0xFFE4EC) : Color(hex: 0xFFB6C8)
                for puff in 0..<6 {
                    let px = x + (Double(puff) - 2.5) * cloudWidth * 0.16
                    let py = y - cloudWidth * 0.08 * sin(Double(puff) / 5 * .pi)      // rounded top
                    ctx.glow(at: CGPoint(x: px, y: py), radius: cloudWidth * 0.34,
                             color: tint, opacity: 0.16 + 0.08 * depth)
                }
            }
        }
    }
}

/// Twinkling stars, shared by several night wallpapers.
enum StarField {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, count: Int, maxY: Double = 1) {
        for i in 0..<count {
            let point = CGPoint(x: size.width * WallpaperMath.random(i, 11),
                                y: size.height * maxY * WallpaperMath.random(i, 12))
            let r = 0.6 + 1.4 * WallpaperMath.random(i, 13)
            ctx.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(0.25 + 0.75 * WallpaperMath.twinkle(t, index: i))))
        }
    }
}
