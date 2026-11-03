# Development Log

## 2026-11-03 — fix: step date ranges by calendar day across DST; testable sync service; release-check follow-ups

### What was done

- Release check for 1.0.11+12 (`tester-release-check`: runner, release-consistency, gaps) came out
  NO-GO: the c21afb4 sync fix had tests for `SyncLedger` only, none for the service. This session
  works through its follow-ups.
- `PocketBaseSyncService` takes an optional `@visibleForTesting httpClientFactory`, forwarded to
  `PocketBase(url, httpClientFactory:)` in the constructor and `updateServerUrl` (`_createClient`).
  Production code passes nothing and behaves as before.
- New `lib/core/utils/calendar_day.dart` → `addCalendarDays(date, days)` (midnight of the day
  `days` later, via `DateTime(y, m, d + days)`). Every day/week boundary that was computed as
  `start.add(Duration(days: n))` now uses it:
  - `TimeEntryRepository.getToday` / `getThisWeek`;
  - `StatisticsBloc._onChangeRange` (today / week / default);
  - `statistics_screen.dart`: `_getDateRange` (today with offset, week with offset), week label end,
    week picker end, custom range day/week, working-days loop, "today" hours per target, weekly chart
    day labels;
  - `time_entries_overview_screen.dart`: "today" hours per target, running seconds for a day, the
    overlap checks in the add and edit dialogs;
  - `time_tracking_screen.dart`: "today" hours in `_calculateMonthlyDailyNeeded`.
  Left alone: due dates (+14 days), date-picker `lastDate`, snapshot retention cutoff, token margin —
  none of them is a day boundary.
- `.github/workflows/ci.yml`: the test step runs with `TZ: Europe/Prague`, so the DST tests can fail
  in CI (it ran in UTC, where the old code passes them too).
- Tests (all new):
  - `test/core/utils/calendar_day_test.dart` — 7 tests: autumn/spring change, weeks containing a
    change, stepping back, time dropped, month/year rollover, walking October once per day.
  - `test/data/repositories/time_entry_repository_test.dart` — 4 tests: an entry at 23:30 on
    2026-10-25 belongs to that day and that week; 00:30 on 2026-03-30 is not counted in 2026-03-29.
  - `test/core/services/backup_service_test.dart` — 4 tests: v3 round trip of work schedule and
    context settings; v2 restore keeps local context settings; delete data+settings wipes them; a
    file without `backup_version` is refused before anything is cleared.
  - `test/core/services/pocketbase_sync_service_test.dart` (written by `tester-regression`) — 7 tests
    against an in-memory fake PocketBase REST API (`MockClient`) with real Hive repos: `downloadAll`
    deletes a confirmed record gone from the server, keeps and queues a never-uploaded one, does not
    overwrite an unsent local edit, uploads both once writes succeed; a rejected push stays queued in
    the persisted ledger, the next `downloadAll` sends it once in its latest state, a queued upsert for
    a locally deleted record is dropped.
- `DEVLOG.md` was 2815 lines with no archive: the 67 entries from 2026-09-11 and older were moved
  unchanged into `docs/devlog/2025-07.md` … `2026-09.md` (newest first per file). A script check
  confirmed all 72 entries are byte-identical to the original.

### What was fixed

- **Day and week ranges were an hour off across a DST change.** Adding `Duration(days: 1)` to a
  midnight gives 23:00 on the 25-hour autumn day and 01:00 the next day after the 23-hour spring
  day. So on 2026-10-25 entries after 23:00 were missing from "today", from that week, and from the
  target cards' "worked today"; after the spring change the first hour of the next day was counted
  in the previous one; and the weekly chart / week labels showed the wrong weekday after the change
  (Saturday 23:00 instead of Sunday). Same class as b19dab4, which fixed only the calculator.

### Design decisions

- The release check also reported that restoring a v2 backup wipes context settings. It does not:
  `restoreBackup` calls only `_clearAllData`, which leaves settings alone; `clearAllContextSettings`
  runs only from `deleteAllDataAndSettings` and sign-out with `clearLocal`. No code change, the
  behaviour is now locked by `backup_service_test.dart`.

### Current state

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 94 passed (72 before + 22 new), both with `TZ=Europe/Prague` and `TZ=UTC`.
- The DST tests were proven: with `addCalendarDays` temporarily reverted to `.add(Duration(days:))`,
  9 of the 11 calendar/repository tests fail under `TZ=Europe/Prague`; restored afterwards.
