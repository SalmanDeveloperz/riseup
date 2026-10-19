// generate_app_icon.swift
// RiseUp
//
// LAYER: Tool (NOT part of the app: a script you run on the Mac)
// WHAT:  Draws the RiseUp logo with CoreGraphics and saves it as PNG files:
//          • the app icon (normal, dark and tinted versions) → Alarm/Assets.xcassets/AppIcon.appiconset
//          • the in-app logo                                 → Alarm/Assets.xcassets/AppLogo.imageset
//          • the widget marks (rooster only, no background)  → RiseUpWidgets/Assets.xcassets
//              RoosterMark (colour, home-screen widgets) + RoosterGlyph (one-colour silhouette,
//              lock-screen widgets: iOS tints it in the user's lock-screen colour)
// RUN:   swift Tools/generate_app_icon.swift      (from the project folder; takes a few seconds)
//
// THE DESIGN (v3, "the Crowing Rooster", chosen by Salman on 2026-10-14)
// ─────────────────────────────────────────────────────────────────────
// A rooster is nature's alarm clock: it crows at sunrise. So one character says "morning" AND
// "alarm" with no explanation, and no alarm app uses one (the App Store is full of twin-bell
// clocks, digits and cartoon clock faces; Alarmy's own icon is a pink-orange twin-bell clock).
//   • its HEAD is the sun (golden circle), its COMB the sun's rays (three lobes pointing outward
//     from the head's centre), its open BEAK + two sound waves = the crow = the alarm
//   • the whole bird is tilted up 10°: crowing at the sky = "Rise Up"
//   • the background is night breaking into dawn: a warm glow rising from the bottom edge
//   • only 6 simple shapes, so it still reads at 29 pt (Settings) and as a widget
// The journey (see docs/HOW_IT_WORKS.md "the logo"): v1 sunrise (didn't say alarm) → v2 alarm clock
// (looked like Alarmy, too busy) → 20 minimal concepts compared on a home screen → the rooster.
//
// WHY a script instead of a drawing app: like our sounds, the logo is code. Every size is sharp,
// the colours match Theme.swift, and a change is one number + one run.
// TRY: change `tilt` to 0 or 16 (degrees), run the script, rebuild, and look at the Home Screen.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Settings

let size: CGFloat = 1024
let head = CGPoint(x: 476, y: 586)     // centre of the head (measured from the TOP)
let headRadius: CGFloat = 190
let tilt: CGFloat = 10                 // degrees the whole rooster leans back to crow at the sky
let lift: CGFloat = 20                 // moves the bird down a little, so the tilted mark sits centred

/// How wide the rooster (comb to sound waves) is on the app icon, as a share of the icon's width.
/// WHY 0.80 (Salman, 2026-10-19: "fill it like WhatsApp, Mail, Google Keep"): the bird used to be
/// only ~65 % wide and ~50 % tall, so it looked small next to other apps. Apple's icon grid keeps
/// artwork inside a circle of ~81 % of the icon, and WhatsApp's bubble / Mail's envelope are ~76–80 %
/// wide. 80 % fills the icon like theirs, while the rounded corners still never touch the bird.
/// TRY: 0.72 (more air) or 0.86 (bolder), run the script, rebuild, and compare on the Home Screen.
let iconFill: CGFloat = 0.80

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

// Colours (Theme's neon pink/purple/orange, plus the sun's gold).
let headGold = gradient([rgb(0xFFB13D), rgb(0xFFCF5A)], [0, 1])           // bottom → top: sunlit from above
let crimson = gradient([rgb(0xFF2D55), rgb(0xFF3D8B)], [0, 1])            // comb + wattle
let waves = gradient([rgb(0xFF3D8B), rgb(0xB04DFF)], [0, 1])              // the crow's sound waves
let upperBeak = rgb(0xFFD36B), lowerBeak = rgb(0xFFB13D)
let eyeInk = rgb(0x120B2C)

/// True while drawing the one-colour silhouette (RoosterGlyph): every part white, the eye punched out.
var silhouette = false

// MARK: - Shape helpers

