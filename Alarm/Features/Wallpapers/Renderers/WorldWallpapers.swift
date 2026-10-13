//
//  WorldWallpapers.swift
//  RiseUp
//
//  LAYER: View (live-wallpaper renderers, category "Around the World")
//  WHAT:  Kyoto Blossoms · Taj at Dawn · Sahara Dunes · Savanna Sunset · Tropical Island · Himalaya ·
//         Paris Nights · Alpine Meadow · Scottish Highlands · Andes Condor · City Lights.
//         Each pairs with a sound from the same place (LiveWallpaper.signatureSound).
//  DATA:  none.
//
//  CONNECTIONS:
//    ← CALLED BY: LiveWallpaperView (60× a second inside a Canvas)
//    → USES:      WallpaperMath, StarField, GraphicsContext.glow / fillSky, wavyHorizon, poly
//
//  LEARN: silhouettes. Landmarks here (a pagoda, the Taj Mahal, the Eiffel Tower) are simple
//  outlines filled with one dark colour against a glowing sky. Our eyes recognise shapes from
//  their outline alone, so a few points are enough, and they're cheap to draw 60× a second.
//

import SwiftUI

/// A closed shape from points given as fractions of the screen (0…1), so it fits every iPhone.
func poly(_ points: [(Double, Double)], in size: CGSize) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: CGPoint(x: first.0 * size.width, y: first.1 * size.height))
    for point in points.dropFirst() {
        path.addLine(to: CGPoint(x: point.0 * size.width, y: point.1 * size.height))
    }
    path.closeSubpath()
    return path
}

/// A small bird (a "V" with flapping wings), used by several world scenes.
func birdPath(at center: CGPoint, span: Double, flap: Double) -> Path {
    var path = Path()
    let lift = span * 0.35 * flap
    path.move(to: CGPoint(x: center.x - span / 2, y: center.y - lift))
    path.addQuadCurve(to: center, control: CGPoint(x: center.x - span / 4, y: center.y - lift * 1.4))
    path.addQuadCurve(to: CGPoint(x: center.x + span / 2, y: center.y - lift), control: CGPoint(x: center.x + span / 4, y: center.y - lift * 1.4))
    return path
}

private func drawBirds(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, count: Int, color: Color, salt: Int) {
    for i in 0..<count {
        let speed = 18 + 14 * WallpaperMath.random(i, salt)
        let x = WallpaperMath.fract(WallpaperMath.random(i, salt + 1) + t * speed / size.width) * (size.width + 60) - 30
        let y = size.height * (0.15 + 0.25 * WallpaperMath.random(i, salt + 2)) + 6 * sin(t * 0.7 + Double(i))
        let flap = sin(t * (6 + 3 * WallpaperMath.random(i, salt + 3)) + Double(i))
        ctx.stroke(birdPath(at: CGPoint(x: x, y: y), span: 14 + 8 * WallpaperMath.random(i, salt + 4), flap: flap),
                   with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Japan

/// Kyoto at dawn: Mount Fuji, a pagoda, a cherry branch and petals drifting down.
enum KyotoBlossomsRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x5E4B8C), location: 0),
            .init(color: Color(hex: 0xE59BB8), location: 0.5),
            .init(color: Color(hex: 0xFFE0D0), location: 0.7),
        ])
        ctx.glow(at: CGPoint(x: w * 0.3, y: h * 0.58), radius: w * 0.7, color: Color(hex: 0xFFF2E0), opacity: 0.5 + 0.3 * energy)
        // Mount Fuji with its snow cap.
        ctx.fill(poly([(0.0, 0.74), (0.42, 0.46), (0.58, 0.46), (1.0, 0.74)], in: size),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x6F5F9E), Color(hex: 0xB89BC8)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.46), endPoint: CGPoint(x: 0, y: h * 0.74)))
        ctx.fill(poly([(0.42, 0.46), (0.58, 0.46), (0.65, 0.51), (0.6, 0.5), (0.56, 0.53), (0.52, 0.505),
                       (0.48, 0.53), (0.44, 0.5), (0.35, 0.51)], in: size), with: .color(.white.opacity(0.92)))
        // Lake + shore.
        ctx.fill(Path(CGRect(x: 0, y: h * 0.74, width: w, height: h * 0.26)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x4A3B6E), Color(hex: 0x1C1530)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.74), endPoint: CGPoint(x: 0, y: h)))
        // A five-roofed pagoda.
        let ink = Color(hex: 0x24182F)
        let pagodaX = 0.8, base = 0.88
        for tier in 0..<5 {
            let d = Double(tier)
            let y = base - d * 0.045
            let body = 0.07 - d * 0.009
            ctx.fill(poly([(pagodaX - body / 2, y), (pagodaX + body / 2, y), (pagodaX + body / 2, y - 0.03), (pagodaX - body / 2, y - 0.03)], in: size), with: .color(ink))
            let roof = body + 0.05
            ctx.fill(poly([(pagodaX - roof / 2 - 0.012, y - 0.026), (pagodaX + roof / 2 + 0.012, y - 0.026),
                           (pagodaX + roof / 2 - 0.01, y - 0.04), (pagodaX - roof / 2 + 0.01, y - 0.04)], in: size), with: .color(ink))
        }
        ctx.fill(Path(CGRect(x: w * pagodaX - 1.5, y: h * (base - 0.29), width: 3, height: h * 0.07)), with: .color(ink))
        // The cherry branch in the top-left corner, with blossoms.
        var branch = Path()
        branch.move(to: CGPoint(x: -10, y: h * 0.1))
        branch.addCurve(to: CGPoint(x: w * 0.62, y: h * 0.06), control1: CGPoint(x: w * 0.2, y: h * 0.18), control2: CGPoint(x: w * 0.4, y: h * 0.02))
        branch.move(to: CGPoint(x: w * 0.25, y: h * 0.12))
        branch.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.2), control: CGPoint(x: w * 0.33, y: h * 0.13))
        ctx.stroke(branch, with: .color(Color(hex: 0x3A2230)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        for i in 0..<22 {
            let along = WallpaperMath.random(i, 5)
            let p = CGPoint(x: w * (0.02 + 0.6 * along) + 18 * (WallpaperMath.random(i, 6) - 0.5),
                            y: h * (0.06 + 0.1 * sin(along * .pi)) + 22 * (WallpaperMath.random(i, 7) - 0.5))
            ctx.glow(at: p, radius: 16 + 8 * WallpaperMath.random(i, 8), color: Color(hex: 0xFFB7CF), opacity: 0.85)
            ctx.glow(at: p, radius: 3, color: .white, opacity: 0.9)
        }
        // Falling petals: each spins slowly and sways in the breeze.
        let petals = 55 + Int(45 * energy)
        for i in 0..<petals {
            let speed = 0.03 + 0.04 * WallpaperMath.random(i, 11)
            let y = WallpaperMath.fract(WallpaperMath.random(i, 12) + t * speed) * (h + 40) - 20
            let x = w * WallpaperMath.random(i, 13) + 40 * sin(t * 0.8 + Double(i)) + (y / h) * 30
            let angle = t * (1 + 2 * WallpaperMath.random(i, 14)) + Double(i)
            let petal = Path(ellipseIn: CGRect(x: -5, y: -3, width: 10, height: 6))
                .applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: x, y: y)))
            ctx.fill(petal, with: .color(Color(hex: 0xFFC6D9, opacity: 0.85)))
        }
    }
}

