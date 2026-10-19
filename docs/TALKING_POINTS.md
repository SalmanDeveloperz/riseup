# RiseUp: how to explain it to anyone

Plain answers for the questions people (your lead, a tester, an interviewer) actually ask. Each answer is short
enough to say out loud, and ends with where to look in the code if they want proof.
For the deep version: `ARCHITECTURE.md` (structure), `HOW_IT_WORKS.md` (traces + real bugs), `screens/*.md`.

---

## The 30-second pitch
RiseUp is a mission alarm clock for iPhone (like Alarmy). To stop the alarm you have to do something that
proves you're awake: solve maths, type a phrase, shake the phone, walk, do squats, play a memory game, take
a photo of a place you registered, or scan a barcode. Alarms ring through Silent mode and when the app is
closed, because they use **AlarmKit**, Apple's real alarm system (iOS 26). Each alarm has a living animated
wallpaper with its own sound, there are home and lock screen widgets, sleep sounds, a morning check-in and
stats. It's free, has no account, no server and no tracking: everything stays on the phone.

**In numbers:** ~140 Swift files, 8 missions, 36 alarm sounds, 10 sleep sounds, 25 live wallpapers,
6 widget sizes, light & dark themes with 5 colour palettes, your own alarm sounds, 155 unit tests, 0 build warnings.

---

## "How is the app built?" (architecture)
- **SwiftUI** for every screen, **MVVM + Coordinator**:
  - **View** draws and forwards taps. **ViewModel** (`@Observable`) holds the screen's state and logic.
  - **Repository / Service** talks to the database or to iOS. **Model** is the saved data.
  - **AppCoordinator** decides which screen shows next. Screens never push other screens themselves.
- **Dependency injection:** every service is created once in `AppDependencies` and handed to ViewModels by
  `ScreenFactory`. Each service has a protocol + a real version + a mock, so previews and tests never touch real
  alarms, sensors or speakers.
- **Swift 6** with strict concurrency (data-race safety checked by the compiler).
- 👉 `docs/ARCHITECTURE.md`, `Alarm/App/AppDependencies.swift`, `Alarm/Coordinator/`

