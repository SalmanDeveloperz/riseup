# How to trace any RiseUp feature (debugging guide)

The skill your seniors are asking for: **pick any feature, find where it starts, and follow it through every
file with the debugger until you can explain it.** This guide has three parts:
1. **The method:** how to think about a feature so the codebase stops being a maze.
2. **The toolkit:** the Xcode debugger, plus RiseUp's built-in 🔎 trace.
3. **Eight trace labs:** real questions a senior would ask, with the exact breakpoints to set.

Line numbers change as code changes, so every breakpoint below is given as **file + function**. Open the file
(⇧⌘O, type its name), then find the function (⌃6 shows the function list).

---

## Part 1 · The method: "follow the arrows"

### The map you always carry
Every feature in RiseUp moves through the same five layers, in the same direction:

```
 YOU tap something
   ↓
 View          (Features/…/Views)       draws, and forwards the tap        → "viewModel.save()"
   ↓
 ViewModel     (Features/…/ViewModels)  decides what happens, holds state   → "repository… / scheduler…"
   ↓
 Repository /  (Repositories/, Services/)  talks to the database or to iOS
 Service
   ↓
 iOS / Model   (SwiftData, AlarmKit, AVFoundation, WidgetKit…)
   ↑
 …and the answer comes back up: the ViewModel's state changes → SwiftUI redraws the View.
 Navigation always goes through AppCoordinator (Coordinator/), never View → View.
```

So when someone asks **"how does X work?"** you already know the shape of the answer. You only have to fill in
the names.

### The 5-step loop (use it for every feature)
1. **Start from the user's action.** What does the user tap or see? Find that text in the code: ⇧⌘F, search
   for the button's title (e.g. `"I'm up"`). That lands you in a **View**.
2. **Follow the arrow comments.** Every call that crosses a layer has a `// → …` comment telling you where it
   goes next (a project rule). ⌘-click a method name to jump to it. Each file's header has a **CONNECTIONS**
   block: `←` who calls me, `→` what I call.
3. **Put one breakpoint per layer:** in the View's action, the ViewModel method, the Service method. Not
   twenty; three or four.
4. **Run it and watch:** at each stop, look at the **values** (Variables view) and the **call stack** (who called
   me). Step forward, see what changes.
5. **Write the trace down as an arrow chain**, in your own words, like the traces in `HOW_IT_WORKS.md`. If you
   can write the chain from memory, you understand the feature. If not, run it again.

### How to answer a senior in 30 seconds
Use this template; it works for every feature:
> "It starts in **[View]** when the user **[action]**. That calls **[ViewModel.method]**, which
> **[the decision it makes]**, then **[Service]** asks iOS to **[the system part]**. The result comes back as
> **[state change]**, and the screen redraws. One tricky part is **[a WHY comment you found]**."

The last sentence is what impresses people: every file has `// WHY:` comments explaining the non-obvious
decisions. Quote one.

---

## Part 2 · The toolkit

### Breakpoints: the basics
| Do this | How |
|---|---|
| Add / remove a breakpoint | click the line number in the gutter (blue arrow) / drag it out |
| Turn one on/off | click it (dark blue = off) |
| Turn ALL on/off | ⌘Y |
| See every breakpoint | Breakpoint navigator ⌘8 |
| Show the console + variables | ⇧⌘Y |

When the app stops, the **debug bar** appears above the console:

| Button | Key | Meaning |
|---|---|---|
| Continue | ⌃⌘Y | run until the next breakpoint |
| Step Over | F6 | run this line, stop at the next one in the SAME function |
| Step Into | F7 | go INSIDE the function called on this line (this is how you "follow the arrow") |
| Step Out | F8 | finish this function, stop back in the caller |

### Read the call stack: "who called me?"
Debug navigator (⌘7) shows the **call stack**: the function you're stopped in at the top, the one that called it
below, and so on. Click any line to jump there and see ITS variables.
**Read it from the bottom up and you get the whole story**, e.g.
`RingingView (tap) → RingingViewModel.dismiss() → finish() → AlarmKitScheduler.wakeUpCompleted`.
With `async` code you'll see "async" frames; that's normal (the code waited and came back).

### Ask questions with LLDB (the console, while stopped)
| Type | What it does |
|---|---|
| `po alarm` | print an object nicely ("print object") |
| `p alarm.hour` / `v self.phase` | print a value (`v` is fastest, reads the variable directly) |
| `po repository.alarms.count` | call properties to look around |
| `bt` | print the call stack as text |
| `expr minutes = 1` | **change** a value, then continue (e.g. make a snooze 1 minute while testing) |

