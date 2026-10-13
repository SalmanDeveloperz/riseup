//
//  WallpaperView.swift
//  RiseUp
//
//  LAYER: View (reusable: draws ANY wallpaper)
//  WHAT:  • LiveWallpaperView: runs one live wallpaper (up to 60 frames a second)
//         • PhotoWallpaperView: the user's photo with a slow cinematic zoom (the "Ken Burns" effect)
//         • WallpaperView: picks the right one; adds a dark "scrim" so text on top stays readable
//  DATA:  a Wallpaper value + (for photos) the already-loaded UIImage. Never reads files itself.
//
//  CONNECTIONS:
//    ← USED BY: RingingView (behind the alarm), WallpaperPickerView (live thumbnails),
//               WallpaperPreviewView (full-screen "Try it"), AlarmEditorView (small preview)
//    → CALLS:   the renderers in Features/Wallpapers/Renderers/
//
//  WHY the photo is passed in (not loaded here): Views don't talk to services. The ViewModel loads
//  it from WallpaperStore (off the main thread) and hands the finished image over.
//

import SwiftUI

/// Any wallpaper: live, photo or "surprise".
struct WallpaperView: View {
    let wallpaper: Wallpaper
    /// The decoded photo for `.photo` wallpapers (nil while loading or if the file is gone).
    var photo: UIImage? = nil
    /// How awake it looks. The Ringing screen uses a ramp that rises the longer the alarm rings.
    var energy: WallpaperEnergy = .fixed(0)
    /// Thumbnails run at a lower frame rate to keep a grid of them smooth.
    var isThumbnail = false
    /// Darkens the edges so white text on top is always readable.
    var showsScrim = false

    var body: some View {
        ZStack {
            switch wallpaper.resolved() {
            case .live(let style):
                LiveWallpaperView(style: style, energy: energy, isThumbnail: isThumbnail)
            case .photo:
                if let photo {
                    PhotoWallpaperView(image: photo, energy: energy, isThumbnail: isThumbnail)
                        .transition(.opacity)
                } else {
                    // WHY a live fallback: the photo loads in a split second, or was deleted.
                    // Either way the screen is never empty.
                    LiveWallpaperView(style: .goldenHour, energy: energy, isThumbnail: isThumbnail)
                }
            case .surprise:
                LiveWallpaperView(style: .goldenHour, energy: energy, isThumbnail: isThumbnail)  // never reached: resolved above
            }
            if showsScrim {
                LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.05), .black.opacity(0.15), .black.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: photo != nil)
        .accessibilityHidden(true)                    // decoration only
    }
}

/// Runs one live wallpaper.
///
/// LEARN: `TimelineView(.animation)` redraws its content every display frame (up to 60×/s,
/// 120×/s on ProMotion screens; we cap it). Inside, `Canvas` hands us a drawing context.
/// When the view is off-screen, SwiftUI stops the timeline: no wasted battery.
struct LiveWallpaperView: View {
    let style: LiveWallpaper
    var energy: WallpaperEnergy = .fixed(0)
    var isThumbnail = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When this view appeared; `time` = seconds since then.
    @State private var start = Date.now

    var body: some View {
        // Thumbnails: 24 frames a second is plenty and keeps a whole grid smooth.
        // TRY: change 1.0 / 60 to 1.0 / 30 and compare the Ringing screen.
        TimelineView(.animation(minimumInterval: isThumbnail ? 1.0 / 24 : 1.0 / 60, paused: reduceMotion)) { timeline in
            // Each style starts at a different moment, so the grid doesn't look in sync.
            let offset = Double(LiveWallpaper.allCases.firstIndex(of: style) ?? 0) * 37
            let level = energy.level(at: timeline.date)
            let time = reduceMotion ? offset + 8 : offset + energy.clock(elapsed: elapsed(at: timeline.date), boost: style.speedBoost)
            if style == .breathe {
                BreatheWallpaper(time: time, energy: level)
            } else {
                Canvas { context, size in
                    Self.draw(style, context: &context, size: size, time: time, energy: level)
                }
            }
        }
    }

    /// Seconds since the ramp started (Ringing screen) or since this view appeared.
    private func elapsed(at date: Date) -> Double {
        if case .ramp(let rampStart, _) = energy { return max(0, date.timeIntervalSince(rampStart)) }
        return date.timeIntervalSince(start)
    }

