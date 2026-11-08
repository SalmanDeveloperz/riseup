//
//  SpaceWallpapers.swift
//  RiseUp
//
//  LAYER: View (live-wallpaper renderers, category "Space")
//  WHAT:  Hyperspace · Nebula · Planet Rise.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← CALLED BY: LiveWallpaperView
//    → USES:      WallpaperMath, StarField, GraphicsContext.glow / fillSky
//

import SwiftUI

/// Flying through stars: they stream out of the centre, faster and longer as energy rises.
enum HyperspaceRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        let center = CGPoint(x: w / 2, y: h * 0.45)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x02010A)))
        ctx.glow(at: center, radius: w * 0.9, color: Color(hex: 0x5B2DFF), opacity: 0.35 + 0.25 * energy)

        // LEARN: 3D in 10 lines. Each star has a direction (x, y) and a distance z (1 = far,
        // ~0 = right in front of us). On screen: position = centre + direction / z.
        // Making z shrink over time = flying forward.
        let speed = 0.12
        let tints: [UInt32] = [0xFFFFFF, 0xBFD7FF, 0xFFB3E1, 0xB8A6FF]
        let scale = max(w, h) * 0.5
        for i in 0..<220 {
            let dx = WallpaperMath.random(i, 1) * 2 - 1
            let dy = WallpaperMath.random(i, 2) * 2 - 1
            let z = 1 - WallpaperMath.fract(WallpaperMath.random(i, 3) + t * speed)
            let zTail = min(1, z + 0.02 + speed * 0.12)          // where the star was a moment ago
            guard z > 0.02 else { continue }
            let head = CGPoint(x: center.x + dx / z * scale * 0.2, y: center.y + dy / z * scale * 0.2)
            let tail = CGPoint(x: center.x + dx / zTail * scale * 0.2, y: center.y + dy / zTail * scale * 0.2)
            var streak = Path()
            streak.move(to: tail)
            streak.addLine(to: head)
            let brightness = min(1, (1 - z) * 1.4)
            ctx.stroke(streak, with: .color(Color(hex: tints[i % tints.count], opacity: brightness)),
                       style: StrokeStyle(lineWidth: 0.6 + 2.2 * (1 - z), lineCap: .round))
        }
    }
}

/// Glowing gas clouds slowly turning in deep space.
enum NebulaRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x05010F)))
        StarField.draw(&ctx, size: size, time: t, count: 150)

        let colors: [UInt32] = [0x8B5CFF, 0xFF3D8B, 0x3DD6FF, 0x2EE6B6, 0xFF8A3D, 0x5B2DFF]
        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            // The whole cloud turns very slowly around the centre.
            layer.translateBy(x: w / 2, y: h / 2)
            layer.rotate(by: .radians(t * 0.02))
            layer.translateBy(x: -w / 2, y: -h / 2)
            for i in 0..<colors.count {
                let x = w * (0.2 + 0.6 * WallpaperMath.random(i, 61)) + w * 0.12 * WallpaperMath.wave(t, period: 23 + Double(i) * 3)
                let y = h * (0.2 + 0.6 * WallpaperMath.random(i, 62)) + h * 0.08 * WallpaperMath.wave(t, period: 29 + Double(i) * 2, phase: 0.3)
                let radius = w * (0.45 + 0.35 * WallpaperMath.random(i, 63)) * (1 + 0.15 * energy)
                layer.glow(at: CGPoint(x: x, y: y), radius: radius, color: Color(hex: colors[i]),
                           opacity: 0.28 + 0.12 * WallpaperMath.twinkle(t, index: i, speed: 0.2))
            }
        }
        // A few bright young stars inside the cloud.
        for i in 0..<6 {
            let p = CGPoint(x: w * WallpaperMath.random(i, 71), y: h * (0.2 + 0.6 * WallpaperMath.random(i, 72)))
            ctx.glow(at: p, radius: 22, color: .white, opacity: 0.5 + 0.5 * WallpaperMath.twinkle(t, index: i + 90))
        }
    }
}