// MARK: - India

/// The Taj Mahal at dawn, mirrored in its long reflecting pool.
enum TajDawnRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        let ground = 0.6
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x2B2050), location: 0),
            .init(color: Color(hex: 0xC56A8C), location: 0.42),
            .init(color: Color(hex: 0xFFC7A0), location: 0.6),
        ])
        ctx.glow(at: CGPoint(x: w * 0.5, y: h * 0.5), radius: w * 0.8, color: Color(hex: 0xFFE4C4), opacity: 0.5 + 0.3 * energy)
        let monument = tajPath(in: size, ground: ground)
        ctx.fill(monument, with: .linearGradient(Gradient(colors: [Color(hex: 0xF4D8E4), Color(hex: 0x9C7A9E)]),
                                                 startPoint: CGPoint(x: 0, y: h * 0.25), endPoint: CGPoint(x: 0, y: h * ground)))
        // The pool, then the reflection drawn in wobbling strips (water ripples).
        ctx.fill(Path(CGRect(x: 0, y: h * ground, width: w, height: h * (1 - ground))),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xB07A98), Color(hex: 0x2A1C3A)]),
                                       startPoint: CGPoint(x: 0, y: h * ground), endPoint: CGPoint(x: 0, y: h)))
        let mirror = CGAffineTransform(translationX: 0, y: 2 * h * ground).scaledBy(x: 1, y: -1)
        let reflection = monument.applying(mirror)
        let strips = 28
        let top = h * ground, depth = h * 0.36
        for s in 0..<strips {
            let y0 = top + depth * Double(s) / Double(strips)
            var strip = ctx
            strip.clip(to: Path(CGRect(x: 0, y: y0, width: w, height: depth / Double(strips) + 1)))
            strip.translateBy(x: 4 * sin(Double(s) * 0.9 + t * 2), y: 0)
            strip.fill(reflection, with: .color(Color(hex: 0xF4D8E4, opacity: 0.35 * (1 - Double(s) / Double(strips)))))
        }
        // Dark cypress trees along the pool.
        for side in [0.08, 0.92] {
            for k in 0..<3 {
                let x = w * (side + (side < 0.5 ? 1 : -1) * Double(k) * 0.05)
                ctx.fill(Path(ellipseIn: CGRect(x: x - 9, y: h * (ground - 0.1 + Double(k) * 0.02), width: 18, height: h * 0.12)),
                         with: .color(Color(hex: 0x24182F)))
            }
        }
        drawBirds(&ctx, size: size, time: t, count: 5, color: Color(hex: 0x3A2440), salt: 40)
    }

    /// Platform, main hall, the great onion dome, two small domes and four minarets.
    private static func tajPath(in size: CGSize, ground: Double) -> Path {
        let w = size.width, h = size.height
        var p = Path()
        p.addRect(CGRect(x: w * 0.14, y: h * (ground - 0.03), width: w * 0.72, height: h * 0.03))   // platform
        p.addRect(CGRect(x: w * 0.3, y: h * (ground - 0.13), width: w * 0.4, height: h * 0.1))     // hall
        // Great dome: a drum, then an onion shape built from curves, then the finial.
        p.addRect(CGRect(x: w * 0.42, y: h * (ground - 0.16), width: w * 0.16, height: h * 0.03))
        let domeBase = h * (ground - 0.16)
        p.move(to: CGPoint(x: w * 0.4, y: domeBase))
        p.addCurve(to: CGPoint(x: w * 0.5, y: domeBase - h * 0.14), control1: CGPoint(x: w * 0.36, y: domeBase - h * 0.08), control2: CGPoint(x: w * 0.47, y: domeBase - h * 0.1))
        p.addCurve(to: CGPoint(x: w * 0.6, y: domeBase), control1: CGPoint(x: w * 0.53, y: domeBase - h * 0.1), control2: CGPoint(x: w * 0.64, y: domeBase - h * 0.08))
        p.closeSubpath()
        p.addRect(CGRect(x: w * 0.5 - 1.5, y: domeBase - h * 0.18, width: 3, height: h * 0.05))
        for x in [0.35, 0.65] {                                               // small domes
            p.addEllipse(in: CGRect(x: w * x - w * 0.035, y: h * (ground - 0.18), width: w * 0.07, height: h * 0.06))
            p.addRect(CGRect(x: w * x - w * 0.03, y: h * (ground - 0.15), width: w * 0.06, height: h * 0.03))
        }
        for x in [0.17, 0.27, 0.73, 0.83] {                                   // minarets
            p.addRect(CGRect(x: w * x - w * 0.012, y: h * (ground - 0.24), width: w * 0.024, height: h * 0.21))
            p.addEllipse(in: CGRect(x: w * x - w * 0.02, y: h * (ground - 0.265), width: w * 0.04, height: h * 0.035))
        }
        return p
    }
}

