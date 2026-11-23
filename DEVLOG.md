# Development Log

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

## 2026-11-23 (part 8) — feat(projects): richer project cards

### What was done

- `projects_screen.dart` `_ProjectCard` rewritten (the user found the cards too sparse compared to
  the edit form). It now shows: clients in the project's order (the invoice default in bold) and the
  default's service description; this month's and total time; rate; amount to invoice this month
  (billable time × rate); number of tasks; date of the last entry; progress bars for planned time and
  planned budget (billable amount so far, red when exceeded); start – due dates with "po termínu";
  the first two lines of the notes; "Nefakturovatelné" / "Archivovaný" badges. The card rebuilds on
  `ClientBloc` changes.
- The fixed-aspect `GridView` became rows built with `LayoutBuilder` + `IntrinsicHeight`: up to
  440 pt per card, cards in a row share the tallest card's height, so no card carries empty space.
- New strings `projects.this_month/total/rate/month_amount/last_entry/no_entries/plan_time/
  plan_budget/archived/overdue` (cs/en).

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 105 passed (no
  widget tests for the card).
- Checked in the isolated preview with a fresh copy of the real data: 1. Ostatní and 2. Artemis show
  Medutech s.r.o. with "Vývoj aplikace Artemis", 6h 8m / 52h 40m this month, 3 382 / 28 969 CZK to
  invoice, last entry 23. 11. 2026; testovací projekt shows "Zatím bez firmy". The plan, date and notes
  rows are not set on any real project, so they were not seen rendered.
- Installed: backup `~/Documents/timer_counter_container_backup_2026-11-23_18-39-56/`, release
  58.3 MB, `codesign --verify` OK, running from `/Applications`.

### Pending / next steps

