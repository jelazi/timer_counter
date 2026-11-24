# Development Log

## 2026-11-24 (part 7) — pomodoro build installed on the owner's iPhone

### What was done

- iPhone "Lubomír Žižka’s iPhone" (`00008120-000619A10AE8201E`): app container (`Documents`,
  `Library`, 20 MB) backed up to `~/Documents/timer_counter_iphone_backup_2026-11-24_13-09-49/`,
  `flutter build ios --release` (29.6 MB, team BZF32VC6NQ), installed with `devicectl device install
  app` and launched. Other devices not touched. The version is still 1.0.12 (13) — no bump requested.
- Owner report "it says no timer is running, but it runs" — withdrawn by the owner ("opravdu neběží"):
  the warning was correct.

### Current state

- iPhone container read back after launch: `Library/Sounds` holds the 7 `pomodoro_*.wav`; the
  pomodoro settings edited on the Mac (work-end sound `arpeggio`, 12:02 UTC) and the live state (no
  session, the 4 ended ids, 12:10:25 UTC) arrived; sync ledger pending empty, `pomodoro_state`
  confirmed. Not checked on the phone's screen by me; notifications on the phone not tested.
- History: the Mac's `pomodoro_sessions` box is empty and so is the server (the iPhone downloaded
  none). The Hive log shows each of the 4 records put, then deleted (one deleted, restored, deleted
  again) — consistent with deleting them in the history with one undo. The 3 records from before 13:06
  are in the Mac container backup `~/Documents/timer_counter_container_backup_2026-11-24_13-06-04/`.

### Pending / next steps

- Owner to confirm the history was deleted on purpose; otherwise restore from the backup above.
- Notifications on the iPhone with the screen locked; Windows build on the Lenovo; release 1.0.13.

## 2026-11-24 (part 6) — feat: pomodoro timer, step 5 of 5 (history and Pomodoro screen)

### What was done

- Sync of finished sessions (`pomodoro_sessions`, imported in part 3): `pushPomodoroRecord` /
  `deletePomodoroRecord` (ledger-queued like other records), `_localRecordMap` case, `downloadAll`
  reconciles with `_replaceLocal` (adds the server's, uploads never-sent local ones, deletes locally
  only records the server had and lost — deleted on another device; mass deletes stay guarded),
  `uploadAll` only upserts (never deletes server sessions the device lacks), real-time subscription,
  `SyncCollection.pomodoroSessions`. Sessions superseded in a state merge are pushed too.
- `PomodoroRepository`: `getRecord`, `deleteRecord`, per-device `mobile_tab`.
- `core/services/pomodoro_stats.dart` `PomodoroStats` (pure): `summarize` (records ended in a range +
  the running session, without counting its record twice), `startOfDay`, `startOfWeek` (Monday,
  DST-safe via `addCalendarDays`), `byDay` grouping. `todayCompleted` now uses it.
- `PomodoroBloc`: files every record through `_fileRecord` (local + push), `history` in the state,
  `DeletePomodoroRecord` / `RestorePomodoroRecord` (undo re-files and re-pushes),
  `TogglePomodoroMobileTab`, reloads on `pomodoroSessions` sync events.
- `presentation/screens/pomodoro_screen.dart` `PomodoroScreen`: large ring countdown with controls
  (or a start button), today / this week cards (🍅, work time, sessions), history by day — time range,
  🍅, work / breaks / paused / waiting, end reason when not manual, start device, delete with an undo
  snackbar (`persist: false`). `standalone` = pushed route with an app bar.
- `pomodoro_card.dart`: the card opens `PomodoroScreen`; `startPomodoroFromUi`, `PomodoroControls`,
  `showPomodoroStartConflict`, `pomodoroStatusText` made public for the screen.
- `home_screen.dart`: navigation by a `_Section` list instead of fixed indexes — desktop sidebar item
  "Pomodoro" under Time Tracking (hidden with "Show pomodoro" off), mobile bottom-bar tab only with
  Settings → Pomodoro → "Pomodoro ve spodní liště" (mobile-only switch, default off); Cmd+1…9 and
  Cmd+, follow the current list; a hidden selected section falls back to Time Tracking.
- Translations cs + en (`pomodoro.history*`, `summary_*`, `record_*`, `end_reason_*`,
  `settings_mobile_tab*`; `settings_show_desc` now mentions the menu item).

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 199 passed (new
  `test/core/services/pomodoro_stats_test.dart` 4, 4 session-sync tests in
  `pocketbase_sync_service_test.dart` (+ `FakePocketBase.remove`), 2 bloc tests,
  `test/presentation/pomodoro_screen_test.dart` at 320 px incl. delete + undo).