// MARK: - Africa

/// Golden Sahara dunes at sunrise, a camel caravan on the ridge and sand blowing in the wind.
enum SaharaDunesRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x3B1E54), location: 0),
            .init(color: Color(hex: 0xE8775A), location: 0.42),
            .init(color: Color(hex: 0xFFC170), location: 0.56),
        ])
        let sun = CGPoint(x: w * 0.68, y: h * 0.5)
        ctx.glow(at: sun, radius: w * 0.6, color: Color(hex: 0xFFD08A), opacity: 0.6 + 0.3 * energy)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - w * 0.11, y: sun.y - w * 0.11, width: w * 0.22, height: w * 0.22)),
                 with: .color(Color(hex: 0xFFE6A8)))
        // Dunes from far (light) to near (deep orange), each lit from the left.
        let dunes: [(base: Double, amp: Double, color: UInt32, light: UInt32)] = [
            (0.58, 0.04, 0xE09A63, 0xF2B97E), (0.66, 0.05, 0xCF7D47, 0xE89A5E),
            (0.76, 0.06, 0xB4602F, 0xD07A40), (0.88, 0.05, 0x8E4421, 0xAE5A2C),
        ]
        var ridgeY: (Double) -> Double = { _ in 0 }
        for (i, dune) in dunes.enumerated() {
            let phase = Double(i) * 1.7
            func y(_ x: Double) -> Double {
                h * dune.base + h * dune.amp * (sin(x / (w * 0.32) + phase) + 0.4 * sin(x / (w * 0.13) + phase * 2))
            }
            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))
            for x in stride(from: 0.0, through: w + 6, by: 6) { path.addLine(to: CGPoint(x: x, y: y(x))) }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
            ctx.fill(path, with: .linearGradient(Gradient(colors: [Color(hex: dune.light), Color(hex: dune.color)]),
                                                 startPoint: CGPoint(x: 0, y: h * (dune.base - dune.amp)), endPoint: CGPoint(x: w, y: h)))
            if i == 1 { ridgeY = y }
        }
        // The caravan: three camels walking slowly along the second dune's ridge.
        for c in 0..<3 {
            let x = WallpaperMath.fract(t * 0.012 + Double(c) * 0.06) * (w + 120) - 60
            drawCamel(&ctx, at: CGPoint(x: x, y: ridgeY(x)), scale: w / 400, step: t * 3 + Double(c))
        }
        // Sand blowing across the ground.
        let gusts = 30 + Int(40 * energy)
        for i in 0..<gusts {
            let y = h * (0.7 + 0.28 * WallpaperMath.random(i, 21))
            let x = WallpaperMath.fract(WallpaperMath.random(i, 22) + t * (0.25 + 0.2 * WallpaperMath.random(i, 23))) * (w + 80) - 40
            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y))
            streak.addLine(to: CGPoint(x: x + 22, y: y - 2))
            ctx.stroke(streak, with: .color(Color(hex: 0xFFE2B0, opacity: 0.25)), lineWidth: 1.2)
        }
    }

    /// A camel silhouette: body, hump, neck, head and four legs that swing as it walks.
    private static func drawCamel(_ ctx: inout GraphicsContext, at foot: CGPoint, scale s: Double, step: Double) {
        let ink = Color(hex: 0x3A1E1A)
        let body = CGRect(x: foot.x - 14 * s, y: foot.y - 22 * s, width: 28 * s, height: 11 * s)
        ctx.fill(Path(ellipseIn: body), with: .color(ink))
        ctx.fill(Path(ellipseIn: CGRect(x: foot.x - 7 * s, y: foot.y - 28 * s, width: 12 * s, height: 10 * s)), with: .color(ink))   // hump
        var neck = Path()
        neck.move(to: CGPoint(x: foot.x + 12 * s, y: foot.y - 18 * s))
        neck.addQuadCurve(to: CGPoint(x: foot.x + 22 * s, y: foot.y - 30 * s), control: CGPoint(x: foot.x + 22 * s, y: foot.y - 18 * s))
        ctx.stroke(neck, with: .color(ink), style: StrokeStyle(lineWidth: 4 * s, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: foot.x + 20 * s, y: foot.y - 33 * s, width: 8 * s, height: 5 * s)), with: .color(ink))
        for (i, legX) in [-10.0, -5.0, 6.0, 11.0].enumerated() {
            let swing = 3 * s * sin(step + Double(i % 2) * .pi)
            var leg = Path()
            leg.move(to: CGPoint(x: foot.x + legX * s, y: foot.y - 13 * s))
            leg.addLine(to: CGPoint(x: foot.x + legX * s + swing, y: foot.y))
            ctx.stroke(leg, with: .color(ink), style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
        }
    }
}

