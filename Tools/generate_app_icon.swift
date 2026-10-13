// generate_app_icon.swift
// RiseUp
//
// LAYER: Tool (NOT part of the app: a script you run on the Mac)
// WHAT:  Draws the RiseUp logo with CoreGraphics and saves it as PNG files:
//          • the app icon (normal, dark and tinted versions) → Alarm/Assets.xcassets/AppIcon.appiconset
//          • the in-app logo                                 → Alarm/Assets.xcassets/AppLogo.imageset
// RUN:   swift Tools/generate_app_icon.swift      (from the project folder; takes a few seconds)
//
// THE DESIGN: a sun rising over the horizon, and the sun is also a clock face:
//   • tick marks around its edge (a dial)
//   • ONE hand, shaped like an arrow, pointing straight up to 12 = "wake time" and "Rise Up"
//   • rays above it, a glowing horizon and a soft reflection below
//   • colours = Theme.Gradients.sunrise (purple → pink → orange) on Theme's night navy
//
// WHY a script instead of a drawing app: like our sounds, the logo is code. Every size is sharp,
// the colours match Theme.swift exactly, and a change is one number + one run.
// TRY: change `sunRadius` or `rayCount`, run the script, rebuild, and look at the Home Screen.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Settings

let size: CGFloat = 1024
let horizonY: CGFloat = 640          // measured from the TOP
let sunRadius: CGFloat = 268
let rayCount = 5

// Theme colours (same hex values as Shared/DesignSystem/Theme.swift).
func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let navy = rgb(0x0B0B1A)
let deepPurple = rgb(0x1E0B3D)
let purple = rgb(0x8B5CFF)
let pink = rgb(0xFF3D8B)
let orange = rgb(0xFF8A3D)
let cutout = rgb(0x120A28)           // the arrow and ticks are "cut out" of the sun in this colour

let center = CGPoint(x: size / 2, y: horizonY)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}
let sunrise = gradient([orange, pink, purple], [0, 0.45, 1])   // bottom → top

// MARK: - Drawing