/// A point `distance` from `c`, `degrees` clockwise from straight up.
func polar(_ c: CGPoint, _ degrees: CGFloat, _ distance: CGFloat) -> CGPoint {
    let r = degrees * .pi / 180
    return CGPoint(x: c.x + sin(r) * distance, y: c.y - cos(r) * distance)
}
func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil)
}
/// An ellipse turned by `degrees` (the comb lobes and the wattle).
func ellipse(_ c: CGPoint, rx: CGFloat, ry: CGFloat, degrees: CGFloat) -> CGPath {
    var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: degrees * .pi / 180)
    return CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: &t)
}
/// Fills `path` with a vertical gradient between two y values.
func fill(_ ctx: CGContext, _ path: CGPath, _ g: CGGradient, top: CGFloat, bottom: CGFloat, alpha: CGFloat = 1) {
    ctx.saveGState()
    ctx.setAlpha(silhouette ? 1 : alpha)
    ctx.addPath(path)
    ctx.clip()
    if silhouette {
        ctx.setFillColor(rgb(0xFFFFFF)); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    } else {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: bottom), end: CGPoint(x: 0, y: top), options: [])
    }
    ctx.restoreGState()
}
/// A triangle with rounded corners (fill + a thick round-joined outline in the same colour).
/// WHY two steps: filling the triangle and its outline as ONE path made the inside empty
/// (overlapping shapes cancel out), and the beak looked like an outline (found in the logo lab).
func roundedTriangle(_ ctx: CGContext, _ points: [CGPoint], _ color: CGColor, rounding: CGFloat) {
    let p = CGMutablePath()
    p.addLines(between: points)
    p.closeSubpath()
    let color = silhouette ? rgb(0xFFFFFF) : color
    ctx.setFillColor(color)
    ctx.addPath(p); ctx.fillPath()
    ctx.setStrokeColor(color); ctx.setLineWidth(rounding); ctx.setLineJoin(.round)
    ctx.addPath(p); ctx.strokePath()
}

// MARK: - Drawing

/// Draws the logo. `background: false` leaves the background transparent (for the dark icon).
/// `fit`: moves and scales the bird (not the sky) so it fills the icon; nil = the original drawing size.
func drawLogo(in ctx: CGContext, background: Bool, fit: CGAffineTransform? = nil) {
    // LEARN: CoreGraphics measures y from the BOTTOM. Flipping once lets us think "from the top".
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    if background {
        // 1. Night sky, breaking into dawn: a warm glow rises from below the bottom edge.
        ctx.drawLinearGradient(gradient([rgb(0x22104A), rgb(0x150B32), rgb(0x1A0B30)], [0, 0.6, 1]),
                               start: .zero, end: CGPoint(x: 0, y: size), options: [])
        let glow = CGPoint(x: 512, y: size + 260)
        ctx.drawRadialGradient(gradient([rgb(0xFF5A5F, 0.55), rgb(0xFF3D8B, 0.28), rgb(0x8B5CFF, 0)], [0, 0.45, 1]),
                               startCenter: glow, startRadius: 0, endCenter: glow, endRadius: 720, options: [])
    }

    // 2. Lean the whole bird back by `tilt` degrees around its head (crowing at the sky).
    // LEARN: translate → rotate → translate back = "rotate around this point".
    ctx.saveGState()
    if let fit { ctx.concatenate(fit) }      // grow the bird to `iconFill` and centre it (see iconFitTransform)
    ctx.translateBy(x: head.x, y: head.y + lift)
    ctx.rotate(by: -tilt * .pi / 180)
    ctx.translateBy(x: -head.x, y: -head.y)

    let r = headRadius
    let top = head.y - r - 150, bottom = head.y + r

    // 3. Comb: three lobes pointing outward from the head's centre (the sun's rays), the middle one tallest.
    for (degrees, rx, ry) in [(CGFloat(-40), CGFloat(54), CGFloat(84)), (-7, 62, 102), (25, 54, 84)] {
        fill(ctx, ellipse(polar(head, degrees, r + 40), rx: rx, ry: ry, degrees: degrees), crimson, top: top, bottom: bottom)
    }

    // 4. Wattle: the little drop under the beak (drawn first, so the head overlaps it).
    fill(ctx, ellipse(polar(head, 128, r - 10), rx: 46, ry: 66, degrees: -14), crimson, top: top, bottom: bottom + 80)

    // 5. Open beak (crowing): upper and lower halves with a gap between them.
    let tip = CGPoint(x: head.x + r + 86, y: head.y - 36)
    roundedTriangle(ctx, [polar(head, 60, r - 18), CGPoint(x: tip.x + 10, y: tip.y - 26), polar(head, 86, r - 10)],
                    upperBeak, rounding: 34)
    roundedTriangle(ctx, [polar(head, 96, r - 12), CGPoint(x: tip.x - 28, y: tip.y + 46), polar(head, 112, r - 16)],
                    lowerBeak, rounding: 34)

    // 6. The crow: two sound waves in front of the beak (the near one bright, the far one softer).
    for (radius, alpha) in [(CGFloat(96), CGFloat(1)), (160, 0.55)] {
        let arc = CGMutablePath()
        arc.addArc(center: CGPoint(x: tip.x - 30, y: tip.y + 12), radius: radius, startAngle: -0.55, endAngle: 0.55, clockwise: false)
        fill(ctx, arc.copy(strokingWithWidth: 30, lineCap: .round, lineJoin: .round, miterLimit: 1), waves,
             top: 380, bottom: 760, alpha: alpha)
    }

    // 7. The head: the sun.
    fill(ctx, circle(head, r), headGold, top: head.y - r, bottom: head.y + r)

    // 8. The eye: wide awake, with a tiny highlight.
    let eye = CGPoint(x: head.x + 78, y: head.y - 52)
    if silhouette {
        // LEARN: the `.clear` blend mode erases what's there, so the eye becomes a see-through hole.
        ctx.setBlendMode(.clear); ctx.addPath(circle(eye, 30)); ctx.fillPath(); ctx.setBlendMode(.normal)
    } else {
        ctx.setFillColor(eyeInk); ctx.addPath(circle(eye, 30)); ctx.fillPath()
        ctx.setFillColor(rgb(0xFFFFFF, 0.9)); ctx.addPath(circle(CGPoint(x: eye.x + 10, y: eye.y - 10), 9)); ctx.fillPath()
    }

    ctx.restoreGState()
}