## "Where is the data stored?"
- **SwiftData** (Apple's database) for alarms, their missions and the wake-up history. It's versioned
  (`SchemaV1 → V2 → V3 → V4`) with a migration plan, so updates never lose anyone's alarms. The file sits in the
  App Group folder; installs from before the widgets are moved there on first launch (`StoreRelocation`).
- **UserDefaults** (`AppSettings`) for small preferences: default sound, Time Pressure, Wake-up guarantee…
- **Files** for big things: your wallpaper photos, mission reference photos.
- **App Group** (a folder shared with the widget extension): a small JSON "next alarms" snapshot + wallpaper pictures.
- **Nothing leaves the phone.** No server, no analytics, no account.
- 👉 `Alarm/Models/SchemaV4.swift`, `Alarm/Repositories/`, `ARCHITECTURE.md` §5 (data map)

## "How do the alarms actually ring?" (the most important answer)
- We don't fake alarms with notifications: we use **AlarmKit** (new in iOS 26), the same system the Clock app
  uses. iOS rings the alarm itself, full screen on the lock screen, through Silent mode and Focus, even if
  RiseUp was force-quit.
- **The weak spot of every iPhone alarm app:** iOS always shows **Stop**, and the **side and volume buttons silence
  any app's alarm.** No app can block that, Alarmy included.
- **Our answer, the Wake-up guarantee (re-ring chain):**
  - every alarm schedules extra "backup" alarms at +30 s, 1, 1.5, 2, 3, 5, 8 and 12 minutes
  - pressing Stop or a button only buys 30 seconds
  - the backups are cancelled only when you finish waking up *inside* RiseUp ("I'm up" or the last mission)
- **Wake up / Start Mission button:** every ring has one. It opens the app straight onto the Ringing screen:
  the wallpaper animates, the sound plays, the mission starts.
- **Keep-alive (a "dead man's switch"):** while you're on that screen, the app pushes the backups 75 s ahead every
  30 s, so iOS doesn't interrupt you. Lock the phone or leave the app and it rings again within about a minute.
- 👉 `Alarm/Services/AlarmKit/AlarmKitScheduler.swift` (read its header first), `docs/screens/34-wake-up-guarantee.md`

## "How do notifications work?"
Careful: RiseUp has **three different things** people call "notifications":
1. **Alarms are NOT notifications.** They're AlarmKit system alarms (above): louder, full screen, ignore Silent
   mode. A normal notification can't do that.
2. **One real local notification:** the optional nightly **bedtime reminder** ("time to wind down"), scheduled
   with `UserNotifications` (`UNCalendarNotificationTrigger`, repeats daily). Local = scheduled on the phone, no
   server, no push.
3. **Live Activity:** while an alarm rings or snoozes on an *unlocked* phone, iOS shows our Live Activity
   (lock screen banner + Dynamic Island), drawn by the widget extension.

There are **no push notifications** (there's no server to send them).
👉 `Alarm/Services/Notifications/BedtimeReminder.swift`, `RiseUpWidgets/AlarmLiveActivity.swift`

## "Does it have dark mode / themes?"
- Yes: Settings → Appearance. **System / Light / Dark** (System is the default: it follows the iPhone) and **5 colour palettes**:
  Sunrise, Ocean, Aurora, Ember, Lavender.
- **How it works:** every colour in the app comes from one file, `Theme.swift`, so themes only had to change that
  file. Each colour is "adaptive": it holds a light AND a dark value, and iOS picks while drawing. Accent colours come
  from the chosen palette in four roles (main, deep, warm, cool). The palette is also saved in the App Group, so the
  widgets match.
- **Always dark on purpose:** the ringing screen, the wallpaper player and the widgets sit on night-sky wallpapers.
- 👉 `Shared/DesignSystem/Theme.swift`, `docs/screens/35-themes.md`

## "Can an alarm ring once AND on certain days?" (#36)
- Yes: in the editor tick **Once** together with days, e.g. **Once + Wed** at 12:00. It rings one extra time at the
  next 12:00 (today, or tomorrow if that's passed) and then every Wednesday. A sentence under the days says exactly
  which: "Rings once today at 12:00 PM, then every Wed."
- **How:** iOS has no "weekly plus one extra" alarm, so RiseUp schedules two: the weekly one and one exact-time one.
  We save the extra ring's exact moment (`extraOnceDate`), so once it has passed it's simply ignored.
- **The tricky cases are tested** (17 tests): on a Wednesday it rings once, not twice; after the extra ring the
  alarm stays on for its days; saving the editor after the extra ring rang doesn't create a new one.
- 👉 `docs/screens/36-once-and-days.md`, `RiseUpTests/OnceAndDaysTests.swift`

## "Can I use my own song as the alarm?" (#37)
- Yes: Sound → **Add your own sound** → **From Files** (MP3, M4A, WAV…) or **Sound of a Video** (from Photos).
  It's ready in about a tenth of a second, selected and playing. There's also a **search bar** for all sounds.
- **What RiseUp does to it:** keeps up to 30 seconds (Apple's limit for alarm sounds), skips silence at the
  start, makes quiet recordings loud, repeats short "dings", and saves it in the same format as our own sounds.
- **Honest limit:** iOS 26 has a reported bug where the lock-screen alarm plays iOS's own tone instead of an app's
  added sound. Even then the alarm rings, and your sound plays as soon as you open RiseUp.
- **Negative cases are handled and tested** (29 tests with real generated files): not audio, empty files,
  silence, a click, a video without sound, Apple Music songs, deleting a sound an alarm still uses…
- 👉 `docs/screens/37-custom-sounds-and-search.md`, `Alarm/Services/Audio/SoundClipMaker.swift`

## "How are the wallpapers / backgrounds made?"
- **They're code, not videos or images.** Each of the 25 live wallpapers (Golden Hour, Aurora, Kyoto Blossoms,
  Synthwave…) is a small "renderer": a pure function that draws one frame with SwiftUI's **Canvas** (shapes,
  gradients, blend modes) given two numbers: **time** and **energy**.
- **Animation:** a **`TimelineView(.animation)`** asks for a new frame 60× a second (24× for small thumbnails),
  so the animation is simply "draw again with a slightly later time".
- **"Energy":** when the alarm rings it goes from 0 to 1 over 40 seconds, so the wallpaper gets brighter, busier
  and faster: it "wakes up with you". Speed changes come from an integral of the speed (`WallpaperEnergy.clock`),
  so nothing ever jumps.
- **Why code:** instant loading, tiny download, sharp on every screen, and it can react to the alarm.
- **Your own photos:** picked with the system photo picker (no photo-library permission needed), shrunk once,
  saved as files, shown with a slow "Ken Burns" zoom.
- **Each wallpaper has a signature sound** (the Kyoto scene plays a koto…). The Scene Player plays them together.
- **The app's dark background and neon colours** come from one design system: `Theme` tokens (colours,
  gradients, spacing) + reusable components (`GlowCard`, `BigClockText`, neon buttons…).
- 👉 `Alarm/Features/Wallpapers/Renderers/` (start with `WallpaperKit.swift`), `Shared/DesignSystem/Theme.swift`

## "Where do the sounds come from? Did you download or scrape them?"
- **Neither. We generated every sound ourselves with a Python script, using maths.** No internet, no scraping,
  no recordings, no licences.
- **How the script works** (`Tools/generate_sounds.py`, Python standard library only):
  1. Each sound is a list of numbers (44,100 per second), each one a speaker position.
  2. It builds instruments from classic synthesis techniques:
     - **sine waves + overtones:** bells, singing bowls, organ-like tones
     - **Karplus–Strong:** a plucked string (koto, sitar, guitar, harp)
     - **FM synthesis:** electric piano
     - **filtered noise:** rain, surf, wind, breath in a flute
     - **envelopes:** each note's attack and fade
  3. It plays melodies with those instruments for 12 seconds, made to loop without a gap.
  4. It saves a WAV, then macOS's built-in `afconvert` turns it into a compressed `.caf` file (what AlarmKit
     wants).
  - `Tools/generate_sleep_sounds.py` makes the 10 sleep sounds the same way.
