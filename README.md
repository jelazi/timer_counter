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

## Licence

Tento projekt je pro osobní použití.
