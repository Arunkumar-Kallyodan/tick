# Tick

> A tiny character who lives in the corner of your Mac and nags you about your tasks. Politely. Mostly.

You already have a to-do list. It's in a notes app you opened once in March.

**Tick** is the fix: a small macOS app that puts your tasks on your screen as a character who *cannot be closed by accident, forgotten, or buried under 47 browser tabs*. He sits in a corner with a badge showing how many tasks are open, waves when you hover, throws confetti when you finish something, and falls asleep after 10 PM, like a person with a healthy routine, unlike you.

- **He lives in a corner.** The badge shows how many tasks are open. It turns red when something is overdue or due today, which is Tick's way of clearing his throat.
- **Click him** to open your task list. Click again to close it.
- **Hover over him** and he tells you how many tasks are going on. He is not judging. (He is a little bit judging.)
- **Every morning** he walks in from the edge of the screen, recaps what you finished, asks how your open tasks are going, and helps you plan today.
- **Every evening** he comes back for a short wrap-up and says goodnight.
- **During the day** he gets alarmed about tasks that are due or overdue.

Tasks have a priority (P1, P2, P3), a due date, a progress bar, a checkbox, a checklist and free-text notes. Everything is stored locally on your Mac. No account, no cloud, no "sign in to continue". Tick has never heard of the internet and is happier for it.

## What you need

- macOS 13 (Ventura) or later
- Xcode, or at least the Xcode Command Line Tools. That gives you `swiftc`, which builds the app.

Check that you have it:

```bash
swiftc --version
```

If that complains, install the tools:

```bash
xcode-select --install
```

That's the whole list. No other dependencies, no package manager, and no Xcode project to open and stare at while it "indexes".

## Get Tick onto your screen

From this folder:

```bash
./build.sh
```

The script:

1. Stops any running copy of Tick.
2. Compiles the source into `~/Applications/Tick.app`.
3. Signs the app locally (ad hoc, so no Apple developer account is needed).
4. Launches it.

If you get "permission denied", the script just needs to be told it's allowed to run:

```bash
chmod +x build.sh
```

Changed the code? Run `./build.sh` again. It swaps the old Tick for the new one while he isn't looking.

### Starting him later

