# Development Log

## 2026-11-24 (part 11) — fix: timer header icon in the tray menu as large as the pomodoro one

### What was done

- `SystemTrayService.updateMenu`: the timer header is `⏱️  Timer` (U+23F1 followed by U+FE0F) instead of a bare
  U+23F1.

### What was fixed

- Owner report: the timer icon in the dropdown menu was faint and smaller than 🍅. Without the emoji variation
  selector macOS draws U+23F1 as a small monochrome text glyph; with it, as a colour emoji the size of 🍅.

### Current state

- `flutter analyze`: no issues; `flutter test`: 200 passed.
- Rendered with `NSFont.menuFont` in a throwaway Swift script: `⏱️` matches 🍅 in size and colour, the old `⏱`
  is a small black glyph.
- Release build installed into `/Applications/Timer Counter.app` and launched (container backup
  `~/Documents/timer_counter_container_backup_2026-11-24_16-01-38/`).

### Pending / next steps

- Owner check of the tray menu with a running pomodoro.
- Allow notifications on the iPhone (Settings → Pomodoro → Allow), then Windows build and release 1.0.13.

## 2026-11-24 (part 10) — fix: one pomodoro icon in the tray menu, timer icon in the timer header

### What was done

- `app.dart` `_trayPomodoroMenu`: the status line of a running pomodoro is `Práce 18:42 (2/4)` without the 🍅 / ☕
  in front; only the section header „🍅 Pomodoro“ carries the icon.
- `SystemTrayService.updateMenu`: the timer section header is „⏱  Timer“ (text icon like the pomodoro header)
  instead of the app icon image; `_iconPath` removed.

### What was fixed

- Owner report: the pomodoro section showed the 🍅 twice (header and the phase line), the timer header had no icon.

### Current state

- `flutter analyze`: no issues; `flutter test`: 200 passed.
- Release build installed into `/Applications/Timer Counter.app` and launched (container backup
  `~/Documents/timer_counter_container_backup_2026-11-24_15-58-41/`). The menu itself not opened by me.

### Pending / next steps

- Owner check: tray menu with a running pomodoro; menu bar `🍅 time <icon> timer` in light and dark menu bar.
- Allow notifications on the iPhone (Settings → Pomodoro → Allow), then Windows build and release 1.0.13.

## 2026-11-24 (part 9) — feat: menu bar order pomodoro → app icon → timer, tray menu sections in one language

### What was done

- `TrayTitle.parts` (lib/app/tray_title.dart) returns the pomodoro part and the timer part (task, elapsed,
  `| today`) apart; `TrayTitle.build` keeps the old joined text for the fallback.
- macOS (`macos/Runner/AppDelegate.swift`): channel `com.timer_counter/tray`, `setTitle {leading, trailing}`.
  The status button of the system_tray plugin is found in the status bar window; with a pomodoro the title becomes
  `🍅 18:42 <app icon> Úkol 00:42 | 03:15` (attributed title, icon as a text attachment, menu bar font,
  `labelColor`); without a pomodoro the icon goes back to the left of the plain title.
  `SystemTrayService.updateTitle(title, pomodoroPart:, timerPart:)` uses it on macOS and falls back to the plugin's
  `setTitle(title)` when the button is not found.
- Tray menu (`SystemTrayService.updateMenu`): section header „🍅 Pomodoro“ above the pomodoro items, header „Timer“
  with the app icon above the running timers, „Zastavit všechny timery“, recent tasks and „Spustit časovač:“ +
  projects, one separator after each section. Pomodoro items start with ▶ instead of a second 🍅.
- Every menu text is translated: `TrayMenuLabels` from `app.dart` (`tray.show`, `pomodoro.title`, new `tray.timer`,
  new `tray.stop_all`, `tray.start_timer`, `tray.quit`); before, „Show Timer Counter“, „Stop All Timers“,
  „--- Start Timer ---“ and „Quit“ were English in the Czech app. Settings label `tray.menu_running_timers` (cs)
  no longer says „Stop all“.
- Test: `TrayTitle.parts` for pomodoro + timer, no pomodoro, pomodoro icon + today total only.

### What was fixed

- Owner report: the menu mixed English and Czech; the pomodoro and the timer were not separated in the menu bar
  title and the tray menu.

### Current state

- `flutter analyze`: no issues; `flutter test`: 200 passed.
- Release build installed into `/Applications/Timer Counter.app` and launched (container backup
  `~/Documents/timer_counter_container_backup_2026-11-24_15-49-07/`). Not checked visually: the status item is
  hidden in the menu bar overflow on this screen and no pomodoro was started by me.
- Older entries (2026-11-24 parts 1–2) moved to `docs/devlog/2026-11.md`.

### Pending / next steps

- Owner check: start a pomodoro on the Mac — menu bar `🍅 time <icon> timer`, text colour in light and dark menu
  bar; open the tray menu (sections, Czech texts).
- Allow notifications on the iPhone (Settings → Pomodoro → Allow), then Windows build and release 1.0.13.

## 2026-11-24 (part 8) — fix: notifications could not be allowed on iOS

### What was fixed

- iPhone: the "Notifications are off" hint in Settings → Pomodoro only opened `app-settings:`, but iOS
  lists Notifications under the app only after the app has asked once. The pomodoro had never been
  started on the phone (it ran from the Mac), so permission was still not determined, no system
  dialog ever appeared and the system settings had nothing to switch on.

### What was done

- `ios/Runner/AppDelegate.swift`: channel `com.timer_counter/pomodoro` (registrar
  `PomodoroPermission`) with `authorizationStatus` (`notDetermined` / `denied` / `authorized`) and
  `openNotificationSettings` (`openNotificationSettingsURLString` on iOS 16+, else app settings).
- `PomodoroAlerts.requestPermission({fromUser})`; `DefaultPomodoroAlerts` on iOS asks the system
  (dialog) unless permission was denied before, and only then — and only for `fromUser` — opens the
  notification settings. `_macChannel` renamed `_channel`, as iOS uses it too.
- `PomodoroBloc._onRequestPermission` passes `fromUser: true`; the hint's button now always sends
  `RequestPomodoroPermission` with the label "Allow"; key `pomodoro.permission_open_settings` removed
  (cs/en); `url_launcher` / `dart:io` imports dropped from `pomodoro_settings_section.dart`.
- `_AppWithThemeState.didChangeAppLifecycleState` (`lib/app/app.dart`): on resume adds `LoadPomodoro`, so the hint goes away
  after returning from the system settings.

### Current state

- `flutter analyze`: no issues; `flutter test`: 199 passed.
- iPhone: container backed up to `~/Documents/timer_counter_iphone_backup_2026-11-24_14-19-20/`,
  release build installed and launched. Mac: container backed up to
  `~/Documents/timer_counter_container_backup_2026-11-24_14-20-33/`, release installed into
  `/Applications`. The dialog on the phone not yet confirmed by the owner.

### Pending / next steps

- Owner: Settings → Pomodoro → "Allow" on the iPhone, then check a phase-end notification with the
  phone locked.
- Windows build on the Lenovo, then release 1.0.13.

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