/// A giant savanna sun, an acacia tree, a giraffe strolling by and birds flying home.
enum SavannaSunsetRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        let groundY = h * 0.72
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x2B0F3A), location: 0),
            .init(color: Color(hex: 0xB8325A), location: 0.4),
            .init(color: Color(hex: 0xF77B3A), location: 0.62),
            .init(color: Color(hex: 0xFFC05A), location: 0.72),
        ])
        let sun = CGPoint(x: w * 0.5, y: h * 0.62)
        ctx.glow(at: sun, radius: w * 0.9, color: Color(hex: 0xFF9A3D), opacity: 0.5 + 0.3 * energy)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - w * 0.32, y: sun.y - w * 0.32, width: w * 0.64, height: w * 0.64)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xFFD27A), Color(hex: 0xFF6A3D)]),
                                       startPoint: CGPoint(x: 0, y: sun.y - w * 0.32), endPoint: CGPoint(x: 0, y: sun.y + w * 0.32)))
        drawBirds(&ctx, size: size, time: t, count: 7, color: Color(hex: 0x2A0F1E), salt: 60)
        let ink = Color(hex: 0x1A0B14)
        // The acacia: a crooked trunk and a wide, flat umbrella of leaves.
        var trunk = Path()
        trunk.move(to: CGPoint(x: w * 0.24, y: groundY))
        trunk.addCurve(to: CGPoint(x: w * 0.3, y: h * 0.53), control1: CGPoint(x: w * 0.26, y: h * 0.64), control2: CGPoint(x: w * 0.22, y: h * 0.58))
        trunk.move(to: CGPoint(x: w * 0.26, y: h * 0.6))
        trunk.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.535), control: CGPoint(x: w * 0.18, y: h * 0.57))
        ctx.stroke(trunk, with: .color(ink), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        for i in 0..<9 {
            let cx = w * (0.02 + 0.06 * Double(i)) + 4 * sin(t * 0.6 + Double(i))
            ctx.fill(Path(ellipseIn: CGRect(x: cx, y: h * (0.5 + 0.012 * sin(Double(i))), width: w * 0.12, height: h * 0.04)), with: .color(ink))
        }
        // The giraffe walks slowly from right to left.
        let gx = w * (1.1 - WallpaperMath.fract(t * 0.008) * 1.4)
        drawGiraffe(&ctx, at: CGPoint(x: gx, y: groundY), scale: w / 400, step: t * 2.2, ink: ink)
        // Ground and swaying grass.
        ctx.fill(Path(CGRect(x: 0, y: groundY, width: w, height: h - groundY)), with: .color(ink))
        var grass = Path()
        for i in 0..<90 {
            let x = w * Double(i) / 90 + 3 * WallpaperMath.random(i, 70)
            let height = 10 + 16 * WallpaperMath.random(i, 71)
            let sway = (3 + 4 * energy) * sin(t * 1.4 + Double(i) * 0.5)
            grass.move(to: CGPoint(x: x, y: groundY + 1))
            grass.addQuadCurve(to: CGPoint(x: x + sway, y: groundY - height), control: CGPoint(x: x, y: groundY - height * 0.5))
        }
        ctx.stroke(grass, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    private static func drawGiraffe(_ ctx: inout GraphicsContext, at foot: CGPoint, scale s: Double, step: Double, ink: Color) {
        let body = CGRect(x: foot.x - 18 * s, y: foot.y - 46 * s, width: 34 * s, height: 16 * s)
        ctx.fill(Path(roundedRect: body, cornerRadius: 8 * s), with: .color(ink))
        var neck = Path()
        neck.move(to: CGPoint(x: foot.x - 14 * s, y: foot.y - 42 * s))
        neck.addLine(to: CGPoint(x: foot.x - 30 * s, y: foot.y - 86 * s))
        ctx.stroke(neck, with: .color(ink), style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: foot.x - 42 * s, y: foot.y - 92 * s, width: 15 * s, height: 8 * s)), with: .color(ink))
        for (i, legX) in [-14.0, -8.0, 8.0, 13.0].enumerated() {
            var leg = Path()
            leg.move(to: CGPoint(x: foot.x + legX * s, y: foot.y - 32 * s))
            leg.addLine(to: CGPoint(x: foot.x + legX * s + 4 * s * sin(step + Double(i % 2) * .pi), y: foot.y))
            ctx.stroke(leg, with: .color(ink), style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round))
        }
    }
}

// MARK: - Caribbean