- Release build installed into `/Applications/Timer Counter.app` (container backup
  `~/Documents/timer_counter_container_backup_2026-11-24_13-06-04/`). Window screenshot: sidebar shows
  "Pomodoro" under Sledování, the Time Tracking card shows the owner's paused session next to a
  running timer. The Pomodoro screen itself was not opened by me in the real app.
- All 5 steps of `docs/pomodoro-spec.md` are implemented. Older DEVLOG entries (2026-11-23 parts
  14–16) moved unchanged to `docs/devlog/2026-11.md`.

### Pending / next steps

- Owner test on the Mac: Pomodoro screen, history delete/undo, sounds and notifications (step 4).
- Build and install on the Lenovo (Windows; new native notification plugin) and the iPhone; check
  sync between devices (start on one, control on the other; history appears on both).
- Release: version bump (1.0.13), commit, tag — when the owner asks.
- Backups (`BackupService`) still do not include the pomodoro data.

## 2026-11-24 (part 5) — feat: pomodoro timer, step 4 of 5 (sounds and notifications)

### What was done

- Packages: `audioplayers` ^6.8.1, `flutter_local_notifications` ^22.3.3 (23.x needs AGP 9.1.1 and
  compileSdk 37; the project is on AGP 8.11.1 / compileSdk 36), `timezone` ^0.11.2.
- Sounds: `tool/generate_pomodoro_sounds.py` synthesises 7 sounds + a tick (bell, chime, ding_dong,
  marimba, triple_beep, arpeggio, soft_gong, tick; 16-bit mono WAV, 968 KB) into `assets/sounds/` and
  `android/app/src/main/res/raw/pomodoro_*.wav` (kept by `res/raw/keep.xml`); iOS copies them into
  `Library/Sounds` at start (custom notification sounds must live there or in the bundle).
- `PomodoroSettings` (synced): `warningMinutes` (1, 0 = off), a sound per `PomodoroSoundEvent`
  (work start / work end / break end / long break end / warning), `volume`, `ticking`;
  `PomodoroSounds` catalogue with `sanitize`. `PomodoroRepository`: per-device `sounds_on_device`,
  `notifications_on_device`, `exact_alarms_asked`.
- `core/services/pomodoro_alerts.dart`: `PomodoroAlerts` interface (replaces step 3's
  `PomodoroNotifier`, file removed) and `PomodoroAlertPlan.upcoming` (pure): warnings and phase ends
  ahead, following automatic transitions until a phase waits (max 8 phases).
- `core/services/pomodoro_alerts_service.dart` `DefaultPomodoroAlerts`:
  - desktop: sounds via `audioplayers` (tick on a low-latency player) + an immediate notification at a
    phase end; macOS through a new `com.timer_counter/pomodoro` channel, Windows through the plugin;
  - mobile: the plan is scheduled with `zonedSchedule` (UTC instants; Android exact when allowed,
    else inexact-while-idle; one channel per sound), so it rings with the app suspended; in the
    foreground the app then stays silent for phase ends/warnings to avoid a double sound;
  - rescheduling cancels only still-pending notifications (ids from the fire time), never delivered ones;
  - tapping a notification of a waiting phase (or its "Spustit" action) → `startPendingRequests`.
- macOS `AppDelegate.swift`: `com.timer_counter/pomodoro` channel (`show` silent notification with
  category `POMODORO` / `POMODORO_AWAITING`); a tap on an awaiting one calls back `onStartPending`
  and never raises the window; the two categories join the reminders' category set. The app
  delegate keeps owning the notification centre (it is set after the plugin registers), so the work
  reminders are unaffected.
- iOS `AppDelegate.swift`: notification centre delegate per the plugin's setup. Android: desugaring
  (`desugar_jdk_libs` 2.1.4), `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`,
  the plugin's three receivers.
- `PomodoroBloc`: initialises the alerts on the first load; work-start sound on start / confirmed work
  / skip into work; phase-end alert only for transitions in the last 30 s; warning once per phase when
  the countdown crosses the threshold (not when opened later in the phase); ticking during running
  work; reschedules when the session, settings, device switch or permission changed; asks for the
  notification permission on a start while not granted. New events: `TogglePomodoroDeviceSounds`,
  `TogglePomodoroDeviceNotifications`, `RequestPomodoroPermission`, `PreviewPomodoroSound`; state
  `soundsOnDevice`, `notificationsOnDevice`, `notificationsPermitted`.
