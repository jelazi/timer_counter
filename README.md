# Timer Counter

A cross-platform time tracking desktop application built with Flutter. Track your work hours, manage projects and tasks, view statistics, and export/import data in Tyme-compatible JSON format.

![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.10+-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Windows%20|%20Linux-lightgrey.svg)

## Features

### Time Tracking
- **Live timer** — Start/stop timer with one click, track time for specific projects and tasks
- **Manual entry** — Add time entries manually with date picker, start/end time, notes, and billable toggle
- **Multiple timers** — Optionally run multiple timers simultaneously
- **Quick start** — Inline project/task selection with remembered last used project

### Projects & Tasks
- **Project management** — Create projects with categories, colors, hourly rates, planned time/budget
- **Task management** — Organize tasks within projects with individual rates
- **Archive** — Archive completed projects while keeping their data

### Time Entries Overview
- **Monthly view** — Browse all entries grouped by day with month navigation
- **Timeline visualization** — 24-hour horizontal bar per day showing colored time blocks
- **Edit & delete** — Modify or remove existing entries with overlap validation
- **Day totals** — See total tracked time per day and per month

### Statistics & Reports
- **Preset ranges** — Today, This Week, This Month, This Year
- **Custom ranges** — Pick specific day, week, month, year, or custom date range
- **Summary cards** — Worked hours, billable hours, revenue, daily average
- **Daily chart** — Bar chart of hours worked per day
- **Project distribution** — Pie chart with percentage and time per project

### Data Export & Import
- **Export** — Tyme-compatible JSON format with selectable date range and custom filename
- **Import** — Import from Tyme JSON with three modes:
  - **Merge** — Update existing entries, add new ones (match by ID)
  - **Append** — Add imported data alongside existing data
  - **Overwrite** — Replace all data with imported data
- **Smart import** — Auto-creates categories, projects, and tasks if they don't exist; skips duplicates by name

### System Integration
- **System tray** — Minimize to system tray with quick-access menu for starting/stopping timers
- **Tray info** — Shows running timer and daily total in tray tooltip
- **Launch at startup** — Optional auto-start with the system
- **Dock hiding** — Hide from macOS dock when minimized to tray (macOS only)

### General
- **Multi-language** — English and Czech (Čeština) with locale-aware date/month names
- **Themes** — Light, Dark, and System theme modes
- **Time rounding** — Optional rounding to 5/10/15/30 minutes
- **Overlap protection** — Prevents overlapping time entries (configurable)
- **Currency support** — CZK, EUR, USD, GBP

## Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter** | UI framework |
| **flutter_bloc** | State management (BLoC pattern) |
| **Hive CE** | Local NoSQL database |
| **easy_localization** | Internationalization (i18n) |
| **fl_chart** | Charts (bar, pie) |
| **system_tray** | System tray integration |
| **window_manager** | Window management |
| **file_picker** | File/directory selection |
| **Google Fonts (Inter)** | Typography (bundled, no network) |

## Architecture

```
lib/
├── app/                    # App shell, system tray service
├── core/
│   ├── constants/          # App constants, Hive box names
│   ├── services/           # Export, import, dock services
│   ├── theme/              # App theme configuration
│   └── utils/              # Time formatting utilities
├── data/
│   ├── datasources/        # Data source abstractions
│   ├── models/             # Hive data models (Category, Project, Task, TimeEntry)
│   └── repositories/       # Data access layer
├── presentation/
│   ├── blocs/              # BLoC classes (category, project, task, timer, statistics, settings)
│   ├── screens/            # Main screens (tracking, projects, statistics, settings, overview)
│   └── widgets/            # Reusable widgets
└── main.dart               # Entry point
```

## Getting Started

### Prerequisites
- Flutter SDK 3.10+
- Dart SDK 3.10+

### Install dependencies
```bash
flutter pub get
```

### Generate Hive adapters
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Run on macOS
```bash
flutter run -d macos
```

### Run on Windows
```bash
flutter run -d windows
```

### Run on Linux
```bash
flutter run -d linux
```

### Build release
```bash
flutter build macos
flutter build windows
flutter build linux
```

