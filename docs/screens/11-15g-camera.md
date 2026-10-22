# Camera screen (used by #11 Photo registration and #15g Photo mission): brief & review guide

**Phase 7** · on `development`

## What it does
A full-screen camera that opens **instantly**:
- "Starting camera…" while the hardware wakes up, then the live picture fades in
- a hint on top ("Photograph the same spot")
- big sunrise shutter button (white flash + haptic), **torch** button for dark rooms, ✕ to cancel
- no "Use Photo / Retake" step: one tap and the check starts

## Why it was rebuilt
Salman's iPhone test: after allowing the camera, the app looked frozen for seconds ("did it crash?").
Apple's `UIImagePickerController` starts the camera on the main thread. Now the slow work happens on a background
queue, and the camera is **pre-warmed** (set up, not switched on) while you read the mission screen.

## Connection map
```
PhotoMissionViewModel.start() / MissionPickerViewModel.choose(.photo)
  → CameraAccess.prepareCamera() → CameraSession.prepare()        (background: find + set up the camera)
"Take photo" → requestIfNeeded (popup first time) → isShowingCamera = true
  → .photoCapture(isPresented:title:onImage:)  (PhotoCapture.swift)
       real iPhone → fullScreenCover → CameraScreen
                        .task → CameraSession.start()             (background: camera on)
                        shutter → CameraSession.capturePhoto()    (background: take + shrink to 1600 px)
                        → onImage(UIImage) → ViewModel.check / registerPhoto
                             → CameraAccess.makeJPEG (background) → Vision fingerprint (background)
                        .onDisappear → CameraSession.stop()       (camera + torch off)
       Simulator   → PhotosPicker (photo library, for testing only)
```

## Files, in reading order
1. `Services/Camera/CameraSession.swift`: the WHY at the top, then `start`, `capturePhoto`, `PhotoProcessor`
2. `Features/Missions/Views/Capture/CameraScreen.swift`
3. `Features/Missions/Views/Capture/PhotoCapture.swift`: camera vs library
4. `Services/Camera/CameraAccess.swift`: `prepareCamera`, `makeJPEG`

## Data
Nothing stored here. The registered spot keeps only a fingerprint + 320 px thumbnail (see `PhotoMissionPayload`).

## Test on the iPhone
- First open after allowing the camera: the screen appears at once, the picture within about half a second.
- Torch on/off; it switches off when the camera closes.
- Take a photo → "Checking…" appears immediately.

## Exercises
1. **TRY:** `CameraSession.maxPhotoSide = 1024` (even faster photos).
2. Change the hint text passed to `.photoCapture` in `PhotoMissionView`.
