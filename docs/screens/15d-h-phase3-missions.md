# Missions 15d–15h · Memory, Steps, Squats, Photo, Barcode (+ #11/#12 registration): brief & review guide

**Phase 3** · on `development`

## What they do
| Mission | How it works | Needs | Simulator |
|---|---|---|---|
| **Memory** (15d) | Tiles glow for ~2 s, then you tap the same ones. A wrong tap shows the answer, then a **new** pattern | nothing | works fully |
| **Steps** (15e) | Walk N steps (pedometer). Steps arrive in small batches | Motion & Fitness permission | "Simulate 5 steps" button |
| **Squats** (15f) | Phone against your chest; a dip followed by a rise = one squat | nothing (raw motion) | "Simulate squat" button |
| **Photo** (11 + 15g) | Register a spot (bathroom sink…). In the morning, photograph it again; Vision compares the two | Camera permission | photo library + simple pixel matcher |
| **Barcode** (12 + 15h) | Register any QR/barcode in another room. In the morning, scan the same one | Camera permission | type a code instead |

Photo and Barcode show a **registration card** in Mission Settings. "Add mission" and "Try it now" stay disabled
until the photo or code is registered.

## The safety net (the most important design decision)
An alarm must **never be impossible to turn off**, and **never free to skip**:
```
sensor missing / permission denied / registration damaged ─► Math, 3 normal problems
"Can't match? / Can't find it?" (after 3 failed tries)    ─► Math, 5 HARD problems
```
It's all in one place, `MissionView.replacement`. Every sensor/camera mission gets two closures,
`onUnavailable` and `onGiveUp`, and calling one swaps the screen to Math.

## Connection map
```
RingingView / MissionPickerView (practice)
  └─ MissionView(mission:, services: MissionServices, onInteraction:, onComplete:)
        ├─ .memory  → MemoryMissionViewModel  → MemoryPatternGenerator (pure, tested)
        ├─ .steps   → StepsMissionViewModel   → services.steps  (StepCounting → CMPedometer)
        ├─ .squat   → SquatMissionViewModel   → services.squat  (SquatDetecting → CoreMotion + SquatRepCounter)
        ├─ .photo   → PhotoMissionViewModel   → services.photoMatcher (Vision / Pixel) + .photoCapture
        ├─ .barcode → BarcodeMissionViewModel → BarcodeScanScreen (VisionKit DataScanner)
        └─ replacement != nil → MathMissionView (the safety net)

Mission Settings (registration)
  MissionPickerViewModel.takePhoto()  → CameraAccess.requestIfNeeded → .photoCapture → registerPhoto
        → CameraAccess.jpegData (shrink) → photoMatcher.fingerprint → PhotoMissionPayload → draft.dataPayload
  MissionPickerViewModel.scanCode()   → BarcodeScanScreen → registerCode → draft.textPayload
  Editor Save → AlarmRepository.replaceMissions → MissionConfig.textPayload / dataPayload
```

## Files, in reading order
1. `Features/Missions/MissionDraft.swift`: payloads, `needsRegistration`, `isReadyToSave`, `idleSecondsAllowed`, `init(_ config:)`
2. `Features/Missions/MissionEnvironment.swift`: why the Simulator is treated differently
3. `Features/Missions/Views/MissionView.swift`: the router and **the safety net**
4. Memory: `Logic/MemoryPatternGenerator.swift` → `ViewModels/MemoryMissionViewModel.swift` (state machine) → `Views/MemoryMissionView.swift`
5. Steps: `Services/Motion/StepCounter.swift` (read the `@Sendable` WHY!) → `StepsMissionViewModel` → `StepsMissionView`
6. Squats: `Services/Motion/SquatDetector.swift` (`SquatRepCounter`) → `SquatMissionViewModel` → `SquatMissionView`
7. Shared ring: `Views/MissionCounterRing.swift` (used by Shake, Steps, Squats)
8. Photo: `Models/PhotoMissionPayload.swift` → `Services/Camera/CameraAccess.swift` → `Services/Camera/PhotoMatcher.swift`
   → `Views/Capture/PhotoCapture.swift` → `PhotoMissionViewModel` → `PhotoMissionView`
9. Barcode: `Views/Capture/BarcodeScanScreen.swift` → `BarcodeMissionViewModel` → `BarcodeMissionView`
10. `Services/MissionServices.swift` + `App/AppDependencies.swift`: how the sensors reach the missions

## Data
| Reads | Writes |
|---|---|
| `MissionConfig` (type, difficulty, count, **textPayload** = barcode, **dataPayload** = photo) | Registration writes the payloads into the draft; the editor's Save stores them. No schema change was needed: `MissionConfig` had both payload fields since SchemaV1. |

## Design decisions (WHY)
- **`@Sendable` on the pedometer callback.** CMPedometer calls back on a background thread. In a main-actor
  project, an un-annotated closure is assumed to be main-actor, and Swift 6 would **crash** at runtime.
  (Shake/Squat use `to: .main`, so they're fine with `MainActor.assumeIsolated`.)
- **Longer quiet time for walking missions** (`idleSecondsAllowed`): Photo/Barcode 90 s, Steps 45 s, others 15 s.
  Walking to the bathroom shouldn't make the alarm blast again.
- **A new memory pattern after a mistake:** otherwise you'd just re-tap the answer we showed you.
- **Photos are shrunk to ~640 px** before Vision looks at them: just as accurate, much faster. The rotation flag gets "baked in" too.
- **Vision doesn't work in the Simulator.** It fails, or (forced onto the CPU) returns the same fingerprint for every
  photo. We measured this with a throwaway test. So the Simulator uses `PixelPhotoMatcher`. Real iPhones always use Vision.
- **Photo library only in the Simulator:** on a real iPhone, a library photo would let you cheat.
- **Camera permission is asked before opening the camera**, so a "Don't Allow" leads to a helpful message, not a black screen.

## How to try it
- **Simulator:** Editor → Add mission → each type → **Try it now**. Photo: pick a library photo to register, then the same
  photo (match) or a different one (no match; a Debug line shows the distance). Barcode: type any code, then type it again.
- **iPhone (needed for real sensors):** Steps (walk), Squats (phone on chest), Photo (real camera), Barcode (any product code).

## ⚠️ To check on your iPhone
- `VisionPhotoMatcher.matchThreshold = 0.65` is a starting guess. In practice mode (Debug build) the distance is shown
  under the result. Photograph your spot a few times (different light), note the distances, and adjust.
- Squat sensitivity: `CoreMotionSquatDetector` threshold 0.18 g. Lower it if squats aren't counted.

## Exercises
1. **TRY:** `MemoryPatternGenerator.level(for: .veryHard)` → `gridSize: 6`. Is it still possible?
2. Change `PhotoMissionViewModel.attemptsBeforeGiveUp` to 1. When does "Can't match?" appear now?
3. Read `SquatRepCounter.add` and the test `squatCounting` in `RiseUpTests/MissionLogicTests.swift`. Add a test for
   "a rise WITHOUT a dip before it doesn't count".