### Pro breakpoints (right-click a breakpoint → Edit Breakpoint)
- **Condition:** stop only when it matters, e.g. in `AlarmKitScheduler.schedule`: `alarm.hour == 7`.
- **Ignore N times:** skip the first N hits (great inside things that run often).
- **Log Message + "Automatically continue":** a "logpoint". It prints without stopping and without editing code.
  Example message: `schedule @alarm.hour@:@alarm.minute@`.
- **Symbolic breakpoint** (⌘8 → `+` → Symbolic Breakpoint): stop whenever a function runs, *wherever it's called
  from*. Type `AlarmKitScheduler.holdBackupChain`. Perfect when you don't know who calls something: stop there,
  then read the call stack.
- **Swift Error breakpoint** (⌘8 → `+`): stops the moment any `throw` happens: finds "why did it fail?" fast.

### SwiftUI-specific tricks
- **Breakpoints inside `body`** stop on EVERY redraw (often). Prefer the action closure (`Button { … }`) or the
  ViewModel method.
- **"Why did this view redraw?"** Temporarily add `let _ = Self._printChanges()` as the first line of a `body`;
  the console prints which property changed. Remove it after.
- **Debug View Hierarchy** (debug bar, the 3-rectangles icon): explode the screen into 3D layers to see what's
  on top of what.
- **Memory Graph** (debug bar, the 3-circles icon): find objects that should have been freed (leaks).

### RiseUp's built-in trace (🔎)
Key junctions print one line each, so you can watch a whole feature without stopping:
```
🔎 [sync]   AlarmSyncService.sync() → compare the database with iOS's alarms
🔎 [widget] WidgetBridge.update → 6 rings, 1 pictures, changed: false
🔎 [nav]    open(nap(minutes: 10)) ← a widget link
```
- In Xcode's console, type `🔎` (or `[ring]`, `[editor]`…) in the **filter box** at the bottom right.
- The areas: `editor`, `scheduler`, `ring`, `nav`, `sync`, `widget`, `wallpaper`, `audio`, `theme`.
- Code: `Alarm/Services/Logging/Trace.swift`. To add your own: `Trace.log(.ring, "my message")`.
- **Try it:** run the app and read the first lines. You'll see `sync()` twice at launch: once for the app
  becoming active (RootView) and once for the Alarm List loading. The second one finds nothing to do, which is
  exactly why sync is written to be "safe to call often".

### Debugging what iOS launches by itself (alarms, widgets)
When an alarm rings and you tap **Wake up**, *iOS* starts RiseUp, not Xcode, so your breakpoints won't stop.
Two fixes:
1. **Wait for the launch:** Product → Scheme → Edit Scheme (⌘<) → Run → Info → Launch: **"Wait for the executable
   to be launched"**. Press Run: Xcode waits. Let the alarm ring on the iPhone, tap Wake up: Xcode attaches and
   your breakpoints work. (Switch it back to "Automatically" afterwards.)
2. **Console.app, no Xcode at all:** plug in the iPhone → open Console.app on the Mac → select the iPhone →
   Action menu → "Include Debug Messages" → search `subsystem:com.riseup.trace` → let the alarm ring. You see
   the 🔎 trace live, even if the app was killed before.
- **Widgets:** they run in a separate program (`RiseUpWidgets`). Debug → **Attach to Process** →
  `RiseUpWidgets` while the widget is on the home screen, then set breakpoints in
  `NextAlarmWidget.swift` → `NextAlarmProvider.getTimeline`.
- **Remember:** the Simulator can't ring real alarms. Lab 2 and Lab 3 need the iPhone.

---

## Part 3 · The trace labs
Each lab = a question a senior might ask → where to put breakpoints (in order) → what to look at → the answer.
Do them in order; each one teaches a new tool.

### Lab 1 · "What happens when I tap Save on an alarm?" (Simulator)
**Breakpoints:**
1. `AlarmEditorView.swift`: the line `Task { await viewModel.save() }` (search `viewModel.save`)
2. `AlarmEditorViewModel.swift` → `save()`: the first line
3. `AlarmRepository.swift` → `insert(_:)` (new alarm) or `save()` (edited alarm)
4. `AlarmKitScheduler.swift` → `schedule(_:)`
5. `AppCoordinator.swift` → `popAlarms()`