/// A tropical island at sunset: turquoise sea, swaying palm trees and gentle waves.
enum TropicalIslandRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        let horizon = h * 0.5
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x3A2C7A), location: 0),
            .init(color: Color(hex: 0xF06E8C), location: 0.34),
            .init(color: Color(hex: 0xFFB37A), location: 0.5),
        ])
        let sun = CGPoint(x: w * 0.55, y: horizon - w * 0.04)
        ctx.glow(at: sun, radius: w * 0.6, color: Color(hex: 0xFFD49A), opacity: 0.6 + 0.3 * energy)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - w * 0.09, y: sun.y - w * 0.09, width: w * 0.18, height: w * 0.18)), with: .color(Color(hex: 0xFFE7B5)))
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x2EC4C6), Color(hex: 0x127EA5), Color(hex: 0x0B4F7A)]),
                                       startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))
        for i in 0..<36 {                                   // sun glitter on the water
            let depth = WallpaperMath.random(i, 1)
            let y = horizon + (h * 0.3) * depth * depth + 4
            let x = sun.x + (WallpaperMath.random(i, 2) - 0.5) * w * (0.06 + 0.4 * depth)
            let shine = pow(WallpaperMath.twinkle(t, index: i, speed: 2.5), 3)
            ctx.fill(Path(CGRect(x: x - 8, y: y, width: 16 + 10 * depth, height: 1.5)), with: .color(Color(hex: 0xFFF1CC, opacity: 0.8 * shine)))
        }
        // The island and its beach.
        ctx.fill(Path(ellipseIn: CGRect(x: -w * 0.25, y: h * 0.78, width: w * 1.0, height: h * 0.3)), with: .color(Color(hex: 0xE9C28A)))
        ctx.fill(Path(ellipseIn: CGRect(x: -w * 0.2, y: h * 0.8, width: w * 0.85, height: h * 0.3)), with: .color(Color(hex: 0x2B5A3C)))
        // Foam lines rolling toward the beach.
        for k in 0..<3 {
            let phase = WallpaperMath.fract(t * 0.12 + Double(k) / 3)
            var foam = Path()
            foam.addArc(center: CGPoint(x: w * 0.25, y: h * 0.93), radius: w * (0.55 + 0.25 * (1 - phase)),
                        startAngle: .degrees(200), endAngle: .degrees(330), clockwise: false)
            ctx.stroke(foam, with: .color(.white.opacity(0.35 * phase)), lineWidth: 2)
        }
        // Two palm trees, swaying more as energy rises.
        for (baseX, height, lean) in [(0.18, 0.36, 0.08), (0.34, 0.28, -0.05)] {
            let sway = (0.04 + 0.05 * energy) * sin(t * 0.9 + baseX * 10)
            let top = CGPoint(x: w * (baseX + lean + sway * 0.4), y: h * (0.84 - height))
            var trunk = Path()
            trunk.move(to: CGPoint(x: w * baseX, y: h * 0.86))
            trunk.addQuadCurve(to: top, control: CGPoint(x: w * (baseX + lean * 0.2), y: h * (0.84 - height * 0.5)))
            ctx.stroke(trunk, with: .color(Color(hex: 0x2A1A1E)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            for f in 0..<8 {
                let angle = Double(f) / 8 * 2 * .pi + sway * 3
                let length = w * 0.16
                let tip = CGPoint(x: top.x + cos(angle) * length, y: top.y + sin(angle) * length * 0.45 + length * 0.25)
                var frond = Path()
                frond.move(to: top)
                frond.addQuadCurve(to: tip, control: CGPoint(x: top.x + cos(angle) * length * 0.5, y: top.y - length * 0.2))
                ctx.stroke(frond, with: .color(Color(hex: 0x1E3A24)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
    }
}

// MARK: - Himalaya

/// Snowy Himalayan peaks in morning light, clouds in the valleys and prayer flags in the wind.
enum HimalayaRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x0E2A5A), location: 0),
            .init(color: Color(hex: 0x5B8FD0), location: 0.45),
            .init(color: Color(hex: 0xFFD9B0), location: 0.62),
        ])
        ctx.glow(at: CGPoint(x: w * 0.85, y: h * 0.55), radius: w * 0.6, color: Color(hex: 0xFFE2B8), opacity: 0.5 + 0.2 * energy)
        // Back range (pale blue) and the big peak with snow and golden "alpenglow".
        ctx.fill(poly([(0, 0.62), (0.1, 0.5), (0.2, 0.55), (0.32, 0.44), (0.45, 0.53), (0.6, 0.47), (0.75, 0.55), (0.9, 0.46), (1, 0.52), (1, 0.7), (0, 0.7)], in: size),
                 with: .color(Color(hex: 0x9DB4D4)))
        let peak = poly([(0.05, 0.75), (0.3, 0.52), (0.42, 0.56), (0.55, 0.3), (0.68, 0.5), (0.8, 0.46), (1.0, 0.68), (1.0, 0.8), (0.05, 0.8)], in: size)
        ctx.fill(peak, with: .linearGradient(Gradient(colors: [Color(hex: 0x5D7AA3), Color(hex: 0x2E4568)]),
                                             startPoint: CGPoint(x: 0, y: h * 0.3), endPoint: CGPoint(x: 0, y: h * 0.8)))
        ctx.fill(poly([(0.55, 0.3), (0.62, 0.4), (0.58, 0.39), (0.55, 0.43), (0.52, 0.39), (0.47, 0.42)], in: size), with: .color(.white.opacity(0.95)))
        ctx.fill(poly([(0.55, 0.3), (0.68, 0.5), (0.64, 0.49), (0.6, 0.42)], in: size), with: .color(Color(hex: 0xFFB27A, opacity: 0.5 + 0.3 * energy)))
        // Clouds drifting through the valleys.
        for i in 0..<7 {
            let x = WallpaperMath.fract(WallpaperMath.random(i, 31) + t * 0.008 * (1 + WallpaperMath.random(i, 32))) * (w * 1.6) - w * 0.3
            ctx.glow(at: CGPoint(x: x, y: h * (0.58 + 0.08 * WallpaperMath.random(i, 33))), radius: w * 0.22, color: .white, opacity: 0.32)
        }
        ctx.fill(poly([(0, 0.82), (0.3, 0.78), (0.6, 0.83), (1, 0.79), (1, 1), (0, 1)], in: size), with: .color(Color(hex: 0x1A2236)))
        // Prayer flags on a sagging string: blue, white, red, green, yellow.
        let colors: [UInt32] = [0x2F6FD6, 0xF4F4F4, 0xD8343A, 0x2FA35A, 0xF5C531]
        let count = 18
        func stringPoint(_ u: Double) -> CGPoint {
            CGPoint(x: w * u, y: h * (0.62 + 0.08 * u) + h * 0.06 * sin(u * .pi))
        }
        var line = Path()
        line.move(to: stringPoint(0))
        for k in 1...40 { line.addLine(to: stringPoint(Double(k) / 40)) }
        ctx.stroke(line, with: .color(Color(hex: 0x3A2A1E)), lineWidth: 1.2)
        for i in 0..<count {
            let u = (Double(i) + 0.5) / Double(count)
            let top = stringPoint(u)
            let flutter = (2 + 4 * energy) * sin(t * 5 + Double(i) * 0.8)
            let fw = w / Double(count) * 0.8, fh = h * 0.04
            var flag = Path()
            flag.move(to: CGPoint(x: top.x - fw / 2, y: top.y))
            flag.addLine(to: CGPoint(x: top.x + fw / 2, y: top.y))
            flag.addLine(to: CGPoint(x: top.x + fw / 2 + flutter, y: top.y + fh))
            flag.addLine(to: CGPoint(x: top.x - fw / 2 + flutter, y: top.y + fh))
            flag.closeSubpath()
            ctx.fill(flag, with: .color(Color(hex: colors[i % colors.count], opacity: 0.92)))
        }
    }
}

// MARK: - Europe

