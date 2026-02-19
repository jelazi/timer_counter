# Development Log

## 2026-02-19 — Remove Firebase secrets from git history

### What was done
- Identified 4 sensitive Firebase files tracked in git: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `macos/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`
- Installed `git-filter-repo` and used it to purge all 4 files from the entire commit history (21 commits rewritten)
- Files backed up locally at `/tmp/firebase_backup/` and restored to working directory after history rewrite
- Added all 4 files to `.gitignore` to prevent future accidental commits
- Force-pushed rewritten history to `origin/master` — secrets are no longer present in any remote commit

### Current state
- Firebase files exist locally but are NOT tracked by git
- Remote history is clean — no secrets in any commit
- App builds and works as before (files are present on disk)

### Next steps
- Consider revoking and regenerating Firebase API keys as best practice, since they were previously public
- Consider using environment variables or a secrets manager for CI/CD

---

## 2026-02-18 — Replace collapse animations with natural scrolling

### What was done
- Removed all `AnimatedSize` / `NotificationListener` / scroll-detection collapse logic from 3 screens
- Cards that should "hide" are now part of the scrollable content — they scroll away naturally with the list

#### 1. Time tracking screen (mobile)
- Running timer card + Total Today card + "Today" header + entries are now all inside a single `ListView`
- Project/task selector stays fixed above the scroll area
- Removed `_showTotalCard`, `_scrollController`, `_lastScrollOffset` state variables

#### 2. Time entries overview (mobile)
- Month total card + monthly targets are now prepended as the first item in the `ListView.builder`
- Removed `_showSummaryCards`, `_lastScrollOffset` state variables

#### 3. Statistics screen (mobile)
- Title, date range controls, project filter, summary cards, and charts are all inside a single `SingleChildScrollView`
- Removed `_showFilters`, `_lastScrollOffset` state variables

### What is the current state
- All 3 screens: cards scroll away naturally on mobile, no animation/collapse
- Desktop layouts unchanged
- `flutter analyze` — no issues found
- Delete confirmation dialog + undo SnackBar (10s) still in place
- Settings: fixed title + time format Column layout still in place

---

## 2026-02-18 — Mobile UX: collapsible headers, delete confirm, time format fix

### What was done

#### 1. Delete confirmation restored + undo SnackBar (10s)
- Re-added confirmation dialog before deleting time entries (was removed in previous session)
- After confirmation + deletion, SnackBar with "Undo" appears for 10 seconds
- Undo restores the entry + syncs to Firebase

#### 2. Time tracking screen: collapsible "Total Today" card (mobile)
- Added scroll detection on the today's entries ListView
- When user scrolls down, the "Total Today" card and running timer card animate away (collapse)
- When user scrolls back up, cards reappear
- Uses `AnimatedSize` + `NotificationListener<ScrollNotification>` for smooth animation
- Desktop layout unchanged

#### 3. Time entries overview: collapsible month summary (mobile)
- Month total card and monthly targets progress cards collapse when scrolling the day entries list
- Same scroll detection pattern as time tracking screen
- Desktop layout unchanged

#### 4. Statistics: collapsible date picker + project filter (mobile)
- Title "Statistics" stays fixed at top
- Date range selector, custom range button, period navigator, and project filter collapse on scroll
- Added `_buildHeaderControls` method for mobile-specific header without title
- Desktop layout unchanged

#### 5. Settings: fixed title on scroll
- Extracted "Settings" title from `SingleChildScrollView` into a fixed `Column` header
- All settings content scrolls below the fixed title using `Expanded > SingleChildScrollView`

#### 6. Settings: time format — Column layout on mobile
- Time format row (icon + label + SegmentedButton) was wrapping to multiple lines on mobile
- On mobile: now uses a vertical Column layout — label on top, full-width SegmentedButton below
- On desktop: keeps original ListTile with trailing SegmentedButton

### Files modified
- `lib/presentation/screens/time_entries_overview_screen.dart`
- `lib/presentation/screens/time_tracking_screen.dart`
- `lib/presentation/screens/statistics_screen.dart`
- `lib/presentation/screens/settings_screen.dart`

### Current state
- `flutter analyze`: No issues found
- All 6 changes implemented and verified

---

## 2026-02-18 — 9-point fix: Firebase sync, mobile UI, backup, undo

### What was done

#### 1. Deleted old unused firebase_sync_service.dart
- `firebase_sync_service.dart` (REST API-based) was never imported — fully replaced by `firebase_sync_service_v2.dart` (Cloud Firestore SDK). Deleted the old file.

#### 2. Firebase sync on edit/delete across all BLoCs and screens
- **ProjectBloc**: Added `FirebaseSyncService?` field. Sync on add, update, archive, unarchive, delete (cascade: entries + tasks + project).
- **TaskBloc**: Added `FirebaseSyncService?` field. Sync on add, update, delete (cascade: entries + task).
- **CategoryBloc**: Added `FirebaseSyncService?` field. Sync on add, update, delete.
- **app.dart**: All three BLoCs now receive `firebaseSyncService` in their `BlocProvider` creation.
- **time_entries_overview_screen.dart**: `_deleteEntry`, edit callback, add manual entry — all call appropriate Firebase sync methods.
- **settings_screen.dart**: Monthly target add/update/delete — all call Firebase sync methods.

#### 3. Mobile UI overflow fixes
- **Entry tile trailing Row**: Wrapped in `ConstrainedBox(maxWidth: screenWidth * 0.55)`, made time text `Flexible` with `ellipsis`, reduced IconButton sizes to 32x32 with 16px icons.
- **Month total Row**: Wrapped text in `Expanded` with ellipsis, replaced `Spacer` with `SizedBox(width: 8)`.

#### 4. Mobile bottom tabs — icons only
- `NavigationBar` in `home_screen.dart`: Added `labelBehavior: NavigationDestinationLabelBehavior.alwaysHide` and `height: 56`.

#### 5. Statistics screen scroll fix
- Split into `_buildMobileStatistics` (everything in `SingleChildScrollView`) and `_buildDesktopStatistics` (original Row layout). Mobile now scrolls summary cards + charts together.

#### 6. Mobile backup/restore via share_plus
- Added `share_plus: ^12.0.1` dependency.
- **_createBackup**: On mobile, writes to temp dir then shares via `SharePlus.instance.share()`. Desktop keeps `FilePicker.saveFile`.
- **_ExportDialog**: On mobile, writes to temp dir. Desktop keeps file picker.
- **_exportData callback**: On mobile, shares file via SharePlus after export.
- `_restoreBackup`: `FilePicker.pickFiles()` already works on mobile — no change needed.

#### 7. Delete undo history (SnackBar with Undo action)
- **Time entry**: Removed confirmation dialog, deletes immediately, shows SnackBar with 5s undo window. Undo re-adds entry + syncs to Firebase.
- **Project**: Keeps confirmation dialog (cascade delete). After confirming, collects all tasks + entries, deletes, then shows SnackBar with 8s undo window. Undo restores project + all tasks + all entries + syncs all to Firebase.
- **Task**: After deletion, shows SnackBar with 5s undo window. Undo re-adds task via BLoC.
- **Category**: Keeps confirmation dialog. After deletion, shows SnackBar with 5s undo window. Undo restores category + syncs to Firebase.
- **Monthly target**: Keeps confirmation dialog. After deletion, shows SnackBar with 5s undo window. Undo restores target + syncs to Firebase.
- Added translation keys: `entry_deleted`, `entry_restored`, `project_deleted`, `project_restored`, `task_deleted`, `task_restored`, `category_deleted`, `category_restored`, `target_deleted`, `target_restored` (both EN and CS).

### Files modified
- DELETED: `lib/core/services/firebase_sync_service.dart`
- `lib/presentation/blocs/project/project_bloc.dart`
- `lib/presentation/blocs/task/task_bloc.dart`
- `lib/presentation/blocs/category/category_bloc.dart`
- `lib/app/app.dart`
- `lib/presentation/screens/home_screen.dart`
- `lib/presentation/screens/time_entries_overview_screen.dart`
- `lib/presentation/screens/statistics_screen.dart`
- `lib/presentation/screens/settings_screen.dart`
- `lib/presentation/screens/projects_screen.dart`
- `lib/presentation/screens/project_detail_screen.dart`
- `assets/translations/en.json`
- `assets/translations/cs.json`
- `pubspec.yaml` (share_plus)

### Current state
- `flutter analyze`: No issues found
- All 9 reported issues addressed
- Firebase sync is now complete across all CRUD operations
- Mobile backup/export works via system share sheet
- All deletions have undo capability via SnackBar

### What is pending
- Real device testing to confirm all changes work on iPhone
- Consider building iOS release to verify
- Project delete undo with very large datasets (many tasks/entries) may be slow

---

## 2026-02-18 — Fix entry tile title overflow & DateFormat locale

### What was done
- **time_entries_overview_screen.dart:484** — `_buildEntryTile` title Row overflowed by 117-179px: project name + task name were unconstrained `Text` widgets. Wrapped both in `Flexible` with `TextOverflow.ellipsis`.
- **Day header** — Wrapped date text in `Flexible` with ellipsis to prevent overflow in narrow day section headers.
- **DateFormat locale** — `time_tracking_screen.dart` had `DateFormat('EEEE, d MMMM yyyy')` without locale param → English day/month names. Added `context.locale.languageCode` to both mobile and desktop DateFormat calls.
- **initializeDateFormatting()** — Added `await initializeDateFormatting()` in `main.dart` to ensure `intl` has Czech locale date symbols loaded.

### Current state
- `flutter analyze`: No issues found
- All DateFormat calls with weekday/month names now use locale parameter
- Entry tiles truncate long project/task names with ellipsis instead of overflowing

---

## 2026-02-18 — Mobile responsive layout round 3: vertical stacking & padding

### What was done
Based on real device testing feedback ("put things vertically, not side-by-side", "some widgets too narrow"):

#### 1. time_tracking_screen.dart — Project/task selection card
- On mobile (<600px): Project dropdown, task dropdown, and action button now stack vertically (Column) instead of side-by-side (Row)
- Action button becomes full-width on mobile
- Header: On mobile, title/date and running badge stack vertically instead of Row

#### 2. Running badge text overflow protection
- Wrapped project/task name Column in `Flexible` with `TextOverflow.ellipsis`
- Reduced horizontal padding on mobile (16→10)

#### 3. Global padding reduction on mobile
- All 4 main screens (statistics, settings, time_entries_overview, projects) now use `EdgeInsets.all(16)` on mobile instead of `EdgeInsets.all(24)`
- Gives ~16px more content width on each side (~305px usable vs ~289px)

#### 4. Previous fixes verified intact
- Statistics: 2×2 summary card grid on mobile, StatCard padding 12
- Settings: Work schedule row with Expanded day names, reduced spacers, WorkTimeButton padding 8