- The sync tests were proven by `tester-regression` in a throw-away worktree: 5 of 7 fail against the
  `c21afb4^` service; the other 2 (confirmed delete, dropping an op for a deleted record) pass pre-fix
  by design and were checked by mutation instead.
- Not run in the app: the screen changes are only covered through `addCalendarDays` and the
  repository, there are no widget tests.

### Pending / next steps

- Manual test plan written by `tester-plan`: `docs/test-plans/1.0.11-test-plan.md` (sections A–L,
  sync on a throw-away server first, live server only in section F). Not run yet.
- Found while writing the plan, verified, not fixed yet:
  - `android/app/src/main/AndroidManifest.xml` has no `android.permission.INTERNET` (only the
    debug/profile manifests do), so a release APK likely cannot sync at all;
  - `windows/installer/timer_counter_setup.iss` still hard-codes `AppVersion "1.0.10"`.
- Still untested in the sync service: token refresh / re-login / 30-min keep-alive (needs `fakeAsync`
  and a `signIn` path through the mock), real-time events ignored while a change is pending, the
  keyed collections (day overrides, context day overrides), `uploadAll` ledger bookkeeping, and the
  `context_settings` / `context_day_overrides` 404/403 handling.
- Live-server checks from the 2026-10-23 entries are still open (phone sign-in, ~697 entries).
- The 2026-10-23 (part 2) note "Commit the `ios/Podfile` change" is done (`4cf128f`).
- Repo has no release tags; tag 1.0.11 after merging develop → master.

## 2026-10-23 (part 2) — iPhone: two stale installs replaced by 1.0.11; Pods deployment target fix

### What was fixed

- **The user's iPhone ran two outdated, separate installs**, both signed in as `lzizka@gmail.com`:
  `cz.medutech.timerCounter` 1.0.8 (local data up to 2026-06-23, 196 entries behind the server) and
  `com.example.timerCounter` 1.0.6 (up to 2026-07-09, 164 behind). Their app containers were copied
  with `xcrun devicectl device copy from` and the Hive boxes read with the project's adapters: no entry
  existed only on the phone, and all shared entries matched the server.
  - 1.0.6 predates the startup catch-up and resume resync (added in 1.0.7, `7392df9`), so it only
    received real-time events while open.
  - 1.0.8 resyncs on resume but returns early once its 7-day token has expired; its settings box was
    last written on 2026-06-23, i.e. no successful sign-in since.
  - Both predate `SyncGuard`, so a manual "upload" from either would have deleted the newer server data.
- **`flutter build ios --release` failed under Xcode 27**: `IPHONEOS_DEPLOYMENT_TARGET` 13.0 on the
  remaining CocoaPods target (`printing`, the only plugin without Swift Package Manager support);
  Xcode 27 accepts 15.0–27.0.

### What was done

- `ios/Podfile` `post_install`: raise every pod target's `IPHONEOS_DEPLOYMENT_TARGET` below 15.0 to
  15.0 (matches `platform :ios, '15.0'` and the Runner target).
- The user deleted both old apps; 1.0.11+12 (`c21afb4`) was built and installed with
  `xcrun devicectl device install app` as `cz.jelazi.timerCounter`.

### Current state

- `flutter build ios --release`: built `build/ios/iphoneos/Runner.app` (27.7 MB), all 15 Pods
  deployment-target settings at 15.0.
- `devicectl device info apps` on the iPhone: only `Timer Counter cz.jelazi.timerCounter 1.0.11 (12)`.
- Not launched by me; the PocketBase account still has to be entered in Settings (the local
  `lib/config/pocketbase_config.json` holds placeholders, so nothing is bundled).

### Pending / next steps

- Enter URL/e-mail/password in Settings → PocketBase on the phone and check that ~697 entries arrive.
- Commit the `ios/Podfile` change.

## 2026-10-23 — fix(sync): stop deleting local entries the server never received; restore 75 lost entries

### What was fixed

