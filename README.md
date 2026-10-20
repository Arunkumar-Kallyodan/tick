# DeskTasks

A small macOS app that keeps your tasks on screen as a character called **Tick**.

- Tick lives in a corner of your screen with a badge showing how many tasks are open.
- Click Tick to open your task list. Click again to close it.
- Hover over Tick and he tells you how many tasks are going on.
- Once a day, in the morning, Tick walks in from the edge of the screen, recaps what you finished, asks how your open tasks are going, and lets you add today's tasks.
- Late in the day he comes back for a short wrap-up.
- During the day he reminds you about tasks that are due or overdue.

Tasks have a priority (P1, P2, P3), a due date, a progress bar, a checkbox, a checklist and free-text notes. Everything is stored locally on your Mac.

## Requirements

- macOS 13 (Ventura) or later
- Xcode installed, or at least the Xcode Command Line Tools. This provides `swiftc`, which builds the app.

Check that it is available:

```bash
swiftc --version
```

If that fails, install the tools with:

```bash
xcode-select --install
```

There are no other dependencies and no Xcode project to open.

## Install and run

From this folder, run:

```bash
./build.sh
```

This script:

1. Stops any running copy of DeskTasks.
2. Compiles the source files into `~/Applications/DeskTasks.app`.
3. Signs the app locally (ad hoc, no Apple developer account needed).
4. Launches it.

If you get "permission denied", make the script executable first:

```bash
chmod +x build.sh
```

Run `./build.sh` again any time you change the code. It replaces the installed app and relaunches it.

### Start it later

Open `~/Applications/DeskTasks.app` from Finder or Spotlight. The app has no Dock icon. Look for Tick in a screen corner and the checklist icon in the menu bar.

## First launch

- Tick appears in the bottom-right corner of your main display.
- The app registers itself to **launch at login**. macOS may show a notice about this in *System Settings → General → Login Items*. You can turn it off from the menu bar (see below).
- If macOS says the app cannot be opened because it is from an unidentified developer, right-click the app in Finder, choose **Open**, then confirm. The app is built on your own Mac, so this should not normally appear.

## Using it

### Tick in the corner

| Action | What happens |
| --- | --- |
| Hover over Tick | He waves and says "You have N tasks going on. Click me to view them." If some are overdue or due today, a red chip says how many |
| Click Tick | Opens the task list next to him |
| Click Tick again, or the ✕ in the list | Closes the list |

The badge shows the number of open tasks. It turns **red** if any open task is overdue or due today, and **blue** otherwise.

Tick has moods:

- **Celebrating:** when you finish a task he cheers, confetti bursts out and a "Nice work!" bubble shows for a moment.
- **Alert:** when he reminds you about a due task (see below).
- **Relaxed:** when nothing is open, he hums happily. Hovering invites you to add a task.
- **Sleepy:** before 6 AM and after 10 PM he nods off.

### The task list

- **Add a task:** type in the top field, pick P1, P2 or P3, and press Return.
- **Complete a task:** click the circle on the left. This sets progress to 100%, and the task moves to the archive straight away.
- **Set progress:** drag across the progress bar. It snaps to 5% steps. Reaching 100% marks the task done.
- **Change priority:** click the P1/P2/P3 chip to cycle through the priorities.
- **Set a due date:** click the date chip, then pick a date, or use Today, Tomorrow or Clear.
- **Add notes:** click the **Notes** chip on a task and write what is done and what is pending. Click the chip again to hide the box. Tasks with notes show a blue chip and a two-line preview, so you can see their status at a glance. You can also edit notes during the morning review.
- **Edit the title:** click the task text and type.
- **Add a checklist:** click the checklist chip on a task, type a step and press Return. Tick steps off as you go. The progress bar follows (2 of 4 steps is 50%), and the chip shows a count such as `2/4`. The steps also appear on the review card during visits.
- **Delete a task:** click the × on the right of the task. A bar asks "Delete this task?". Press **Delete** to confirm or **Cancel** to keep it.
- **See the archive:** click the archive box icon in the header. It lists finished tasks, newest first, grouped by the day you finished them. Click the circle on an archived task to reopen it (it goes back to the main list), or the × to delete it for good (after a confirmation). Click the icon again to go back to your open tasks. The header always shows how many tasks are open and archived.
- **P3 tasks:** P1 and P2 are always shown. P3 is collapsed under its own header. Click the header to expand or collapse it.

Colours:

| Priority | Colour |
| --- | --- |
| P1 | Red |
| P2 | Amber |
| P3 | Blue |

Due-date chips: red is overdue, amber is today, yellow is within 2 days, grey is later, and green marks a completed task.

### The morning visit

Once per day, from 9 AM by default, Tick walks in from the left or right edge to the middle of the screen.

1. **Recap:** if you finished tasks on your last active day, Tick lists them first.
2. **Review:** Tick shows your open tasks one at a time. Tap **0%, 25%, 50%, 75%** or **Done** for each, tick checklist steps, update the notes box if needed, then press **Next**. Use **‹** to go back.
3. **Plan:** after the last task, type today's tasks, pick a priority for each, and press Return. Press **All set** (or **Nothing new**) when you are done.
4. Tick cheers and walks back off the screen.