    /// The one place that maps a style to its renderer.
    static func draw(_ style: LiveWallpaper, context: inout GraphicsContext, size: CGSize, time: Double, energy: Double) {
        switch style {
        case .goldenHour: GoldenHourRenderer.draw(&context, size: size, time: time, energy: energy)
        case .aurora: AuroraRenderer.draw(&context, size: size, time: time, energy: energy)
        case .dawnDrift: DawnDriftRenderer.draw(&context, size: size, time: time, energy: energy)
        case .ocean: OceanRenderer.draw(&context, size: size, time: time, energy: energy)
        case .fireflies: FirefliesRenderer.draw(&context, size: size, time: time, energy: energy)
        case .rainyWindow: RainyWindowRenderer.draw(&context, size: size, time: time, energy: energy)
        case .hyperspace: HyperspaceRenderer.draw(&context, size: size, time: time, energy: energy)
        case .nebula: NebulaRenderer.draw(&context, size: size, time: time, energy: energy)
        case .planetRise: PlanetRiseRenderer.draw(&context, size: size, time: time, energy: energy)
        case .synthwave: SynthwaveRenderer.draw(&context, size: size, time: time, energy: energy)
        case .neonPulse: NeonPulseRenderer.draw(&context, size: size, time: time, energy: energy)
        case .lavaLamp: LavaLampRenderer.draw(&context, size: size, time: time, energy: energy)
        case .bokeh: BokehRenderer.draw(&context, size: size, time: time, energy: energy)
        case .breathe: break                                  // a SwiftUI view, see body
        case .kyotoBlossoms: KyotoBlossomsRenderer.draw(&context, size: size, time: time, energy: energy)
        case .tajDawn: TajDawnRenderer.draw(&context, size: size, time: time, energy: energy)
        case .saharaDunes: SaharaDunesRenderer.draw(&context, size: size, time: time, energy: energy)
        case .savannaSunset: SavannaSunsetRenderer.draw(&context, size: size, time: time, energy: energy)
        case .tropicalIsland: TropicalIslandRenderer.draw(&context, size: size, time: time, energy: energy)
        case .himalaya: HimalayaRenderer.draw(&context, size: size, time: time, energy: energy)
        case .parisNights: ParisNightsRenderer.draw(&context, size: size, time: time, energy: energy)
        case .alpineMeadow: AlpineMeadowRenderer.draw(&context, size: size, time: time, energy: energy)
        case .scottishHighlands: ScottishHighlandsRenderer.draw(&context, size: size, time: time, energy: energy)
        case .andesCondor: AndesCondorRenderer.draw(&context, size: size, time: time, energy: energy)
        case .cityLights: CityLightsRenderer.draw(&context, size: size, time: time, energy: energy)
        }
    }
}

/// The user's photo, slowly zooming and drifting, with a warm glow that grows with energy.
struct PhotoWallpaperView: View {
    let image: UIImage
    var energy: WallpaperEnergy = .fixed(0)
    var isThumbnail = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || isThumbnail)) { timeline in
            let t = reduceMotion || isThumbnail ? 0 : timeline.date.timeIntervalSince(start)
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    // Ken Burns: zoom 112–118 % and drift a few points, very slowly.
                    .scaleEffect(1.15 + 0.03 * WallpaperMath.wave(t, period: 18))
                    .offset(x: 14 * WallpaperMath.wave(t, period: 23), y: 10 * WallpaperMath.wave(t, period: 29, phase: 0.25))
                    .clipped()
                    .overlay {
                        LinearGradient(colors: [.clear, Theme.Colors.neonPink.opacity(0.25 * energy.level(at: timeline.date))],
                                       startPoint: .center, endPoint: .bottom)
                    }
            }
        }
    }
}

extension View {
    /// A soft dark glow right behind the clock, so it stays readable on any wallpaper.
    ///
    /// WHY behind the clock only (found in the Simulator): first we darkened a fixed spot in the
    /// middle of every wallpaper. That made the clock readable on Synthwave's bright sun, but it
    /// also turned other wallpapers' suns and snowy peaks a muddy grey. Now it follows the clock.
    /// ← USED BY: RingingView, ScenePlayerView
    func clockHalo() -> some View {
        background {
            // WHY a square squashed into an oval (found in the Simulator): a gradient wider than its
            // frame is tall gets cut off at the frame's top and bottom, leaving faint straight edges.
            RadialGradient(colors: [.black.opacity(0.45), .black.opacity(0.15), .clear],
                           center: .center, startRadius: 0, endRadius: 200)
                .frame(width: 420, height: 420)
                .scaleEffect(x: 1, y: 0.7)
                .allowsHitTesting(false)
        }
    }
}

#Preview("Live wallpapers") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
            ForEach(LiveWallpaper.allCases) { style in
                LiveWallpaperView(style: style, isThumbnail: true)
                    .frame(height: 200)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(alignment: .bottom) { Text(style.title).font(.caption).foregroundStyle(.white).padding(4) }
            }
        }
        .padding()
    }
    .background(.black)
}
