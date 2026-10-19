# #38 Missions you can't miss (UX review by the lead)

**Phase 7+** · on `development` · no database change

## The problem
Missions are what makes RiseUp different, but "Add mission" sat **below the fold** in the editor (after Repeat
and Label), behind a sheet with two steps. Many people never found it, so their alarm stopped with one tap.

## What changed: one tap, in three places
1. **Alarm Editor**: the "Wake-up mission" card is now **second, right under the time**:
   - a status pill: **OFF** (grey) or **ON** (gradient), and a sentence: "Pick one: the alarm won't stop until
     it's done." / "Stops only after: Math, Steps."
   - a strip of **8 mission tiles**. **One tap adds** Math, Steps, Shake, Memory, Typing or Squats with sensible
     settings (no sheet at all). **Photo** and **QR code** (small ⚙︎) open straight on their setup, because a photo
     or code must be registered first. Tapping a chosen tile (✓) opens it to **Adjust**.
   - the chosen missions as rows (Adjust, − remove), "Add another mission" / "All missions & settings".
   - the icon breathes (`symbolEffect(.pulse)`) only while there's no mission; the 5th tile peeks at the edge, so
     people see they can swipe.
2. **Alarm list**: a card without a mission shows a dashed **"+ Add mission"** pill. One tap → Mission Picker →
   **saved to the alarm right away** (no editor, no Save). Cards with missions show **"⚡ Math · Steps"** chips.
3. **Widgets** (every home-screen size): the next alarm's mission on a dark glass pill (**"⚡ Steps"**), or a bright
   **"+ Add mission"** / **"+ Add a wake-up mission"** button that opens RiseUp **straight into the Mission Picker
   for that alarm** (`riseup://alarm/<id>/mission`). Later alarms show their mission icons next to the time.
   A small widget for an alarm without a mission opens the picker when tapped.

## Every case, and what happens
| Case | Result |
|---|---|
| Tap Math (no missions yet) | Math · Normal · 3 problems added, status ON, no sheet |
| Tap Math again | its settings open (Adjust), never a second Math |
| Tap Photo / QR | the picker opens on its setup; nothing is added until it's registered and "Add" is tapped |
| 3 missions chosen | other tiles grey out; chosen ones can still be adjusted; "That's the most: 3" |
| Card "+ Add mission", pick Memory | saved + re-scheduled (a mission alarm gets its backup chain) |
| …the alarm is switched off | saved, not scheduled (an off alarm never rings) |
| …the alarm's wake-up is pending (it rang) | blocked: "This alarm is locked until you're up…" |
| …iOS refuses to schedule | the mission is taken off again, the card never pretends; a message explains |
| …the alarm was deleted while the picker was open | nothing happens |
| Widget "+ Add mission" (app closed or open) | Alarms tab → Mission Picker for THAT alarm → saved |
| Old widget data (before #38) | still loads: icons only, no names (`missionTitles` is optional) |
| A typo'd link `riseup://alarm/<id>/nonsense` | ignored |

## Connection map
```
AlarmEditorView → MissionCard(viewModel:)
   tile tap → AlarmEditorViewModel.quickAddMission(type)
                chosen?      → editMission → AppCoordinator.presentMissionPicker(editing:)
                Photo / QR   → presentMissionPicker(editing: nil, startingWith: type) → MissionPickerViewModel.choose
                else         → draft.missions.append(.defaults(for: type))
AlarmListView → AlarmCardView(onAddMission:) → AlarmListViewModel.addMission(toAlarm:)
                → presentMissionPicker → callback → save(_:toAlarm:) → replaceMissions + save + scheduler.schedule
Widget MissionLine → Link(riseup://alarm/<id>/mission) → RootView .onOpenURL → DeepLink.addMission
                → AppCoordinator.open → missionRequestAlarmID → AlarmListView .task(id:)
                → AlarmListViewModel.handleMissionRequest → addMission(toAlarm:)
WidgetBridge.plan → WidgetAlarmEvent.missionTitles ("Math", "QR code")
```

## Files, in reading order
1. `Alarm/Features/Missions/MissionDraft.swift`: `quickPickOrder`, `shortTitle`, `tagline`, `needsSetup`
2. `Alarm/Features/AlarmEditor/ViewModels/AlarmEditorViewModel.swift`: "One-tap mission tiles (#38)"
3. `Alarm/Features/AlarmEditor/Views/MissionCard.swift` (the whole card), `AlarmEditorView` (its new place)
4. `Alarm/Features/Alarms/ViewModels/AlarmListViewModel.swift`: `addMission(toAlarm:)`, `save(_:toAlarm:)`,
   `handleMissionRequest()` → `Views/AlarmCardView.swift` (`missionChips`, `addMissionPill`)
5. `Alarm/Coordinator/DeepLink.swift`, `AppCoordinator.open(.addMission)`, `takeMissionRequest()`
6. `RiseUpWidgets/NextAlarmWidget.swift`: `MissionLine`, `UpcomingRow`; `Shared/WidgetSnapshot.swift`
7. Tests: `RiseUpTests/MissionUXTests.swift` (12 tests)

## Design decisions (WHY)
- **Defaults, not a sheet:** most people want "Math, normal". Asking difficulty first is why they gave up.
  Adjusting is one tap away (the ✓ tile or "Adjust").
- **Photo/QR are the exception:** a photo mission without a registered photo can't work, so those tiles open setup.
- **Saving straight from the card/widget:** it's a small, clear change ("add Memory to this alarm"). Same safety
  rules as the on/off switch: the wake-up lock, re-check after `await`, roll back if iOS refuses.
- **The widget doesn't change data itself:** widgets can't run our code on tap; they open a link, and the app does
  the work with all its rules.
- **Links can't sit inside links** (WidgetKit): the "+ Add mission" pill is a sibling of the alarm's link.

## Test on the iPhone
1. New alarm → tap Steps → Save. The card says "⚡ Steps". Ring it: the Steps mission runs.
2. An alarm without a mission → "+ Add mission" on its card → Math → Add. No editor opened.
3. Medium widget → "+ Add mission" → RiseUp opens on "Choose a mission" → Shake → Add → the widget shows "⚡ Shake".

## Exercises
1. **TRY:** move `.memory` to the front of `MissionType.quickPickOrder` and open the editor.
2. Put a breakpoint in `AlarmListViewModel.save(_:toAlarm:)`, set the mock's `scheduleError` in a test, and step
   through the rollback.
3. Why does `missionTitles` have `= nil` and a `?`? (Hint: `widgetSnapshot` test "old snapshot still loads".)
