# #35 Themes: Appearance (System / Light / Dark) + colour palettes

**Phase 7+** · on `development` · no database change (2 preferences in `AppSettings`, palette also in the App Group)

## What it does
Settings → **Appearance** (the first section):
- **System / Light / Dark.** System is the default (follows the iPhone; changed 2026-10-18); Light is a soft lavender-white with
  white cards; System follows the iPhone.
- **Colours:** five palettes: **Sunrise** (the original purple/pink/orange), **Ocean**, **Aurora**, **Ember**,
  **Lavender**. Buttons, switches, the tab bar, the background glow, the big clocks and the widgets all follow.
- **Always dark, on purpose:** the Ringing flow (wallpaper, missions, "You're up!"), the Scene Player, the widgets
  and the alarm's Live Activity. They're drawn on night-sky wallpapers; dark text would vanish.

## Connection map
```
SettingsView (Appearance card) → SettingsViewModel.appearance / .palette
  → AppSettings.appearance (UserDefaults)          → RiseUpApp .preferredColorScheme(appearance.colorScheme)
  → AppSettings.palette → Theme.palette + ThemeStorage.save (App Group)
                                                     → RiseUpApp .id(palette): every screen is rebuilt
                                                     → WidgetBridge.reloadForNewTheme → widgets redraw
Every colour: Theme.Colors.accent / background / textPrimary …
  → Color.adaptive(light:dark:) / Color.accent(hex): a dynamic UIColor that asks iOS "light or dark?" while drawing
RingingView / ScenePlayerView .preferredColorScheme(.dark) · widgets .environment(\.colorScheme, .dark)
```

## Files, in reading order
1. `Shared/DesignSystem/Theme.swift`: `AppearanceMode`, `ColorPalette` (the 4 roles), `ThemeStorage`, then
   `Theme.Colors` and the two colour helpers at the bottom (read their LEARNs)
2. `Alarm/Services/Settings/AppSettings.swift` (`appearance`, `palette`)
3. `Alarm/App/RiseUpApp.swift` (`.preferredColorScheme`, `.id`)
4. `Alarm/Features/Settings/…/SettingsViewModel.swift` → `SettingsView.swift` (`appearanceCard`, `paletteSwatch`)
5. `RingingView`, `ScenePlayerView`, `RiseUpWidgets/*`: where "always dark" is set
6. Tests: `RiseUpTests/ThemeTests.swift`

## Design decisions (WHY)
- **Role names, not colour names:** the tokens were `neonPink`, `neonPurple`… but in Ocean "pink" is blue. They're
  now `accent`, `accentDeep`, `accentWarm`, `accentCool` (+ `Gradients.brand`), so the code never lies.
- **Dynamic colours, not two themes:** each token holds its light AND dark value; iOS picks while drawing. No
  screen needed an `if colorScheme == .light`.
- **Accents get a bit deeper in light mode** (`Color.accent`): pale ones like Aurora's lime would be unreadable on
  white otherwise.
- **`onAccent` (white)** for text and icons ON a gradient or accent fill; `textPrimary` would turn dark ink in
  light mode (found in the Simulator: the shield in "Check my alarms").
- **`.id(palette)` rebuild:** colours are read when a view is drawn, and a static value can't tell SwiftUI it
  changed. Rebuilding on the (rare) palette change is simple and safe; navigation lives in `AppCoordinator`.
- **Palette in the App Group** so the widgets use it too (and re-read it in `getTimeline`).
- **Removed `UIUserInterfaceStyle = Dark`** from the build settings; it would lock "System" to dark.

## Test on the iPhone
1. Settings → Light → walk through every tab and sheet: text readable everywhere?
2. System + switch the iPhone between light and dark (Control Center): RiseUp follows.
3. Pick Ember → go Home: the widgets' accents change. Ring an alarm: Ringing is still dark.

## Exercises
1. **TRY:** change `background`'s light value `0xF6F3FB` to `0xFFF8F0` (a warm cream) and look at Light mode.
2. Add a sixth palette "Midnight Gold": a new case + its 4 hex values. The test `palettesComplete` checks it.
3. Find `Theme.Colors.onAccent` in `NeonButtonStyle` and explain why it isn't `textPrimary`.