/// Paris at night: the Eiffel Tower sparkling, a rotating searchlight and glowing rooftops.
enum ParisNightsRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x0A0E2E), location: 0),
            .init(color: Color(hex: 0x2A2052), location: 0.6),
            .init(color: Color(hex: 0x5A2E58), location: 0.85),
        ])
        StarField.draw(&ctx, size: size, time: t, count: 90, maxY: 0.6)
        ctx.glow(at: CGPoint(x: w * 0.82, y: h * 0.12), radius: w * 0.25, color: Color(hex: 0xFFF4D6), opacity: 0.35)
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.78, y: h * 0.1, width: w * 0.08, height: w * 0.08)), with: .color(Color(hex: 0xFFF7E6)))
        let top = CGPoint(x: w * 0.5, y: h * 0.16)
        // The searchlight from the top of the tower.
        let angle = t * 0.6
        ctx.drawLayer { beam in
            beam.blendMode = .plusLighter
            var wedge = Path()
            wedge.move(to: top)
            wedge.addLine(to: CGPoint(x: top.x + cos(angle - 0.05) * h, y: top.y + sin(angle - 0.05) * h * 0.3 - h * 0.05))
            wedge.addLine(to: CGPoint(x: top.x + cos(angle + 0.05) * h, y: top.y + sin(angle + 0.05) * h * 0.3 - h * 0.05))
            wedge.closeSubpath()
            beam.fill(wedge, with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE9B0, opacity: 0.35), .clear]), center: top, startRadius: 0, endRadius: h))
        }
        // The tower: two curved legs meeting at the top, with platforms and the arch.
        let ink = Color(hex: 0x16112C)
        var tower = Path()
        tower.move(to: CGPoint(x: w * 0.28, y: h * 0.86))
        tower.addQuadCurve(to: CGPoint(x: w * 0.485, y: h * 0.3), control: CGPoint(x: w * 0.44, y: h * 0.52))
        tower.addLine(to: top)
        tower.addLine(to: CGPoint(x: w * 0.515, y: h * 0.3))
        tower.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.86), control: CGPoint(x: w * 0.56, y: h * 0.52))
        tower.addLine(to: CGPoint(x: w * 0.62, y: h * 0.86))
        tower.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.86), control: CGPoint(x: w * 0.5, y: h * 0.7))
        tower.closeSubpath()
        ctx.fill(tower, with: .color(ink))
        for (y, half) in [(0.66, 0.13), (0.48, 0.065)] {
            ctx.fill(Path(CGRect(x: w * (0.5 - half), y: h * y, width: w * half * 2, height: h * 0.012)), with: .color(ink))
        }
        ctx.fill(Path(CGRect(x: top.x - 1.5, y: top.y - h * 0.04, width: 3, height: h * 0.04)), with: .color(ink))
        // Golden lights all over the tower, plus the famous sparkle (more with energy).
        for i in 0..<70 {
            let u = WallpaperMath.random(i, 41)
            let side = WallpaperMath.random(i, 42) < 0.5 ? -1.0 : 1.0
            let spread = (1 - u) * 0.2 * WallpaperMath.random(i, 43)
            let p = CGPoint(x: w * (0.5 + side * spread), y: top.y + (h * 0.86 - top.y) * u)
            ctx.glow(at: p, radius: 3.5, color: Color(hex: 0xFFC46B), opacity: 0.8)
            let sparkle = pow(WallpaperMath.twinkle(t, index: i, speed: 3), 8) * (0.4 + 0.6 * energy)
            ctx.glow(at: p, radius: 7, color: .white, opacity: sparkle)
        }
        // Rooftops with chimneys and warm windows.
        var roofs = Path()
        var x = 0.0
        var i = 0
        while x < w {
            let width = w * (0.08 + 0.06 * WallpaperMath.random(i, 51))
            let height = h * (0.08 + 0.05 * WallpaperMath.random(i, 52))
            roofs.addRect(CGRect(x: x, y: h - height, width: width + 1, height: height))
            roofs.addRect(CGRect(x: x + width * 0.3, y: h - height - 8, width: 5, height: 8))
            x += width
            i += 1
        }
        ctx.fill(roofs, with: .color(Color(hex: 0x0C0A1E)))
        for k in 0..<40 {
            let wx = w * WallpaperMath.random(k, 61), wy = h * (0.93 + 0.05 * WallpaperMath.random(k, 62))
            let on = WallpaperMath.random(Int(t / 4) + k * 7, 63) > 0.35
            if on { ctx.fill(Path(CGRect(x: wx, y: wy, width: 4, height: 5)), with: .color(Color(hex: 0xFFC46B, opacity: 0.85))) }
        }
    }
}

/// A sunny Alpine meadow: snowy Alps, green hills, a chalet and wildflowers in the breeze.
enum AlpineMeadowRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x3F8FD8), location: 0),
            .init(color: Color(hex: 0xBFE3F7), location: 0.5),
        ])
        ctx.glow(at: CGPoint(x: w * 0.82, y: h * 0.12), radius: w * 0.45, color: Color(hex: 0xFFF6D8), opacity: 0.7 + 0.2 * energy)
        for i in 0..<5 {                                    // clouds
            let x = WallpaperMath.fract(WallpaperMath.random(i, 1) + t * 0.006) * (w * 1.5) - w * 0.25
            ctx.glow(at: CGPoint(x: x, y: h * (0.1 + 0.15 * WallpaperMath.random(i, 2))), radius: w * 0.18, color: .white, opacity: 0.7)
        }
        ctx.fill(poly([(0, 0.5), (0.12, 0.36), (0.22, 0.44), (0.36, 0.3), (0.5, 0.42), (0.64, 0.33), (0.8, 0.45), (0.92, 0.38), (1, 0.44), (1, 0.6), (0, 0.6)], in: size),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xF4F8FF), Color(hex: 0x9FB6D6)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.3), endPoint: CGPoint(x: 0, y: h * 0.6)))
        let hills: [(Double, Double, UInt32)] = [(0.58, 0.04, 0x8CCB79), (0.68, 0.05, 0x5DAA5C), (0.8, 0.05, 0x3A8A47)]
        for (i, hill) in hills.enumerated() {
            ctx.fill(wavyHorizon(in: size, baseY: h * hill.0, amplitude: h * hill.1, waves: [(w * 0.3, Double(i)), (w * 0.12, 2 + Double(i))]),
                     with: .color(Color(hex: hill.2)))
            if i == 1 {                                       // a chalet on the middle hill
                let cx = w * 0.7, cy = h * 0.66
                ctx.fill(Path(CGRect(x: cx - 18, y: cy - 16, width: 36, height: 18)), with: .color(Color(hex: 0x7A4A2A)))
                ctx.fill(poly([(0.7 - 0.06, 0.66 - 0.018), (0.7, 0.66 - 0.045), (0.7 + 0.06, 0.66 - 0.018)], in: size), with: .color(Color(hex: 0x4A2A18)))
                ctx.fill(Path(CGRect(x: cx - 4, y: cy - 10, width: 8, height: 8)), with: .color(Color(hex: 0xFFE1A0)))
            }
        }
        // Wildflowers that nod in the wind.
        let palette: [UInt32] = [0xFFFFFF, 0xFFD84A, 0xB28DFF, 0xFF7AA8]
        for i in 0..<130 {
            let depth = WallpaperMath.random(i, 11)
            let baseY = h * (0.8 + 0.2 * depth)
            let x = w * WallpaperMath.random(i, 12) + (2 + 3 * energy) * sin(t * 1.5 + Double(i))
            let r = 1.5 + 3 * depth
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: baseY - r, width: r * 2, height: r * 2)), with: .color(Color(hex: palette[i % palette.count])))
        }
    }
}