Open `~/Applications/Tick.app` from Finder or Spotlight. He has no Dock icon (he's not that kind of app). Look for him in a screen corner and for the checklist icon in the menu bar.

## First launch

- Tick appears in the bottom-right corner of your main display.
- He registers himself to **launch at login**, because a task buddy who isn't there when you start work is just a sticker. macOS may show a notice in *System Settings → General → Login Items*. You can turn it off from the menu bar.
- If macOS says the app can't be opened because it's from an unidentified developer, right-click it in Finder, choose **Open**, then confirm. You built it on your own Mac, so this shouldn't happen, but macOS likes to be sure.

## How to live with Tick

### Tick in the corner

| You do this | Tick does this |
| --- | --- |
| Hover over him | Waves and says "You have N tasks going on. Click me to view them." If some are overdue or due today, a red chip says how many |
| Click him | Opens the task list next to him |
| Click him again, or hit the ✕ in the list | Closes the list |

The badge counts your open tasks. **Red** means something is overdue or due today. **Blue** means you're fine. For now.

Tick has moods:

- **Celebrating:** you finish a task, he cheers, confetti explodes, and a "Nice work!" bubble appears. Yes, finishing tasks is now a party.
- **Alert:** he reminds you about a due task. He looks worried. Take it personally.
- **Relaxed:** nothing is open, so he hums happily. Hovering invites you to add a task, because he gets bored.
- **Sleepy:** before 6 AM and after 10 PM he nods off. Take the hint.

**Bedtime police.** If it's between 10 PM and 6 AM and you're *still* typing or clicking, a sleepy Tick pipes up with "It's 11:34 PM. Bedtime!" He reminds you at most every 30 minutes, and gets firmer each time ("Still at it? I'm yawning." ... "Tired brains write buggy code. Sleep now, fix later."). He only speaks up when there's been keyboard or mouse activity in the last 5 minutes, so an idle Mac gets to sleep in peace. No permissions needed. Turn it off with the checkbox in the settings.

### The task list

- **Add a task:** type in the top field, pick P1, P2 or P3, press Return. Done. No forms, no wizard.
- **Complete a task:** click the circle on the left. If the task is already at 100%, it goes straight to the archive. If it isn't, Tick asks "Only 75% done. Finish it?" first, because he knows you. Press **Done** to complete it (progress jumps to 100%) or **Not yet** to keep it open. Very satisfying either way.
- **Set progress:** drag across the progress bar. It snaps to 5% steps. Hitting 100% marks the task done.
- **Change priority:** click the P1/P2/P3 chip (it has a small arrow) and pick from the dropdown. The current one is ticked. Everything is P1 when you're stressed. Resist.
- **Set a due date:** click the date chip, then pick a date, or use Today, Tomorrow or Clear.
- **Add notes:** click the **Notes** chip and write what's done and what's pending. Click it again to hide the box. Tasks with notes get a blue chip and a two-line preview, so future-you can see where past-you left off. You can also edit notes during the morning review.
- **Edit the title:** click the task text and type.
- **Add a checklist:** click the checklist chip, type a step, press Return. Tick steps off as you go. The progress bar follows (2 of 4 steps is 50%) and the chip shows a count like `2/4`. The steps also show up on the review card during visits.
- **Delete a task:** click the × on the right. A bar asks "Delete this task?". Press **Delete** to confirm or **Cancel** if your finger had other ideas.
- **See the archive:** click the archive box icon in the header. It lists finished tasks, newest first, grouped by the day you finished them. It's your personal hall of fame. Click the circle on an archived task to reopen it (it goes back to the main list), or the × to delete it for good (after a confirmation). Click the icon again to go back. The header always shows how many tasks are open and archived.
- **P3 tasks:** P1 and P2 are always shown. P3 hides under its own header like the "someday" pile it is. Click the header to expand or collapse it.

Colours:

| Priority | Colour |
| --- | --- |
| P1 | Red |
| P2 | Amber |
| P3 | Blue |

Due-date chips: red is overdue, amber is today, yellow is within 2 days, grey is later, and green is a completed task. Basically a traffic light for your guilt.

### The morning visit

Once a day, from 9 AM by default, Tick walks in from the left or right edge of the screen to the middle. He does not knock.

1. **Recap:** if you finished tasks on your last active day, he lists them first. Free praise.
2. **Review:** he shows your open tasks one at a time. Tap **0%, 25%, 50%, 75%** or **Done** for each, tick checklist steps, update the notes if needed, then press **Next**. **‹** takes you back.
3. **Plan:** after the last task, type today's tasks, pick a priority for each, and press Return. Press **All set** (or **Nothing new**) when you're done.
4. Tick cheers and walks back off the screen.

Not in the mood? Press **Later** on the first screen and he leaves. He comes back in 30 minutes. He is persistent, not pushy.

If your Mac was asleep, or the app wasn't running at the set hour, Tick makes the visit the next time the app is running before 6 PM. Once you finish the visit, he leaves you alone until the next day.

To trigger a visit right now, use **Morning Visit Now** in the menu bar.

### The evening wrap-up

Once a day, from 5 PM by default, Tick comes back. You can pick any hour from noon to 10 PM in the settings. If the Mac was asleep at that hour, the wrap-up still happens when it wakes, up to 11 PM.

1. He goes through your open tasks one at a time, like in the morning, so you can update progress.
2. **Summary:** he shows how many tasks you finished today and how many are still open. A checkbox offers to **move due or overdue tasks to tomorrow**, on by default. Procrastination, but organised.
3. Press **Done for today**. Tick says goodnight and walks off.

If the wrap-up window has started and you missed the morning visit, the wrap-up takes its place. Use **Evening Wrap-up Now** in the menu bar to try it.

### Due-date reminders

Between 9 AM and 6 PM, once the morning visit is done, Tick checks every 2 hours. If a task is overdue or due today, he looks alarmed and a bubble names the most important one (plus how many more need attention) for about 8 seconds. Click him to open the list.

He won't interrupt while the list is open or a visit is in progress. To preview a reminder, press **Test** in the settings or choose **Test Reminder** in the menu bar.

### Settings

Click the gear icon in the task list header:

- **Opacity slider:** from 20% to 100%. For when Tick is too present.
- **Tick lives in:** bottom right, bottom left, top right or top left. Pick a corner. He'll move in.
- **Morning visit from:** the earliest hour for the visit, between 9 AM and 5 PM. The visit only happens before 6 PM.
- **Visit now:** starts the morning visit straight away.
- **Wrap-up from:** turn the wrap-up on or off and choose the hour (noon to 10 PM).
- **Wrap up now:** starts the wrap-up straight away.
- **Remind me about due and overdue tasks:** turns Tick's reminders on or off. Press **Test** to see one right now.
- **Tell me to go to bed after 10 PM:** turns the bedtime reminders on or off. For people who think they don't need sleep.

### Menu bar icon

The checklist icon in the menu bar gives you:

- **Open Task List**
- **Copy Standup Summary** (⌘C in the menu): copies a Markdown status update to your clipboard. It lists what you finished since yesterday and everything still open, sorted by priority, with progress, checklist counts, due dates (overdue ones flagged) and your notes. Paste it into Slack, an email or a standup doc and look organised without trying.
- **Morning Visit Now**
- **Evening Wrap-up Now**
- **Test Reminder:** shows the due-date reminder bubble right away, using a sample task if nothing is due
- **Test Bedtime Reminder:** shows the bedtime bubble right away, at any hour
- **Launch at Login:** a toggle. A tick means it's on.
- **Quit Tick**

Quitting Tick is allowed. He'll just be quietly disappointed.

## Where your stuff lives

| What | Location |
| --- | --- |
| Tasks | `~/Library/Application Support/Tick/tasks.json` |
| Settings and window state | macOS user defaults, domain `com.arun.tick` |

The tasks file is plain JSON, so there's no lock-in and nothing to decode. To back it up, copy the file. To start fresh, quit the app and delete it. Changes are saved a moment after you stop typing, and always when the app quits.

Coming from the app's old name, **DeskTasks**? Tick copies your tasks and settings over the first time he starts. The old folder is left alone, so you can delete it when you're happy.

## Breaking up with Tick (uninstall)

```bash
pkill -x Tick
rm -rf ~/Applications/Tick.app
rm -rf ~/Library/Application\ Support/Tick
defaults delete com.arun.tick
```

Also remove Tick from *System Settings → General → Login Items* if he's still listed. He won't take it personally. (He will.)

## When things go wrong

**Nothing appears after `./build.sh`**
Check whether he's running with `pgrep -lx Tick`. If not, run the binary directly to see any error messages:

```bash
~/Applications/Tick.app/Contents/MacOS/Tick
```

**The build fails with compiler errors**
Make sure Xcode or the Command Line Tools are installed and up to date (`swiftc --version`). The app needs macOS 13 or later.

**Tick is nowhere to be seen**
He doesn't appear over full-screen apps. Otherwise he shows on every desktop (Space). If he's hiding, use **Open Task List** from the menu bar, or relaunch the app.

**Tick is on the wrong screen**
He uses your main display, the one with the menu bar. Move him to another corner from the gear settings.

**The morning visit didn't happen**
- It only runs between the chosen hour and 6 PM, and only once per day.
- It won't run if you already finished today's visit. Use **Morning Visit Now** to call him in manually.
- The app has to be running. Check that **Launch at Login** is ticked in the menu bar.

**Changes to the code don't show up**
Re-run `./build.sh`. It stops the old copy and installs the new one.

## What's inside

| File | Purpose |
| --- | --- |
| `Model.swift` | Task model, settings, task storage, the standup summary, and the visit, reminder and bedtime schedulers |
| `Views.swift` | All the screens: task list, Tick and his moods, speech bubbles, confetti, recap, review, plan and wrap-up screens |
| `main.swift` | App startup, the corner mascot and its message overlay, the list panel, the walk-in animation and the menu bar |
| `Snapshot.swift` | Renders the screens to PNG files so the design can be checked without a human clicking around |
| `build.sh` | Builds, installs and launches the app |

### Previewing the design without running the app

The app can render its screens to image files. This needs no screen-recording permission and never touches your real tasks:

```bash
swiftc -O Model.swift Views.swift Snapshot.swift main.swift -o /tmp/tick-snap
/tmp/tick-snap --snapshot /tmp/tick-out
open /tmp/tick-out
```

It writes the task list, task rows, the mascot and his bubbles, the character moods and each step of the visits.

---

Now go and finish something. Tick is watching.
