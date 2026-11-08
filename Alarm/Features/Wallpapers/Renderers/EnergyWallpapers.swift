//
//  EnergyWallpapers.swift
//  RiseUp
//
//  LAYER: View (live-wallpaper renderers, category "Neon Energy")
//  WHAT:  Synthwave · Neon Pulse · Lava Lamp. The loudest, most energetic looks.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← CALLED BY: LiveWallpaperView
//    → USES:      WallpaperMath, StarField, GraphicsContext.glow / fillSky
//

import SwiftUI

/// The retro-future classic: striped neon sun, purple mountains and a glowing grid rushing toward you.
enum SynthwaveRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        let horizon = h * 0.56
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x0D0221), location: 0),
            .init(color: Color(hex: 0x3A0C5A), location: 0.35),
            .init(color: Color(hex: 0xC2185B), location: 0.56),
        ])
        StarField.draw(&ctx, size: CGSize(width: w, height: horizon), time: t, count: 70, maxY: 0.7)

        // The sun with horizontal stripes cut out of its lower half.
        let r = w * 0.3
        let sunCenter = CGPoint(x: w / 2, y: horizon - r * 0.55)     // sits ON the horizon
        ctx.glow(at: sunCenter, radius: r * 2.2, color: Color(hex: 0xFF3D8B), opacity: 0.5 + 0.3 * energy)
        ctx.drawLayer { layer in
            let disc = Path(ellipseIn: CGRect(x: sunCenter.x - r, y: sunCenter.y - r, width: r * 2, height: r * 2))
            layer.fill(disc, with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFE66B), Color(hex: 0xFF8A3D), Color(hex: 0xFF2D95)]),
                startPoint: CGPoint(x: 0, y: sunCenter.y - r), endPoint: CGPoint(x: 0, y: sunCenter.y + r)))
            // LEARN: `.destinationOut` ERASES what's already in this layer where we draw,
            // so these bars become holes that show the sky behind the sun.
            layer.blendMode = .destinationOut
            let drift = WallpaperMath.fract(t * 0.25)
            for i in 0..<7 {
                let p = (Double(i) + drift) / 7
                let y = sunCenter.y + r * (0.05 + 0.95 * p)
                let height = 2 + 9 * p
                layer.fill(Path(CGRect(x: sunCenter.x - r, y: y, width: r * 2, height: height)), with: .color(.black))
            }
        }

        // Mountains on both sides (the middle stays open so the striped sun shows), outlined in neon.
        var mountains = Path()
        mountains.move(to: CGPoint(x: 0, y: horizon))
        let peaks: [(x: Double, y: Double)] = [(0.0, 0.47), (0.07, 0.43), (0.15, 0.5), (0.22, 0.46), (0.3, 0.56),
                                               (0.7, 0.56), (0.78, 0.47), (0.86, 0.51), (0.93, 0.44), (1.0, 0.49)]
        for peak in peaks { mountains.addLine(to: CGPoint(x: w * peak.x, y: h * peak.y)) }
        mountains.addLine(to: CGPoint(x: w, y: horizon))
        mountains.closeSubpath()
        ctx.fill(mountains, with: .linearGradient(Gradient(colors: [Color(hex: 0x2A0845), Color(hex: 0x12022B)]),
                                                  startPoint: CGPoint(x: 0, y: h * 0.44), endPoint: CGPoint(x: 0, y: horizon)))
        ctx.stroke(mountains, with: .color(Color(hex: 0xFF4FD8, opacity: 0.6)), lineWidth: 1.5)

        // The ground covers the bottom of the sun: the sun "sets" behind the horizon.
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x1A0433), Color(hex: 0x05000F)]),
            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))

        // The grid: lines fan out from the vanishing point; cross lines rush toward the viewer.
        let gridColor = Color(hex: 0xFF4FD8)
        var grid = Path()
        for i in -14...14 {
            grid.move(to: CGPoint(x: w / 2 + Double(i) * w * 0.025, y: horizon))
            grid.addLine(to: CGPoint(x: w / 2 + Double(i) * w * 0.32, y: h))
        }
        let speed = 0.6
        let rows = 14
        for k in 0..<rows {
            // LEARN: squaring the position makes lines bunch up near the horizon = perspective.
            let z = WallpaperMath.fract(Double(k) / Double(rows) + t * speed / Double(rows))
            let y = horizon + (h - horizon) * z * z
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: w, y: y))
        }
        ctx.stroke(grid, with: .color(gridColor.opacity(0.25)), lineWidth: 5)    // soft glow
        ctx.stroke(grid, with: .color(gridColor.opacity(0.9)), lineWidth: 1.2)   // bright core
        // Fade the grid into the horizon haze.
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h * 0.08)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xC2185B, opacity: 0.8), .clear]),
                                       startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: horizon + h * 0.08)))
    }
}

