// generate_app_icon.swift
// RiseUp
//
// LAYER: Tool (NOT part of the app: a script you run on the Mac)
// WHAT:  Draws the RiseUp logo with CoreGraphics and saves it as PNG files:
//          • the app icon (normal, dark and tinted versions) → Alarm/Assets.xcassets/AppIcon.appiconset
//          • the in-app logo                                 → Alarm/Assets.xcassets/AppLogo.imageset
// RUN:   swift Tools/generate_app_icon.swift      (from the project folder; takes a few seconds)
//
// THE DESIGN (v2, 2026-10-13): a ringing alarm clock whose face is a sunrise.
//   • twin bells, a hammer knob and little feet: anyone sees "alarm clock" in a split second
//     (v1 was only a sunrise, and Salman found it didn't say "alarm")
//   • ringing arcs beside the bells: it's alive, it's morning
//   • inside the face: the sun rising over the horizon, and the clock's hand is an arrow
//     pointing straight up to 12 = "wake time" and "Rise Up"; dots mark 3, 9 and 6
//   • colours = Theme.Gradients.sunrise (purple → pink → orange) on Theme's night navy
//
// WHY a script instead of a drawing app: like our sounds, the logo is code. Every size is sharp,
// the colours match Theme.swift exactly, and a change is one number + one run.
// TRY: change `faceRadius` or `bellAngle`, run the script, rebuild, and look at the Home Screen.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Settings

let size: CGFloat = 1024
let center = CGPoint(x: 512, y: 560)   // the clock's centre, measured from the TOP
let faceRadius: CGFloat = 262          // the inside of the clock face
let ringWidth: CGFloat = 46            // the glowing rim
let bellAngle: CGFloat = 46            // degrees from straight up, for each bell
let sunRadius: CGFloat = 158

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
let cutout = rgb(0x120A28)           // the arrow is "cut out" of the sun in this colour

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}
let sunrise = gradient([orange, pink, purple], [0, 0.45, 1])   // bottom → top

/// A point `distance` away from the clock's centre, `degrees` clockwise from straight up.
func polar(_ degrees: CGFloat, _ distance: CGFloat) -> CGPoint {
    let r = degrees * .pi / 180
    return CGPoint(x: center.x + sin(r) * distance, y: center.y - cos(r) * distance)
}

/// Fills `path` with the sunrise gradient running from `bottom` up to `top` (y values).
func fillSunrise(_ ctx: CGContext, _ path: CGPath, bottom: CGFloat, top: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(sunrise, start: CGPoint(x: 0, y: bottom), end: CGPoint(x: 0, y: top), options: [])
    ctx.restoreGState()
}

// MARK: - Drawing

