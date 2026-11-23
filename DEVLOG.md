# Development Log

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

## 2026-11-23 (part 4) — feat(data): clients, project–client links, synced invoices and supplier profile (phase 1, data layer)

### What was done

- Final decisions from the user: no validity period on a project–client link (the most recently
  linked client is offered, the user changes it per invoice); every project–client pair has its own
  service description; one project rate; several projects for one client go either as one line per
  project or as one summary line, editable before issuing; one supplier per account; the export gets
  an own format instead of Tyme. Design page updated (`docs/datovy-model.html`, artifact v3).
- Models: `ClientModel` (Hive typeId 9), `ProjectClientModel` (typeId 10), `SupplierProfile`
  (JSON in the settings box under `supplier_profile`), `StandaloneInvoiceModel.clientId` (HiveField 20,
  nullable). New `parseStringOrNull` in `json_utils.dart`. Adapters generated with build_runner;
  the regenerated adapters of untouched models were reverted, `lib/hive_registrar.g.dart` removed.
- Repositories: `ClientRepository`, `ProjectClientRepository` (`getByProject`, `getByClient`, `find`,
  `clientIdsForProjects` — most recently linked first), `SettingsRepository.get/set/clearSupplierProfile`.
  Both new repositories journal deletions. Wired in `main.dart`.
- `PocketBaseSyncService`:
  - new collections `clients`, `project_clients`, `invoices` (searchable columns + full invoice as
    `data` JSON) and `user_settings` (record `supplier_profile`);
  - `pushClient/deleteClient`, `pushProjectClient/deleteProjectClient`, `pushInvoice/deleteInvoice`,
    `pushSupplierProfile`, all through the ledger; `_localRecordMap` covers them for the offline queue;
  - `downloadAll` fetches them with `_downloadOptionalCollection` (404/403 → skipped, nothing touched)
    and reconciles with the same `_replaceLocal` + ledger + `SyncGuard` as the other collections;
  - supplier profile: the side with the later `updatedAt` wins; a local profile the server lacks is
    queued, never dropped (`_applyRemoteUserSettings`);
  - `uploadAll` → `_uploadClientData` (failures logged, not thrown);
  - real-time: `_subscribeClientCollections` subscribes only after `_serverHasCollection` confirms
    the collection exists, so no unknown topic is added to the shared realtime connection;
  - `clearLocalData` (account switch / sign-out with clear) now also wipes clients, links, invoices
    and the profile, journalled like the rest — otherwise account A's invoices would be uploaded
    into account B.
- `BackupService`: version 4 adds `clients`, `project_clients`, `supplier_profile`; restoring an
  older backup that has no `clients` key keeps the current clients and links.
- `pocketbase/pb_schema.json`: the four collections added (additive only, 318 inserted lines,
  existing definitions byte-identical). Not applied to any server.

### Design decisions