- **Account `eli.zizkova@gmail.com` lost 75 time entries (96 h) in two batches**, found by diffing her
  device's daily snapshots (`snapshots/`, 47 files from 2026-07-29 to 2026-10-23) against the live
  server:
  - 33 entries dated 2026-08-05 – 2026-09-01 (53.9 h), gone between the 2026-09-07 and 2026-09-08
    snapshots;
  - 42 entries dated 2026-09-23 – 2026-10-14 (42.1 h), gone on 2026-10-15 after 11:14 UTC, when a new
    app build signed in.
  None of them ever reached the server. Between 2026-10-11 and 2026-10-15 her app ran and its
  snapshots grew daily, but the server log shows no request from her account at all.
- **Root cause, three parts in `PocketBaseSyncService`:**
  1. The app signs in only at startup (`main.dart`) and never refreshes the token. The server issues
     7-day tokens (`users.authToken.duration = 604800`), and a desktop app can sit in the tray longer.
  2. With an invalid token, every `push*` returned early on `if (!isSignedIn) return;`, and a failed
     `_upsertRecord` was only logged. Nothing recorded that the change still had to be sent.
  3. On the next sign-in, `downloadAll()` → `_replaceLocal()` deleted every local record missing from
     the server. `SyncGuard` only blocks 10+ deletions that are also over 30 % of the collection;
     42 of 239 (18 %) passed silently. The deletions went to her device's deletion journal as
     `syncReconcile`.

### What was done

- New `lib/core/services/sync_ledger.dart` — `SyncLedger`, persisted under the new settings key
  `pocketbase_sync_ledger` (`AppConstants.pocketBaseSyncLedger`, accessors in `SettingsRepository`):
  - `confirmed`: per collection, the ids the server is known to hold (set from each download,
    successful push and real-time event);
  - `pending`: per collection, local upserts/deletes not sent yet, with an in-memory version so an
    older in-flight push cannot clear a newer pending change;
  - `plan()`: a local record missing remotely is deleted only if it is confirmed and has no pending
    change; everything else is kept and queued for upload. An empty or malformed ledger therefore
    never deletes anything.
- `PocketBaseSyncService`:
  - All `push*`/`delete*` methods go through `_pushUpsert`/`_pushDelete`: queue first, then send, and
    clear the queue entry only on success. `_upsertRecord`/`_deleteRecord` now return `bool`.
  - `_flushPending()` sends every queued change, rebuilding upserts from the current local record
    (`_localRecordMap`). It runs at the start and end of `downloadAll()` and from the keep-alive.
  - `_replaceLocal()` and the new `_reconcileKeyed()` (day overrides, context day overrides) use
    `SyncLedger.plan()`; they do not overwrite records with unsent changes, and they queue local-only
    records for upload. Remote context settings skip contexts with a pending upsert.
  - Real-time events go through `_acceptRemoteChange()`, which updates `confirmed` and ignores events
    for records with unsent local changes.
  - `_replaceRemote()` (`uploadAll`) updates `confirmed` and clears the pending entries it uploaded.
  - Auth: `_ensureAuth()` refreshes a token with less than a day left (`authRefresh`), and signs in
    again with the credentials from the last `signIn()` (kept in memory only) once it has expired.
    `resync`, `uploadAll`, `downloadAll` and every push use it. A 30-minute `Timer.periodic`
    keep-alive refreshes the token and flushes the queue; after a re-login it runs `resync()`
    because the real-time subscriptions were authorized with the expired token.
  - Static `tokenExpiry(token)` reads the JWT `exp` claim (`@visibleForTesting`).
  - `clearLocalData()` (account switch) also clears the ledger.
- New `test/core/services/sync_ledger_test.dart`: 11 tests (reconcile plan incl. the 197 synced +
  42 offline case, pending versioning, encode/decode, `tokenExpiry`).

### Data restore (production server, done with the user's OK)

- Full PocketBase backup first via `POST /api/backups`: `timer_counter_pre_eli_restore_2026-10-23.zip`
  (1.78 MB), kept on the server and copied to `~/Documents/timer_counter_pb_backup_2026-10-23/`.
- Created a temporary superuser (`/app/pocketbase superuser upsert … --dir=/app/pb_data` in container
  `cmmor94eo0006qiadvnesp5qu`), inserted the 75 entries through the records API with their original
  `item_id` and fields, user `4f3ehkb4t4mod2q`, after checking each `item_id` was absent. One request
  timed out after 64 inserts; the idempotent rerun added the remaining 11. Then the superuser was
  deleted again (its token now gets HTTP 401).