/// The misty Scottish Highlands: rolling hills, a castle and mist drifting through.
enum ScottishHighlandsRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x2E3A4E), location: 0),
            .init(color: Color(hex: 0x7A8A9A), location: 0.45),
            .init(color: Color(hex: 0xE6BD8A), location: 0.6),
        ])
        ctx.glow(at: CGPoint(x: w * 0.3, y: h * 0.55), radius: w * 0.5, color: Color(hex: 0xFFD9A0), opacity: 0.4 + 0.3 * energy)
        ctx.fill(wavyHorizon(in: size, baseY: h * 0.58, amplitude: h * 0.05, waves: [(w * 0.28, 0.4), (w * 0.1, 1.9)]), with: .color(Color(hex: 0x5E7A5A)))
        // The castle on the middle hill.
        let ink = Color(hex: 0x2A3328)
        let cx = w * 0.62, base = h * 0.64
        var castle = Path()
        castle.addRect(CGRect(x: cx - 30, y: base - 34, width: 60, height: 34))
        for tx in [-34.0, 26.0] { castle.addRect(CGRect(x: cx + tx, y: base - 52, width: 12, height: 52)) }
        castle.addRect(CGRect(x: cx - 8, y: base - 58, width: 16, height: 24))
        for k in 0..<6 { castle.addRect(CGRect(x: cx - 30 + Double(k) * 11, y: base - 40, width: 6, height: 6)) }
        ctx.fill(castle, with: .color(ink))
        ctx.fill(wavyHorizon(in: size, baseY: h * 0.68, amplitude: h * 0.06, waves: [(w * 0.24, 2.2), (w * 0.09, 0.7)]), with: .color(Color(hex: 0x3A5238)))
        ctx.fill(wavyHorizon(in: size, baseY: h * 0.82, amplitude: h * 0.05, waves: [(w * 0.3, 1.0), (w * 0.11, 3.0)]), with: .color(Color(hex: 0x1E2E20)))
        // Mist drifting in bands.
        for i in 0..<6 {
            let x = WallpaperMath.fract(WallpaperMath.random(i, 21) + t * 0.01 * (1 + energy)) * (w * 1.8) - w * 0.4
            ctx.glow(at: CGPoint(x: x, y: h * (0.6 + 0.12 * WallpaperMath.random(i, 22))), radius: w * 0.35, color: .white, opacity: 0.22)
        }
        for i in 0..<80 {                                    // purple heather
            let p = CGPoint(x: w * WallpaperMath.random(i, 31), y: h * (0.86 + 0.13 * WallpaperMath.random(i, 32)))
            ctx.glow(at: p, radius: 4, color: Color(hex: 0xB86BC8), opacity: 0.7)
        }
    }
}

// MARK: - South America

/// The Andes at sunrise: terraced peaks above the clouds, and condors gliding in wide circles.
enum AndesCondorRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x23154A), location: 0),
            .init(color: Color(hex: 0x9A3F6E), location: 0.45),
            .init(color: Color(hex: 0xF2A35C), location: 0.62),
        ])
        ctx.glow(at: CGPoint(x: w * 0.25, y: h * 0.6), radius: w * 0.6, color: Color(hex: 0xFFC27A), opacity: 0.5 + 0.3 * energy)
        ctx.fill(poly([(0, 0.62), (0.15, 0.5), (0.3, 0.58), (0.5, 0.45), (0.7, 0.56), (0.85, 0.48), (1, 0.56), (1, 0.75), (0, 0.75)], in: size), with: .color(Color(hex: 0x6A3F6E)))
        // The steep green peak with farming terraces.
        // WHY these points (found in the visual check): a narrow triangle looked like a green cone.
        // A wide base with a steep, rounded top reads as a real Andes peak.
        let peak = poly([(0.18, 0.84), (0.36, 0.6), (0.44, 0.5), (0.5, 0.42), (0.56, 0.39), (0.62, 0.42),
                         (0.68, 0.5), (0.76, 0.62), (0.92, 0.84)], in: size)
        ctx.fill(peak, with: .linearGradient(Gradient(colors: [Color(hex: 0x3F6E4A), Color(hex: 0x1E3A2A)]),
                                             startPoint: CGPoint(x: 0, y: h * 0.4), endPoint: CGPoint(x: 0, y: h * 0.8)))
        var terraces = Path()
        for k in 0..<9 {
            let y = h * (0.5 + 0.035 * Double(k))
            let half = w * (0.09 + 0.028 * Double(k))
            terraces.move(to: CGPoint(x: w * 0.55 - half, y: y))
            terraces.addQuadCurve(to: CGPoint(x: w * 0.55 + half, y: y), control: CGPoint(x: w * 0.55, y: y + 6))
        }
        ctx.stroke(terraces, with: .color(Color(hex: 0x8FCF7A, opacity: 0.5)), lineWidth: 1.2)
        for i in 0..<6 {                                       // clouds below the peaks
            let x = WallpaperMath.fract(WallpaperMath.random(i, 11) + t * 0.01) * (w * 1.6) - w * 0.3
            ctx.glow(at: CGPoint(x: x, y: h * (0.74 + 0.05 * WallpaperMath.random(i, 12))), radius: w * 0.25, color: Color(hex: 0xFFE6D0), opacity: 0.45)
        }
        ctx.fill(poly([(0, 0.85), (0.4, 0.8), (1, 0.86), (1, 1), (0, 1)], in: size), with: .color(Color(hex: 0x1A1028)))
        // Two condors circling: big wings that flex slowly.
        for (k, depth) in [(0, 1.0), (1, 0.6)] {
            let angle = t * 0.18 * (1 + 0.3 * Double(k)) + Double(k) * 2.4
            let center = CGPoint(x: w * (0.5 + 0.28 * cos(angle)), y: h * (0.25 + 0.06 * Double(k) + 0.05 * sin(angle)))
            drawCondor(&ctx, at: center, span: w * 0.26 * depth, flex: sin(t * 1.2 + Double(k)))
        }
    }

    private static func drawCondor(_ ctx: inout GraphicsContext, at c: CGPoint, span: Double, flex: Double) {
        let ink = Color(hex: 0x1A0F22)
        let lift = span * 0.06 * flex
        var wings = Path()
        wings.move(to: CGPoint(x: c.x - span / 2, y: c.y - lift))
        wings.addQuadCurve(to: CGPoint(x: c.x, y: c.y), control: CGPoint(x: c.x - span / 4, y: c.y - span * 0.12 - lift))
        wings.addQuadCurve(to: CGPoint(x: c.x + span / 2, y: c.y - lift), control: CGPoint(x: c.x + span / 4, y: c.y - span * 0.12 - lift))
        wings.addQuadCurve(to: CGPoint(x: c.x, y: c.y + span * 0.05), control: CGPoint(x: c.x + span / 4, y: c.y - span * 0.04))
        wings.addQuadCurve(to: CGPoint(x: c.x - span / 2, y: c.y - lift), control: CGPoint(x: c.x - span / 4, y: c.y - span * 0.04))
        ctx.fill(wings, with: .color(ink))
        for side in [-1.0, 1.0] {                              // "finger" feathers at the wing tips
            for f in 0..<4 {
                var feather = Path()
                let start = CGPoint(x: c.x + side * span * (0.42 - 0.02 * Double(f)), y: c.y - lift - span * 0.01)
                feather.move(to: start)
                feather.addLine(to: CGPoint(x: start.x + side * span * 0.07, y: start.y - span * 0.02 * Double(f - 1)))
                ctx.stroke(feather, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - span * 0.03, y: c.y - span * 0.05, width: span * 0.06, height: span * 0.05)), with: .color(Color(hex: 0xEDE6F0)))
    }
}

