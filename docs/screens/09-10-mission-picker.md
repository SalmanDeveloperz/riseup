# Screens #9 + #10 · Mission Picker & Mission Settings: brief & review guide

**Phase 2** · on `development`

## What it does
One sheet with up to three steps, opened from the editor's **Missions** card ("Add mission" or a mission's edit button):
1. **Choose a mission** (#9): a 2-column grid of all 8 mission types. Math, Typing and Shake work now;
   the others show a "Phase 3" badge and can't be tapped.
2. **Mission settings** (#10): difficulty (5 levels, for Math and Typing), "How many" (−/+), and a live **example**
   that changes with the difficulty ("27 + 48 = ?", "“I am wide awake”"…).
3. **Practice** (optional): **Try it now** runs the real mission screen. Finish it and you return with
   "Nice! You're ready for tomorrow."

**Add mission** (or **Save mission** when editing) sends the result back to the editor. An alarm can have up to **3 missions**;
they run in order when it rings.

## Connection map
```
AlarmEditorView Missions card ("Add mission" / ✎)
  → AlarmEditorViewModel.addMission() / editMission(_:)
  → AppCoordinator.presentMissionPicker(editing:onPick:)      ← stores the callback
  → sheet = .missionPicker → RootView .sheet → ScreenFactory
       └─ MissionPickerView ── owns ──► MissionPickerViewModel
            NavigationStack(path: $viewModel.path)        ← the sheet's OWN small path
              root      : type grid
              .settings : difficulty / how many / example
              .practice : MissionView (the real mission, see screens 14–16)
                                         └─► AppCoordinator.completeMissionPicker(with: MissionDraft)
                                               → callback → editor's draft.missions (add or replace)
```

## Files, in reading order
1. `Models/MissionType.swift` + `Features/Missions/MissionDraft.swift`: the value we pass around, and the
   `nonisolated extension MissionType` (which types work, repetition ranges, units)
2. `Features/Missions/Logic/MathProblemGenerator.swift`: pure logic, easy to test
3. `Features/Missions/Logic/TypingPhrases.swift`
4. `Features/MissionPicker/ViewModels/MissionPickerViewModel.swift`: read the "child coordinator" LEARN block
5. `Features/MissionPicker/Views/MissionPickerView.swift`
6. `Repositories/AlarmRepository.swift` → `replaceMissions(of:with:)`: how drafts become `MissionConfig` rows on Save

## Data
| Reads | Writes |
|---|---|
| The mission being edited (a `MissionDraft` value) | Nothing directly. On the editor's **Save**, `AlarmRepository.replaceMissions` deletes the old `MissionConfig` rows and creates new ones in order. |

## Design decisions (WHY)
- **A sheet with its own `path`:** the steps inside the sheet are private to this flow. The app coordinator only knows
  "the mission picker is open". That's a *child coordinator*. It's smaller, and it can't break the app's tabs.
- **The example text is stored, not computed:** a computed random example changed on every redraw (it flickered while you
  tapped). Now it's refreshed only when the type or difficulty changes (`refreshSample()`).
- **Practice uses the real mission screen** (`MissionView`). What you try is exactly what you'll get at 6 a.m.
- **Max 3 missions:** more is mostly frustrating. TRY: change `AlarmEditorViewModel.maxMissions`.
- **Mission alarms can't snooze:** the snooze section in the editor turns off with a note.

## How to try it (Simulator is fine)
1. **+** → Missions → **Add mission** → **Math** → **Hard** → the example gets harder → **Try it now** → solve it → "Nice!".
2. **Add mission** → the editor shows "Math · Hard · 3 problems". Add **Shake** too. In the Simulator, use
   "Simulate shake (no sensor)".
3. Tap the ✎ on the Math row → change to Easy → **Save mission**.

## Exercises
1. Add a new typing phrase in `TypingPhrases.swift`. Where does it show up?
2. In `MathProblemGenerator`, make "Very easy" use numbers 1–5 only. Try it in the practice screen.
3. Why is `MissionDraft` a `struct` but `MissionConfig` a `class`? (Hint: `HOW_IT_WORKS.md` Part 4, Bug 2.)
