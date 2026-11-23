# Development Log

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
- On the Lenovo `flutter pub get` changed the generated plugin registrants (linux/macos/windows); left
  uncommitted there.

### Pending / next steps

- Run the installer on the Lenovo and check the app (sync, earnings).
- Decide whether the regenerated plugin registrants from the Lenovo belong in the repo.

## 2026-11-23 (part 16) — fix: confirm dialogs closed the screen instead of themselves (blank pane)

### What was fixed

- Deleting a monthly target (and a project) left a blank pane: the dialogs were built with
  `builder: (_)` but popped `Navigator.pop(context)` with the screen's context. Since the desktop
  shell puts screens in a nested navigator while dialogs open on the root one, that popped the
  screen's route, not the dialog. 12 pops in 6 dialogs (settings ×4, project delete, entry delete)
  now use the builder's `dialogContext`.
- New `test/presentation/dialog_context_test.dart` scans `lib/` and fails when a dialog builder pops
  the outer `context`; it fails on the old `projects_screen.dart` (line 240) and passes now.

### Current state

- `flutter analyze --no-pub`: no issues; `flutter test`: 112 passed. Installed on the Mac.

### Pending / next steps

- Lenovo installer: ask whether it is Windows or Android (APK 1.0.12 is built). Eli's iPhone install.

## 2026-11-23 (part 15) — fix: undo snackbars stayed on screen

### What was fixed

- After deleting a project the "Projekt smazán" snackbar with "Zpět" never went away. Since the
  current Flutter, `SnackBar.persist` defaults to `true` whenever an `action` is set
  (`persist ?? action != null` in `snack_bar.dart`), so `duration` is ignored until the user closes it.
- `persist: false` added to every snackbar with an action (6): project delete (`projects_screen`),
  task delete (`project_detail_screen`), entry delete (`time_entries_overview_screen`), invoice delete
  (`standalone_invoices_screen`), the undo in `settings_screen`, and the sync-guard warning in
  `app.dart` (10 s) — they disappear after their duration again.

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 111 passed.
- Installed on the Mac (backup `~/Documents/timer_counter_container_backup_2026-11-23_19-18-08/`);
  not clicked through by me.

## 2026-11-23 (part 14) — feat: earned amount next to tracked time

### What was done

- User request: every card that sums up time should also show the money earned.
- `core/services/earnings.dart` `Earnings`: `ofEntries` (billable entries × the project's hourly rate,
  the rule `StatisticsBloc` uses), `ofRunning` (running timers count at their project's rate — they
  are saved as billable entries when stopped), `perProject`, `format` (whole units, locale grouping).
- Time Tracking — "Celkem dnes" card: new column "Vyděláno dnes" (today's entries + running timers,
  updates every tick) with "Tento měsíc: …" below; on phones it is a third row.
- Time Entries: month card "Vyděláno …" next to the month total; each day header shows the day's
  amount (today incl. running timers); each monthly target card shows the amount of its projects
  for the month. `_EarnedLabel` widget, strings `earnings.earned/today/this_month` (cs/en).
- `test/core/services/earnings_test.dart`: 5 tests (rate, non-billable / no rate / unknown project,
  running timer, per project, Czech formatting).

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 111 passed.
- Preview on a copy of the real data: today 890 CZK, November 32 352 CZK (Artemis target 32 352,
  testovací cíl 0), Friday 20. 11. 2 814 CZK. The statistics' revenue uses the same rule; the
  project cards' "K fakturaci" round per project (3 382 + 28 969 = 32 351).
- Installed on the Mac (backup `~/Documents/timer_counter_container_backup_2026-11-23_19-14-25/`).
  Not installed on the iPhone.

## 2026-11-23 (part 13) — Clients on mobile, Android INTERNET permission, installer versions, tag v1.0.11

### What was done

- A3 — Clients on mobile: `home_screen.dart` mobile tabs are now Tracking, Entries, Projects,
  **Clients**, Statistics, Settings. `clients_screen.dart` has a phone layout (< 600 pt): title with
  an add button, search and the archived filter below; the desktop pane toolbar is unchanged.