### Current state
- `flutter analyze`: No issues found
- `flutter build ios --debug --no-codesign`: Build successful
- All 5 main screens (time_tracking, time_entries_overview, projects, statistics, settings) now have responsive mobile layouts

### What is pending
- Real device testing to confirm all overflows are resolved
- Consider reducing padding/spacing on project_detail_screen and pdf_reports_screen if they overflow on mobile

---

## 2026-02-18 — Fix statistics summary cards mobile overflow (1.8px)

### What was done
- Fixed `_buildSummaryCards` in `statistics_screen.dart`: 4 cards in a single Row overflowed on ~337px iPhone screens (each card only ~49px wide, content area ~9px after padding)
- Used `LayoutBuilder` to switch to a 2×2 grid layout (two rows of two cards) when width < 600px
- Reduced `_StatCard` internal padding from 20px to 12px to give more room for content

### Current state
- Statistics screen summary cards render correctly on both mobile (~337px) and desktop (wide) screens
- No compile errors

---

## 2026-02-18 — Fix all mobile (iPhone/Android) overflow issues

### What was done
Fixed all RenderFlex overflow errors when running on iPhone/Android. The app was designed for desktop/wide screens and multiple Row/Column widgets overflowed on narrow ~337px phone screens.

#### 1. time_tracking_screen.dart — Row overflow (159px)
- `_buildTotalTodayCard`: Used `LayoutBuilder` to create a responsive layout
- Narrow (< 500px): 2-row layout — icon + total time + progress on row 1, remaining + expected on row 2
- Wide: original single Row preserved

#### 2. time_entries_overview_screen.dart — Row overflow (8.6px)
- Header: Wrapped title `Text` in `Flexible` with `TextOverflow.ellipsis`
- Month navigator: Wrapped month name `TextButton` in `Flexible` with `TextOverflow.ellipsis`

#### 3. projects_screen.dart — Row overflow (404px)
- `_buildHeader`: Used `LayoutBuilder` with two layouts
- Narrow (< 600px): Column with title + add button, full-width search, Wrap with filter chip + add category
- Wide: original Row preserved

#### 4. statistics_screen.dart — 3 distinct overflows (274px, 75-78px, 139px)
- Header: `LayoutBuilder` — narrow screens stack title, SegmentedButton, and custom range button vertically
- `_StatCard`: Wrapped title `Text` in `Expanded` with `TextOverflow.ellipsis`
- Chart + Distribution: `LayoutBuilder` — narrow screens stack chart and distribution vertically in a `SingleChildScrollView`

#### 5. settings_screen.dart — 3 distinct overflows (13px, 17px, 1.8px)
- Work schedule rows: Replaced `SizedBox(width: 80)` day name with `Expanded` + ellipsis
- Firebase sync section: Replaced `ListTile` with custom Row layout — `Expanded(Column(title, statusChip))` + trailing button

### Current state
- `flutter analyze` → **No issues found!**
- iOS build: ✅ (`flutter build ios --debug --no-codesign`)
- All overflow errors resolved across 5 screen files
- Desktop/tablet layouts unchanged (breakpoint: 500-600px)

### What is pending
- Test on physical iPhone/Android device
- Check for any remaining overflow on very small screens (< 320px width)

## 2026-02-18 — Major package upgrade + iOS build fix + analysis cleanup

### What was done

#### Package upgrades
- Ran `flutter pub upgrade --major-versions` — 10 packages upgraded:
  - `firebase_core`: 3.x → 4.4.0
  - `firebase_auth`: 5.x → 6.1.4
  - `cloud_firestore`: 5.x → 6.1.2 (Firebase SDK 12.8.0)
  - `fl_chart`: → 1.1.1
  - `google_fonts`: → 8.0.2
  - `window_manager`: → 0.5.1
  - `launch_at_startup`: → 0.5.1
  - `file_picker`: → 10.3.10
  - `csv`: → 7.1.0 (breaking: `CsvToListConverter` → `CsvDecoder`, `ListToCsvConverter` → `CsvEncoder`)
  - `package_info_plus`: → 9.0.0
- Regenerated `firebase_options.dart` via `flutterfire configure`

#### iOS build fix
- Created `ios/Runner/Runner.entitlements` with `keychain-access-groups`
- Updated iOS deployment target from 13.0 to 15.0 (required by cloud_firestore 6.x):
  - `ios/Podfile`: `platform :ios, '15.0'`
  - `ios/Runner.xcodeproj/project.pbxproj`: 3x `IPHONEOS_DEPLOYMENT_TARGET = 15.0`
- Cleaned and reinstalled iOS pods

#### macOS Podfile fix
- Added post_install hook to enforce minimum deployment target 10.15 on all pods (fixes abseil/BoringSSL-GRPC warnings)

#### Dart analysis cleanup (22 issues → 0)
- Replaced deprecated `value:` → `initialValue:` on 11 `DropdownButtonFormField` widgets
- Wrapped `RadioListTile` in `RadioGroup<ImportMode>` (Flutter 3.33+ API change)
- Fixed 5 `use_build_context_synchronously` issues with `if (!context.mounted) return;` / pre-capturing scaffoldMessenger
- Fixed `unnecessary_underscores` and `unnecessary_string_interpolations` in statistics_screen
- Fixed CSV v7 breaking changes: `CsvDecoder`/`CsvEncoder` API

### Current state
- `flutter analyze` → **No issues found!**
- iOS build: ✅ (`flutter build ios --debug --no-codesign`)
- macOS build: ✅ (`flutter build macos --debug`)
- Firebase Auth on macOS still works (keychain fix from previous session intact)

### Remaining upstream warnings (cannot fix)
- Firebase Auth plugin ObjC warnings (deprecated methods, unused variables) — upstream issue
- gRPC/abseil/BoringSSL "Run script build phase" warnings — upstream CocoaPods issue

### What is pending
- Test iOS build on physical device
- Test macOS app launch with new packages
- Verify Firebase sync still works end-to-end

---

## 2026-02-18 — Fix Firebase Auth keychain-error on macOS

### What was done

#### Root cause
- macOS sandboxed apps need proper code signing + keychain entitlements for Firebase Auth
- Three issues were found and fixed:
  1. `CODE_SIGN_IDENTITY = "-"` (ad-hoc) inherited from project-level → changed to `"Apple Development"` on Runner target
  2. Missing `keychain-access-groups` entitlement required by Firebase Auth's keychain storage
  3. Missing provisioning profile — resolved by running xcodebuild with `-allowProvisioningUpdates` once

#### Changes made
- **macos/Runner.xcodeproj/project.pbxproj**:
  - Added `CODE_SIGN_IDENTITY = "Apple Development"` to Debug, Profile, and Release Runner target configs
  - Added `DEVELOPMENT_TEAM = 6TM56V7DG8` to Debug and Profile (was only in Release)
- **macos/Runner/DebugProfile.entitlements**:
  - Added `com.apple.security.application-groups` with `6TM56V7DG8.com.example.timerCounter`
  - Added `keychain-access-groups` with `$(AppIdentifierPrefix)com.example.timerCounter`
- **macos/Runner/Release.entitlements**:
  - Same entitlements as DebugProfile
- **Provisioning profile**: Auto-generated by Xcode for `com.example.timerCounter` via `-allowProvisioningUpdates`

#### Key learnings
- `CODE_SIGN_IDENTITY = "-"` (ad-hoc) does NOT grant keychain access in sandboxed apps
- `keychain-access-groups` entitlement requires provisioning profile (SIGKILL without it)
- After profile is generated once, `flutter run -d macos` works normally
- Firebase Auth restores sessions from keychain on app launch

### Current state
- Firebase Auth works correctly on macOS in debug mode
- Keychain access is properly configured with provisioning profile
- App auto-restores auth session and starts real-time listeners on launch
- All entitlements verified: `com.apple.application-identifier`, `keychain-access-groups`, `application-groups`, sandbox, network, JIT

### What is pending
- Test Firebase Auth on iOS
- Test sign-out and re-sign-in flow
- Test on Release build

---

## 2026-02-19 (session 16) — Mobile support (Android/iOS) with Firebase real-time sync

### What was done

#### 1. Firebase SDK dependencies
- Added `firebase_core: ^3.9.0`, `firebase_auth: ^5.4.0`, `cloud_firestore: ^5.6.0` to pubspec.yaml
- Created `lib/firebase_options.dart` placeholder (must be overwritten by `flutterfire configure`)

#### 2. Platform utilities
- Created `lib/core/utils/platform_utils.dart` with `isMobile`, `isDesktop`, `isWeb` static getters
- Used throughout the app to conditionally enable desktop-only features (window_manager, system_tray, launch_at_startup)

#### 3. New FirebaseSyncService (v2) — real-time Cloud Firestore SDK
- Created `lib/core/services/firebase_sync_service_v2.dart` (~700 lines)
- Uses `FirebaseAuth` for email/password authentication (signIn, signUp, signOut)
- Uses `FirebaseFirestore` snapshot listeners for all 6 collections: categories, projects, tasks, time_entries, running_timers, monthly_targets
- Real-time bidirectional sync: local changes pushed immediately, remote changes applied via listeners
- SyncStatus stream (disabled, connecting, connected, error) for UI status display
- SyncCollection stream for BLoC notification when specific collections change
- Push/delete methods for each model type
- Bulk uploadAll/downloadAll with progress callbacks
- Replaces old REST API-based `firebase_sync_service.dart` (kept for reference)

#### 4. Mobile-compatible app initialization (main.dart)
- Firebase.initializeApp() wrapped in try/catch (app still works without Firebase)
- Desktop-only code (window_manager, system_tray, launch_at_startup) wrapped in `PlatformUtils.isDesktop`
- SystemTrayService and FirebaseSyncService created conditionally
- Auto-starts Firebase listeners if user already signed in

#### 5. Nullable services in app.dart
- `SystemTrayService?` and `FirebaseSyncService?` are now nullable optional parameters
- Added `Provider<FirebaseSyncService?>.value` for settings screen access
- TimerBloc receives optional `firebaseSyncService` constructor param
- System tray listener guarded by `PlatformUtils.isDesktop`

#### 6. Desktop window handling extracted
- Created `lib/app/desktop_window_handler.dart`
- Moved `WindowListener` mixin logic (onWindowClose, onWindowMinimize) out of HomeScreen
- Prevents window_manager mixin from being used on mobile

#### 7. Responsive HomeScreen layout
- Mobile: `NavigationBar` (bottom) with 5 tabs (no PDF reports)
- Desktop: `NavigationRail` (left sidebar) with 6 tabs (includes PDF reports)
- Removed window_manager dependency from home_screen.dart

