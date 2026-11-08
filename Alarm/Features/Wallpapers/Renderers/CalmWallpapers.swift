//
//  CalmWallpapers.swift
//  RiseUp
//
//  LAYER: View (live-wallpaper renderers, category "Calm")
//  WHAT:  Breathe (a slowly flowing colour mesh with a breathing circle) · Bokeh Lights.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: LiveWallpaperView
//    → USES:    MeshGradient (SwiftUI, iOS 18+), WallpaperMath, GraphicsContext.glow / fillSky
//

import SwiftUI

/// A flowing 3×3 colour mesh, with a soft circle that grows and shrinks like a slow breath.
///
/// LEARN: `MeshGradient` blends colours between a grid of points. Moving the middle points a
/// little every frame makes the colours flow like silk. It's drawn by the GPU: very cheap.
struct BreatheWallpaper: View {
    let time: Double
    let energy: Double

    var body: some View {
        let t = time
        // WHY edge points only move ALONG their edge (found in the visual check): when the
        // left/right points moved sideways, the mesh pulled away from the screen edge and left a dark gap.
        func wobble(_ x: Double, _ y: Double, _ i: Int) -> SIMD2<Float> {
            let dx = (x == 0 || x == 1) ? 0 : 0.12 * WallpaperMath.wave(t, period: 9 + Double(i), phase: Double(i) * 0.17)
            let dy = 0.10 * WallpaperMath.wave(t, period: 11 + Double(i), phase: Double(i) * 0.29)
            return SIMD2(Float(x + dx), Float(y + dy))
        }
        // Breathing: 4 s in, 4 s out. TRY: change 8 to 6 for a quicker rhythm.
        let breath = 0.5 + 0.5 * WallpaperMath.wave(time, period: 8)
        return ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    wobble(0, 0.5, 1), wobble(0.5, 0.5, 2), wobble(1, 0.5, 3),
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    Color(hex: 0x1B1340), Color(hex: 0x3B1C6E), Color(hex: 0x123A5C),
                    Color(hex: 0x6B2C7A), Color(hex: 0xC2557A), Color(hex: 0x2E6E8E),
                    Color(hex: 0x0F1030), Color(hex: 0x40306E), Color(hex: 0x0E2A3E),
                ]
            )
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.28), .white.opacity(0.05), .clear],
                                     center: .center, startRadius: 0, endRadius: 220))
                .frame(width: 440, height: 440)
                .scaleEffect(0.7 + 0.5 * breath)
                .blendMode(.plusLighter)
        }
    }
}

/// Out-of-focus lights floating upward at different depths.
enum BokehRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, time t: Double, energy: Double) {
        let w = size.width, h = size.height
        ctx.fillSky(size, stops: [
            .init(color: Color(hex: 0x0A0718), location: 0),
            .init(color: Color(hex: 0x1D0F2E), location: 1),
        ])
        let palette: [UInt32] = [0xFFC46B, 0xFF7AA8, 0x7AD7FF, 0xFFE9B0, 0xB28DFF]
        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            for i in 0..<42 {
                let depth = WallpaperMath.random(i, 91)                // 0 = far, 1 = near
                let speed = 0.006 + 0.02 * depth
                let y = (1 - WallpaperMath.fract(WallpaperMath.random(i, 92) + t * speed)) * (h + 200) - 100
                let x = w * WallpaperMath.random(i, 93) + 30 * WallpaperMath.wave(t, period: 13 + 7 * depth, phase: depth)
                let radius = 10 + 60 * depth
                let point = CGPoint(x: x, y: y)
                let color = Color(hex: palette[i % palette.count])
                // Near lights: large, faint, with a brighter rim (like a real out-of-focus lens).
                layer.glow(at: point, radius: radius, color: color, opacity: 0.18 + 0.2 * (1 - depth))
                layer.stroke(Path(ellipseIn: CGRect(x: x - radius * 0.7, y: y - radius * 0.7, width: radius * 1.4, height: radius * 1.4)),
                             with: .color(color.opacity(0.08 + 0.1 * depth)), lineWidth: 1.5)
            }
        }
    }
}