- Settings → Pomodoro: second card — permission hint on mobile (Android "Povolit", iOS opens the
  system settings), the two device switches, warning minutes, sound per event with ▶ preview, volume
  and ticking (desktop). `pomodoro.*` texts cs + en. Spec §6 updated (own synthesised sounds).

### What was fixed

- Found by the new narrow-phone test: the sound picker + ▶ in a `ListTile` trailing broke the layout
  at 320 px; the picker now sits full-width under the event name.

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 188 passed (new
  `test/core/services/pomodoro_alert_plan_test.dart` 6, 7 bloc tests for sounds/notifications,
  `test/presentation/pomodoro_settings_section_test.dart`).
- Builds: `flutter build apk --release` ok (66.3 MB; `aapt2 dump resources` lists all 8
  `raw/pomodoro_*`), `flutter build ios --release --no-codesign` ok (27.4 MB), `flutter build macos
  --release` ok and installed into `/Applications` (container backup
  `~/Documents/timer_counter_container_backup_2026-11-24_12-57-16/`); the app starts.
- Not verified: hearing the sounds or seeing the notifications on any device (nothing clicked by me);
  Windows was not built (the Windows notification plugin is new native code there); the APK/iOS
  builds were not installed.

### Pending / next steps

- Try on the Mac: Settings → Pomodoro → ▶ previews, a short work phase (e.g. 1 min) for the end
  sound + notification, tap on "Klepni pro start práce".
- Build on the Lenovo (Windows) and install the new build on the iPhone to check scheduled
  notifications with the screen locked.
- Step 5: history — `pomodoro_sessions` sync, Pomodoro screen, today/week summary, delete with undo.

## 2026-11-24 (part 4) — feat: pomodoro timer, step 3 of 5 (menu bar, tray, no-timer warning)

### What was done

- `data/models/tray_display_settings.dart` `TrayDisplaySettings` (per device, `settings` box key
  `tray_display`): title parts pomodoro icon (on) / countdown (off) / round (off) / task name / timer
  time / today's total (on), and tray blocks pomodoro / "Pomodoro + timer ▸" / running timers /
  recent tasks / start timer (all on). `SettingsRepository.get/setTrayDisplay`, `SettingsBloc`
  `ChangeTrayDisplay`, `SettingsState.trayDisplay`.
- `app/tray_title.dart` `TrayTitle.build` (pure): `[pomodoro] · [task time] | [today]`; with the
  defaults and no pomodoro it gives exactly the old titles (`Úkol 00:42 | 03:15`, `0:00 | 03:15`, `0:00`);
  paused adds `⏸`, waiting `▶`; every part off → empty title (only the app icon).
- `SystemTrayService.updateMenu`: pomodoro block (`TrayPomodoroMenu`, `TrayMenuAction`) — idle:
  "🍅 Spustit pomodoro" + "🍅 Pomodoro + timer ▸" (recent tasks; starts the task timer unless it
  already runs, then the pomodoro); active: "🍅 Práce 18:42 (2/4)" + start work/break, pause/resume,
  skip, end session. Each block honours `TrayDisplaySettings`. Title, tooltip and menu are only
  pushed to the native tray when they changed (menu compared by a label signature).