- Phase 3 (needs the user's OK): PocketBase dump, additive collections, dry run on a copy of both
  accounts.

## 2026-11-23 (part 7) — feat: the client at the top of a project is the invoice default

### What was done

- User request: the invoice must use the client the user put at the top of a project, not the one
  added last, so the default can be changed later.
- `ProjectClientModel.position` (HiveField 5, default 0); adapter regenerated (other adapters
  restored byte-identical). `ProjectClientRepository._ordered` sorts by position, ties (links from
  before positions existed) newest first; used by `getByProject`, `getByClient`,
  `clientIdsForProjects`.
- Sync: `project_clients.position`; `pocketbase/pb_schema.json` gets the `position` number field
  (still not applied to any server).
- `ClientBloc` `SetProjectClients` stores positions 0…n in the order given and updates a link when
  its description or position changed.
- Project form: the clients list is a `ReorderableListView` with drag handles; the first row shows
  "Na faktuře"; hint "Na faktuře se použije firma nahoře. Pořadí změníš přetažením."
- `ClientMigrationService` appends new links below a project's existing clients.
- Texts and comments that said "most recently linked/added" updated (cs/en, PDF reports).
- The migration from part 6 was confirmed by the user at 18:31: `clients.hive` holds Medutech s.r.o.
  (08975922, CZ08975922) and Mateřská škola (49137182); `project_clients.hive` holds 2 links with
  "Vývoj aplikace Artemis" (checked with `strings` on the Hive files).

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 105 passed
  (ordering by position, fallback to newest when all positions are 0, position survives the server
  round trip; the old "most recently linked first" test replaced).
- Installed: backup `~/Documents/timer_counter_container_backup_2026-11-23_18-35-54/`, release
  58.2 MB, `codesign --verify` OK, running from `/Applications`.
- Not exercised by me: dragging clients in the project form.

### Pending / next steps

- Phase 3 (needs the user's OK): PocketBase dump, import the new collections additively, dry run on
  a copy of both accounts, compare ids; then the queued clients, links and invoices go up.

## 2026-11-23 (part 6) — feat: create clients from existing invoices (migration with preview)

### What was done

- The user asked to create clients from the existing invoices. This Mac's invoices: no. 3
  (standalone) to "Mateřská škola" (IČO 49137182); no. 4–10 (time-based) to "Medutech s.r.o."
  (IČO 08975922), listing 1. Ostatní, 2. Artemis and, on 9–10, the idle "testovací projekt".
- `core/services/client_migration_service.dart` — `ClientMigrationService.buildPlan()` /
  `apply(plan, syncService:)`, `ClientMigrationPlan`:
  - one client per company on the invoices and in the old saved customer list, keyed by IČO (name
    when there is none); the newest invoice provides the details; an existing client with the same
    IČO/name is reused;
  - every invoice without `clientId` gets the client of its customer;
  - a project is linked to the client only if it is in that client's time invoice *and* had time
    entries in the invoiced month (so the idle testovací projekt is not linked); the service
    description comes from the invoice's single line, the link is dated by the latest invoice;
  - the supplier profile is created once from the old invoice settings;
  - nothing is deleted; running it again plans nothing; `apply` writes locally, then queues
    everything for sync.
- `widgets/client_migration_dialog.dart` — preview per client (projects, number of invoices, new),
  profile line, "Teď ne" / "Vytvořit firmy". Offered once per device after the first frame of
  `HomeScreen` (flag `client_migration_offered` in settings) and always available in Settings →
  Fakturace → "Vytvořit firmy z faktur".

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 103 passed
  (+7 `client_migration_service_test.dart`: one client per IČO, invoices get their client, only
  worked projects linked with the invoice text and latest date, idempotent, a hand-made client with the
  same IČO is reused, nothing deleted / invoices otherwise unchanged, profile created once).
- On a copy of the real data (isolated preview, no network) the dialog plans exactly: Medutech s.r.o.
  — 1. Ostatní, 2. Artemis, 7 invoices; Mateřská škola — no project, 1 invoice; profile from
  "Lubomír Žižka".
- Installed: backup `~/Documents/timer_counter_container_backup_2026-11-23_18-30-14/`, release
  58.0 MB, `codesign --verify` OK; the dialog appears in `/Applications/Timer Counter.app` with the
  same plan. Clicking "Vytvořit firmy" via `cliclick` did not reach the app (dialog stayed open,
  nothing applied) — the user has to confirm it.

### Pending / next steps

- User confirms "Vytvořit firmy"; then check Firmy, the project links and the invoices' client.
- Phase 3 (server) with the user's OK; until then the new clients, links and the 8 invoices stay
  queued locally.

## 2026-11-23 (part 5) — feat: clients UI, per-project clients, supplier profile, new invoice flow, own export (phase 2)

### What was done

- Confirmed with the user's data: categories "Medutech" (1. Ostatní, 2. Artemis) and "testovací
  kategorie" (testovací projekt) exist only in lzizka's account; eli.zizkova's 2 projects have none
  (October server dump). "Medutech" will be merged with customer "Medutech s.r.o." in phase 4.
- Clients:
  - `ClientBloc` (`blocs/client/`: event/state/bloc) — load, add, update, delete (refused with a
    message while an invoice refers to the client; links removed with it), `SetProjectClients`
    (diffs a project's links, new ones get increasing timestamps in the order added); every change
    is pushed through `PocketBaseSyncService`; reloads on `SyncCollection.clients/projectClients`.
  - `screens/clients_screen.dart` (sidebar "Firmy" after Projects; Cmd+1…Cmd+8): search, archived
    filter, grouped list with IČO/city and linked projects, edit/archive/delete menu;
    `widgets/client_form_dialog.dart`.
- Project form (`project_form_dialog.dart`): category picker removed (the stored `categoryId` is
  kept and saved back unchanged); new "Firmy" section — link existing or new clients, a service
  description per link, remove; saved through `SetProjectClients`.
- Categories hidden: filter chips, "Add category" and the category dialogs removed from
  `projects_screen.dart`; `category_form_dialog.dart` deleted. Category data and its sync are untouched.
- Supplier profile: `widgets/supplier_profile_dialog.dart` replaces the 5-tab `_InvoiceSettingsDialog`
  (supplier/customer lists by index); reachable from PDF reports ("Můj profil") and Settings →
  Fakturace. `SettingsRepository.getEffectiveSupplierProfile()` falls back to the old invoice settings
  (dated at the epoch, so a server profile wins). Saving pushes the profile.
- Invoices:
  - `core/services/time_invoice_builder.dart` (`TimeInvoiceBuilder`, `ProjectBillingLine`,
    `InvoiceLineMode`): one line per project (service description or project name, hours × project
    rate) or one line (hours × rate when rates match, otherwise 1 × exact sum with the hours in the
    text); projects without hours are skipped.
  - PDF reports: client picker (clients of the active projects, most recently linked first; the old
    customer while no client exists) and line-mode switch in the invoice card; the combined invoice
    covers the chosen client's projects (all projects while it has none); generating shows
    `widgets/invoice_lines_dialog.dart` to edit/split/add lines, then writes the two reports and the
    invoice via `PdfReportService.writeMonthlyPdfs` and stores the invoice through the bloc (synced).
    Per-project mode bills each project to its most recently linked client. Preview uses the same draft.
  - The time invoice PDF is now rendered by `generateStandaloneInvoicePdf` from the stored invoice, so
    the printed number equals the saved one; `generateInvoicePdf`/`generateAllReports` removed.
    Issue date = today, due +14 days, tax date = last day of the month.
  - `StandaloneInvoiceRepository.findTimeBasedInvoice` matches by tax-date month and by client
    (an old invoice without client matches by customer name).
  - `StandaloneInvoiceBloc` pushes add/update/delete to sync and reloads on `SyncCollection.invoices`.
  - Invoice form: "Vybrat firmu" picks a client (sets `clientId`), "Uložit jako firmu" creates a
    client, the supplier button loads the profile; new invoices default to the profile.
- Export: `core/services/data_export_service.dart` — own JSON format (`timer_counter.export` v1 with
  period, currency, summary and entries incl. clients) and `;`-separated CSV with Czech decimals;
  `tyme_export_service.dart` and its test removed.

### What was fixed

- Editing a time-based invoice in the invoice form saved it as `standalone` and dropped its
  `sourceProjectIds`; the form now keeps the type, the projects and the client.
- The time invoice PDF printed `year-month` as its number even when the saved invoice got another
  number (month number already used); it now prints the stored number.
- "Datum vystavění" typo on the PDF invoice → "Datum vystavení".

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 96 passed
  (17 Tyme-export tests removed with the service; new: 5 `time_invoice_builder_test.dart`,
  6 `data_export_service_test.dart`).
- Visual check in the isolated preview (no network): Clients (empty state) and PDF reports (client
  hint, line-mode switch, profile button) render.
- Installed: backup `~/Documents/timer_counter_container_backup_2026-11-23_18-24-06/`, release
  57.9 MB, `codesign --verify` OK, running from `/Applications` with the user's data (sidebar shows
  "Firmy").
- Not exercised: creating a client, linking it in the project form, generating an invoice end to end
  (needs clicks and the folder picker), the invoice form changes. The server still has none of the new
  collections, so new clients/invoices stay queued locally until phase 3.

### Pending / next steps

- Click through: add a client, link it to a project with a service description, generate a November
  invoice in both line modes, edit an invoice in the invoice form.
- Phase 3 (needs the user's OK): PocketBase dump, import the four collections additively, dry run on a
  copy of both accounts, compare ids.
- Phase 4: migration with a preview — customer "Medutech s.r.o." + category "Medutech" → one client
  (match a client already created by hand by IČO), links for 1. Ostatní / 2. Artemis with
  "Vývoj aplikace Artemis", supplier profile from the old settings, upload this Mac's invoices with
  `clientId`.