**Do:** run, create an alarm, tap Save. At (2) press **F6** line by line: watch `isAllowed`, then `alarm`. At (4)
type `po alarm.hour` and `po isGuarded(alarm)`. Open ⌘7 and read the stack bottom-up.
**🔎 you'll see:** `[editor] save() → …` → `[scheduler] schedule(…) 7:0 → main alarm + backup chain` → `[editor] save() done`.
**The answer:** "The editor's ViewModel asks permission first, writes the alarm with SwiftData through
AlarmRepository, then AlarmKitScheduler gives iOS the main alarm plus its backup chain, and the coordinator pops
back to the list. WHY permission first: otherwise the database could say 'on' while iOS has nothing."

### Lab 2 · "How does RiseUp open on the Ringing screen when the alarm rings?" (iPhone)
**Setup:** scheme set to "Wait for the executable to be launched" (Part 2). Quick alarm in 1 minute, lock the phone.
**Breakpoints:**
1. `StartMissionIntent.swift` → `perform()`
2. `AlarmLaunchRouter.swift` → `requestRinging(for:)`
3. `RootView.swift` → the line `coordinator.presentRinging(alarmID: alarmID)` (search `consumePendingAlarmID`)
4. `ScreenFactory.swift` → `case .ringing(let alarmID):`
5. `RingingViewModel.swift` → `start()`

**Do:** when it rings tap **Wake up**. Stop at each. At (5) step over `scheduler.stopRinging`,
`audio.startAlarm`, `startKeepAlive()`.
**The answer:** "The alarm's button runs an App Intent inside our app. It hands the alarm ID to a small router
object; RootView watches the router and asks the coordinator to present the Ringing screen, which ScreenFactory
builds. RingingViewModel silences iOS's alarm and plays our own sound over the wallpaper."
**Bonus:** open the app by tapping the app icon while it's ringing instead. Find the OTHER path
(`RootView` → `alarmSync.ringingAlarmID()`). Two roads, same screen.

### Lab 3 · "If I press the volume button, why does it ring again? And why not while I'm on the screen?" (iPhone)
**Breakpoints (use logpoints: Log Message + auto-continue, so timing isn't disturbed):**
1. `AlarmKitScheduler.swift` → `scheduleBackupChain(for:after:)`: log `chain from @ringDate@`
2. `AlarmKitScheduler.swift` → `holdBackupChain(for:)`
3. `RingingViewModel.swift` → `appActivityChanged(isActive:)`
4. `RingingViewModel.swift` → `finish()`

**Do:** alarm rings → press volume down → wait 30 s (it rings again) → tap Wake up → stay 1 minute (watch the
hold every 30 s) → lock the phone (activity false) → it rings again → open → I'm up.
**The answer:** "Every alarm has backups at +30 s, 1, 1.5… 12 min. iOS lets buttons silence an alarm, so the next
backup rings. While the Ringing screen is in front, a keep-alive pushes the chain 75 s ahead every 30 s; if you
leave, nobody pushes, so it rings again. I'm up cancels the chain, after waiting for any running push to finish."
Read the WHYs in `AlarmKitScheduler` (`serially`, `chainVersions`); that's the advanced part.

### Lab 4 · "How does a mission finish the alarm?" (Simulator: Developer mode → sample data, or any alarm with Math)
**Breakpoints:**
1. `MathMissionViewModel.swift` → `submit()`, on the line `onComplete()`
2. `RingingViewModel.swift` → `missionFinished()`
3. `RingingViewModel.swift` → `finish()`

**Do:** at (1) press **F7 (Step Into)** on `onComplete()`. Where do you land? (A closure handed over by the View.)
That's how a mission tells the Ringing flow "done" without knowing about it: a **callback**.
**The answer:** "Each mission has its own small ViewModel. When it's solved it calls a closure it was given;
RingingViewModel moves to the next mission or calls finish(), which cancels the backups and saves the WakeRecord."

### Lab 5 · "How does a wallpaper play its sound?" (Simulator)
**Breakpoints:**
1. `WallpaperPickerView.swift` → `viewModel.openPlayer(wallpaper)`
2. `WallpaperPickerViewModel.swift` → `openPlayer(_:)` and `playCurrentSound()`
3. `AudioService.swift` → `previewLooping(_:)`
4. `WallpaperView.swift` → `LiveWallpaperView.draw(…)` *(stops 60× a second! use "Ignore 100 times", or a condition)*

**Do:** Settings → Wallpaper → tap a card. At (2) `po sound(for: wallpaper)`. At (4) look at `time` and `energy`,
continue, look again: time grew. That's the whole animation.
**The answer:** "The picker's ViewModel builds a playlist from the tab, flips `isShowingPlayer` (the View shows
a full-screen cover), and asks AudioService to loop that wallpaper's signature sound. The wallpaper is a function
of time and energy, redrawn every frame by a TimelineView."