- **How the app connects to them:**
  - the files sit in `Alarm/Resources/Sounds/`, bundled inside the app
  - the Swift enum `AlarmSound` has one case per file, its raw value is the file name (`"riseup_koto.caf"`), and
    it gives each sound a title, a category and an icon for the UI
  - the alarm stores only that file name in the database
  - when scheduling, `AlarmKitScheduler` tells iOS "ring with `riseup_koto.caf`"; inside the app,
    `AudioService` plays the same file with `AVAudioPlayer`
- **So the script is a build tool, not part of the app:** run it on the Mac, it writes the files, the app ships
  them.
- 👉 `Tools/generate_sounds.py`, `Alarm/Models/AlarmSound.swift`, `docs/ASSETS.md`

## "How do the missions work? Which Apple frameworks?"
| Mission | How it checks you're awake | Apple framework |
|---|---|---|
| Math | random problems by difficulty, solve N | (pure Swift logic) |
| Typing | type a phrase exactly | SwiftUI text input |
| Memory | remember and repeat a pattern on a grid | SwiftUI |
| Shake | shake the phone N times (acceleration peaks) | **Core Motion** (accelerometer) |
| Steps | walk N steps | **Core Motion** (`CMPedometer`) |
| Squats | detect up/down body movement | **Core Motion** (device motion) |
| Photo | photograph the same place you registered (e.g. your sink) | **AVFoundation** camera + **Vision** (image "feature prints": a fingerprint of a photo; small distance = same place) |
| Barcode / QR | scan the code you registered (toothpaste, coffee…) | **VisionKit** (`DataScannerViewController`) |

**Safety net:** if a sensor or the camera can't work, the mission turns into Math, so nobody can ever be stuck
with a ringing alarm. While you work, the alarm goes quiet; stop for 15 s and it comes back.
"Time Pressure" reads the time aloud with **AVSpeechSynthesizer**.