- No `client_ids` field on projects: the `projects` collection stays exactly as older builds
  (iPhone 1.0.11, eli.zizkova's device) expect it.
- Existing collections, `category_id` on projects and `project_id` on entries are untouched.

### Current state

- `flutter analyze --no-pub`: no issues.
- `TZ=Europe/Prague flutter test --no-pub`: 102 passed (94 + 8 new: 6 in
  `pocketbase_sync_service_test.dart` — missing collections keep the rest syncing and the new data
  queued, queued data goes out once the collections exist, full round trip incl. invoice, client
  order, profile newer-wins both ways, local-only profile uploaded; 2 in `backup_service_test.dart`
  — v4 round trip, v3 restore keeps clients). The fake server got a `missingCollections` switch.
- Proven by mutation: using `_downloadCollection` for clients, or clearing clients on every
  restore, makes the matching test fail; restored afterwards.
- Installed: backup `~/Documents/timer_counter_container_backup_2026-11-23_18-07-09/`, release build
  57.9 MB, `codesign --verify` OK, running from `/Applications` with the user's data; the new
  `clients.hive` / `project_clients.hive` boxes exist and are empty. The live server has none of the
  new collections, so this build only skips them; nothing new is sent.
- No UI for clients yet; nothing migrated.

### Pending / next steps

- Phase 2 (screens): Clients section, clients + service descriptions in the project form, new
  invoice flow (client pick, per-project or single line, editable items), supplier profile in
  Settings, hide categories, own export format; call the new push methods from the blocs.
- Phase 3 (server, needs the user's OK): PocketBase dump, import the four collections without
  deleting anything, dry run on a copy of both accounts, compare ids before/after.
- Phase 4: migrate this Mac's customers/suppliers/invoices, links from past time invoices.

## 2026-11-23 (part 3) — refactor: remove Tyme import; data model redesign (clients) proposed

### What was done

- Tyme import removed at the user's request (they will never use Tyme again):
  - deleted `lib/core/services/tyme_import_service.dart`, `tyme_data_import_service.dart`,
    `tyme_data_import_service_io.dart`, `tyme_data_import_service_stub.dart`;
  - `settings_screen.dart`: removed the "Import data" tile, `_showImportDialog` and `_ImportDialog`;
  - removed the `import` translation block and `settings.import_data` from en/cs;
  - `pubspec.yaml`: dropped `sqlite3` (only the Tyme `.data` reader used it); `pubspec.lock` updated by
    `flutter pub get`, the release bundle no longer ships `sqlite3.framework`;
  - README: "Data Export & Import" reduced to export.
  - The JSON/CSV export (`tyme_export_service.dart`, still Tyme format) and the backup/restore are kept.
- Data-model review for the planned rework (categories → clients). Page published as an artifact
  and saved as `docs/datovy-model.html`. Findings from the code:
  - there is no client entity: category "Medutech" and invoice customer "Medutech s.r.o." are unrelated;
    the customer is a global, index-based pick (`invoiceSelectedCustomerIndex`);
  - the invoice rate is the rate of the first entry's project in the month, else hard-coded 550
    (`pdf_report_service.dart:104–111`); `TaskModel.hourlyRate` is only used by the Tyme export;
  - customers, suppliers, bank/issuer settings, invoice counter, standalone invoices and the global
    work schedule are local-only (Hive + backup), not on PocketBase;
  - `TimeEntryModel`/`RunningTimerModel` store `projectId` next to `taskId`;
  - categories are only used for the Projects filter chips and Tyme import/export.
- User decisions: categories go away in the app; a project can have several clients (M:N) and clients
  sync; everything syncs; all PocketBase data must stay visible and the eli.zizkova account must keep
  working. Proposed design: new collections `clients`, `project_clients`, `supplier_profiles`,
  `invoices`, `user_settings`; existing collections unchanged (`projects` keeps `category_id`,
  `time_entries` keeps `project_id`), categories hidden but never deleted.

### Design decisions

- Project ↔ client as a separate `project_clients` collection instead of a `client_ids` field on
  projects: the `projects` collection stays byte-for-byte compatible with older builds (iPhone 1.0.11,
  eli.zizkova's device), the link can carry its own data (default flag, service description), and
  unlinking never touches issued invoices.
- Rollout order: PocketBase dump → additive schema import (no "delete missing") → dry run on a copy of
  both accounts → migration on the user's account only → other devices update whenever.

### Current state

- `flutter analyze --no-pub`: no issues. `TZ=Europe/Prague flutter test --no-pub`: 94 passed.
- Installed: container backup `~/Documents/timer_counter_container_backup_2026-11-23_17-50-18/`,
  clean `flutter build macos --release` (57.8 MB, `objective_c.framework` present,
  `codesign --verify --deep --strict` OK), `/Applications/Timer Counter.app` replaced and launched;
  screenshot shows the user's November entries.
- No data-model code written yet; nothing on PocketBase changed.

### Pending / next steps

- Open questions to the user: validity period (from–to) on the project–client link; per-link service
  description / hourly rate; keep or drop the Tyme-format JSON/CSV export; one or several supplier
  profiles.
- Then implement the clients model following the rollout order above.

## 2026-11-23 (part 2) — macOS desktop UI installed into /Applications; shorter sidebar label

### What was done

- New rule from the user: every change is built and installed into `/Applications/Timer Counter.app`
  on this Mac.
- Sidebar uses a new short key `nav.time_entries` ("Time Entries" / "Záznamy"); the Czech
  `time_entries.title` ("Přehled časových záznamů") was cut off in the 220 pt sidebar.
- Installed: container backed up to `~/Documents/timer_counter_container_backup_2026-11-23_17-11-47/`,
  `flutter clean && flutter pub get && flutter build macos --release`, bundle replaced (the previous
  installed bundle kept in the session scratchpad), app launched.

### Current state

- `flutter analyze --no-pub`: no issues.
- Release bundle: `objective_c.framework` and `sqlite3.framework` present,
  `codesign --verify --deep --strict` OK, ad-hoc signed, version 1.0.11.
- `/Applications/Timer Counter.app` running with the user's real data: the new sidebar and toolbars
  render (screenshot of "Sledování času"), today's two entries shown.
- The isolated preview copy was closed.

### Pending / next steps

- Same as the previous entry: dialogs, pushed screens and the invoice form in the new theme; dark
  mode; Windows layout; native macOS menu bar.
