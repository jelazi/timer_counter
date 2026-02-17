# Development Log

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
