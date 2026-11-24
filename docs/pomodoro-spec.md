# Pomodoro timer — specification

Agreed with the owner on 2026-11-24 (design interview Q1–Q17). Delivered in 5 steps (see the end).

## 1. Relationship to project timers (Q1, Q2)

- The pomodoro is **fully independent** of project timers: it never starts, pauses or stops them.
  The data model keeps room for an optional link later, but it is not used now.
- Breaks are proper phases of the cycle with their own countdown. Project timers keep running
  during a pomodoro break.
- A session shows its total time plus the split into work / breaks / paused.

## 2. Cycle and phases (Q5, Q9, Q14)

- Phases: work → short break → work → … → after N **completed** pomodoros a long break; the cycle
  repeats until the session is stopped.
- Two settings: "Auto-start break" (default on) and "Auto-start work after a break" (default off).
  A phase that is not auto-started waits for confirmation; the waiting time counts as neither
  work nor break and is recorded as "waiting".
- Manual controls: pause / resume (freezes the countdown; paused time counts as neither work nor
  break and is recorded as "paused"), skip phase, stop session.
- A completed pomodoro = a work phase that ran to its end. A skipped or stopped work phase does not
  count as a pomodoro, but its elapsed time counts as work time. A skipped break only counts its
  elapsed time.

## 3. History (Q3, Q14)

- Live state in `pomodoro_state` (one record per account) and finished sessions in
  `pomodoro_sessions`.
- Session record: start, end, end reason (manual / inactivity), completed pomodoros, work time,
  break time, paused time, waiting time, whether a project timer was running at session start
  (yes/no only), start device.
- Sessions can be deleted (snackbar with undo); they cannot be edited.

## 4. "No project timer running" warning (Q4)

- At session start in the app window: dialog "Start timer" (opens `StartTimerDialog`, then starts
  the pomodoro) / "Continue without timer" / "Cancel".
- At the start of every later work phase: a system notification only.
- From the tray: the pomodoro starts immediately and a system notification is shown; the tray also
  has "Pomodoro + timer ▸" with the recent tasks.
- Settings switch "Warn when no timer is running" (default on).

## 5. Settings (Q8)

| Item | Default | Scope |
|---|---|---|
| Work length | 25 min | synced |
| Short break | 5 min | synced |
| Long break | 15 min | synced |
| Pomodoros before a long break | 4 | synced |
| Auto-start break | on | synced |
| Auto-start work after a break | off | synced |
| Warning before phase end | 1 min (0 = off) | synced |
| Warn when no timer is running | on | synced |
| Sounds for 6 events + volume + ticking | see §6 | synced |
| Sounds on this device | on | local |
| System notifications on this device | on | local |
| Show pomodoro (card, sidebar item) | on | local |
| Pomodoro tab in the mobile bottom bar | off | local |
| Menu bar title / tray menu parts | see §7 | local |

- Synced settings live in the existing `user_settings` collection as item `pomodoro_settings`.
- Changes made during a running session apply from the **next phase**; the running phase keeps
  the length it started with.

## 6. Sounds and notifications (Q6, Q7, Q16)

- Events: work start, work end (break begins), break end, long break end / cycle done, "X minutes
  left" warning, optional ticking during work (desktop only; default off).
- Each event: a choice from a bundled set (7 short sounds in `assets/sounds/`, synthesised by
  `tool/generate_pomodoro_sounds.py`, so there is no third-party licence) or "no sound"; one volume
  (desktop); a ▶ preview button.
- Desktop plays sounds with `audioplayers`. Mobile uses scheduled local notifications
  (`flutter_local_notifications`) that carry the sound, so it rings with the phone locked.
- System notifications at phase end; clicking one that waits for confirmation starts the next
  phase. The window is never brought to the front. Mobile notifications get a "Start work" action
  where the platform allows it.
- Notification permission is requested on the first pomodoro start; when refused, the pomodoro
  still works and Settings shows a hint with a link to the system settings.

## 7. Menu bar and tray (Q9, Q10)

- Title parts, each switchable (local per device): pomodoro icon 🍅/☕ (on), pomodoro countdown
  (off), round `2/4` (off), task name (on), timer elapsed (on), today's total (on). With every part
  off only the app icon is left.
- Tray menu blocks, each switchable: pomodoro controls, "Pomodoro + timer ▸", running timers +
  "Stop all", recent tasks ★, "Start timer ▸" (projects). All on by default — the existing parts
  behave as today.
- Pomodoro block: idle → "🍅 Start pomodoro"; running → "🍅 Work 18:42 (2/4)", pause/resume,
  skip phase, stop session.

## 8. In-app UI (Q11, Q12)

- A compact card on Time Tracking (desktop and mobile): idle → start button and "today N 🍅";
  running → phase, countdown, progress ring, round, controls, session total with the split.
- A Pomodoro screen with a large countdown and the session history (today / week summary).
- Desktop: sidebar item "Pomodoro" under Time Tracking. Mobile: opened by tapping the card; an
  optional bottom-bar tab (default off).
- "Show pomodoro" off hides the card and the sidebar item.

## 9. Sync across devices (Q13, Q15)

- One active session per account.
- State: phase, phase start, phase length (copied from the settings at phase start), round,
  phase sequence number `seq`, paused flag, accumulated work / break / paused / waiting time.
- Automatic transitions are computed by every device from the timestamps; the first device that
  sees a transition writes it, and a write with a `seq` already on the server is dropped.
- Manual actions: the last one wins; an action from an offline device on a session that has ended
  meanwhile is dropped.
- Starting while a session runs elsewhere: "Pomodoro is already running (Mac, work 12:40).
  Take over / End it and start a new one".
- When no app runs anywhere the phase is recomputed on the next start; when more than a whole
  cycle has passed the session ends automatically and is saved as "ended by inactivity".
- Server rollout: `pocketbase/pb_schema_pomodoro_addon.json` (rules `user = @request.auth.id`),
  imported after a DB dump, with no collection deleted, comparing record counts before and after.
  Done only with the owner's explicit OK.
- Without the collections on the server the pomodoro works locally only.
- `uploadAll`: `pomodoro_sessions` upsert only, never a bulk orphan delete; `pomodoro_state`
  newer `updatedAt` wins. Older app versions ignore the new collections.

## 10. Other

- Translations cs + en via `easy_localization`.
- The pomodoro does not affect earnings or project statistics.

## Delivery steps (Q17)

1. **Core** — pure `PomodoroEngine` (phase, round, remaining time, transitions from timestamps and
   settings) with unit tests; `PomodoroBloc` (state / event / bloc); Hive storage; Time Tracking
   card; Settings section with lengths and auto-start switches. Local only.
2. **Sync** — addon schema, `pomodoro_state` + `pomodoro_settings`, realtime, §9 rules, the
   "already running elsewhere" dialog.
3. **Menu bar** — title and menu blocks (§7), switchable parts, the no-timer warning (§4).
4. **Sounds and notifications** — `audioplayers`, `flutter_local_notifications`, bundled sounds,
   permission, scheduled notifications on mobile.
5. **History** — `pomodoro_sessions`, Pomodoro screen (sidebar, optional mobile tab), today /
   week summary, delete with undo.

Every step: `flutter analyze`, tests, a DEVLOG entry, release build installed into `/Applications`.