#### 8. Firebase sync integrated into TimerBloc
- Constructor accepts optional `FirebaseSyncService?`
- Listens to `onCollectionChanged` for running_timers and time_entries collections
- StartTimer pushes running timer to Firebase
- StopTimer pushes time entry and deletes running timer from Firebase
- Added `SyncTimersChanged` event to re-emit state on remote changes

#### 9. Settings screen Firebase section rewritten
- Replaced old REST API config dialog (project_id + api_key) with email/password auth dialog
- `_FirebaseSyncSection` reads `FirebaseSyncService?` from Provider
- Shows real-time sync status chip (connected/connecting/disconnected/error)
- Sign in/out buttons, upload/download bulk operations
- `_FirebaseAuthDialog` with email + password fields, sign in and sign up buttons

#### 10. Translations updated
- Added new keys to both en.json and cs.json:
  - `sync.firebase_auth`, `sync.email`, `sync.password`, `sync.sign_in`, `sync.sign_up`, `sync.sign_out`
  - `sync.confirm_sign_out`, `sync.signed_in_as`, `sync.not_signed_in`, `sync.fill_all_fields`
  - `sync.firebase_not_available`, `sync.firebase_not_configured_hint`
  - `sync.real_time_hint`, `sync.status_disabled`, `sync.status_connecting`, `sync.status_connected`, `sync.status_error`

#### 11. Android/iOS build configuration
- Android: `minSdk = 23` in android/app/build.gradle.kts (required for Firebase)
- iOS: `platform :ios, '13.0'` uncommented in ios/Podfile (required for Firebase)

#### 12. Documentation
- Created `FIREBASE_SETUP.md` with full setup instructions (Firebase Console, FlutterFire CLI, Firestore rules, troubleshooting)

### Files created
- `lib/firebase_options.dart` — Firebase config placeholder
- `lib/core/utils/platform_utils.dart` — cross-platform detection
- `lib/core/services/firebase_sync_service_v2.dart` — real-time Firestore sync service
- `lib/app/desktop_window_handler.dart` — desktop window close/minimize handler
- `FIREBASE_SETUP.md` — Firebase setup guide

### Files modified
- `pubspec.yaml` — added firebase_core, firebase_auth, cloud_firestore
- `lib/main.dart` — conditional platform init, Firebase init, nullable services
- `lib/app/app.dart` — nullable SystemTrayService/FirebaseSyncService, Provider setup
- `lib/presentation/screens/home_screen.dart` — responsive mobile/desktop layout
- `lib/presentation/screens/settings_screen.dart` — new Firebase auth UI section
- `lib/presentation/blocs/timer/timer_bloc.dart` — Firebase sync integration
- `lib/presentation/blocs/timer/timer_event.dart` — added SyncTimersChanged event
- `assets/translations/en.json` — new sync auth translation keys
- `assets/translations/cs.json` — new sync auth translation keys
- `android/app/build.gradle.kts` — minSdk = 23
- `ios/Podfile` — platform :ios, '13.0'

### Current state
- App compiles and runs on desktop (macOS) as before
- Mobile support (Android/iOS) structurally implemented
- Firebase SDK integration complete with real-time sync
- **To fully enable Firebase**: run `flutterfire configure` to generate real `firebase_options.dart`
- Old REST API sync service (`firebase_sync_service.dart`) still exists but is no longer used by the UI
- PDF reports and import/export features are desktop-only (hidden on mobile)

### Pending / Next steps
- Run `flutterfire configure` with actual Firebase project to generate platform configs
- Test on Android emulator and iOS simulator
- Consider adding Firebase sync to other BLoCs (projects, categories, time entries) for full real-time push
- May want to remove or deprecate old `firebase_sync_service.dart`
- Mobile-specific UI polish (responsive time tracking screen, etc.)

---

## 2026-02-18 (session 15) — Bug fixes: version, red line, period button, daily hours needed

### What was done

#### 1. Fix About dialog version (home_screen.dart)
- Replaced hardcoded `'1.0.0'` with `PackageInfo.fromPlatform()` via `FutureBuilder`
- Now shows the real version + build number from pubspec.yaml (same as Settings About section)

#### 2. Fix statistics red line expected hours
- The chart horizontal red line was using legacy `getDailyWorkingHours()` (defaulting to 8.0h)
- Now uses `getExpectedHoursForDay()` from the per-weekday work schedule
- For "today" view: uses the specific day's scheduled hours
- For "week"/"month" views: uses the average of enabled working days' hours

#### 3. Fix "Today" button label in statistics per view type
- Added `_getCurrentPeriodLabel()` method
- Button now shows: "Dnes/Today" (day), "Tento týden/This Week" (week), "Tento měsíc/This Month" (month), "Tento rok/This Year" (year)

#### 4. Add daily hours needed to monthly target cards
- Both time_entries_overview_screen.dart and statistics_screen.dart
- Calculates remaining working days in the month (using work schedule settings)
- Shows `~Xh/day needed (N work days left)` when target is not yet completed
- Added `monthly_targets.daily_needed` translation key in both en.json and cs.json

### Files modified
- `lib/presentation/screens/home_screen.dart` — PackageInfo import, FutureBuilder for version
- `lib/presentation/screens/statistics_screen.dart` — red line uses schedule, period button label, monthly targets daily needed
- `lib/presentation/screens/time_entries_overview_screen.dart` — monthly targets daily needed calculation
- `assets/translations/en.json` — added `monthly_targets.daily_needed`
- `assets/translations/cs.json` — added `monthly_targets.daily_needed`

### Current state
- All 4 fixes implemented and build verified (macOS release)
- About dialog shows correct version from pubspec.yaml
- Statistics red line reflects per-day work schedule
- Period navigation button label matches selected view type
- Monthly target cards show daily hours needed to meet target

---

## 2026-02-20 (session 14) — Refinements: sort fix, statistics navigation, monthly targets rework

### What was done

#### 1. Version from pubspec.yaml in Settings
- Added `package_info_plus: ^8.3.0` to pubspec.yaml
- Settings About section now uses `FutureBuilder<PackageInfo>` to display the real app version dynamically instead of hardcoded value

#### 2. Fix time entries sort order
- Within each day group in time_entries_overview_screen.dart, entries are now sorted `b.startTime.compareTo(a.startTime)` (newest on top)

#### 3. Statistics date navigation
- Statistics header now shows actual date range (e.g. "Mon 16 Jun – Sun 22 Jun 2025") with prev/next arrows
- Added `_periodOffset` state variable to track navigation offset
- Added `_dispatchRange()`, `_getDateRange()`, `_formatRangeLabel()` helper methods
- "Back to current" button appears when offset ≠ 0
- SegmentedButton shows short labels (Day/Week/Month/Year) + custom range button
- `LoadStatistics` event now accepts `range` parameter (default 'custom')
- `StatisticsBloc._onLoadStatistics` uses `event.range` instead of hardcoded 'custom'

#### 4. Filter chips initially selected
- In both statistics_screen.dart and pdf_reports_screen.dart, project filter chips now appear visually selected when filteredIds is empty (meaning all projects are included)
- Smart toggle logic: deselecting one chip switches to explicit mode (all-except-one); re-selecting all switches back to empty list (all included)

#### 5. Remove redundant daily/weekly settings
- Removed daily_working_hours and weekly_working_days dropdown ListTiles from settings_screen.dart UI
- Kept underlying bloc/repository methods for backward compatibility (used by chart expected hours line and work schedule)

#### 6. Monthly hours targets rework
- **Removed** `monthlyRequiredHours` from `ProjectModel`, `.g.dart` adapter (backward-compat read still ignores field 13), `ProjectFormDialog`, `project_detail_screen.dart`, `projects_screen.dart`
- **Created** `MonthlyHoursTargetModel` (Hive typeId: 6) with fields: id, name, targetHours, projectIds (List<String>), createdAt
- **Created** `MonthlyHoursTargetModelAdapter` (manually written Hive adapter)
- **Created** `MonthlyHoursTargetRepository` with CRUD methods (getAll, getById, add, update, delete, deleteAll)
- **Registered** adapter in main.dart, created repository instance, passed to TymeApp via Provider in app.dart
- **Settings UI**: New "Monthly Targets" section with list of targets (name, hours, project chips), add/edit/delete functionality
- **Target dialog**: Name field, hours field, multi-select project chips, save/update logic
- **Time Entries Overview**: Monthly targets progress cards with progress bars, worked/target hours, project names
- **Statistics Screen**: Horizontal scrollable target progress chips shown when range is "month"
- Added `monthlyHoursTargetsBox` constant to AppConstants
- Added translations for `monthly_targets` section in both en.json and cs.json

### Files created
- `lib/data/models/monthly_hours_target_model.dart`
- `lib/data/models/monthly_hours_target_model.g.dart`
- `lib/data/repositories/monthly_hours_target_repository.dart`

### Files modified
- `pubspec.yaml` — added package_info_plus
- `lib/main.dart` — adapter registration, repository creation
- `lib/app/app.dart` — MonthlyHoursTargetRepository field + Provider
- `lib/core/constants/app_constants.dart` — monthlyHoursTargetsBox
- `lib/data/models/project_model.dart` — removed monthlyRequiredHours
- `lib/data/models/project_model.g.dart` — backward-compat adapter update
- `lib/presentation/widgets/project_form_dialog.dart` — removed monthly hours field
- `lib/presentation/screens/project_detail_screen.dart` — removed monthly target section
- `lib/presentation/screens/projects_screen.dart` — removed monthly progress bar
- `lib/presentation/screens/settings_screen.dart` — StatefulWidget, version FutureBuilder, removed daily/weekly settings, monthly targets section + dialog
- `lib/presentation/screens/time_entries_overview_screen.dart` — sort fix, monthly targets progress
- `lib/presentation/screens/statistics_screen.dart` — date navigation, filter chips fix, monthly targets progress
- `lib/presentation/screens/pdf_reports_screen.dart` — filter chips fix
- `lib/presentation/blocs/statistics/statistics_event.dart` — LoadStatistics range param
- `lib/presentation/blocs/statistics/statistics_bloc.dart` — uses event.range
- `assets/translations/en.json` — monthly_targets section
- `assets/translations/cs.json` — monthly_targets section

### Current state
- All 6 requested changes implemented
- Monthly hours are now managed as grouped targets (not per-project) in Settings > Monthly Targets
- Target progress is visible in Time Entries Overview (card format) and Statistics (horizontal chips, month view only)
- Statistics screen has full date navigation with prev/next arrows and back-to-current button
- Build verification needed

### Known issues / technical debt
- The settings `daily_working_hours` and `weekly_working_days` Hive keys still exist in repository/bloc for backward compat — could be cleaned up in future
- `ProjectModel` adapter still reads field 13 silently for backward compatibility with existing Hive data

---

## 2026-02-19 (session 13) — Three major features: project filter, work schedule, monthly hours

### What was done

