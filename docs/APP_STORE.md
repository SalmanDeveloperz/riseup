# RiseUp: App Store launch guide

Everything to submit RiseUp, in order. Items marked **(you)** need your Apple account, a decision or a website;
everything else is already done in the code.

## 1. Before the first upload
| Step | Status |
|---|---|
| Decide the final **bundle ID** (e.g. `com.yourname.riseup`) and register it in developer.apple.com → Identifiers **(you)** | ⬜ |
| Change `PRODUCT_BUNDLE_IDENTIFIER` for the app AND the widget (`<app id>.RiseUpWidgets`) in Xcode → Signing & Capabilities | ⬜ |
| Create the app in App Store Connect with that bundle ID **(you)** | ⬜ |
| Host `docs/PRIVACY_POLICY.md` somewhere public (GitHub Pages, Notion, your site) and note the URL **(you)** | ⬜ |
| A support URL or e-mail (can be the same page) **(you)** | ⬜ |
| App icon (1024 px, normal / dark / tinted) | ✅ `Tools/generate_app_icon.swift` |
| Privacy manifest (`Alarm/PrivacyInfo.xcprivacy`) | ✅ no tracking, no data collected |
| Export compliance (`ITSAppUsesNonExemptEncryption = NO`) | ✅ in `Config/Info.plist` |
| Dark launch screen (no white flash) | ✅ `LaunchBackground` colour |
| Debug tools hidden in the App Store build (Lab, Design Gallery, sample data) | ✅ all `#if DEBUG`, checked in a Release build |
| Release build compiles with zero warnings | ✅ checked 2026-10-13 |
| Real-iPhone test list (section 5) passed **(you)** | ⬜ |

## 2. Upload
1. Xcode → choose **Any iOS Device (arm64)** as destination.
2. **Product → Archive**.
3. In the Organizer: **Distribute App → App Store Connect → Upload**.
4. In App Store Connect → TestFlight, install it on your own iPhone first.

## 3. The listing (copy and paste, adjust as you like)
**Name:** RiseUp: Mission Alarm Clock
**Subtitle:** (30 characters max) `Wake up for real, every day`
**Category:** Lifestyle (secondary: Health & Fitness)
**Age rating:** 4+ (no objectionable content)
**Price:** Free, no in-app purchases

**Promotional text** (170 max):
> The alarm you can't sleep through. Solve a puzzle, walk, squat or snap a photo of your bathroom sink, and you're up. For real.

**Description:**
> RiseUp is an alarm clock that makes sure you actually get up.
>
> Turn off your alarm by completing a mission:
> • Math: solve a few problems to wake your brain
> • Typing: copy a short motivating line
> • Memory: repeat a pattern of glowing tiles
> • Shake, Steps or Squats: get your body moving
> • Photo: take a picture of a spot in another room, like your bathroom sink
> • Barcode: scan your toothpaste or coffee jar
>
> Pressing "Stop" isn't enough: backup alarms keep ringing until your mission is done.
>
> MORE THAN AN ALARM
> • 20 alarm sounds, from a classic twin-bell clock to birdsong and lo-fi
> • Wake-up check: a second alarm makes sure you didn't go back to sleep
> • Morning panel with your streak, a line of the day and your next alarm
> • Records calendar and stats: wake-up times, snoozes and mood
> • Sleep sounds: mix rain, ocean, fireplace and more, with a sleep timer
> • Bedtime reminder
>
> PRIVATE BY DESIGN
> Everything stays on your iPhone. No account, no ads, no tracking.
>
> Alarms ring in Silent mode, during Focus and even when the app is closed.

**Keywords** (100 characters, comma separated, no spaces needed):
`alarm,clock,wake up,mission,alarmy,math alarm,loud alarm,morning,sleep,snooze,routine,habit`

## 4. App Privacy ("nutrition label")
Answer **"Data Not Collected"**. RiseUp has no server, no analytics, no accounts and no ads.
Camera photos are reduced to a fingerprint + small thumbnail and never leave the iPhone.
If you ever add analytics, crash reporting or iCloud, update this AND `PrivacyInfo.xcprivacy`.

## 5. Notes for the App Review team (paste into "Notes")
> RiseUp uses AlarmKit (iOS 26) to schedule alarms. To test quickly: tap the ⚡ button on the Alarms tab,
> choose "1 min", tap "Start", and wait. When the alarm rings, tap "Start Mission" (or open the app) to see the
> mission screen. Missions: Math is the quickest to try. Photo and Barcode missions need a registered photo or
> code, set in the alarm editor → Missions. Backup alarms ring at +1, +2, +3, +5 and +8 minutes until a mission is
> finished; this is the core feature ("you can't just press Stop"). Camera and Motion are used only for missions;
> nothing leaves the device.

## 6. Screenshots (6.9" iPhone, 1320 × 2868 px)
Take them in the Simulator (iPhone 17 Pro Max) with ⌘S. Suggested 6, in order:
1. Alarm list with the "Rings in…" header
2. A mission (Math or Memory) mid-solve
3. The mission picker grid
4. "You're up!" success screen with confetti
5. Morning panel (streak + week chart). Use "Add sample data (Debug)" in Stats/Records first
6. Sleep sounds with a mix playing

## 7. Real-iPhone test list (before every submission)
- [ ] Alarm rings with the app **killed**, phone **locked**, **Silent** switch on, **Focus** on
- [ ] Pressing Stop on a mission alarm → backups ring at +1, +2, +3 min
- [ ] Finishing the mission → no more backups today, tomorrow's chain armed
- [ ] Photo mission: camera opens in under a second, torch works, matching works in your bathroom
- [ ] Barcode, Steps, Squat missions on the device
- [ ] Sleep sounds keep playing when locked; the timer fades out; an alarm stops them
- [ ] Bedtime reminder notification arrives
- [ ] Change the time zone (Settings → General → Date & Time) with a mission alarm on → backups move with it