Press **Later** on the first screen to send Tick away. He returns after 30 minutes.

If your Mac was asleep, or the app was not running at the set hour, Tick makes the visit the next time the app is running before 6 PM. If you finish the visit, he will not come again until the next day.

To trigger a visit immediately for testing, use **Morning Visit Now** in the menu bar.

### The evening wrap-up

Once per day, from 5 PM by default, Tick comes back. You can pick any hour from noon to 10 PM in the settings. If the Mac was asleep at that hour, the wrap-up still happens when it wakes, up to 11 PM.

1. He goes through your open tasks one at a time, like in the morning, so you can update progress.
2. **Summary:** he shows how many tasks you finished today and how many are still open. A checkbox offers to **move due or overdue tasks to tomorrow**, which is on by default.
3. Press **Done for today**. Tick says goodnight and walks off.

If the wrap-up window has started and the morning visit was missed, the wrap-up replaces it. Use **Evening Wrap-up Now** in the menu bar to try it.

### Due-date reminders

Between 9 AM and 6 PM, once the morning visit is done, Tick checks every 2 hours. If a task is overdue or due today, he looks alarmed and a bubble names the most important one (and how many more need attention) for about 8 seconds. Click him to open the list. Reminders are skipped while the list is open or a visit is in progress. To preview one, press **Test** in the settings or choose **Test Reminder** in the menu bar.

### Settings

Click the gear icon in the task list header:

- **Opacity slider:** from 20% to 100%.
- **Tick lives in:** bottom right, bottom left, top right or top left.
- **Morning visit from:** the earliest hour for the visit, between 9 AM and 5 PM. The visit only happens before 6 PM.
- **Visit now:** starts the morning visit straight away.
- **Wrap-up from:** turn the wrap-up on or off and choose the hour (noon to 10 PM).
- **Wrap up now:** starts the wrap-up straight away.
- **Remind me about due and overdue tasks:** turns Tick's reminders on or off. Press **Test** to see a reminder right now.

### Menu bar icon

The checklist icon in the menu bar has:

- **Open Task List**
- **Morning Visit Now**
- **Evening Wrap-up Now**
- **Test Reminder:** shows the due-date reminder bubble right away, using a sample task if nothing is due
- **Launch at Login:** a toggle. A tick means it is on.
- **Quit DeskTasks**

## Where your data is stored

| What | Location |
| --- | --- |
| Tasks | `~/Library/Application Support/DeskTasks/tasks.json` |
| Settings and window state | macOS user defaults, domain `com.arun.desktasks` |

The tasks file is plain JSON. To back it up, copy that file. To start fresh, quit the app and delete it. Changes are saved a moment after you stop typing, and always when the app quits.

## Uninstall

```bash
pkill -x DeskTasks
rm -rf ~/Applications/DeskTasks.app
rm -rf ~/Library/Application\ Support/DeskTasks
defaults delete com.arun.desktasks
```

Also remove DeskTasks from *System Settings → General → Login Items* if it is still listed.

## Troubleshooting

**Nothing appears after `./build.sh`**
Check that the app is running with `pgrep -lx DeskTasks`. If it is not, run the binary directly to see any error messages:

```bash
~/Applications/DeskTasks.app/Contents/MacOS/DeskTasks
```

**The build fails with compiler errors**
Make sure Xcode or the Command Line Tools are installed and up to date (`swiftc --version`). The app needs macOS 13 or later.

**Tick is not visible**
Tick does not appear over full-screen apps. He shows on every desktop (Space) otherwise. If he is hidden, use **Open Task List** from the menu bar, or relaunch the app.

**Tick is on the wrong screen**
Tick uses your main display, the one with the menu bar. Move him to another corner from the gear settings.

**The morning visit did not happen**
- The morning visit only runs between the chosen hour and 6 PM, and only once per day.
- It does not run if you already finished today's visit. Use **Morning Visit Now** to trigger it manually.
- The app must be running. Check that **Launch at Login** is ticked in the menu bar.

**Changes to the code do not show up**
Re-run `./build.sh`. It stops the old copy and installs the new one.

## Project layout

| File | Purpose |
| --- | --- |
| `Model.swift` | Task model, settings, task storage, and the visit and reminder schedulers |
| `Views.swift` | All the screens: task list, Tick the character and his moods, speech bubbles, confetti, recap, review, plan and wrap-up screens |
| `main.swift` | App startup, the corner mascot and its message overlay, the list panel, the walk-in animation and the menu bar |
| `Snapshot.swift` | Renders the screens to PNG files for checking the design |
| `build.sh` | Builds, installs and launches the app |

### Previewing the design without running the app

The app can render its screens to image files. This does not need screen-recording permission and does not touch your real tasks:

```bash
swiftc -O Model.swift Views.swift Snapshot.swift main.swift -o /tmp/desktasks-snap
/tmp/desktasks-snap --snapshot /tmp/desktasks-out
open /tmp/desktasks-out
```

This writes the task list, task rows, the mascot and its bubbles, the character moods and each step of the visits.