## License

This project is for personal use.

---

# Timer Counter (Česky)

Multiplatformní desktopová aplikace pro sledování času vytvořená ve Flutteru. Sledujte pracovní hodiny, spravujte projekty a úkoly, prohlížejte statistiky a exportujte/importujte data v Tyme-kompatibilním JSON formátu.

## Funkce

### Sledování času
- **Živý časovač** — Spuštění/zastavení jedním kliknutím, sledování času pro konkrétní projekty a úkoly
- **Ruční zadání** — Přidávání záznamů ručně s výběrem data, času začátku/konce, poznámek a přepínače fakturovatelnosti
- **Více časovačů** — Volitelné spuštění více časovačů současně
- **Rychlý start** — Inline výběr projektu/úkolu s pamatováním posledního použitého

### Projekty a úkoly
- **Správa projektů** — Vytváření projektů s kategoriemi, barvami, hodinovými sazbami, plánovaným časem/rozpočtem
- **Správa úkolů** — Organizace úkolů v rámci projektů s individuálními sazbami
- **Archivace** — Archivace dokončených projektů se zachováním dat

### Přehled časových záznamů
- **Měsíční zobrazení** — Procházení všech záznamů seskupených po dnech s navigací po měsících
- **Vizualizace časové osy** — 24hodinový horizontální pás pro každý den s barevnými bloky
- **Úprava a mazání** — Změna nebo odstranění existujících záznamů s kontrolou překrývání
- **Denní součty** — Celkový sledovaný čas za den a za měsíc
- **České názvy** — Měsíce a dny v týdnu zobrazeny v češtině při české lokalizaci

### Statistiky a reporty
- **Přednastavená období** — Dnes, Tento týden, Tento měsíc, Tento rok
- **Vlastní období** — Výběr konkrétního dne, týdne, měsíce, roku
- **Souhrnné karty** — Odpracované hodiny, fakturovatelné hodiny, příjmy, denní průměr
- **Denní graf** — Sloupcový graf odpracovaných hodin za den
- **Rozložení projektů** — Koláčový graf s procentuálním zastoupením a časem za projekt

### Export a import dat
- **Export** — Tyme-kompatibilní JSON formát s volitelným obdobím a vlastním názvem souboru
- **Import** — Import z Tyme JSON se třemi režimy:
  - **Sloučit** — Aktualizace existujících záznamů, přidání nových (shoda podle ID)
  - **Přidat** — Přidání importovaných dat ke stávajícím
  - **Přepsat** — Nahrazení všech dat importovanými
- **Chytrý import** — Automaticky vytváří kategorie, projekty a úkoly pokud neexistují; přeskakuje duplicity podle názvu

### Systémová integrace
- **Systémová lišta** — Minimalizace do systémové lišty s rychlým menu pro správu časovačů
- **Informace v liště** — Zobrazení běžícího časovače a denního celku v tooltipu
- **Spuštění při startu** — Volitelné automatické spuštění se systémem
- **Skrytí z Docku** — Skrytí z macOS Docku při minimalizaci (pouze macOS)

### Obecné
- **Vícejazyčnost** — Angličtina a čeština s lokalizovanými názvy měsíců a dnů
- **Motivy** — Světlý, tmavý a systémový režim
- **Zaokrouhlování času** — Volitelné zaokrouhlování na 5/10/15/30 minut
- **Ochrana překrývání** — Zabránění překrývajícím se záznamům (nastavitelné)
- **Podpora měn** — CZK, EUR, USD, GBP

## Začínáme

### Předpoklady
- Flutter SDK 3.10+
- Dart SDK 3.10+

### Instalace závislostí
```bash
flutter pub get
```

### Generování Hive adaptérů
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Spuštění na macOS
```bash
flutter run -d macos
```

### Sestavení release verze
```bash
flutter build macos
```

---

## PocketBase Deployment Guide (Hetzner + Coolify)

Step-by-step guide to deploy PocketBase on a Hetzner VPS using Coolify and configure the database for this app.

### 1. Create a Hetzner VPS