### Lab 6 · "How does the widget know my next alarm?" (Simulator)
**Breakpoints:**
1. `RootView.swift` → `updateWidgets()`
2. `WidgetBridge.swift` → `plan(…)` and the line `let changed = snapshot.save()`
3. (attach to `RiseUpWidgets`) `NextAlarmWidget.swift` → `NextAlarmProvider.getTimeline`

**Do:** change an alarm's time, go Home. At (2) `po planned.count`, `po planned.first?.event`.
**The answer:** "When the app goes to the background, WidgetBridge writes the next week of rings and a still
picture of each wallpaper into the App Group (a folder both programs share) and asks WidgetKit to reload. The
widget's timeline has an entry for each ring, so it moves on by itself."

### Lab 7 · "How does changing the theme recolour everything?" (Simulator)
**Breakpoints:**
1. `SettingsViewModel.swift` → the `palette` setter
2. `AppSettings.swift` → `palette`'s `didSet`
3. `Theme.swift` → `Color.accent(_:)`, inside the closure *(stops a lot: add the condition `traits.userInterfaceStyle == .light`)*

**Do:** pick Ocean. Then try Light: (3) now stops with `.light`, and `b * 0.84` makes the colour deeper.
**The answer:** "Every colour is a token in Theme. The palette choice is saved and set on `Theme.palette`;
RiseUpApp changes the root view's `.id`, so SwiftUI rebuilds every screen and reads the new colours. Light/dark
needs no code at all: each colour is a dynamic colour that iOS resolves while drawing."

### Lab 8 · "What happens when the app starts?" (Simulator)
**Breakpoints:**
1. `RiseUpApp.swift` → `@State private var dependencies = AppDependencies.live()`
2. `AppDependencies.swift` → `live()`, then `openDatabase()`
3. `RootView.swift` → the `.onChange(of: scenePhase, initial: true)` block
4. `AlarmSyncService.swift` → `sync()`

**Do:** Step Into `live()` and watch every service being created once (Dependency Injection). In (4), step through
the rules and read `system` (what iOS really has).
**The answer:** "RiseUpApp builds one AppDependencies toolbox (database, scheduler, audio, settings…) and one
coordinator, injects them into RootView, and every time the app becomes active RootView syncs the database with
iOS's alarms and opens the Ringing screen if something is ringing."

---

## Part 4 · A routine that works
- **One lab a day**, 30–45 minutes. Run it, then close the laptop and write the arrow chain on paper.
- **Teach it back:** explain the lab out loud in 60 seconds using the template from Part 1. If you get stuck,
  that's the part to trace again.
- **Then break it on purpose** (on a scratch branch): change a `TRY:` value, comment out one line (e.g.
  `startKeepAlive()`), and predict what goes wrong *before* you run it. Predicting = understanding.
- **Keep a log:** add what you learned and your questions to `docs/LEARNING_LOG.md`.
- **Where to read next for each layer:** `docs/ARCHITECTURE.md` (the map), `docs/HOW_IT_WORKS.md` (traces + real
  bugs), `docs/screens/NN-*.md` (each feature's connection map), `docs/TALKING_POINTS.md` (plain answers).

## Common surprises (so they don't confuse you)
- **"My breakpoint never hits."** The code path isn't running (check with a 🔎 line), the breakpoint is disabled
  (⌘Y), or iOS launched the app (use "Wait for the executable").
- **Stepping over `await` jumps around.** The function paused and resumed later; other code ran in between.
  That's async. Put a breakpoint on the line AFTER the `await` and Continue.
- **Values show `<optimized out>`.** You're running a Release build. Debug builds (the default Run) show everything.
- **SwiftUI redraws a lot.** That's normal and cheap; only the ViewModel methods matter for "what happens".
- **The Simulator never rings.** AlarmKit alarms only ring on a real iPhone.