## "Which Apple frameworks does it use, and what for?"
| Framework | Used for |
|---|---|
| SwiftUI | every screen, animations, Canvas wallpapers |
| SwiftData | the database (alarms, missions, history) with versioned migrations |
| Observation (`@Observable`) | ViewModels and settings update the UI automatically |
| **AlarmKit** | real system alarms, snooze, the re-ring chain (iOS 26) |
| ActivityKit | the alarm's Live Activity (lock screen + Dynamic Island) |
| WidgetKit | home and lock screen widgets |
| App Intents | the "Start Mission / Wake up" button on a ringing alarm |
| AVFoundation | sounds (`AVAudioPlayer`, audio session), the camera (`AVCaptureSession`), speech |
| MediaPlayer | sleep sounds on the lock screen's Now Playing controls |
| Core Motion | shake, steps and squat missions |
| Vision | photo mission: comparing two photos |
| VisionKit | barcode / QR mission scanner |
| PhotosUI | choosing your own wallpaper photo, or a video whose sound becomes an alarm sound |
| UserNotifications | the bedtime reminder |
| Charts (Swift Charts) | wake-up statistics |
| UIKit / ImageIO / CoreGraphics | images, haptics, drawing the app icon (tool) |
| Swift Testing | 155 unit tests |
| Accelerate (vDSP) | making your own sounds loud enough, fast (`SoundClipMaker`) |
| CoreTransferable / UniformTypeIdentifiers | receiving a video from Photos as a file; which files the Files picker offers |

No third-party libraries at all, so nothing to update and nothing that tracks users.

## "Why doesn't it run on my iPhone 11 / 12 with iOS 18?"
- **The short answer:** RiseUp needs **iOS 26** because it's built on **AlarmKit**, which only exists in iOS 26.
  Without AlarmKit an app can't make a real alarm (loud, through Silent mode, when the app is closed).
- **Good news:** iPhone 11 and newer **can update to iOS 26**. Your 11 and 12 just need *Settings → General →
  Software Update*, and RiseUp will install and work the same. iOS 26 runs on iPhone 11 and later; older models
  (XS, XR and before) can't get it.
- **What about Alarmy?** It existed years before AlarmKit, so on older iOS it uses the old trick: lots of normal
  notifications in a row, plus keeping the app alive in the background playing silent audio so it can ring at
  full volume. Limits of that trick:
  - notification sounds max 30 s
  - they **obey the Silent switch**
  - **killing the app breaks it**, which is why Alarmy asks you not to swipe it away
- **Can we support iOS 17 / 18 too?** Yes, with a "fallback alarm engine". The UI is almost ready, the alarm
  engine needs a second version. See the plan below.

### Plan: support iOS 18 (iPhone XS and newer) if we decide to
iOS 18 is the sensible floor: we use iOS 18 features (the new `Tab` API, `MeshGradient` wallpaper, Vision's
modern Swift API), and SwiftData needs 17 anyway.
1. **Deployment target:** set it to 18.0 for the app, widget and test targets.
2. **Guard the iOS 26 code:**
   - wrap AlarmKit users in `if #available(iOS 26, *)`: `AlarmKitScheduler`, `StartMissionIntent`, the Live
     Activity, the debug Lab
   - the compiler lists every place that needs it
3. **A second engine:** `NotificationAlarmScheduler` implements the same `AlarmScheduling` protocol, so no screen
   changes, only `AppDependencies` picks the engine by iOS version.
   - each alarm becomes a burst of local notifications (main ring + re-rings every 30 s)
   - they're "time-sensitive", so they break through Focus
   - each has a "Wake up" button opening the Ringing screen
   - limit: iOS keeps only **64 pending notifications per app**, so the engine schedules the next few days and
     tops up whenever the app opens
4. **Sounds:** notification sounds must be ≤ 30 s, so the script exports 28-second versions too.
5. **Optional keep-alive:** background audio keeps the app alive overnight to ring at full volume (Alarmy's
   method). This needs a clear "don't close RiseUp" message, and App Review watches background audio closely.
6. **Honest limits on iOS 18** (shown in the app):
   - rings at the **ringer** volume
   - **silent when the Silent switch is on**
   - Stop doesn't exist, but swiping the notification away does
   - "Critical Alerts" would fix Silent mode, but Apple only grants them to health/safety apps