/// Draws the logo. `background: false` leaves the background transparent (for the dark icon).
func drawLogo(in ctx: CGContext, background: Bool) {
    // LEARN: CoreGraphics measures y from the BOTTOM. Flipping once lets us think "from the top".
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    if background {
        // 1. Night sky: deep purple at the top fading into navy.
        ctx.drawLinearGradient(gradient([deepPurple, navy, navy], [0, 0.55, 1]),
                               start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size), options: [])
        // 2. Glow behind the sun (pink → purple, so the dark parts stay clean, never brown).
        let glowCenter = CGPoint(x: center.x, y: center.y - 90)
        ctx.drawRadialGradient(gradient([rgb(0xFF3D8B, 0.42), rgb(0x8B5CFF, 0.16), rgb(0x8B5CFF, 0)], [0, 0.5, 1]),
                               startCenter: glowCenter, startRadius: 0,
                               endCenter: glowCenter, endRadius: 520, options: [])
        // 3. The water below the horizon is a little darker, so the horizon reads clearly.
        ctx.setFillColor(rgb(0x07071A, 0.45))
        ctx.fill(CGRect(x: 0, y: horizonY, width: size, height: size - horizonY))
    }

    // 4. Rays: short rounded beams fanned above the sun (they also feel like an alarm "ringing").
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineWidth(30)
    for i in 0..<rayCount {
        let angle = CGFloat.pi * (CGFloat(i) + 0.5) / CGFloat(rayCount)       // 18°, 54°, 90°…
        let isTop = i == rayCount / 2
        let inner = sunRadius + 46, outer = sunRadius + (isTop ? 128 : 100)
        let a = CGPoint(x: center.x - cos(angle) * inner, y: center.y - sin(angle) * inner)
        let b = CGPoint(x: center.x - cos(angle) * outer, y: center.y - sin(angle) * outer)
        ctx.saveGState()
        let path = CGMutablePath()
        path.move(to: a); path.addLine(to: b)
        ctx.addPath(path.copy(strokingWithWidth: 30, lineCap: .round, lineJoin: .round, miterLimit: 1))
        ctx.clip()
        ctx.drawLinearGradient(sunrise, start: CGPoint(x: 0, y: center.y), end: CGPoint(x: 0, y: center.y - sunRadius - 140), options: [])
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // 5. The sun: a half disc sitting on the horizon, filled with the sunrise gradient.
    ctx.saveGState()
    let sun = CGMutablePath()
    sun.addArc(center: center, radius: sunRadius, startAngle: .pi, endAngle: 0, clockwise: false)
    sun.closeSubpath()
    ctx.addPath(sun)
    ctx.clip()
    ctx.drawLinearGradient(sunrise, start: CGPoint(x: 0, y: center.y), end: CGPoint(x: 0, y: center.y - sunRadius), options: [])

    // 6. Clock ticks around the inside edge of the sun (12 o'clock is left free for the arrow).
    ctx.setStrokeColor(cutout)
    ctx.setLineCap(.round)
    for hour in [1, 2, 4, 5] {                            // 30°, 60°, 120°, 150°
        let angle = CGFloat.pi * CGFloat(hour) / 6
        let r1 = sunRadius - 28, r2 = sunRadius - 58
        ctx.setLineWidth(16)
        ctx.move(to: CGPoint(x: center.x - cos(angle) * r1, y: center.y - sin(angle) * r1))
        ctx.addLine(to: CGPoint(x: center.x - cos(angle) * r2, y: center.y - sin(angle) * r2))
        ctx.strokePath()
    }

    // 7. The hand: an upward arrow from the centre to 12 o'clock ("Rise Up").
    ctx.setFillColor(cutout)
    let shaftWidth: CGFloat = 50
    let headBaseY = center.y - 138, apexY = center.y - sunRadius + 44, headHalf: CGFloat = 82
    let shaft = CGPath(roundedRect: CGRect(x: center.x - shaftWidth / 2, y: headBaseY - 10,
                                           width: shaftWidth, height: center.y - headBaseY + 40),
                       cornerWidth: shaftWidth / 2, cornerHeight: shaftWidth / 2, transform: nil)
    ctx.addPath(shaft)
    ctx.fillPath()
    let head = CGMutablePath()
    head.move(to: CGPoint(x: center.x, y: apexY))
    head.addLine(to: CGPoint(x: center.x + headHalf, y: headBaseY))
    head.addLine(to: CGPoint(x: center.x - headHalf, y: headBaseY))
    head.closeSubpath()
    ctx.addPath(head)
    ctx.fillPath()
    // Round the arrow's corners a little: also fill a thick outline of the same triangle.
    // WHY two separate fills: filled together, the overlapping shapes cancelled out and left a hole.
    ctx.addPath(head.copy(strokingWithWidth: 22, lineCap: .round, lineJoin: .round, miterLimit: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // 8. Horizon: a bright line that fades out towards both edges.
    ctx.saveGState()
    let horizon = CGPath(roundedRect: CGRect(x: 96, y: horizonY - 7, width: size - 192, height: 14),
                         cornerWidth: 7, cornerHeight: 7, transform: nil)
    ctx.addPath(horizon)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0xFF8A3D, 0), rgb(0xFFE3C8), rgb(0xFF3D8B, 0)], [0, 0.5, 1]),
                           start: CGPoint(x: 96, y: 0), end: CGPoint(x: size - 96, y: 0), options: [])
    ctx.restoreGState()

    // 9. Reflection on the water: three soft bars, each shorter and fainter.
    for (i, width) in [CGFloat(430), 300, 170].enumerated() {
        let y = horizonY + 52 + CGFloat(i) * 46
        let alpha: CGFloat = [0.75, 0.5, 0.3][i]
        ctx.saveGState()
        ctx.setAlpha(alpha)
        let bar = CGPath(roundedRect: CGRect(x: center.x - width / 2, y: y, width: width, height: 20),
                         cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.addPath(bar)
        ctx.clip()
        ctx.drawLinearGradient(gradient([orange, pink, purple], [0, 0.5, 1]),
                               start: CGPoint(x: center.x - width / 2, y: 0),
                               end: CGPoint(x: center.x + width / 2, y: 0), options: [])
        ctx.restoreGState()
    }
}

// MARK: - Saving

func render(background: Bool, grayscale: Bool = false, pixels: Int = 1024) -> CGImage {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(pixels) / size, y: CGFloat(pixels) / size)
    if !background && grayscale {
        // Tinted icon: black background (iOS adds the tint colour on top of the light parts).
        ctx.setFillColor(rgb(0x000000)); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }
    drawLogo(in: ctx, background: background)
    let image = ctx.makeImage()!
    guard grayscale else { return image }
    // Grayscale copy for the "tinted" Home Screen style.
    let gray = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    gray.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return gray.makeImage()!
}

func save(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Couldn't write \(path)") }
    print("✓ \(path)")
}

let iconFolder = "Alarm/Assets.xcassets/AppIcon.appiconset"
let logoFolder = "Alarm/Assets.xcassets/AppLogo.imageset"
try FileManager.default.createDirectory(atPath: logoFolder, withIntermediateDirectories: true)

save(render(background: true), to: "\(iconFolder)/AppIcon.png")                        // normal
save(render(background: false), to: "\(iconFolder)/AppIcon-Dark.png")                  // dark: iOS draws the dark background
save(render(background: false, grayscale: true), to: "\(iconFolder)/AppIcon-Tinted.png")
save(render(background: true, pixels: 512), to: "\(logoFolder)/AppLogo.png")           // in-app logo
