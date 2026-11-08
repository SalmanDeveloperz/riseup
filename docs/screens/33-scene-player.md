# Screen #33 Scene Player + Around the World: brief & review guide

**Phase 7+** · on `development` · no database change (bookmarks live in `AppSettings`)

## What it does
Tap any wallpaper card and it opens **full screen with its own sound playing**, like a music player:
- **Every live wallpaper has a signature sound** (`LiveWallpaper.signatureSound`): Kyoto Blossoms plays a koto,
  the Taj Mahal a sitar raga, Paris an accordion, Aurora a harp. Your own photos play the alarm's sound.
- **Controls:** ♥ save · ⏮ previous · ▶︎/⏸ · ⏭ next · 👁 hide the clock. Swipe left/right does ⏮ ⏭ too.
  The playlist is the tab you came from ("2 / 3"), and it wraps around at the end.
- **Two ways to choose:** "Use wallpaper + sound" (the alarm gets both) or "Wallpaper only" (keeps its sound).
- **♥ Saved** tab: your bookmarked scenes, first in the tab bar.
- **Around the World** (new tab, 11 scenes): Kyoto Blossoms, Taj Mahal Dawn, Sahara Dunes, Savanna Sunset,
  Tropical Island, Himalaya, Paris Nights, Alpine Meadow, Scottish Highlands, Andes Condor, City Lights.
- **17 new alarm sounds** (36 in total), with new categories in the Sound Picker:
  Around the world (koto, sitar, oud, savanna drums, steel drum, singing bowls, accordion, alpine horn,
  highland pipes, pan flute) · Nature (+ rainforest, seashore) · Music (jazz piano, acoustic guitar,
  epic strings) · plus Thunderstorm (loud) and Starlight (gentle).

## Connection map
```
Editor "Wallpaper" row → AlarmEditorViewModel.chooseWallpaper()
  → AppCoordinator.presentWallpaperPicker(selected:allowsDefault:sound: draft.sound, onPick:)
  → ScreenFactory → WallpaperPickerViewModel(currentSound:, audio: AudioService, settings: AppSettings, …)
       card tap → openPlayer(wallpaper) → playlist = this tab · isShowingPlayer = true
                → audio.previewLooping(sound(for: wallpaper))         ← the sound starts with the scene
  WallpaperPickerView .fullScreenCover(isPresented: $viewModel.isShowingPlayer) → ScenePlayerView
       ⏮ ⏭ / swipe → previous() / next() → playerIndex ± 1 → new scene fades in + its sound
       ▶︎/⏸ → togglePlay()        ♥ → toggleSaved() → AppSettings.savedWallpapers
       "Use wallpaper + sound" → use(withSound: true) → closePlayer → 350 ms → coordinator.completeWallpaperPicker
  → onPick(WallpaperChoice(wallpaper:, sound:)) → draft.wallpaper (+ draft.sound) → Save
```

## Files, in reading order
1. `Models/Wallpaper.swift`: `WallpaperChoice`, `LiveWallpaper.signatureSound`, `WallpaperCategory.saved / .world`
2. `Models/AlarmSound.swift`: the new cases and `Category.world / .music`
3. `Tools/generate_sounds.py`: `harmonic_tone`, `membrane`, `flute`, `piano` and the "Around the world" section
4. `Features/Wallpapers/Renderers/WorldWallpapers.swift`: the 11 scenes (start with `KyotoBlossomsRenderer`)
5. `Features/Wallpapers/ViewModels/WallpaperPickerViewModel.swift` (MARK Scene Player)
6. `Features/Wallpapers/Views/ScenePlayerView.swift` → `WallpaperPickerView.swift`
7. `Services/Audio/AudioService.swift`: `previewLooping`
8. `Features/Wallpapers/Views/WallpaperView.swift`: `clockHalo()` (also used by `RingingView`)
9. Tests: `RiseUpTests/WallpaperTests.swift` (suite `ScenePlayerTests`, test `symbolsExist`)

## Data
| Reads | Writes |
|---|---|
| `AppSettings.savedWallpapers` (bookmarks, raw values like `"live.kyotoBlossoms"`) | the same |
| The alarm's current sound (for photos) | `WallpaperChoice` → the editor or Settings saves it |

## Design decisions (WHY)
- **The player shares the picker's ViewModel.** One playlist, one selection, one set of bookmarks: nothing to sync.
- **Close the player, wait 350 ms, then close the sheet.** Dismissing both in the same instant makes SwiftUI skip
  an animation.
- **"Wallpaper only" exists** because some people love a scene but need a loud sound to wake up.
- **Bookmarks in UserDefaults, not SwiftData:** a small list of strings, same as other preferences.
- **Saved hides missing items** (a deleted photo) instead of deleting them: nothing breaks, nothing to clean up.
- **The clock halo sits behind the clock only.** As a full-screen layer it greyed out suns and snow.
- **The equalizer doesn't analyse the audio:** sine waves look musical and cost nothing.
- **All sounds are synthesised** by our script: no licences, ~280 KB each.

## Test on the iPhone
- Open each world scene: the sound starts at once, ⏭ changes both picture and sound, ⏸ silences it.
- Silent switch on: the scene's sound still plays (the audio session is `.playback`, like the alarm itself).
- Choose "Use wallpaper + sound", save the alarm, let it ring: the scene and its sound appear together.
- ♥ a scene, close the picker, open it again: it's in Saved.

## Exercises
1. **TRY:** in `LiveWallpaper.signatureSound`, give Paris Nights `.jazzPiano` instead of `.accordion`.
2. **TRY:** in `ScenePlayerView`, change the swipe distance `60` to `30` for a lighter swipe.
3. Make your own sound: copy `riseup_panflute` in `generate_sounds.py`, change the notes, run
   `python3 Tools/generate_sounds.py riseup_<name>`, add a case to `AlarmSound` (never rename a shipped one).