7. **Test** on a real iOS 18 phone: locked, Silent on/off, Focus, app killed, after a reboot.
- **Effort:** roughly one phase (a week of focused work + device testing).
- **Recommendation:** launch on iOS 26 (≈ most active iPhones once it's been out a few months), add the iOS 18
  engine in an update if users ask.

## "What happens when the alarm rings?" (the full flow, say it in order)
1. 7:00 iOS rings (AlarmKit), full screen, even locked/silent/closed.
2. You tap **Wake up** (or Start Mission) → RiseUp opens on the **Ringing screen**: live wallpaper getting more
   energetic, our own sound ramping up, the time, Snooze (if allowed and no missions) or the missions.
3. Missions: the alarm goes quiet while you're active; idle 15 s → it rings again.
4. Done → **"You're up!"** screen with confetti, a mood check-in, the backups are cancelled, tomorrow is re-armed,
   and the wake-up is saved to history (streaks and stats on the Morning tab).
5. Optional **Wake-up check** a few minutes later: "Are you up?" one more alarm.
- If you pressed Stop or a button instead: backups ring 30 s later, again and again, until you get up in RiseUp.

## "What are the widgets?"
- Home screen small / medium / large, and lock screen circle / rectangle / inline.
- They show the next alarm on its own wallpaper with a live countdown, the next alarms, and +10/+20/+30 nap
  buttons.
- The app writes a small snapshot into a shared App Group folder; the widget reads it.
- The widget moves to the next alarm by itself after each ring. Taps open the app via `riseup://` links.
- 👉 `docs/screens/31-widgets.md`

## "How would you debug or trace a feature?"
- Breakpoints at each layer (View action → ViewModel method → Service), step through, read the call stack
  bottom-up. For flows iOS starts by itself (an alarm's Wake up button): Edit Scheme → "Wait for the executable to
  be launched", or watch the built-in 🔎 trace (`os.Logger`, subsystem `com.riseup.trace`) in Console.app.
- 👉 `docs/DEBUGGING_GUIDE.md` (8 hands-on labs), `Alarm/Services/Logging/Trace.swift`

## "How do you know it works?" (quality)
- **155 unit tests** (Swift Testing): date maths, mission logic, the re-ring rules, database migrations, sync,
  ViewModels with mocks, widget planning, deep links.
- **Zero-warning builds** in Swift 6 strict concurrency, Debug and Release.
- **Real-device test matrix for alarms:** locked, Silent mode, Focus, app killed, reboot, snooze, Stop without
  mission. The Simulator can't ring real alarms, so the iPhone is the only real test.
- **Code reviews and testing found and fixed ~48 bugs**, each written down with the rule it taught (`HOW_IT_WORKS.md` Part 4).

## "What about privacy and the App Store?"
- No account, no server, no analytics, no ads, no tracking. The privacy manifest (`PrivacyInfo.xcprivacy`)
  declares exactly that.
- Permissions are asked only when needed, each explained first:
  - **alarms:** required
  - **camera:** photo and barcode missions
  - **motion:** shake, steps and squat
  - **notifications:** the bedtime reminder only
- Free, no in-app purchases.
- Store texts, review notes and launch steps: `docs/APP_STORE.md`. Privacy policy: `docs/PRIVACY_POLICY.md`.

## "Why the rooster logo?"
A rooster is nature's alarm clock. Its head is the sun, its comb the rays, its crow (open beak + sound waves) the
alarm; it leans back crowing at the sky ("Rise Up"). Every competitor uses a twin-bell clock or digits, so it's
ownable, and a character is the most memorable kind of brand mark. Drawn in code by
`Tools/generate_app_icon.swift`; the journey is in `HOW_IT_WORKS.md` ("the logo").

## "What's left before launch?"
See `docs/ROADMAP.md`. In short:
- your own **bundle ID** and Apple Developer Program membership (needed for TestFlight / App Store, WeatherKit)
- the **real-device test pass** of the re-ring chain and widgets
- App Store screenshots and the hosted privacy policy
- **TestFlight**, then submission