- `app.dart` `_updateSystemTray` rewritten: refreshed by `TimerBloc`, `PomodoroBloc` and a change of
  `trayDisplay` (a running pomodoro without a running timer did not refresh the title before, since
  `TimerBloc`'s state does not change then).
- No-timer warning (`PomodoroSettings.warnWhenNoTimer`, synced, default on; switch in Settings →
  Pomodoro): the card's start shows a dialog "Neběží žádný timer" → Zrušit / Pokračovat bez timeru /
  Spustit timer (`StartTimerDialog`, then the pomodoro with `timerStarted`); a tray start
  (`StartPomodoro(notifyIfNoTimer: true)`) and every later work phase (confirmed, skipped into, or
  auto-started within the last 30 s — not one replayed after a long gap) send a system notification
  via `core/services/pomodoro_notifier.dart` `NativePomodoroNotifier` (the existing macOS
  `com.timer_counter/notifications` channel; silent on Windows/mobile until step 4).
- Settings: new desktop-only section "Horní lišta a systémové menu"
  (`presentation/widgets/tray_display_settings_section.dart`); `tray.*` and `pomodoro.*` translations
  cs + en (added to the existing `tray` section).

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 174 passed
  (new `test/app/tray_title_test.dart` 8, 5 bloc tests for the warning, the no-timer dialog in
  `pomodoro_card_test.dart`).
- Release build installed into `/Applications/Timer Counter.app` (container backup
  `~/Documents/timer_counter_container_backup_2026-11-24_12-34-30/`). Screenshot of the menu bar:
  `🍅 ▶ · 0:00 | 00:00` (the test session from step 1 waiting for work, no timer). The tray menu,
  the new Settings section and the notifications were not clicked through by me.
- Windows: the title/menu code is shared, but not built or run there; the no-timer notification is
  macOS-only for now.
- Older DEVLOG entries (2026-11-23 parts 9–13) moved unchanged to `docs/devlog/2026-11.md`.

### Pending / next steps

- Try the tray: start pomodoro, "Pomodoro + timer ▸", pause/skip/stop, the Settings switches.
- Step 4: sounds and notifications on all platforms (`audioplayers`, `flutter_local_notifications`),
  replacing `NativePomodoroNotifier`.
- Backups (`BackupService`) still do not include the pomodoro data.

## 2026-11-24 (part 3) — pomodoro collections imported on the live server

### What was done

- The owner backed up the server and imported `pocketbase/pb_schema_pomodoro_addon.json` in the
  PocketBase Admin UI with "Merge with the existing collections" ON (the file was opened in TextEdit
  and copied to the clipboard for them).
- Restarted `/Applications/Timer Counter.app` so the start-up sync and the real-time subscription
  see the new collection (the subscription is only set up at start).

### Current state

- Anonymous `GET /api/collections/<name>/records` on `http://timer.91.98.132.127.sslip.io`: all 15
  app collections answer 200 (so the import deleted none) and return 0 items without auth (owner-only
  rules in place for `pomodoro_state` and `pomodoro_sessions` too).
- This Mac's sync ledger (`settings.hive`) after the restart: `pomodoro_state/current` confirmed,
  pending empty — the session left from trying step 1 (legacy `session` key, started 12:09) was
  uploaded by the start-up `downloadAll`. The server record itself was not read (needs auth).

### Pending / next steps

- Two-device check: start on one device, pause / skip / stop on the other; edit the settings on one.
- Step 3: menu bar title and tray blocks, the no-timer warning (`docs/pomodoro-spec.md` §4, §7).

## 2026-11-24 (part 2) — feat: pomodoro timer, step 2 of 5 (PocketBase sync)

### What was done

- `PomodoroLiveState` (`data/models/pomodoro_session.dart`): what all devices share — the session or
  none, the ids of ended sessions (newest 20) and `updatedAt`. New end reason `replaced`.
- `core/services/pomodoro_state_merge.dart` `PomodoroStateMerge.merge` (pure, order-independent):
  the side that ended a session beats a device still running it, even with an older timestamp; an
  empty side never ends a session it does not list as ended; two different running sessions → the
  later start wins and the other is returned as `SupersededPomodoro` (ends when the winner started);
  otherwise the newer `updatedAt` (then `seq`, then the JSON) wins; ended ids are always united.
- `PomodoroRepository` stores the live state under `live_state` (reads the step-1 `session` key once
  and drops it on the next write); `hasRecord`, `clearAccountData` (keeps the per-device switch).
- `PocketBaseSyncService` (optional `pomodoroRepo`):
  - `pushPomodoroState` (ledger-queued) reads the server record, merges, writes back only when the
    merge differs from the server; `pullPomodoroState` (3 s timeout, no write); `_flushPending`
    sends a queued `pomodoro_state` through the same merge, never a blind upsert;
  - real-time `pomodoro_state` subscription (only when the server has the collection) merges every
    event and pushes back when the local side won; superseded sessions are filed into the history;
  - `downloadAll` merges the optional `pomodoro_state` download and queues a local state the server
    lacks; `uploadAll` sends settings and state via `_uploadPomodoroData`;
  - `pushPomodoroSettings`: item `pomodoro_settings` in `user_settings`, newer `updatedAt` wins,
    unedited defaults (`updatedAt == null`) are never uploaded. `_applyRemoteUserSettings` split
    per item; real-time events pass `complete: false` so an event for one item cannot queue the other;
  - `clearLocalData` (account switch) clears the pomodoro account data; new
    `SyncCollection.pomodoroState` / `pomodoroSettings`.
- `PomodoroBloc`: pushes after every state change, reloads on the two sync events; `StartPomodoro`
  pulls the server state first and, when a session already runs, emits `startConflict` instead of
  starting; `StartPomodoro(replaceExisting: true)` ends it into the history and starts a new one.
- `PomodoroCard`: dialog "Pomodoro už běží" (device, phase, time left) → "Převzít" / "Ukončit a
  začít nové". `pomodoro.conflict_*` translations cs + en.
- `pocketbase/pb_schema_pomodoro_addon.json` (`pomodoro_state`, `pomodoro_sessions`; `item_id`,
  `user`, `data` json; owner-only rules like `user_settings`) and the same two collections appended
  to `pocketbase/pb_schema.json`. `docs/POCKETBASE_SETUP.md` (en + cs) lists the optional
  collections and how to import an add-on with "Merge with the existing collections" ON.

### What was fixed

- Found by the new sync test: when the local and server state had the same session and timestamp,
  the JSON tie-break could pick the server side and drop a freshly ended id, so a superseded session
  could come back. Ended ids are now united in every merge branch.

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 161 passed
  (new: `test/core/services/pomodoro_state_merge_test.dart` 8, pomodoro group in
  `pocketbase_sync_service_test.dart` 8, 3 bloc tests, the conflict dialog in `pomodoro_card_test.dart`).
- Release build installed into `/Applications/Timer Counter.app` (container backup
  `~/Documents/timer_counter_container_backup_2026-11-24_12-19-11/`); the app process starts.
  Not clicked through by me.
- Live server (`http://timer.91.98.132.127.sslip.io`, anonymous GET): `pomodoro_state` and
  `pomodoro_sessions` → 404 (not imported yet), `user_settings` and `time_entries` → 200. Until the
  import the pomodoro state stays local and queued; everything else syncs as before.
- Older app versions (1.0.12) ignore `pomodoro_settings` in `user_settings`; a real-time event for it
  only makes them resend their supplier profile (newer wins, harmless).

### Pending / next steps

- Owner: back up the server and import `pocketbase/pb_schema_pomodoro_addon.json` in the PocketBase
  Admin UI with "Merge with the existing collections" ON; then check the two collections answer 200.
- Try two devices: start on one, pause/skip/stop on the other; settings edited on one appear on the other.
- Step 3: menu bar title and tray blocks, the no-timer warning (`docs/pomodoro-spec.md` §4, §7).
- Backups (`BackupService`) still do not include the pomodoro data.

## 2026-11-24 — feat: pomodoro timer, step 1 of 5 (core, local only)

### What was done

- Design interview with the owner (Q1–Q17) written down as `docs/pomodoro-spec.md`: the pomodoro is
  independent of project timers, breaks are phases of its cycle, one session per account, delivered
  in 5 steps (core → sync → menu bar → sounds/notifications → history).
- `data/models/pomodoro_settings.dart` `PomodoroSettings` (work / short / long break minutes, rounds
  before a long break, auto-start break (on) / work (off), `updatedAt`, lenient `fromJson` with clamping).
- `data/models/pomodoro_session.dart`: `PomodoroPhase`, `PomodoroStatus` (running / paused /
  awaitingStart), `PomodoroSession` (live state derived from timestamps: phase start, phase length
  copied at phase start, paused-in-phase, `seq`, totals of work / break / paused / waiting) and
  `PomodoroSessionRecord` (finished session for the history).
- `core/services/pomodoro_engine.dart` `PomodoroEngine` (pure): `start`, `advance` (replays phase ends
  up to now, long break after N completed pomodoros, ends a session idle for more than one cycle at
  the moment it went idle with reason `inactivity`), `pause`, `resume`, `skip` (skipped work keeps its
  time, is not a pomodoro), `startPendingPhase` (uses current settings), `stop` → record.
- `data/repositories/pomodoro_repository.dart` with two new Hive boxes `pomodoro` (settings, live
  session, local "show pomodoro" switch) and `pomodoro_sessions` (records), stored as JSON maps — no
  new Hive type ids.
- `presentation/blocs/pomodoro/` (`PomodoroBloc` / event / state): 1 s ticker only while a session
  exists, injectable clock, persists replayed transitions, files the record on stop or inactivity,
  `todayCompleted`. Registered in `main.dart` / `app.dart`.
- `presentation/widgets/pomodoro_card.dart` on Time Tracking (desktop and mobile, above the running
  timer card): idle → start + "today N 🍅"; active → phase, progress ring, countdown, round / paused /
  waiting, session total with work and break split, pause/resume, skip, stop, "Start work/break".
- `presentation/widgets/pomodoro_settings_section.dart` in Settings above Working Hours: show pomodoro
  (local), lengths, rounds, both auto-start switches, note that changes apply from the next phase.
- `PlatformUtils.deviceLabel`; `pomodoro.*` translations in cs + en.

### What was fixed

- The "Start work" button overflowed the card by 21 px on a 320 px phone (found by the new widget
  test); the button is now `Flexible` with an ellipsis.

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 142 passed
  (30 new: `test/core/services/pomodoro_engine_test.dart`, `test/presentation/blocs/pomodoro_bloc_test.dart`,
  `test/presentation/pomodoro_card_test.dart`).
- Release build installed into `/Applications/Timer Counter.app` (container backup
  `~/Documents/timer_counter_container_backup_2026-11-24_11-56-27/`); the app starts and the screenshot
  shows the idle pomodoro card on Time Tracking. Start / pause / skip / stop not clicked by me in the
  real app. `sqlite3.framework` is no longer in the bundle — `pubspec.lock` has no sqlite dependency.
- Nothing is synced yet; backups (`BackupService`) and "clear local data" do not include the pomodoro boxes.

### Pending / next steps

- Try the pomodoro in the Mac app (start, pause, skip, waiting for work, stop, settings).
- Step 2: `pocketbase/pb_schema_pomodoro_addon.json`, sync of `pomodoro_state` and `pomodoro_settings`
  (server import only after the owner's OK), "already running elsewhere" dialog.
- Decide in step 2 whether backups and "clear local data" cover the pomodoro boxes.

## 2026-11-23 (part 17) — release 1.0.12: commit, tag, iPhone install, Windows installer on the Lenovo

### What was done

- Committed parts 14–16 (earnings, undo snackbars, dialog contexts) as `27022fd` on `develop`, annotated
  tag `v1.0.12` ("Timer Counter 1.0.12+13"); pushed `develop` and the tags `v1.0.11`, `v1.0.12`.
- User's iPhone (`00008120-000619A10AE8201E`): app container backed up to
  `~/Documents/timer_counter_iphone_backup_2026-11-23_19-28-57/` (17 MB), new `flutter build ios --release`
  (26.1 MB) installed with `devicectl device install app` and launched. Eli's iPhone left alone on request.
- Lenovo (Windows, `lenovo-ideapad`, 192.168.1.26, user `jelazi`): reached over SSH from `m1-server`
  with `~/.ssh/id_ed25519_lenovo` and `HostKeyAlias=lenovo-ideapad` (its known_hosts entry is by name,
  the name does not resolve). Repo `C:\Users\jelazi\Workspace\timer_counter` fast-forwarded
  c21afb4 → 27022fd; `deploy_windows.bat` run with `NONINTERACTIVE_DEPLOY=1` (the app was not running).

### Current state

- Before the build: `flutter analyze --no-pub` no issues; `TZ=Europe/Prague flutter test --no-pub` 112 passed.
- iPhone: `devicectl device info apps` → Timer Counter 1.0.12 (13). Not checked on its screen by me.
- Lenovo: `Output\setup-Timer-Counter-1.0.12.exe` (14.9 MB) and a copy + ZIP in
  `deploy\output\windows\20261123_193409\`; `timer_counter.exe` ProductVersion 1.0.12+13. Not installed.
- Installer ZIP copied to the Raspberry Pi SSD share (`//jelazi@192.168.1.35/SSD`, mounted at
  `/Volumes/SSD`) as `setup-Timer-Counter-1.0.12.zip` next to 1.0.10/1.0.11; SHA-256 `4bb83bef…5f3a`
  matches the Lenovo copy, the ZIP holds `setup-Timer-Counter-1.0.12.exe` (14 944 329 B).
- On the Lenovo `flutter pub get` changed the generated plugin registrants (linux/macos/windows); left
  uncommitted there.

### Pending / next steps

- Run the installer on the Lenovo and check the app (sync, earnings).
- Decide whether the regenerated plugin registrants from the Lenovo belong in the repo.