/// Neon rings beating out from a glowing core, like sound waves of the alarm itself.
enum NeonPulseRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        let center = CGPoint(x: w / 2, y: h * 0.45)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [Color(hex: 0x1C0B3A), Color(hex: 0x07051A)]),
            center: center, startRadius: 0, endRadius: h * 0.7))

        let beatsPerSecond = 0.8
        let maxRadius = hypot(w, h) * 0.6
        let colors: [UInt32] = [0xFF3D8B, 0x8B5CFF, 0xFF8A3D, 0x3DD6FF]
        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            // A slow rotating sweep, like a radar.
            let sweepAngle = t * 0.9
            var sweep = Path()
            sweep.move(to: center)
            sweep.addArc(center: center, radius: maxRadius, startAngle: .radians(sweepAngle), endAngle: .radians(sweepAngle + 0.6), clockwise: false)
            sweep.closeSubpath()
            layer.fill(sweep, with: .radialGradient(Gradient(colors: [Color(hex: 0x8B5CFF, opacity: 0.35), .clear]),
                                                    center: center, startRadius: 0, endRadius: maxRadius))
            // Expanding rings: each starts at the centre and fades as it grows.
            let ringCount = 7
            for i in 0..<ringCount {
                let phase = WallpaperMath.fract(t * beatsPerSecond / 2 + Double(i) / Double(ringCount))
                let radius = maxRadius * phase
                let fade = pow(1 - phase, 1.6)
                let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                let color = Color(hex: colors[i % colors.count])
                layer.stroke(ring, with: .color(color.opacity(0.25 * fade)), lineWidth: 14 * (1 - phase) + 4)
                layer.stroke(ring, with: .color(color.opacity(0.9 * fade)), lineWidth: 2)
            }
        }
        // The core "beats": a quick swell that decays, once per beat.
        let beat = exp(-WallpaperMath.fract(t * beatsPerSecond) * 5)
        let coreRadius = w * (0.09 + 0.04 * beat + 0.03 * energy)
        ctx.glow(at: center, radius: coreRadius * 4, color: Color(hex: 0xFF3D8B), opacity: 0.5 + 0.4 * beat)
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)),
                 with: .radialGradient(Gradient(colors: [.white, Color(hex: 0xFF8AC0), Color(hex: 0xFF3D8B)]),
                                       center: center, startRadius: 0, endRadius: coreRadius))
    }
}

/// Gooey blobs that rise, merge and split, in warm neon colours.
enum LavaLampRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x16032E), location: 0),
            .init(color: Color(hex: 0x3B0A45), location: 1),
        ])
        let speed = 1.2
        func blobs(_ layer: inout GraphicsContext) {
            for i in 0..<8 {
                let period = (16 + 10 * WallpaperMath.random(i, 81)) / speed
                let y = h * (0.5 + 0.42 * WallpaperMath.wave(t, period: period, phase: WallpaperMath.random(i, 82)))
                let x = w * (0.2 + 0.6 * WallpaperMath.random(i, 83)) + w * 0.08 * WallpaperMath.wave(t, period: period * 1.3)
                let r = w * (0.11 + 0.09 * WallpaperMath.random(i, 84))
                layer.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white))
            }
        }
        // Soft glow underneath.
        ctx.drawLayer { glowLayer in
            glowLayer.addFilter(.blur(radius: 40))
            glowLayer.opacity = 0.45
            blobs(&glowLayer)
            glowLayer.blendMode = .sourceIn
            glowLayer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFF3D8B)))
        }
        // LEARN: the "metaball" trick. Blur the white circles so they melt together, then
        // keep only pixels above 50 % opacity (alphaThreshold): blobs that touch become one shape.
        // Then `.sourceIn` paints our gradient ONLY where those shapes are.
        ctx.drawLayer { colored in
            colored.drawLayer { mask in
                mask.addFilter(.alphaThreshold(min: 0.5, color: .white))
                mask.addFilter(.blur(radius: 18))
                mask.drawLayer { inner in blobs(&inner) }
            }
            colored.blendMode = .sourceIn
            colored.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFD36B), Color(hex: 0xFF5E7E), Color(hex: 0xB43DFF)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        }
    }
}