- Working files (not in git, listed in `.git/info/exclude`): `pb_dump_2026-10-23/` with the raw server
  DB, her snapshots (`eli_device/snapshots/`) and the recovered list (`eli_lost_entries.csv/.json`).
- Left out on purpose: a few entries that disappeared one by one outside the two batches and look
  like her own edits (e.g. a 46.5 h runaway timer from 2026-09-18).

### Current state

- `flutter analyze`: No issues found.
- `flutter test`: **72 tests passed** (61 + 11 new).
- Server after the restore: 290 entries for Eli (215 + 75), 290 unique `item_id`s, all 75 present with
  matching start time, duration and project. Per month: Jun 89.3 h, Jul 87.3 h, Aug 79.5 h,
  Sep 48.5 h, Oct 56.6 h.
- The fix is **not yet run against the live server in the app**: token refresh, re-login after
  expiry, the keep-alive and the offline queue are covered by unit tests of `SyncLedger` only.

### Pending / next steps

- Install the new build on Eli's device soon: the build she runs has the old sync, and entries
  recorded there while its token is expired will be deleted again on the next restart.
- Manual test: stop the server (or let a token expire), record entries, bring it back, and confirm
  they upload and survive a restart.
- First run of the new build on any device: the ledger starts empty, so every local record the server
  does not have is uploaded rather than deleted. A record deleted on another device while this one was
  off would come back once.
- Her 2026-10-19 data has a duplicate entry (two records starting 10:04:28, ending 10:38:26 and
  10:38:32) — not touched.
- Commit not made yet.

## 2026-10-02 (part 3) — macOS release build showed only a black window (stale native assets)

### What was fixed

- The 1.0.10 Release build from `develop` (`b19dab4`) opened a black window and never got further.
  Run from the terminal, it reported `Unhandled Exception: ... Couldn't resolve native function
  'DOBJC_initializeApi' in 'package:objective_c/objective_c.dylib' : No available native assets`,
  raised from `path_provider_foundation` inside `HiveX.initFlutter` (`main.dart:55`). No data was
  opened.
- The bundle was missing `objective_c.framework` and `sqlite3.framework`, and its
  `NativeAssetsManifest.json` was empty. `build/native_assets/macos/` only held arm64 dylibs left
  over from the earlier builds of this session. The code was fine: the stale `build/` state was the
  cause.
- Fix: `flutter clean && flutter pub get && flutter build macos --release`. The clean build embeds
  both frameworks and the manifest maps arm64 and x64.

### Current state

- Clean build: ad-hoc signed, `codesign --verify --deep --strict` OK. It launched with one window
  showing "Sledování času", with no exceptions in its output, and the projects were listed.
- Data checked before and after the launch: categories 2, projects 3, tasks 12, time_entries 663,
  monthly_targets 2, standalone_invoices 6, settings 37. Backup taken right before the first real
  launch: `~/Documents/timer_counter_container_backup_2026-10-02_08-59-58/`.
- Not installed into `/Applications`; that still holds the re-signed 1.0.9.

### Pending / next steps

- If a macOS release build ever starts to a black window, run `flutter clean` before rebuilding and
  check that `Contents/Frameworks` contains `objective_c.framework` and `sqlite3.framework`.

## 2026-10-02 (part 2) — fix: remaining work days skipped the last day of a month with a DST change

### What was fixed

- **`MonthlyTargetCalculator.workDaysBetween` stepped through days with `add(Duration(days: 1))`**,
  i.e. 24 hours. Across the end of daylight saving time (2026-10-25 in Europe/Prague, a 25-hour day)
  the loop landed on 23:00 of the same date: 25 October was visited twice and 31 October never.
  So a day off on the last day of October was ignored, and the work-day count was off by one
  whenever the 25th and the 31st differ. The same loop already existed in the three screens before
  the 2026-09-11 refactor; the calculator inherited it.
- Surfaced by `flutter test` today: "a context's own days off shorten only its own count" puts a day
  off on the last day of the *current* month, so it only fails in October (expected 29, got 30).
  It passed on 2026-09-11.

### What was done

- `lib/core/services/monthly_target_calculator.dart`: `workDaysBetween` and the "skip today" step in
  `remainingWorkDays` now advance with `DateTime(y, m, d + 1)` (calendar day, not 24 hours).