#### Feature 1: PDF Reports & Statistics Project Filter
- Added `pdfReportProjectIds` setting in Hive (persisted list of project IDs)
- `SettingsRepository`: `getPdfReportProjectIds()` / `setPdfReportProjectIds()` methods
- `PdfReportService`: Added `projectIds` parameter to `_processEntries()`, `generateReportPdf()`, `generateInvoicePdf()`, `generateAllReports()` — filters entries before processing
- `StatisticsBloc`: Added `FilterStatisticsProjects` event, `filteredProjectIds` in state, filters entries in `_loadStats()`, saves/loads filter from settings
- `StatisticsBloc` constructor now takes `SettingsRepository` (updated in `app.dart`)
- **PDF Reports Screen**: Project filter card with FilterChip per project, saved to Hive, applied to preview and generate
- **Statistics Screen**: Horizontal scrollable project filter chips below header, with clear button

#### Feature 2: Per-Weekday Work Schedule
- Added `workSchedulePrefix` constant for Hive keys
- `SettingsRepository`: Per-weekday `getWorkScheduleStart/End/Enabled()`, `setWorkScheduleStart/End/Enabled()`, `getTodayExpectedHours()`, `getExpectedHoursForDay()` — defaults Mon-Fri 08:00-16:30 enabled, Sat-Sun disabled
- `SettingsState`: Added `workSchedule` map (weekday → start, end, enabled record)
- `SettingsBloc`: `ChangeWorkSchedule` event, `_loadWorkSchedule()` helper, loads schedule on `LoadSettings`
- **Settings Screen**: Per-day schedule editor with checkbox (enabled), time picker buttons (start/end), calculated hours display
- **Time Tracking Screen**: `_buildTotalTodayCard()` now shows remaining work today, overtime indicator, expected hours, circular progress
- **Time Entries Overview Screen**: `_buildTimelineBar()` now shows work schedule period as a subtle background overlay
- **Statistics Screen**: Added expected daily hours dashed red line on bar chart via `ExtraLinesData`

#### Feature 3: Monthly Required Hours Per Project
- `ProjectModel`: Added `@HiveField(13) monthlyRequiredHours` (default 0.0), updated `copyWith`, `props`
- `project_model.g.dart`: Updated adapter to read/write field 13
- **ProjectFormDialog**: Added `monthlyRequiredHours` text field
- **Project Detail Screen**: Monthly target section with progress bar, worked/remaining hours, completion status
- **Projects Screen** (`_ProjectCard`): Monthly progress bar with worked/required hours display

#### Translations
- Added keys to both EN and CS: `remaining_today`, `overtime`, `expected_today`, `monthly_required_hours`, `monthly_target`, `monthly_worked`, `monthly_remaining`, `monthly_completed`, `monthly_short`, `work_schedule`, `work_schedule_desc`, day names (Mon-Sun), `clear`, `project_filter`, `all_projects`, `filtered_projects`

### Files modified
- `lib/core/constants/app_constants.dart` — new Hive keys
- `lib/data/models/project_model.dart` — monthlyRequiredHours field
- `lib/data/models/project_model.g.dart` — updated adapter
- `lib/data/repositories/settings_repository.dart` — project filter + work schedule methods
- `lib/core/services/pdf_report_service.dart` — projectIds filter
- `lib/app/app.dart` — StatisticsBloc settingsRepository param
- `lib/presentation/blocs/settings/settings_state.dart` — workSchedule field
- `lib/presentation/blocs/settings/settings_event.dart` — ChangeWorkSchedule event
- `lib/presentation/blocs/settings/settings_bloc.dart` — work schedule handler
- `lib/presentation/blocs/statistics/statistics_event.dart` — FilterStatisticsProjects
- `lib/presentation/blocs/statistics/statistics_state.dart` — filteredProjectIds
- `lib/presentation/blocs/statistics/statistics_bloc.dart` — project filter logic
- `lib/presentation/screens/pdf_reports_screen.dart` — project filter UI
- `lib/presentation/screens/statistics_screen.dart` — project filter + expected hours line
- `lib/presentation/screens/settings_screen.dart` — work schedule editor + _WorkTimeButton
- `lib/presentation/screens/time_tracking_screen.dart` — remaining work today
- `lib/presentation/screens/time_entries_overview_screen.dart` — work period overlay
- `lib/presentation/screens/project_detail_screen.dart` — monthly hours info
- `lib/presentation/screens/projects_screen.dart` — monthly hours in card
- `lib/presentation/widgets/project_form_dialog.dart` — monthlyRequiredHours field
- `assets/translations/en.json` — new keys
- `assets/translations/cs.json` — new keys

### Current state
- `flutter analyze` passes with 0 errors, 0 warnings (info-level deprecations only)

### Known issues / pending
- Pre-existing deprecation warnings (Flutter 3.33+ deprecated DropdownButtonFormField.value → initialValue, Radio.groupValue, etc.)

## 2026-02-18 (session 12) — Invoice PDF fixes, bar chart RangeError fix

### What was done
1. **Invoice supplier box enlarged** — Increased the supplier container height from 2.02cm to 3.0cm to properly accommodate IČO, Mobil, and Email lines. The fields were already present in the code but the box was too tight. Also made Email conditional (`if isNotEmpty`) like Mobil.

2. **Removed "Dodací adresa"** — Removed the "Dodací adresa:" label from the right column of the dates section on the invoice. The cell is now empty since delivery address is not used.

3. **Removed "Označení obj. zákazníka"** — Removed the "Označení obj. zákazníka:" line from the VS (variabilní symbol) box on the invoice. Only the VS line remains.

4. **Fixed bar chart RangeError** — The error `RangeError (length): Invalid value: Not in inclusive range 0..36: 37` was caused by `fl_chart`'s `BarChartPainter.handleTouch` trying to access a bar index outside the list bounds when the mouse hovered over the chart edge. Fixed by disabling touch events on the bar chart (`BarTouchData(enabled: false)`), since touch interaction is not needed for the statistics chart.

### Files modified
- `lib/core/services/pdf_report_service.dart` — invoice layout: supplier box 2.02cm→3.0cm, removed "Označení obj. zákazníka", removed "Dodací adresa"
- `lib/presentation/screens/statistics_screen.dart` — added `barTouchData: BarTouchData(enabled: false)` to prevent RangeError

### Current state
- `flutter analyze` passes with 0 errors, 0 warnings (21 info-level — pre-existing deprecations)

### Known issues / pending
- Pre-existing deprecation warnings

## 2026-02-18 (session 11) — Full backup/restore, delete all data, Tyme .data import

### What was done
1. **Full Backup Service** — Created `lib/core/services/backup_service.dart` that exports/imports a complete backup of all application data:
   - All categories (id, name, colorValue, createdAt)
   - All projects (id, name, categoryId, colorValue, hourlyRate, plannedTimeHours, plannedBudget, startDate, dueDate, notes, isArchived, isBillable, createdAt)
   - All tasks (id, projectId, name, hourlyRate, isBillable, notes, isArchived, createdAt, colorValue)
   - All time entries (id, projectId, taskId, startTime, endTime, durationSeconds, notes, createdAt, isBillable)
   - All settings: appearance (theme, language), timer (simultaneous, showSeconds, round), working hours, general (timeFormat, currency), system (launchAtStartup, minimizeToTray, allowOverlap), reminders, invoice settings (suppliers list, customers list, bank info, description, issuer, filenames), Firebase config

2. **Delete All Data** — Button in settings that permanently deletes all categories, projects, tasks, time entries, and running timers. Double confirmation dialog for safety. Settings are preserved.

3. **Tyme .data Import** — Created `lib/core/services/tyme_data_import_service.dart` that imports from Tyme app's native SQLite/Core Data backup format:
   - Reads `ZADATA` table for categories (Z_ENT=9), projects (Z_ENT=8), and tasks (Z_ENT=6)
   - Reads `ZATASKRECORD` table for time entries (Z_ENT=14) with proper Core Data timestamp conversion (seconds since 2001-01-01 → Unix → DateTime)
   - Preserves entity relationships (category→project→task→time entry) via PK→FK mapping
   - Imports hourly rates, billable status, notes, colors
   - Supports all 3 import modes: merge, append, overwrite
   - Uses `sqlite3` Dart FFI package for native SQLite read access

4. **Settings Screen Updates** — Added:
   - "Backup & Restore" section with Create Backup, Restore from Backup, Delete All Data buttons
   - Import dialog now accepts `.data` files alongside `.json` and `.csv`
   - Import subtitle shows "JSON / CSV / Tyme .data"
   - Import result shows category count too

5. **Export verification** — Confirmed existing JSON/CSV export already includes `start_time`, `stop_time`, `start_datetime`, `stop_datetime`, project names, task names, category names, category_id, project_id, task_id — all essential data

### New/modified files
- `lib/core/services/backup_service.dart` (NEW) — Full backup/restore service
- `lib/core/services/tyme_data_import_service.dart` (NEW) — Tyme .data SQLite import
- `lib/presentation/screens/settings_screen.dart` — Added backup/restore/delete sections, tyme.data import support
- `assets/translations/cs.json` — ~15 new backup/restore/delete keys + tyme_data_format
- `assets/translations/en.json` — ~15 new backup/restore/delete keys + tyme_data_format
- `pubspec.yaml` — added `sqlite3: ^3.1.6` dependency

### New translation keys
- `settings.backup_restore`, `settings.backup_create`, `settings.backup_create_desc`
- `settings.backup_restore_action`, `settings.backup_restore_desc`, `settings.backup_restore_confirm`, `settings.backup_restored`
- `settings.delete_all_data`, `settings.delete_all_data_desc`, `settings.delete_all_data_confirm`
- `settings.delete_all_data_final`, `settings.delete_all_data_final_confirm`, `settings.delete_all_data_success`
- `import.tyme_data_format`

### Current state
- Full backup/restore with all data and settings implemented
- Delete all data with double confirmation implemented
- Tyme .data import from native SQLite backup implemented
- `flutter analyze` passes with 0 errors, 0 warnings (21 info-level — pre-existing deprecations)

### Known issues / pending
- Pre-existing deprecation warnings (`DropdownButtonFormField.value`, `RadioListTile.groupValue`)
- Tyme .data import maps Z_ENT entity types based on the specific Tyme version used; different versions may use different entity type IDs

## 2026-02-17 (session 10) — Firebase Cloud Sync

### What was done
1. **Firebase Sync Service** — Created `lib/core/services/firebase_sync_service.dart` (~430 lines) that uses Firestore REST API to sync all app data (categories, projects, tasks, time entries) with Firebase. No native Firebase SDK required — uses `http` package for REST calls.
   - Three sync modes: **Upload** (local→remote replace), **Download** (remote→local replace), **Sync/Merge** (bidirectional union, conflicts resolved by `createdAt`)
   - Batch writes with 500-item chunking for efficiency
   - Pagination for collection listing (1000 per page)
   - Full Firestore value type conversion (String, int, double, bool, DateTime)
   - Progress callback for UI feedback