// MARK: - City

/// A city skyline at night: windows switching on and off, the moon, and traffic light trails.
enum CityLightsRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x070A1F), location: 0),
            .init(color: Color(hex: 0x1B1F4A), location: 0.6),
            .init(color: Color(hex: 0x4A2A55), location: 0.85),
        ])
        StarField.draw(&ctx, size: size, time: t, count: 50, maxY: 0.4)
        ctx.glow(at: CGPoint(x: w * 0.22, y: h * 0.14), radius: w * 0.2, color: Color(hex: 0xEAF0FF), opacity: 0.35)
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.12, width: w * 0.08, height: w * 0.08)), with: .color(Color(hex: 0xF4F6FF)))
        ctx.glow(at: CGPoint(x: w * 0.5, y: h * 0.86), radius: w * 0.9, color: Color(hex: 0xFF8A5B), opacity: 0.25 + 0.2 * energy)
        // Three rows of buildings; the front rows have windows.
        let layers: [(UInt32, Double, Double, Int)] = [(0x1F2556, 0.42, 0.25, 0), (0x141838, 0.52, 0.3, 1), (0x0A0C1C, 0.62, 0.32, 2)]
        for (color, minTop, variance, layer) in layers {
            var x = -10.0
            var i = layer * 100
            while x < w {
                let bw = w * (0.07 + 0.08 * WallpaperMath.random(i, 1))
                let top = h * (minTop + variance * WallpaperMath.random(i, 2))
                ctx.fill(Path(CGRect(x: x, y: top, width: bw - 2, height: h - top)), with: .color(Color(hex: color)))
                if layer == 1 && WallpaperMath.random(i, 9) > 0.7 {           // an antenna with a red light
                    ctx.fill(Path(CGRect(x: x + bw / 2 - 1, y: top - 24, width: 2, height: 24)), with: .color(Color(hex: color)))
                    ctx.glow(at: CGPoint(x: x + bw / 2, y: top - 24), radius: 5, color: .red, opacity: 0.5 + 0.5 * sin(t * 3 + Double(i)))
                }
                if layer > 0 {
                    for row in stride(from: top + 8, to: h * 0.92, by: 12) {
                        for col in stride(from: x + 5, to: x + bw - 8, by: 9) {
                            let seed = Int(row) * 31 + Int(col) * 17
                            // Each window flips on/off every few seconds, at its own rhythm.
                            let on = WallpaperMath.random(seed + Int(t / (4 + 6 * WallpaperMath.random(seed, 3))), 4) > 0.55
                            if on {
                                ctx.fill(Path(CGRect(x: col, y: row, width: 4, height: 6)),
                                         with: .color(Color(hex: WallpaperMath.random(seed, 5) > 0.3 ? 0xFFD27A : 0x9AD8FF, opacity: 0.85)))
                            }
                        }
                    }
                }
                x += bw
                i += 1
            }
        }
        // The street: red tail-lights going left, white headlights going right.
        ctx.fill(Path(CGRect(x: 0, y: h * 0.92, width: w, height: h * 0.08)), with: .color(Color(hex: 0x05060F)))
        let cars = 14 + Int(14 * energy)
        for i in 0..<cars {
            let goingRight = i % 2 == 0
            let speed = 0.12 + 0.1 * WallpaperMath.random(i, 21)
            var x = WallpaperMath.fract(WallpaperMath.random(i, 22) + t * speed) * (w + 80) - 40
            if !goingRight { x = w - x }
            let y = h * (goingRight ? 0.95 : 0.935)
            let trail = 40.0
            let color = goingRight ? Color(hex: 0xFFF2D6) : Color(hex: 0xFF3B4A)
            ctx.fill(Path(CGRect(x: goingRight ? x - trail : x, y: y, width: trail, height: 2)),
                     with: .linearGradient(Gradient(colors: goingRight ? [.clear, color] : [color, .clear]),
                                           startPoint: CGPoint(x: goingRight ? x - trail : x, y: 0), endPoint: CGPoint(x: goingRight ? x : x + trail, y: 0)))
        }
    }
}