- `test/core/services/monthly_target_calculator_test.dart`: new test "a month with a daylight saving
  change visits every day once". It uses fixed October and March 2026 dates, so it does not depend on
  today's date. It fails against the old loop and passes now; it can only reproduce the bug when the
  runner's time zone has DST.

### Current state

- `flutter test`: **61 tests passed** (machine time zone CEST).
- `flutter analyze`: no issues.

## 2026-10-02 — fix: macOS app would not launch (expired signing), switch to ad-hoc signing

### What was fixed

- **`/Applications/Timer Counter.app` refused to start** — `open` failed with
  `RBSRequestErrorDomain Code=5 "Launch failed"` / `NSPOSIXErrorDomain Code=162 "Launchd job spawn
  failed"`. Two things had expired: the embedded `Mac Team Provisioning Profile: *` (team
  BZF32VC6NQ) on **2026-09-30**, and the signing certificate `Apple Development: Lubomír Zizka
  (SBG5J7LYK5)` on **2026-08-12**. The binary itself was fine.
- A fresh profile could not be issued: `xcodebuild -allowProvisioningUpdates` reported that the
  BZF32VC6NQ Account Holder must accept the latest Program License Agreement, and the Xcode account
  `lzizka@gmail.com` has invalid keychain credentials ("missing Xcode-Token").
- **`flutter build macos --release` failed** independently of signing: the current Xcode only
  supports macOS deployment targets 12.0–27.0, the project was at 10.15. The local pub cache was also
  missing packages (`google_fonts`, `pocketbase`, …); `flutter pub get` restored them,
  `pubspec.lock` unchanged.

### What was done

- **Release is now ad-hoc signed**, matching Debug/Profile: in `macos/Runner.xcodeproj/project.pbxproj`
  the Release config of the Runner target went from `CODE_SIGN_IDENTITY = "Apple Development"`,
  `Automatic`, `DEVELOPMENT_TEAM = BZF32VC6NQ` to `"-"`, `Manual`, `""`. Nothing in the build can
  expire any more and no paid team is needed.
- `macos/Runner/Release.entitlements`: removed `com.apple.security.application-groups` and
  `keychain-access-groups`. Those need a provisioning profile and were only there for Firebase Auth,
  which is gone; no code references either (checked with grep over `lib/` and `macos/Runner`).
- `MACOSX_DEPLOYMENT_TARGET` 10.15 → 12.0 in the three Runner configs and in `macos/Podfile`
  (`platform :osx` and the `post_install` floor); `Podfile.lock` regenerated by `pod install`.
- **Installed app repaired without changing its code**: copied the existing installed bundle, removed
  `embedded.provisionprofile`, re-signed every framework and the app ad-hoc with sandbox,
  `network.client`, `network.server` and `files.user-selected.read-write` only, and replaced
  `/Applications/Timer Counter.app` with it. The old expired bundle was kept in the session scratchpad
  only.

### Data safety

- The sandbox container `~/Library/Containers/com.example.timerCounter` (20 MB) was backed up first to
  `~/Documents/timer_counter_container_backup_2026-10-02_08-38-58/`.
- The container metadata is bound to team BZF32VC6NQ; the ad-hoc signed app still opened it without
  a prompt and read the existing Hive boxes.
- Record counts in the app's own startup snapshots, 2026-09-30 vs 2026-10-02: categories 2/2,
  projects 3/3, tasks 12/12, time_entries 660/663 (+3 pulled by PocketBase sync), monthly_targets 2/2,
  standalone_invoices 6/6, settings 37/37.

### Current state

- `/Applications/Timer Counter.app` launches (process running, `Signature=adhoc`); data intact as
  above. `spctl` says "rejected", as it did for the old developer-signed build. That does not matter
  for a locally built app without a quarantine attribute.
- `flutter build macos --release` succeeds: ad-hoc signed, `codesign --verify --deep --strict` OK.
- No Dart code changed in this fix; `flutter analyze` / `flutter test` were not re-run.

### Pending / next steps

- The installed app is still the 2026-07-12 build. The fresh Release build in `build/macos/` also
  contains the uncommitted per-context schedule work (2026-09-11 entry), which has never been run in
  the real app. Install it only after trying it out.
- Apps copied to another Mac will need "Open Anyway" in System Settings, because ad-hoc signing is not
  notarised.