2. **Firebase Settings in Settings Screen** — Added "Cloud Sync" section between Data and Reminders in settings:
   - Firebase configuration tile (opens config dialog with Project ID + API Key fields)
   - Connection test button in config dialog
   - Three action buttons: Upload / Download / Sync
   - Progress indicator during sync operations
   - Last sync timestamp display
   - Confirmation dialogs for Upload/Download (destructive operations)
   - SnackBar feedback with per-entity counts

3. **Settings persistence** — Added Firebase config keys to `AppConstants` and getter/setter methods to `SettingsRepository` (Project ID, API Key, Enabled, Last Sync, `isFirebaseConfigured` computed property)

### New/modified files
- `lib/core/services/firebase_sync_service.dart` (NEW) — Firestore REST API sync service
- `lib/core/constants/app_constants.dart` — 4 new Firebase setting keys
- `lib/data/repositories/settings_repository.dart` — Firebase config getters/setters + `isFirebaseConfigured`
- `lib/presentation/screens/settings_screen.dart` — `_FirebaseSyncSection` + `_FirebaseConfigDialog` widgets, import for sync service
- `assets/translations/cs.json` — ~28 new `sync.*` translation keys
- `assets/translations/en.json` — ~28 new `sync.*` translation keys
- `pubspec.yaml` — added `http: ^1.6.0` dependency

### New translation keys
- `sync.title`, `sync.subtitle`, `sync.firebase_config`, `sync.not_configured`, `sync.configured`
- `sync.project_id`, `sync.api_key`, `sync.test_connection`, `sync.connection_ok`, `sync.connection_failed`
- `sync.upload`, `sync.download`, `sync.sync_merge`, `sync.last_sync`, `sync.never`, `sync.last_sync_just_now`
- `sync.syncing`, `sync.upload_success`, `sync.download_success`, `sync.sync_success`, `sync.sync_error`
- `sync.confirm_upload`, `sync.confirm_download`, `sync.items_synced`, `sync.clear_config`
- `sync.projects`, `sync.tasks`, `sync.time_entries`, `sync.categories`, `sync.firestore_hint`

### Current state
- Firebase sync fully implemented with UI
- `flutter analyze` passes with 0 errors, 0 warnings (21 info-level — pre-existing deprecations)
- User needs to create a Firebase project, enable Firestore, set rules to `allow read, write: if true;`, and enter Project ID + API Key in settings