/// Draws the logo. `background: false` leaves the background transparent (for the dark icon).
func drawLogo(in ctx: CGContext, background: Bool) {
    // LEARN: CoreGraphics measures y from the BOTTOM. Flipping once lets us think "from the top".
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    if background {
        // 1. Night sky: deep purple at the top fading into navy, and a pink glow behind the clock.
        ctx.drawLinearGradient(gradient([deepPurple, navy, navy], [0, 0.6, 1]),
                               start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size), options: [])
        ctx.drawRadialGradient(gradient([rgb(0xFF3D8B, 0.38), rgb(0x8B5CFF, 0.14), rgb(0x8B5CFF, 0)], [0, 0.55, 1]),
                               startCenter: center, startRadius: 0, endCenter: center, endRadius: 500, options: [])
    }

    let outer = faceRadius + ringWidth            // outside edge of the rim

    // 2. Ringing arcs: two curved lines beside each bell ("it's ringing!").
    ctx.saveGState()
    for (radius, alpha) in [(outer + 150, CGFloat(0.95)), (outer + 204, 0.55)] {
        for side: CGFloat in [-1, 1] {
            let path = CGMutablePath()
            // LEARN: angles here are CoreGraphics angles (0 = right, counter-clockwise in the
            // flipped space we draw in = clockwise on screen). We convert from "degrees from up".
            let from = (-90 + side * (bellAngle - 13)) * .pi / 180
            let to = (-90 + side * (bellAngle + 13)) * .pi / 180
            path.addArc(center: center, radius: radius, startAngle: min(from, to), endAngle: max(from, to), clockwise: false)
            ctx.setAlpha(alpha)
            fillSunrise(ctx, path.copy(strokingWithWidth: 26, lineCap: .round, lineJoin: .round, miterLimit: 1),
                        bottom: center.y, top: center.y - outer - 200)
        }
    }
    ctx.restoreGState()

    // 3. Feet: two short rounded legs at the bottom.
    for side: CGFloat in [-1, 1] {
        let a = polar(180 - side * 38, outer - 10), b = polar(180 - side * 44, outer + 62)
        let leg = CGMutablePath()
        leg.move(to: a); leg.addLine(to: b)
        fillSunrise(ctx, leg.copy(strokingWithWidth: 40, lineCap: .round, lineJoin: .round, miterLimit: 1),
                    bottom: center.y + outer + 70, top: center.y)
    }

    // 4. Bells: a dome on each side of the top, tilted outwards, with a little stem.
    for side: CGFloat in [-1, 1] {
        ctx.saveGState()
        // WHY so close (found when looking at the render): further out, a dark gap made the bells float.
        let anchor = polar(side * bellAngle, outer + 4)
        ctx.translateBy(x: anchor.x, y: anchor.y)
        ctx.rotate(by: side * bellAngle * .pi / 180)
        let dome = CGMutablePath()
        dome.addArc(center: CGPoint(x: 0, y: 8), radius: 98, startAngle: .pi, endAngle: 0, clockwise: false)
        dome.closeSubpath()
        ctx.addPath(dome)
        ctx.clip()
        ctx.drawLinearGradient(gradient([pink, purple], [0, 1]),
                               start: CGPoint(x: 0, y: 8), end: CGPoint(x: 0, y: -100), options: [])
        ctx.restoreGState()
    }

    // 5. The hammer knob on top: a short stem and a ball.
    let stem = CGMutablePath()
    stem.move(to: polar(0, outer - 8)); stem.addLine(to: polar(0, outer + 44))
    fillSunrise(ctx, stem.copy(strokingWithWidth: 30, lineCap: .round, lineJoin: .round, miterLimit: 1),
                bottom: center.y - outer, top: center.y - outer - 90)
    let knob = polar(0, outer + 66)
    ctx.setFillColor(purple)
    ctx.fillEllipse(in: CGRect(x: knob.x - 30, y: knob.y - 30, width: 60, height: 60))

    // 6. The face: dark sky above the horizon, darker water below.
    ctx.saveGState()
    let face = CGPath(ellipseIn: CGRect(x: center.x - faceRadius, y: center.y - faceRadius,
                                        width: faceRadius * 2, height: faceRadius * 2), transform: nil)
    ctx.addPath(face)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0x2A0F52), rgb(0x3A1450)], [0, 1]),
                           start: CGPoint(x: 0, y: center.y - faceRadius), end: CGPoint(x: 0, y: center.y), options: [])
    ctx.setFillColor(rgb(0x0E0A24))
    ctx.fill(CGRect(x: 0, y: center.y + 46, width: size, height: faceRadius))

    // 7. The sun: a half disc on the horizon (a little below the centre), in the sunrise gradient.
    let horizonY = center.y + 46
    let sun = CGMutablePath()
    sun.addArc(center: CGPoint(x: center.x, y: horizonY), radius: sunRadius, startAngle: .pi, endAngle: 0, clockwise: false)
    sun.closeSubpath()
    fillSunrise(ctx, sun, bottom: horizonY, top: horizonY - sunRadius)

    // Soft rays around the sun.
    for degrees: CGFloat in [-60, -30, 0, 30, 60] {
        let r = degrees * .pi / 180
        let base = CGPoint(x: center.x, y: horizonY)
        let a = CGPoint(x: base.x + sin(r) * (sunRadius + 24), y: base.y - cos(r) * (sunRadius + 24))
        let b = CGPoint(x: base.x + sin(r) * (sunRadius + (degrees == 0 ? 0 : 58)), y: base.y - cos(r) * (sunRadius + (degrees == 0 ? 0 : 58)))
        guard degrees != 0 else { continue }                // 12 o'clock is the arrow's
        let ray = CGMutablePath()
        ray.move(to: a); ray.addLine(to: b)
        ctx.setAlpha(0.85)
        fillSunrise(ctx, ray.copy(strokingWithWidth: 18, lineCap: .round, lineJoin: .round, miterLimit: 1),
                    bottom: horizonY, top: horizonY - sunRadius - 70)
        ctx.setAlpha(1)
    }

    // 8. The hand: an arrow from the sun's centre straight up to 12 o'clock ("Rise Up").
    //    It's cut out of the sun (dark) and continues bright above it.
    let shaftWidth: CGFloat = 40
    let apexY = center.y - faceRadius + 40, headBaseY = apexY + 92, headHalf: CGFloat = 64
    let arrow = CGMutablePath()
    arrow.addPath(CGPath(roundedRect: CGRect(x: center.x - shaftWidth / 2, y: headBaseY - 10,
                                             width: shaftWidth, height: horizonY - headBaseY - 6),
                         cornerWidth: shaftWidth / 2, cornerHeight: shaftWidth / 2, transform: nil))
    let head = CGMutablePath()
    head.move(to: CGPoint(x: center.x, y: apexY))
    head.addLine(to: CGPoint(x: center.x + headHalf, y: headBaseY))
    head.addLine(to: CGPoint(x: center.x - headHalf, y: headBaseY))
    head.closeSubpath()
    // WHY three separate fills: filled together, overlapping shapes cancel out and leave holes.
    ctx.setFillColor(rgb(0xFFE3C8))
    ctx.addPath(arrow); ctx.fillPath()
    ctx.addPath(head); ctx.fillPath()
    ctx.addPath(head.copy(strokingWithWidth: 18, lineCap: .round, lineJoin: .round, miterLimit: 1)); ctx.fillPath()
    // The part inside the sun is cut out (dark), so the sun reads as a dial with a hand.
    ctx.saveGState()
    ctx.addPath(sun)
    ctx.clip()
    ctx.setFillColor(cutout)
    ctx.addPath(arrow); ctx.fillPath()
    ctx.restoreGState()

    // 9. Hour dots at 3, 9 and 6 o'clock (12 belongs to the arrow).
    for degrees: CGFloat in [90, 270] {
        let dot = polar(degrees, faceRadius - 44)
        ctx.setFillColor(rgb(0xFFE3C8, 0.9))
        ctx.fillEllipse(in: CGRect(x: dot.x - 15, y: dot.y - 15, width: 30, height: 30))
    }

    // 10. Reflection on the water: two soft bars below the horizon.
    for (i, width) in [CGFloat(250), 150].enumerated() {
        let y = horizonY + 40 + CGFloat(i) * 44
        let bar = CGPath(roundedRect: CGRect(x: center.x - width / 2, y: y, width: width, height: 18),
                         cornerWidth: 9, cornerHeight: 9, transform: nil)
        ctx.setAlpha([0.75, 0.45][i])
        ctx.saveGState()
        ctx.addPath(bar); ctx.clip()
        ctx.drawLinearGradient(gradient([orange, pink, purple], [0, 0.5, 1]),
                               start: CGPoint(x: center.x - width / 2, y: 0), end: CGPoint(x: center.x + width / 2, y: 0), options: [])
        ctx.restoreGState()
        ctx.setAlpha(1)
    }
    let dot6 = polar(180, faceRadius - 40)
    ctx.setFillColor(rgb(0xFFE3C8, 0.9))
    ctx.fillEllipse(in: CGRect(x: dot6.x - 15, y: dot6.y - 15, width: 30, height: 30))

    // Horizon line: bright in the middle, fading towards the rim.
    ctx.saveGState()
    let horizon = CGPath(roundedRect: CGRect(x: center.x - faceRadius, y: horizonY - 6, width: faceRadius * 2, height: 12),
                         cornerWidth: 6, cornerHeight: 6, transform: nil)
    ctx.addPath(horizon); ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0xFF8A3D, 0), rgb(0xFFE3C8), rgb(0xFF3D8B, 0)], [0, 0.5, 1]),
                           start: CGPoint(x: center.x - faceRadius, y: 0), end: CGPoint(x: center.x + faceRadius, y: 0), options: [])
    ctx.restoreGState()
    ctx.restoreGState()                                  // end of the face clip

    // 11. The rim: a thick glowing ring in the sunrise gradient (purple top → orange bottom).
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 40, color: rgb(0xFF3D8B, 0.6))
    let ring = CGPath(ellipseIn: CGRect(x: center.x - faceRadius - ringWidth / 2, y: center.y - faceRadius - ringWidth / 2,
                                        width: (faceRadius + ringWidth / 2) * 2, height: (faceRadius + ringWidth / 2) * 2),
                      transform: nil)
    ctx.addPath(ring.copy(strokingWithWidth: ringWidth, lineCap: .round, lineJoin: .round, miterLimit: 1))
    ctx.clip()
    ctx.drawLinearGradient(gradient([orange, pink, purple], [0, 0.5, 1]),
                           start: CGPoint(x: 0, y: center.y + outer), end: CGPoint(x: 0, y: center.y - outer), options: [])
    ctx.restoreGState()
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