/// A ringed planet rising above a big blue world, with a little moon circling it.
enum PlanetRiseRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x03020C), location: 0),
            .init(color: Color(hex: 0x120B2E), location: 1),
        ])
        StarField.draw(&ctx, size: size, time: t, count: 120, maxY: 0.8)

        // The ringed planet.
        let center = CGPoint(x: w * 0.6, y: h * (0.38 - 0.03 * energy) + h * 0.012 * WallpaperMath.wave(t, period: 11))
        let r = w * 0.17
        let ring = CGRect(x: center.x - r * 2.1, y: center.y - r * 0.55, width: r * 4.2, height: r * 1.1)
        let tilt = Angle.degrees(-16)
        func ringPath() -> Path {
            Path(ellipseIn: ring).applying(
                CGAffineTransform(translationX: center.x, y: center.y).rotated(by: tilt.radians).translatedBy(x: -center.x, y: -center.y))
        }
        let ringStyle = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(hex: 0xFFD6A5, opacity: 0.2), Color(hex: 0xFFB36B, opacity: 0.85), Color(hex: 0xFF6FA5, opacity: 0.2)]),
            startPoint: CGPoint(x: ring.minX, y: 0), endPoint: CGPoint(x: ring.maxX, y: 0))
        // Back half of the ring (behind the planet).
        var back = ctx
        back.clip(to: Path(CGRect(x: 0, y: 0, width: w, height: center.y)))
        back.stroke(ringPath(), with: ringStyle, lineWidth: r * 0.16)
        // The planet: lit from the upper left, dark on the lower right.
        ctx.glow(at: center, radius: r * 1.8, color: Color(hex: 0xFF8A5B), opacity: 0.35 + 0.2 * energy)
        let planet = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.fill(planet, with: .radialGradient(
            Gradient(colors: [Color(hex: 0xFFC48A), Color(hex: 0xE0607E), Color(hex: 0x3A1450)]),
            center: CGPoint(x: center.x - r * 0.4, y: center.y - r * 0.4), startRadius: 0, endRadius: r * 2))
        // Front half of the ring.
        var front = ctx
        front.clip(to: Path(CGRect(x: 0, y: center.y, width: w, height: h - center.y)))
        front.stroke(ringPath(), with: ringStyle, lineWidth: r * 0.16)

        // The moon: in front of the planet for half its orbit, behind for the other half.
        let angle = t * 0.35
        let moon = CGPoint(x: center.x + cos(angle) * r * 2.6, y: center.y + sin(angle) * r * 0.9)
        let moonPath = Path(ellipseIn: CGRect(x: moon.x - r * 0.16, y: moon.y - r * 0.16, width: r * 0.32, height: r * 0.32))
        if sin(angle) > 0 || hypot(moon.x - center.x, moon.y - center.y) > r {
            ctx.fill(moonPath, with: .color(Color(hex: 0xDCE6FF)))
        }

        // The big world below, with a glowing atmosphere edge.
        let worldR = w * 1.3
        let worldCenter = CGPoint(x: w * 0.4, y: h * 0.78 + worldR)
        ctx.glow(at: CGPoint(x: worldCenter.x, y: worldCenter.y - worldR), radius: w * 0.9, color: Color(hex: 0x3DD6FF), opacity: 0.35)
        ctx.fill(Path(ellipseIn: CGRect(x: worldCenter.x - worldR, y: worldCenter.y - worldR, width: worldR * 2, height: worldR * 2)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x1B6FA8), Color(hex: 0x0A2246), Color(hex: 0x040A1A)]),
                                       startPoint: CGPoint(x: 0, y: worldCenter.y - worldR), endPoint: CGPoint(x: 0, y: h)))
        ctx.stroke(Path(ellipseIn: CGRect(x: worldCenter.x - worldR, y: worldCenter.y - worldR, width: worldR * 2, height: worldR * 2)),
                   with: .color(Color(hex: 0x8FE9FF, opacity: 0.6)), lineWidth: 2)
    }
}