// MARK: - Fitting the bird to the icon

/// The box around everything the bird draws (comb, beak, waves), measured from a test drawing.
/// LEARN: we draw the bird without a background and look for the first and last pixels that aren't
/// see-through. Measuring beats guessing: change the bird, and the fit adjusts by itself.
func birdBounds() -> CGRect {
    let n = Int(size)
    var pixels = [UInt8](repeating: 0, count: n * n * 4)
    let ctx = CGContext(data: &pixels, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawLogo(in: ctx, background: false)
    var minX = n, minY = n, maxX = 0, maxY = 0
    for y in 0..<n {
        for x in 0..<n where pixels[(y * n + x) * 4 + 3] > 8 {      // alpha: not (almost) transparent
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    // The bitmap's rows start at the top here, which is how drawLogo thinks too (it flips the y axis).
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

/// Scales the bird so it's `iconFill` of the icon's width, with its box centred in the icon.
/// LEARN: read the steps bottom-up: move the box's centre to (0,0) → scale → move it to the icon's centre.
func iconFitTransform() -> CGAffineTransform {
    let box = birdBounds()
    let scale = size * iconFill / max(box.width, box.height)
    print("bird box before: \(Int(box.width)) × \(Int(box.height)) px → scale ×\(String(format: "%.2f", scale))")
    return CGAffineTransform(translationX: size / 2, y: size / 2)
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -box.midX, y: -box.midY)
}
let iconFit = iconFitTransform()

// MARK: - Saving

/// `fitted: true` = the app icon and in-app logo (the bird fills the icon); false = the original size
/// (the widget marks below crop the bird out of that).
func render(background: Bool, grayscale: Bool = false, pixels: Int = 1024, fitted: Bool = true) -> CGImage {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(pixels) / size, y: CGFloat(pixels) / size)
    if !background && grayscale {
        // Tinted icon: black background (iOS adds the tint colour on top of the light parts).
        ctx.setFillColor(rgb(0x000000)); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }
    drawLogo(in: ctx, background: background, fit: fitted ? iconFit : nil)
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

// Widget marks: the rooster alone, cropped to the bird (no background), small files for the widget extension.
// WHY cropped: the icon leaves room around the bird; in a widget header every point counts.
func renderMark(pixels: Int) -> CGImage {
    let full = render(background: false, pixels: 1024, fitted: false)   // the crop below is for the original size
    let crop = CGRect(x: 196, y: 250, width: 720, height: 600)            // the bird + its sound waves
    let cropped = full.cropping(to: crop)!
    let ctx = CGContext(data: nil, width: pixels, height: pixels * 600 / 720, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: pixels, height: pixels * 600 / 720))
    return ctx.makeImage()!
}
let widgetAssets = "RiseUpWidgets/Assets.xcassets"
for name in ["RoosterMark", "RoosterGlyph"] {
    try FileManager.default.createDirectory(atPath: "\(widgetAssets)/\(name).imageset", withIntermediateDirectories: true)
}
save(renderMark(pixels: 360), to: "\(widgetAssets)/RoosterMark.imageset/RoosterMark.png")
silhouette = true
save(renderMark(pixels: 360), to: "\(widgetAssets)/RoosterGlyph.imageset/RoosterGlyph.png")
silhouette = false