1. Go to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Create a new project (e.g. `timer-counter`)
3. **Add Server**:
   - Location: any (e.g. `Falkenstein`)
   - Image: **Ubuntu 24.04**
   - Type: **CX22** (2 vCPU, 4 GB RAM) — cheapest option sufficient for PocketBase
   - SSH Key: add your public key (or use password)
   - Name: e.g. `coolify-server`
4. Note the server **IP address**

### 2. Point Domain to Server

1. In your DNS provider, create an **A record**:
   - `pb.yourdomain.com` → `<server-ip>`
2. Optionally create a wildcard for Coolify:
   - `*.coolify.yourdomain.com` → `<server-ip>`
3. Wait for DNS propagation (usually 1–5 minutes)

### 3. Install Coolify

SSH into your server and run:

```bash
ssh root@<server-ip>
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

After installation:
1. Open `http://<server-ip>:8000` in your browser
2. Create your Coolify admin account
3. Complete the initial setup wizard

### 4. Deploy PocketBase via Coolify

#### 4.1 Create a New Resource

1. In Coolify dashboard, go to **Projects** → Create a new project (e.g. `Timer Counter`)
2. Click **+ New** → **Add a Resource**
3. Select **Docker Image**
4. Set the Docker image to:
   ```
   ghcr.io/muchobien/pocketbase:latest
   ```
5. Set a name (e.g. `pocketbase`)

#### 4.2 Configure the Resource

1. **Network** tab:
   - Port exposes: `8090`
   - Set domain: `https://pb.yourdomain.com`
2. **Storage** tab — Add a persistent volume:
   - Container path: `/pb/pb_data`
   - Name: `pocketbase_data`
3. **Environment Variables** (optional):
   - No env vars needed for default config
4. Click **Deploy**

#### 4.3 Verify

1. Open `https://pb.yourdomain.com/_/` — this is the PocketBase **Admin UI**
2. Create your **admin account** (first visit only)
3. You should see the PocketBase admin dashboard

### 5. Import Database Schema

The collection definitions and API rules are in `pocketbase/pb_schema.json` (gitignored — copy it from the repo locally).

1. Open PocketBase Admin UI → **Settings** → **Import collections**
2. Paste the contents of `pocketbase/pb_schema.json`
3. Click **Review** → **Confirm and import**

This creates 6 collections (`categories`, `projects`, `tasks`, `time_entries`, `running_timers`, `monthly_targets`) with all fields, relations, and API rules pre-configured.

> **API Rules** (already included in schema): each collection restricts List/View/Update/Delete to `@request.auth.id != "" && user = @request.auth.id` — users can only access their own records.

### 6. Create User Account

Users can register directly from the app (Sign Up button), or you can create them manually:

1. In Admin UI → **Collections** → **users**
2. Click **+ New record**
3. Fill in email and password
4. The app will authenticate with these credentials

### 7. Connect the App

1. Open the app → **Settings** → **Cloud Sync** section
2. Click **Configure** (or Sign In)
3. Enter:
   - **Server URL**: `https://pb.yourdomain.com`
   - **Email**: your user email
   - **Password**: your password
4. Click **Sign In** (or **Sign Up** to create a new account)
5. Once connected, real-time sync starts automatically
6. Use **Upload** to push local data to PocketBase
7. Use **Download** to pull remote data to the app

### 8. Backups (Optional)

PocketBase stores all data in a single SQLite file. To backup:

```bash
# SSH into server
ssh root@<server-ip>

# Find the PocketBase data volume
docker volume ls | grep pocketbase

# Copy the database file
docker cp <container-id>:/pb/pb_data/data.db ./backup_$(date +%Y%m%d).db
```

Or configure automated backups in Coolify's settings.

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't reach admin UI | Check Coolify deployment logs, verify DNS, check port 8090 |
| Auth fails | Verify user exists in the `users` collection |
| Sync not working | Check API rules are set for all collections |
| SSL certificate error | Coolify auto-provisions Let's Encrypt — wait a few minutes |
| Real-time not updating | Check browser/network firewall isn't blocking SSE connections |

## Licence

Tento projekt je pro osobní použití.