- B4 — `android/app/src/main/AndroidManifest.xml`: `android.permission.INTERNET` (it was only in the
  debug/profile manifests, so a release APK could not sync).
- B5 — `windows/installer/timer_counter_setup.iss`: `AppVersion` takes `/DAppVersion=…` and defaults
  to 1.0.12 (was a hard-coded 1.0.10); `inno_setup.iss` default and usage comment 1.0.10 → 1.0.12.
  `deploy_windows.bat` already passes the pubspec version to `inno_setup.iss`.
- B6 — annotated tag `v1.0.11` on `c21afb4` (the commit that set 1.0.11+12 and was installed on the
  devices). Not pushed. 1.0.12 is not tagged: its changes are not committed yet.
- New `test/presentation/clients_screen_test.dart`: Clients screen at 390×844 (mobile header, no
  overflow, client and linked project shown) and after resizing to 1100×800 (pane toolbar). The
  shared-preferences channel is mocked for EasyLocalization.
- A2 — installs: the user's iPhone got the new iOS build (backup first:
  `~/Documents/timer_counter_iphone_backup_2026-11-23_19-01-58/`); launch refused because the phone
  was locked. Eli's iPhone ("Elinka") went from available to unavailable before the install, so it
  is still on its old build. macOS installed (backup `…container_backup_2026-11-23_19-03-13/`).

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 106 passed.
- `flutter build apk --release`: 63.3 MB, `aapt2 dump badging`: versionName 1.0.12, versionCode 13,
  `uses-permission: android.permission.INTERNET`. Not installed on an Android device.
- iPhone: `devicectl device info apps` → Timer Counter 1.0.12 (13). macOS 1.0.12 running.

### Pending / next steps

- Eli's iPhone: unlock it / bring it on the same network, then back up its container and install.
- Tag v1.0.12 after the user commits the current changes.

## 2026-11-23 (part 12) — release 1.0.12+13 installed on the user's iPhone and the Mac

### What was done

- `pubspec.yaml` version 1.0.11+12 → 1.0.12+13 (clients, synced invoices, desktop UI).
- iPhone "Lubomír Žižka’s iPhone" (iPhone 14 Pro, `00008120-000619A10AE8201E`): it ran 1.0.11 (12),
  signed in as lzizka@gmail.com to the live server, with an empty pending queue. App container
  (`Documents`, `Library`) backed up first with `xcrun devicectl device copy from` to
  `~/Documents/timer_counter_iphone_backup_2026-11-23_18-54-54/`.
- `flutter build ios --release` (26.1 MB, `cz.jelazi.timerCounter`, team BZF32VC6NQ), installed with
  `xcrun devicectl device install app`, launched with `devicectl device process launch`.
- macOS 1.0.12 built and installed into `/Applications` (backup
  `~/Documents/timer_counter_container_backup_2026-11-23_18-57-09/`).
- The second connected iPhone ("Elinka", iPhone 12) was not touched.

### Current state

- iPhone after launch (container copied back and read): pending empty; confirmed time_entries 726
  (was 697 — it caught up), clients 2, project_clients 2, invoices 8, user_settings 1;
  `clients.hive` holds Medutech s.r.o. and Mateřská škola.
- `devicectl device info apps`: Timer Counter 1.0.12 (13). macOS bundle 1.0.12 (13), running.
- Not checked on the phone's screen by me.

### Pending / next steps

- Eli's iPhone ("Elinka") when the user wants it: back up its container first, then install.
- Android release `INTERNET` permission, Windows installer version, git tags.

## 2026-11-23 (part 11) — phase 3 done: new collections on the live server, queued data uploaded

### What was done