### Known issues / pending
- Sync uses `createdAt` for conflict resolution (models don't have `updatedAt` field)
- No Firebase Auth — relies on Firestore rules + API key only
- Running timers and settings are not synced (device-specific)
- Pre-existing deprecation warnings remain

## 2026-02-17 (session 9) — Invoice bank fix, file overwrite dialog, about dialog

### What was done
1. **Invoice bank info fix** — Increased the bank info container height in the invoice PDF from 1.69cm to 2.2cm. The previous height was too tight for 4 lines of 9pt text with padding, causing the "Číslo účtu" and "Kód banky" line to be clipped/hidden. Now matches the Python `json_to_pdf.py` output.
2. **File overwrite confirmation** — Added a dialog that checks if any PDF files already exist in the chosen output directory before generating. If files exist, it lists them and asks the user to confirm overwrite or cancel. Previously files were silently overwritten.
3. **About dialog on Timer icon** — Clicking the Timer icon in the NavigationRail leading now opens an info/about dialog showing app name, version (1.0.0), description, tech stack (Flutter + Dart), author (Lubomír Žižka), and year.

### New translation keys (cs.json + en.json)
- `app_about.description` — App description for the about dialog
- `pdf_reports.files_exist_title` — Title for overwrite confirmation dialog
- `pdf_reports.files_exist_desc` — Description text listing existing files
- `pdf_reports.overwrite_files` — Overwrite button label

### Files modified
- `lib/core/services/pdf_report_service.dart` — bank container height 1.69cm → 2.2cm (+ matching right cell)
- `lib/presentation/screens/pdf_reports_screen.dart` — added `dart:io` import, file existence check + overwrite dialog in `_generatePdfs()`
- `lib/presentation/screens/home_screen.dart` — Timer icon wrapped in InkWell, added `_showAboutDialog()` method
- `assets/translations/cs.json` — 4 new keys
- `assets/translations/en.json` — 4 new keys

### Current state
- All 3 requested features implemented
- `flutter analyze` passes with 0 errors, 0 warnings (21 info-level notices — pre-existing deprecations)

### Known issues / pending
- Pre-existing deprecation warnings (`DropdownButtonFormField.value`, `RadioListTile.groupValue`)

## 2026-02-17 (session 8) — PDF reports overflow fix, configurable invoice settings, tray task name

### What was done
1. **PDF reports overflow fix** — Wrapped the main content of `PdfReportsScreen` in `Expanded` + `SingleChildScrollView` so it scrolls instead of overflowing the vertical `Column`.
2. **Configurable invoice supplier** — Added supplier management with Hive persistence. Users can save multiple suppliers to a list (stored as JSON maps in the settings box), select from saved ones via InputChips, or enter new data. Fields: name, address line 1, address line 2, IČO, phone, email.
3. **Configurable invoice customer (odběratel)** — Same as supplier but for customers. Fields: name, address line 1, address line 2, IČO, DIČ. Also stored as a list in Hive with selection index.
4. **Editable invoice description** — "Vývoj aplikace Artemis" is now configurable via settings. Stored in Hive as `invoice_description`. Also used in QR payment code.
5. **Bank account, bank code & SWIFT** — Added editable fields for bank name, account number, bank code, IBAN, and SWIFT. All rendered on the invoice PDF. Previously bank name and SWIFT were empty.
6. **Editable issuer name & email** — "Vystavil" section on the invoice now uses configurable issuer name and email from settings.
7. **Editable file names** — Users can customize the generated PDF file name patterns using `{month}` and `{year}` placeholders. Defaults: `report_{month}_{year}`, `report_{month}_{year}_rezijni`, `faktura_{month}_{year}`.
8. **Tray icon shows task name** — System tray title now displays `taskName elapsed | totalToday` instead of just `elapsed | totalToday`.

### Architecture: Invoice Settings
- Created `InvoiceParty` data class and `InvoiceSettings` model in `lib/data/models/invoice_settings.dart`
- Extended `SettingsRepository` with ~30 new getter/setter methods for invoice settings (suppliers list, customers list, selection indexes, bank info, description, issuer, filenames)
- Extended `AppConstants` with 15 new keys for invoice settings
- Updated `PdfReportService.generateInvoicePdf()` and `generateAllReports()` to accept optional `InvoiceSettings` parameter
- Created `_InvoiceSettingsDialog` with 5-tab interface (Supplier, Customer, Bank, Invoice, Files)

### New translation keys (cs.json + en.json)
- `pdf_reports.invoice_settings`, `pdf_reports.invoice_info`, `pdf_reports.edit`
- `pdf_reports.supplier`, `pdf_reports.customer`, `pdf_reports.bank_tab`, `pdf_reports.invoice_tab`, `pdf_reports.files_tab`
- `pdf_reports.bank_info`, `pdf_reports.description_label`, `pdf_reports.issuer_section`
- `pdf_reports.saved_suppliers`, `pdf_reports.saved_customers`, `pdf_reports.save_to_list`
- `pdf_reports.supplier_saved`, `pdf_reports.customer_saved`
- `pdf_reports.field_name`, `pdf_reports.field_address1`, `pdf_reports.field_address2`
- `pdf_reports.field_ico`, `pdf_reports.field_dic`, `pdf_reports.field_phone`, `pdf_reports.field_email`
- `pdf_reports.field_bank_name`, `pdf_reports.field_account_number`, `pdf_reports.field_bank_code`
- `pdf_reports.field_description`, `pdf_reports.field_issuer_name`, `pdf_reports.field_issuer_email`
- `pdf_reports.field_report_filename`, `pdf_reports.field_report_rezijni_filename`, `pdf_reports.field_invoice_filename`
- `pdf_reports.filenames_hint`

### Files modified
- `lib/core/constants/app_constants.dart` — 15 new invoice settings keys
- `lib/core/services/pdf_report_service.dart` — parameterized invoice generation (supplier, customer, bank, description, issuer, filenames)
- `lib/data/repositories/settings_repository.dart` — invoice settings getter/setter methods, `getInvoiceSettings()` aggregate loader
- `lib/presentation/screens/pdf_reports_screen.dart` — overflow fix, invoice info card, settings dialog button, full rewrite with `_InvoiceSettingsDialog`
- `lib/app/app.dart` — tray title now includes task name
- `assets/translations/cs.json` — new invoice settings keys
- `assets/translations/en.json` — new invoice settings keys

### Files created
- `lib/data/models/invoice_settings.dart` — `InvoiceParty` and `InvoiceSettings` data classes

### Current state
- All 7 requested features implemented + overflow fix
- `flutter analyze` passes with 0 errors, 0 warnings (21 info-level notices — pre-existing deprecations + async context)
- Invoice settings stored in Hive settings box as key-value pairs
- Supplier/customer lists stored as JSON arrays in Hive
- Default values match the original hardcoded data

### Known issues / pending
- Pre-existing deprecation warnings (`DropdownButtonFormField.value`, `RadioListTile.groupValue`)

## 2026-02-17 (session 7) — Project detail fix, export date fix, PDF reports tab, running timer badge

### What was done
1. **Project detail top overlap fix** — Increased `toolbarHeight` to `kToolbarHeight + 28` in `project_detail_screen.dart` AppBar so the 3 macOS traffic light icons no longer overlap with the title/action icons.
2. **Export date picker error fix** — Changed end-date picker `lastDate` from `DateTime.now() + 1 day` to `DateTime.now() + 365 days` in `settings_screen.dart`. Previously, selecting an end date at end-of-month (e.g. Feb 28) when today was earlier (Feb 17) caused `initialDate > lastDate` assertion error.
3. **PDF Reports tab (new feature)** — Implemented a 6th NavigationRail tab "PDF Reporty" that generates 3 PDF files matching the Python `json_to_pdf.py` script output exactly:
   - `report_{month}_{year}.pdf` — Monthly table with days x tasks, color-coded (blue header, light blue day column, green totals column, green CELKEM row, alternating row colors), summary with total time, hourly rate, total amount
   - `report_{month}_{year}_rezijni.pdf` — Same report but with "Angličtina" entries merged into "Režijní čas"
   - `faktura_{month}_{year}.pdf` — Invoice with supplier (Lubomír Žižka), buyer (Medutech s.r.o.), bank details, item table, CELKEM K ÚHRADĚ, QR payment code, signature sections
4. **Running timer badge in header** — Added `_buildRunningBadge()` to `time_tracking_screen.dart` that shows project name, task name, and elapsed time in a colored badge (with project color border and red pulsing dot) in the top-right header area when a timer is running. Always visible without scrolling.
5. **New service: PdfReportService** — Created `lib/core/services/pdf_report_service.dart` using the `pdf` Dart package. Processes time entries from repositories, generates PDF with layout matching the Python script: same colors, fonts, table structure, invoice layout, QR code.
6. **New screen: PdfReportsScreen** — Created `lib/presentation/screens/pdf_reports_screen.dart` with month/year selection, period summary (total hours, entry count), file list preview, and directory picker for output.

### New translation keys
- `nav.pdf_reports` — "PDF Reporty" / "PDF Reports"
- `pdf_reports.title`, `pdf_reports.subtitle`, `pdf_reports.select_period`, `pdf_reports.month`, `pdf_reports.year`
- `pdf_reports.previous_month`, `pdf_reports.next_month`, `pdf_reports.period_summary`
- `pdf_reports.total_hours`, `pdf_reports.entries_count`, `pdf_reports.period`
- `pdf_reports.generated_files`, `pdf_reports.report_desc`, `pdf_reports.report_rezijni_desc`, `pdf_reports.invoice_desc`
- `pdf_reports.generate`, `pdf_reports.generating`, `pdf_reports.select_output_dir`
- `pdf_reports.success`, `pdf_reports.no_entries`, `pdf_reports.preview_saved`

### Files modified
- `lib/presentation/screens/project_detail_screen.dart` — toolbarHeight fix (task 1)
- `lib/presentation/screens/settings_screen.dart` — date picker lastDate fix (task 2)
- `lib/presentation/screens/time_tracking_screen.dart` — running timer badge (task 4)
- `lib/presentation/screens/home_screen.dart` — added 6th NavigationRail destination + PdfReportsScreen import (task 3)
- `assets/translations/cs.json` — new pdf_reports keys + nav.pdf_reports
- `assets/translations/en.json` — new pdf_reports keys + nav.pdf_reports

### Files created
- `lib/core/services/pdf_report_service.dart` — PDF generation service (task 5)
- `lib/presentation/screens/pdf_reports_screen.dart` — PDF reports UI screen (task 6)

### Current state
- All 4 requested features implemented
- `flutter analyze` passes with 0 errors, 0 warnings (19 info-level deprecation notices)
- PDF generation uses Inter fonts from assets, matching Python script colors and layout

### Known issues / pending
- Invoice has hardcoded supplier/buyer data (matching Python script) — could be made configurable
- Pre-existing deprecation warnings (`DropdownButtonFormField.value`, `RadioListTile.groupValue`)

## 2026-02-18 (session 6) — Timer UX overhaul, CSV support, statistics charts, delete protection, Czech locale fixes

### What was done
1. **Timer card: start/stop/switch** — Rewrote `time_tracking_screen.dart` with `_ButtonMode` enum (start, stop, switchTimer). When no timer is running, shows green "Start" button. When selected task's timer is running, shows red "Stop". When a different task is selected, shows orange "Switch" button. Inline running timer card with project color left border and red pulsing indicator.
2. **Single timer enforcement** — Only one timer can run. Button dynamically changes between stop/switch based on whether the running timer matches the selected project+task.
3. **Removed unnecessary cards** — Removed "Running" count card and "Today entries count" card. Only "Total Today" summary card remains.
4. **Export: start_time/stop_time** — Added `start_time`, `stop_time`, `start_datetime`, `stop_datetime` fields to JSON export in `_buildEntryJson`.
5. **CSV export** — Added `exportToCsv()` method to `TymeExportService`. Uses semicolon delimiter matching Tyme format. Includes all standard columns.
6. **CSV import** — Added `importFromCsv()` method to `TymeImportService`. Parses semicolon-delimited CSV, supports unix timestamps and date+time columns, handles European number format, auto-creates categories/projects/tasks by name.
7. **Tooltips on NavigationRail icons** — Added `Tooltip` widgets wrapping all 5 navigation icons in `home_screen.dart`.
8. **Statistics: full period charts** — Rewrote `_buildDailyChart` to show: 24 hourly bars for "today", 7 day bars for "week", all days for "month", 12 monthly bars for "year". Empty periods show faint bars. Dynamic bar width based on count.
9. **Top padding for macOS traffic lights** — Added `EdgeInsets.only(top: 28)` padding to body in `home_screen.dart`.
10. **Delete protection: category with projects** — `_showDeleteCategoryDialog` in `projects_screen.dart` now checks `projectRepo.getByCategory()` first. Shows info dialog if projects exist.
11. **Delete protection: task with time entries** — Task delete in `project_detail_screen.dart` checks `timeEntryRepo.getByTask()` first. Shows SnackBar warning if entries exist.
12. **Removed timer from projects tab** — Removed play button (`onStartTimer`) from `_TaskListItem` in `project_detail_screen.dart`. Timer can only be started from time tracking screen.
13. **Export: file_picker saveFile** — Replaced directory picker + filename field with `FilePicker.platform.saveFile()` in export dialog. User picks full path in one step.
14. **Export/Import: format selection** — Export dialog now has JSON/CSV segmented button. Import accepts both `.json` and `.csv` files, auto-detects format by extension.
15. **Czech month names: nominative** — Changed `DateFormat('MMMM yyyy')` to `DateFormat('LLLL yyyy')` in month navigator (time_entries_overview_screen) for standalone/nominative form (leden vs. ledna).
16. **Czech day format: period after day** — Changed `DateFormat('EEEE, d MMMM')` to `DateFormat("EEEE, d'.' MMMM")` in day section headers.

### New/updated translation keys
- `time_tracking.switch_timer` — "Přepnout timer" / "Switch Timer"
- `categories.cannot_delete_has_projects` — warning when deleting category with projects
- `projects.cannot_delete_task_has_entries` — warning when deleting task with entries
- `projects.cannot_delete_has_entries` — warning when deleting project with entries
- `export.format`, `export.json_format`, `export.csv_format` — format selection labels
- `import.select_file_csv` — CSV file selection label

### Files modified
- `lib/presentation/screens/time_tracking_screen.dart` — full rewrite (tasks 1-3)
- `lib/presentation/screens/home_screen.dart` — tooltips + top padding (tasks 7, 9)
- `lib/core/services/tyme_export_service.dart` — start/stop_time, CSV export (tasks 4-5)
- `lib/core/services/tyme_import_service.dart` — CSV import (task 6)
- `lib/presentation/screens/statistics_screen.dart` — full period charts (task 8)
- `lib/presentation/screens/projects_screen.dart` — category delete protection (task 10)
- `lib/presentation/screens/project_detail_screen.dart` — task delete protection, removed timer button (tasks 11-12)
- `lib/presentation/screens/settings_screen.dart` — saveFile, format selection, CSV support (tasks 13-14)
- `lib/presentation/screens/time_entries_overview_screen.dart` — Czech locale fixes (tasks 15-16)
- `assets/translations/cs.json` — new keys
- `assets/translations/en.json` — new keys

### Current state
- All 12 requested features implemented
- `flutter analyze` passes with 0 errors, 0 warnings (only info-level deprecation notices)
- Timer tracking, CSV/JSON export/import, statistics charts, delete protection all functional

### Known issues / pending
- `DropdownButtonFormField.value` deprecation warnings (Flutter wants `initialValue` in newer versions)
- `RadioListTile.groupValue` & `.onChanged` deprecated in latest Flutter (use `RadioGroup` ancestor)
- The `timer_card.dart` widget may now be unused (was replaced by inline running card in time_tracking_screen)

## 2026-02-17 (session 5) — Statistics ranges, export dialog, import fixes, Czech localization, README

### What was done
1. **Statistics: This Year + custom period picker** — Added "This Year" preset to statistics SegmentedButton. Added "Custom Range" button that opens a dialog where user can select: specific Day (date picker), Week (pick date → shows Mon-Sun range), Month (year + month dropdowns), or Year (year dropdown). Date range is displayed below the header. Statistics BLoC now handles 'year' range.
2. **Export: date range selection + custom filename** — Replaced simple directory picker with full export dialog: from/to date pickers (default: current month), auto-generated filename based on range (e.g., `timer_counter_2026-02.json`), editable filename field, directory picker. Export service already supported date ranges.
3. **Import: auto-create categories/tasks if not existing** — Import now checks existing categories, projects, and tasks BY NAME (case-insensitive) before creating. If an entity with the same name already exists, it reuses the existing ID instead of creating a duplicate. Only truly new entities are created.
4. **Import: fix start/end times** — Fixed timezone parsing: dates are now converted to local time before extracting the calendar date. Entries are stacked throughout the day starting at 8:00 AM instead of all starting at midnight. Each subsequent entry on the same day starts where the previous one ended.
5. **Czech month/week names in time entries overview** — Added locale parameter (`context.locale.languageCode`) to all `DateFormat` calls that display day/month names: month navigator, day section headers, date pickers in Add/Edit dialogs. Also added locale to statistics chart day labels.
6. **README for Git** — Created comprehensive README.md with full English section + full Czech (Česky) section. Covers: features, tech stack, architecture diagram, getting started, build instructions.

### New translation keys
- `statistics.this_year`, `statistics.select_period`, `statistics.select_day/week/month/year`, `statistics.from`, `statistics.to`, `statistics.apply`
- `export.title`, `export.date_range`, `export.filename`, `export.from`, `export.to`, `export.export`, `export.select_range`, `export.this_month`

### Files modified
- `assets/translations/en.json` — Added statistics + export translation keys
- `assets/translations/cs.json` — Added statistics + export translation keys (Czech)
- `lib/presentation/blocs/statistics/statistics_bloc.dart` — Added 'year' case in _onChangeRange
- `lib/presentation/screens/statistics_screen.dart` — New header with This Year + custom range button, custom period picker dialog with Day/Week/Month/Year modes, locale-aware DateFormat in chart
- `lib/presentation/screens/settings_screen.dart` — Replaced _exportData with dialog-based export, added _ExportDialog widget with date range + filename + directory picker
- `lib/core/services/tyme_import_service.dart` — Name-based entity deduplication, timezone-correct date parsing, day-stacking for sequential start times
- `lib/presentation/screens/time_entries_overview_screen.dart` — Added locale parameter to all DateFormat calls (month navigator, day headers, dialog date pickers)
- `README.md` — Complete rewrite with English + Czech sections

### Build status
- `flutter analyze` — 0 errors, 0 warnings, 13 info only (pre-existing deprecation warnings)

### What is pending
- Some deprecated API warnings (`DropdownButtonFormField.value` → `initialValue`, `RadioListTile.groupValue/onChanged`)
- The `start_timer_dialog.dart` is orphaned (can be deleted in cleanup)

---

## 2026-02-17 (session 4) — 10 feature requests: rename, dock hiding, tray total, overlap blocking, text time input, icon fix, export fix

### What was done
1. **Rename "Tyme Tracker" → "Timer Counter"** — Replaced app name across 20+ files: app_constants.dart, system_tray_service.dart, app.dart, main.dart, home_screen.dart, en.json, cs.json, pubspec.yaml, AppInfo.xcconfig, main.cpp, Runner.rc, my_application.cc, web/index.html, web/manifest.json
2. **Hide from dock when minimized to tray** — Created macOS method channel (`com.timer_counter/dock`) in AppDelegate.swift using `NSApp.setActivationPolicy(.accessory/.regular)`. Created `lib/core/services/dock_service.dart` wrapper. Integrated into home_screen.dart (onWindowClose/onWindowMinimize) and system_tray_service.dart (_showWindow).
3. **Tray shows timer + daily total** — Rewrote `_updateSystemTray` in app.dart. When running: shows `elapsed | totalToday`; when idle: shows `0:00 | totalToday`. Also rebuilds project quick-start menus when idle.
4. **Block save on overlap** — Moved overlap check INSIDE both _AddManualEntryDialog and _EditEntryDialog. Shows red error text in dialog and prevents Navigator.pop when overlap detected (previously overlap was checked in parent callback after dialog closed).
5. **Manual text input for time fields** — Both Add and Edit dialogs now use TextField with HH:mm input + clock icon suffix to open standard TimePicker. Added _formatTimeOfDay, _parseTime helpers, TextEditingControllers for start/end times.
6. **Fix broken export (macOS sandbox)** — Added `com.apple.security.files.user-selected.read-write` entitlement to both DebugProfile.entitlements and Release.entitlements.
7. **Import from test JSON** — Already implemented from previous session. Verified: import service handles test_export.json format correctly with overwrite/append/merge modes. UI dialog exists in settings.
8. **Fix macOS icon** — Added `flutter_launcher_icons: ^0.14.3` to dev_dependencies with config for all platforms. Generated icons for Android, iOS, macOS, Windows, Web.
9. **Fix windows/runner/main.cpp** — Window title updated to "Timer Counter". SetQuitOnClose(false) already correct.
10. **All month entries on one page** — Already working from session 3 (ListView.builder with day cards).

### Files created
- `lib/core/services/dock_service.dart` — Method channel wrapper for macOS dock hide/show (static hideFromDock/showInDock)

### Files modified
- `lib/core/constants/app_constants.dart` — appName → 'Timer Counter'
- `lib/app/system_tray_service.dart` — Renamed strings, added DockService import, _showWindow calls DockService.showInDock()
- `lib/app/app.dart` — Renamed strings, completely rewrote _updateSystemTray for both running/idle states
- `lib/main.dart` — Window title and launchAtStartup appName → 'Timer Counter'
- `lib/presentation/screens/home_screen.dart` — Added DockService.hideFromDock() calls in onWindowClose/onWindowMinimize
- `lib/presentation/screens/time_entries_overview_screen.dart` — Overlap check moved inside dialogs, time pickers replaced with TextFields in both Add/Edit dialogs
- `macos/Runner/AppDelegate.swift` — Added method channel for dock hiding/showing
- `macos/Runner/DebugProfile.entitlements` — Added files.user-selected.read-write
- `macos/Runner/Release.entitlements` — Added files.user-selected.read-write
- `macos/Runner/Configs/AppInfo.xcconfig` — PRODUCT_NAME = Timer Counter
- `windows/runner/main.cpp` — Window title → "Timer Counter"
- `windows/runner/Runner.rc` — FileDescription, ProductName → "Timer Counter"
- `linux/runner/my_application.cc` — Window titles → "Timer Counter"
- `web/index.html` — Title → "Timer Counter"
- `web/manifest.json` — name, short_name → "Timer Counter"
- `assets/translations/en.json` — app_name, tray.show updated
- `assets/translations/cs.json` — app_name, tray.show updated
- `pubspec.yaml` — Added flutter_launcher_icons, updated description
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/` — Regenerated by flutter_launcher_icons
- `windows/runner/resources/app_icon.ico` — Regenerated by flutter_launcher_icons

### Build status
- `flutter analyze` — 0 errors, 0 warnings, 15 info only (deprecated API warnings + async context)

### What is pending
- Some deprecated API warnings (`DropdownButtonFormField.value` → `initialValue`, `RadioListTile.groupValue/onChanged`)
- Consider generating a higher-res source icon (current is 128x128, upscaled for larger sizes)
- The `start_timer_dialog.dart` is orphaned (can be deleted in cleanup)
- iOS alpha channel warning: Set `remove_alpha_ios: true` in flutter_launcher_icons config for App Store submission

---

## 2026-02-17 (session 3) — Complete all 10 UX issues: build verified

### What was done
1. **Close button (X) minimizes to tray** — Fixed ROOT CAUSE: macOS `AppDelegate.swift` had `applicationShouldTerminateAfterLastWindowClosed` returning `true`, Windows `main.cpp` had `SetQuitOnClose(true)`. Both changed to `false`.
2. **Tray shows task/time** — Already implemented from previous session. Menu format improved: removed "--- Running ---" header, added `▶` prefix to running timer entries in tray menu.
3. **Timer start button inline** — Already implemented from previous session (inline project/task dropdowns with Start button).
4. **Date picker in manual entry** — Implemented in overview screen rewrite: both Add and Edit dialogs now have date picker, start/end time pickers, duration preview.
5. **Monthly view for entries** — Complete rewrite of `time_entries_overview_screen.dart`: Month navigator, day-grouped entries (newest first), month total card, day total headers with "Today" badge.
6. **Export with directory picker** — Already implemented in settings: uses `FilePicker.platform.getDirectoryPath()`.
7. **Edit existing entries** — Each entry tile has edit icon. Edit dialog pre-populates all fields (project, task, date, times, notes, billable). Overlap checking skips self.
8. **JSON import** — Import service already existed from previous session with 3 modes (overwrite/append/merge). Settings has import dialog with file picker + mode selection.
9. **App icon fixed** — Generated custom clock icon in all required sizes: macOS (16/32/64/128/256/512/1024px PNGs) and Windows (.ico with 256/128/64/48/32/16). Replaced default Flutter icons.
10. **Timeline visualization** — Each day card shows a 24-hour horizontal bar with colored segments per entry (project colors). Hour labels at 3h intervals. Tooltips show project name + time range on hover.

### Files changed in this session
- `macos/Runner/AppDelegate.swift` — `applicationShouldTerminateAfterLastWindowClosed` → `false`
- `windows/runner/main.cpp` — `SetQuitOnClose` → `false`
- `lib/app/system_tray_service.dart` — Removed "--- Running ---" header, added ▶ prefix
- `lib/presentation/screens/time_entries_overview_screen.dart` — Complete rewrite (1223 lines): monthly view, timeline bar, edit/add dialogs with date picker
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png` — Regenerated from custom icon
- `windows/runner/resources/app_icon.ico` — Regenerated from custom icon
- `pubspec.yaml` — Added `file_picker: ^8.0.0`
- `assets/translations/en.json` + `cs.json` — Added import section + missing time_entries keys

### Build status
- `flutter analyze` — 0 errors, 0 warnings, 15 info only (deprecated API warnings + async context)
- `flutter build macos` — SUCCESS (51.3MB)

### What is pending
- Some deprecated API warnings (`DropdownButtonFormField.value` → `initialValue`, `RadioListTile.groupValue`)
- The `start_timer_dialog.dart` is orphaned (no longer imported) — can be deleted in cleanup
- Consider generating higher-res source icon (current source is only 128x128, upscaled for larger sizes)

---

## 2026-02-17 — Fix 10 UX issues (close button, tray info, quick-start, month view, edit entries, timeline, export picker, import, icons)

### What was done
1. **Close button (X) fix**: Moved `windowManager.setPreventClose(true)` from `HomeScreen.initState` to `main.dart` BEFORE `waitUntilReadyToShow` — fixes race condition where close event fires before prevention is set. Added `isPreventClose` guard in `onWindowClose()`.
2. **Enhanced tray info**: System tray tooltip now shows `"ProjectName / TaskName — 01:23 | Today: 05:30"`. Also calls `updateTitle()` to show running timer info in the tray bar text.
3. **Quick-start timer (inline)**: Rewrote `time_tracking_screen.dart` from StatelessWidget to StatefulWidget. Replaced dialog-based start with inline Card containing Project dropdown → Task dropdown → Start button. Auto-restores last used project/task from `SettingsRepository`.
4. **Date picker in manual entry**: The entry dialog (both add and edit) now has a date picker (`ListTile` with `showDatePicker`), time pickers for start/end, duration preview, notes, and billable toggle.
5. **Month view for entries**: `time_entries_overview_screen.dart` completely rewritten — shows all entries for the selected month on one page. Month navigation with prev/next buttons and clickable month picker. Entries grouped by day (descending), each day grouped by project.
6. **Directory picker for export**: Export now opens `FilePicker.platform.getDirectoryPath()` to let user choose where to save. File is named `tyme_export_<timestamp>.json`.
7. **Edit existing entries**: Each entry tile has an edit button that opens the same `_EntryDialog` pre-populated with existing values. Overlap checking skips self when editing.
8. **JSON import with modes**: Created `TymeImportService` with 3 modes: Overwrite (clears all data first), Append (adds alongside existing), Merge (updates by ID, adds new). Import dialog in Settings with file picker for JSON and radio buttons for mode selection. Overwrite mode shows confirmation dialog.
9. **App icons**: macOS AppIcon.appiconset already had proper custom icons (16–1024px). Generated Windows `app_icon.ico` from the 1024px source with standard sizes (16, 32, 48, 64, 128, 256).
10. **Timeline visualization**: Each day card shows a 24-hour horizontal timeline bar with colored blocks per entry, color-coded by project. Hour markers at 4h intervals. Tooltips show project name and time range on hover.

### New files
- `lib/core/services/tyme_import_service.dart` — Import service with overwrite/append/merge modes
- `windows/runner/resources/app_icon.ico` — Windows application icon

### Files changed
- `lib/main.dart` — Added `setPreventClose(true)` before window show
- `lib/presentation/screens/home_screen.dart` — Removed redundant setPreventClose, added isPreventClose guard
- `lib/app/system_tray_service.dart` — Added `updateTitle()` method
- `lib/app/app.dart` — Enhanced tooltip format with task name + time, added updateTitle calls
- `lib/presentation/screens/time_tracking_screen.dart` — Complete rewrite to StatefulWidget with inline quick-start
- `lib/presentation/screens/time_entries_overview_screen.dart` — Complete rewrite with month view, timeline, edit, date picker
- `lib/presentation/screens/settings_screen.dart` — Directory picker for export, import dialog with 3 modes

### What is pending
- Translations are already comprehensive (en.json, cs.json both have import/time_entries keys)
- The `start_timer_dialog.dart` is now orphaned (no longer imported) — can be deleted in cleanup

---

## 2026-02-17 — Implement 7 new features (close-to-tray, tray menu, last selection, icon, export, entries overview, overlap setting)

### What was done
1. **Close to system tray**: Window close now hides to tray instead of quitting. Only "Quit" from tray menu actually exits the app. Implemented via `WindowListener` on `HomeScreen` with `windowManager.setPreventClose(true)`.
2. **Tray click → tracking menu**: Clicking the tray icon shows a context menu with:
   - Show Tyme Tracker
   - Running timers (click to stop individual timer)
   - Stop All Timers
   - Start Timer → project sub-menus with tasks
   - Quit
   Menu is updated on every `TimerBloc` state change via `BlocListener` in `app.dart`.
3. **Remember last project/task**: Last selected project and task IDs are saved to Hive via `SettingsRepository`. `StartTimerDialog` and `_AddManualEntryDialog` pre-populate with last used selection on open.
4. **Clock app icon**: Generated a 128x128 PNG clock icon with indigo (#6366F1) theme — circle, hour markers, hands at 10:00 position. Stored at `assets/icons/app_icon.png`.
5. **Minimize to tray only**: When `minimizeToTray` setting is enabled (default), minimize hides the window entirely from dock — window only stays in system tray.
6. **Tyme JSON export**: Created `TymeExportService` at `lib/core/services/tyme_export_service.dart` that exports time entries in exact Tyme-compatible JSON format (matching `test_export.json` structure): billing, category, project, task, duration in minutes, rate, sum, rounding settings, etc. Export button added to Settings screen under Data section.
7. **Time entries overview**: New screen added to NavigationRail (5 destinations now). Shows entries grouped by project for a selectable date, with day navigation, total duration, and per-project totals. Manual entry dialog has project/task dropdowns, time pickers, duration preview, notes, billable toggle. Overlap validation prevents overlapping entries unless `allowOverlapTimes` setting is enabled.

### New settings added
- `allowOverlapTimes` — allows time entries to overlap (default: false)
- `lastProjectId` / `lastTaskId` — persisted last selection

### New files
- `lib/core/services/tyme_export_service.dart` — Tyme JSON export service
- `lib/presentation/screens/time_entries_overview_screen.dart` — Time entries overview + manual add dialog

### Files changed
- `lib/app/system_tray_service.dart` — Enhanced with rich menu, project/task data types, click→menu behavior
- `lib/app/app.dart` — Added BlocListener for tray menu updates
- `lib/presentation/screens/home_screen.dart` — Added WindowListener, 5th nav destination
- `lib/presentation/widgets/start_timer_dialog.dart` — Pre-select last project/task from Hive
- `lib/presentation/screens/settings_screen.dart` — Allow overlap toggle, export button
- `lib/presentation/blocs/settings/settings_state.dart` — Added `allowOverlapTimes`
- `lib/presentation/blocs/settings/settings_event.dart` — Added `ToggleAllowOverlapTimes`
- `lib/presentation/blocs/settings/settings_bloc.dart` — Handle new event
- `lib/core/constants/app_constants.dart` — Added new settings keys
- `lib/data/repositories/settings_repository.dart` — Added getters/setters for new settings
- `assets/translations/en.json` — New translations
- `assets/translations/cs.json` — New translations
- `assets/icons/app_icon.png` — Clock icon (128x128 PNG)

### Current state
- `flutter analyze` — 0 errors, 1 info (benign `use_build_context_synchronously` with `mounted` check) ✅
- `flutter build macos` — builds successfully (50.3MB) ✅
- All 7 features implemented ✅

### Known issues / next steps
- App icon is only set for system tray — macOS app bundle icon (AppIcon.appiconset) still uses default Flutter icon
- Export currently saves to Documents folder; could add file picker dialog
- No import functionality yet
- Time entries overview doesn't support editing existing entries (only add + delete)

---

## 2026-02-17 — Fix google_fonts network error on macOS

### Problem
- App crashed at startup: `google_fonts` tried to download Inter font from `fonts.gstatic.com` but macOS sandbox blocked outgoing network connections (`Operation not permitted, errno = 1`)
- Secondary issue: Hive lock files from crashed process blocked subsequent launches (`Resource temporarily unavailable, errno = 35`)

### What was done
1. **Added `com.apple.security.network.client` entitlement** to both:
   - `macos/Runner/DebugProfile.entitlements`
   - `macos/Runner/Release.entitlements`
2. **Bundled Inter font locally** (4 weights: Regular 400, Medium 500, SemiBold 600, Bold 700) in `assets/fonts/`
3. **Configured `GoogleFonts.config.allowRuntimeFetching = false`** in `main.dart` so it never attempts network downloads
4. **Registered fonts in `pubspec.yaml`** under `flutter.fonts` section
5. Cleaned up Hive `.lock` files from crashed previous session

### Current state
- App starts successfully on macOS with no errors ✅
- Fonts render correctly from bundled assets (no network fetch) ✅
- `flutter analyze` — 0 issues ✅
- `Failed to foreground app` and `Resize timed out` are benign debug-mode messages from `window_manager`'s hidden title bar — not real errors

### Files changed
- `macos/Runner/DebugProfile.entitlements` — added `com.apple.security.network.client`
- `macos/Runner/Release.entitlements` — added `com.apple.security.network.client`
- `lib/main.dart` — added `GoogleFonts.config.allowRuntimeFetching = false` + import
- `pubspec.yaml` — added `assets/fonts/` to assets, added `fonts:` section with Inter family
- `assets/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf` — bundled font files

---

## 2026-02-17 — Initial project implementation (Tyme-like time tracking app)

### What was done
- Full project architecture created from scratch: BLoC + Repository + Provider + Hive
- **Data models** (5): `CategoryModel`, `ProjectModel`, `TaskModel`, `TimeEntryModel`, `RunningTimerModel` — all with hand-written Hive TypeAdapters (`.g.dart` files using `part of` directive)
- **Repositories** (6): `CategoryRepository`, `ProjectRepository`, `TaskRepository`, `TimeEntryRepository`, `RunningTimerRepository`, `SettingsRepository` — all use `init()` method to open Hive boxes internally
- **BLoCs** (6): `CategoryBloc`, `ProjectBloc`, `TaskBloc`, `TimerBloc`, `StatisticsBloc`, `SettingsBloc` — each split into 3 files (bloc/event/state)
- **Screens** (6): `HomeScreen` (NavigationRail), `TimeTrackingScreen`, `ProjectsScreen`, `ProjectDetailScreen`, `StatisticsScreen`, `SettingsScreen`
- **Widgets** (5): `TimerCard`, `TimeEntryListItem`, `StartTimerDialog`, `ProjectFormDialog`, `CategoryFormDialog`
- **System tray** service (`lib/app/system_tray_service.dart`) — show/stop/quit menu, tray icon
- **Localization**: English + Czech (`assets/translations/en.json`, `cs.json`)
- **Theme**: Light + Dark with Google Fonts Inter, Material 3, primary color #6366F1
- **Entry point**: `main.dart` initializes Hive, registers adapters, creates repos, sets up window manager + system tray, wraps app in `EasyLocalization` + `TymeApp`
- **App root**: `lib/app/app.dart` — MultiProvider + MultiBlocProvider + MaterialApp with theme switching

### What was fixed during initial build
- Removed conflicting `hive` + `hive_flutter` packages (kept only `hive_ce` + `hive_ce_flutter`)
- Downgraded `uuid` from ^4.5.1 to ^3.0.6 (required by `system_tray`)
- Upgraded `bloc_test` from ^9.1.7 to ^10.0.0 (compatible with `flutter_bloc` ^9.1.0)
- Upgraded `intl` from ^0.19.0 to ^0.20.2 (pinned by Flutter SDK)
- Changed `.g.dart` files from standalone `import` to `part of` directive
- Fixed repositories — they use `init()` pattern (no constructor args), not box-via-constructor
- Fixed `ProjectBloc` constructor — requires `taskRepository` + `timeEntryRepository` in addition to `projectRepository`
- Fixed `TaskBloc` constructor — requires `timeEntryRepository` in addition to `taskRepository`
- Fixed `WindowOptions const` issue — replaced `const` with `final` since `AppConstants` values aren't compile-time constants
- Removed unused imports from multiple files
- Fixed deprecated `value` → `initialValue` on `DropdownButtonFormField`
- Replaced default test file (referenced deleted `MyApp` class)

### Current state
- `flutter analyze` — **0 issues** ✅
- `flutter build macos` — **successful** (48.5MB) ✅
- App structure is complete and compiles
- App has NOT been runtime-tested yet (no manual launch/click-through)
- System tray icon uses a placeholder empty file (`assets/icons/app_icon.png`) — needs a real icon

### Known issues / technical debt
- `assets/icons/app_icon.png` is an empty placeholder file — need to create a proper icon
- No unit tests written yet (only a placeholder test exists)
- No PDF/CSV export functionality implemented yet (dependencies are in pubspec but no code uses them)
- `DropdownButtonFormField.initialValue` may behave differently than `value` — needs runtime verification
- `StatisticsScreen` chart rendering not tested at runtime
- Settings changes (theme, language) need runtime verification of live switching
- System tray behavior on macOS needs testing (might need entitlements or permissions)
- `launch_at_startup` might need additional macOS configuration
- No data migration strategy if models change in the future

### Project structure
```
lib/
├── app/
│   ├── app.dart                    — TymeApp root widget
│   └── system_tray_service.dart    — System tray integration
├── core/
│   ├── constants/app_constants.dart
│   ├── theme/app_theme.dart
│   └── utils/time_formatter.dart
├── data/
│   ├── models/                     — 5 models + 5 .g.dart adapters
│   └── repositories/               — 6 repositories
├── presentation/
│   ├── blocs/                      — 6 BLoCs (each: bloc/event/state)
│   ├── screens/                    — 6 screens
│   └── widgets/                    — 5 reusable widgets
└── main.dart                       — Entry point
```

### Dependencies (key ones)
- `flutter_bloc: ^9.1.0` — state management
- `hive_ce: ^2.10.1` + `hive_ce_flutter: ^2.2.0` — local storage
- `easy_localization: ^3.0.7` — i18n (en, cs)
- `fl_chart: ^0.70.2` — statistics charts
- `system_tray: ^2.0.3` — tray icon
- `window_manager: ^0.4.3` — desktop window control
- `google_fonts: ^6.2.1` — Inter font
- `provider: ^6.1.2` — DI for repositories