- The user made a server backup and imported `pocketbase/pb_schema_clients_addon.json` in the
  PocketBase Admin UI. In 0.36.6 the import has "Merge with the existing collections" (no "Delete
  missing"); it had to be ON — OFF would replace the whole schema and delete the collections not in
  the file. The user was told so before importing.
- Verification (no superuser, read-only):
  - anonymous `GET /api/collections/<name>/records`: all 13 app collections answer 200 (a missing
    one answers 404), and `clients`, `invoices`, `time_entries` return 0 items without auth, so the
    per-user rules are in place;
  - sync ledger in this Mac's `settings.hive` before restart: pending clients 2, project_clients 2,
    invoices 8, user_settings 1; confirmed categories 2, projects 3, tasks 12, time_entries 726,
    monthly_targets 2, day_overrides 23;
  - after restarting `/Applications/Timer Counter.app` (startup `downloadAll` flushes the queue):
    pending empty; confirmed adds clients 2, project_clients 2, invoices 8, user_settings 1; the
    existing collections' confirmed counts are unchanged;
  - local Hive still holds both clients and the invoices.

### Current state

- Clients, project links, all 8 invoices and the supplier profile of lzizka's account are on the
  server. Existing collections were not part of the import.
- Not verified: eli.zizkova's server records (needs admin access); the import was additive, so they
  were not touched by it.

### Pending / next steps

- Install the new build on the other devices (iPhone, eli.zizkova's) when convenient; older builds
  keep working and ignore the new collections.

## 2026-11-23 (part 10) — phase 3: server identified; server-side steps blocked by permissions

### What was done

- With the user's SSH access (`ssh root@91.98.132.127` → ok): the Timer Counter PocketBase is
  container `cmmor94eo0006qiadvnesp5qu` (image `ghcr.io/coollabsio/pocketbase:latest`, PocketBase
  0.36.6, `pb_data` with `backups/`), the same one as in the October restore. Read-only checks only.
- Refused by the Claude Code permission classifier, not retried: creating the temporary superuser
  (`pocketbase superuser upsert` in the container + auth via the API) and downloading the
  PocketBase 0.36.6 binary for a local dry run (`gh release download`). Nothing was changed on the server.
- `pocketbase/pb_schema_clients_addon.json`: only the 4 new collections (`clients`,
  `project_clients`, `invoices`, `user_settings`), so an import cannot touch the existing
  collections. Checked against the October server copy: `users` has id `_pb_users_auth_` (the
  relation target), and no collection id or name collides.

### Current state

- Server unchanged. Clients, links and 8 invoices still queued on this Mac.
- October copy for reference: lzizka 3 projects / 697 entries, eli.zizkova 2 projects / 215 entries.

### Pending / next steps

- The user decides: (a) do the backup + add-on import in the PocketBase Admin UI ("Delete missing"
  off), or (b) allow the superuser/API/binary steps for Claude Code. Then compare counts before/after.

## 2026-11-23 (part 9) — feat(projects): edit a project from its detail screen; phase 3 blocked on server access

### What was done

- `project_detail_screen.dart`: "Upravit projekt" button next to "Přidat úkol" in the toolbar; it opens
  `ProjectFormDialog`, saves through `ProjectBloc` (`UpdateProject`) and keeps the screen in sync via a
  local `_project` state. The old `toolbarHeight: kToolbarHeight + 28` (traffic-light offset from before
  the sidebar shell) removed, the theme's 52 pt toolbar applies.
- Phase 3 preparation: the live server is `http://timer.91.98.132.127.sslip.io/` (from the app
  settings). The October dump (`pb_dump_2026-10-23/raw/data.db`) has the 10 app collections and
  PocketBase ≥ 0.23 system tables; no local `pocketbase` binary on this Mac.
- An SSH check to `root@91.98.132.127` was refused by the Claude Code permission classifier. The user
  was given the rule to add (`Bash(ssh root@91.98.132.127:*)`, `Bash(scp …)` in
  `.claude/settings.local.json`) and asked to confirm the SSH user and key login.

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 105 passed.
- Installed: backup `~/Documents/timer_counter_container_backup_2026-11-23_18-43-20/`, release
  58.3 MB, `codesign --verify` OK, running from `/Applications`.
- Edit button not clicked through by me.

### Pending / next steps

- With access: PocketBase backup downloaded to `~/Documents/`, per-account/per-collection counts;
  dry run on a local copy (old and new app, both accounts); then the additive import of `clients`,
  `project_clients`, `invoices`, `user_settings` on the live server with a temporary superuser,
  before/after comparison, superuser removed.
