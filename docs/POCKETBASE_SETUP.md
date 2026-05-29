# PocketBase setup for a new implementation

This guide explains how to deploy a fresh PocketBase server and connect Timer Counter to it for a new user or a new customer installation.

## What the app expects

The app syncs these PocketBase collections:

- `users` auth collection
- `categories`
- `projects`
- `tasks`
- `time_entries`
- `running_timers`
- `monthly_targets`
- `day_overrides`

Every synced collection uses an `item_id` field for the app's local UUID and a required `user` relation to the authenticated PocketBase user. API rules restrict records to their owner, so one PocketBase server can host multiple users without mixing their data.

## Before you build for another user

1. Do not ship a real `lib/config/pocketbase_config.json` from another user.
2. Use `lib/config/pocketbase_config.example.json` only as a template.
3. For a customer build, either leave PocketBase unconfigured and enter credentials in the app settings, or create a fresh `lib/config/pocketbase_config.json` with that customer's server URL and app user.
4. Check invoice settings in the app after first launch. Defaults are intentionally blank so each user fills their own supplier, customer, bank, and issuer details.

## Option A: Deploy with Coolify

### 1. Create a VPS

1. Create a server, for example on Hetzner Cloud.
2. Ubuntu 24.04 with a small instance is enough for PocketBase.
3. Add an SSH key.
4. Note the server IP address.

### 2. Point a domain to the server

Create an A record such as:

```text
pb.example.com -> <server-ip>
```

Wait for DNS propagation before enabling HTTPS.

### 3. Install Coolify

SSH into the server and run:

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Then open Coolify, create the admin account, and finish the setup wizard.

### 4. Add PocketBase as a Docker image

1. In Coolify, create a project.
2. Add a new Docker image resource.
3. Use this image:

```text
ghcr.io/muchobien/pocketbase:latest
```

4. Expose port `8090`.
5. Set the public domain to `https://pb.example.com`.
6. Add persistent storage:

```text
/pb/pb_data
```

7. Deploy the resource.

### 5. Create the PocketBase admin

Open:

```text
https://pb.example.com/_/
```

On the first visit, PocketBase asks you to create the admin account.

## Option B: Deploy with Docker directly

Create a folder on the server and add `docker-compose.yml`:

```yaml
services:
  pocketbase:
    image: ghcr.io/muchobien/pocketbase:latest
    restart: unless-stopped
    ports:
      - "8090:8090"
    volumes:
      - ./pb_data:/pb/pb_data
```

Start it:

```bash
docker compose up -d
```

Put it behind HTTPS with Caddy, Nginx, Traefik, or another reverse proxy. The app should use the HTTPS URL in production.

## Import the app schema

The schema is stored in `pocketbase/pb_schema.json`.

1. Open PocketBase Admin UI.
2. Go to Settings -> Import collections.
3. Paste the full contents of `pocketbase/pb_schema.json`.
4. Review and confirm the import.
5. Verify that all seven app collections exist: `categories`, `projects`, `tasks`, `time_entries`, `running_timers`, `monthly_targets`, and `day_overrides`.

The schema includes API rules so authenticated users can list, view, update, and delete only their own records.

## Create an app user

1. In Admin UI, open the `users` collection.
2. Create a record for the person who will use the app.
3. Set email and password.
4. Keep these credentials for the app configuration.

For separate users, create separate records in the same `users` collection. Their synced records stay separated by the `user` relation and API rules.

## Connect the app

### Recommended: configure in the app UI

1. Start the app.
2. Open Settings -> PocketBase.
3. Enter:
   - URL: `https://pb.example.com`
   - Email: the app user's email
   - Password: the app user's password
4. Use Test Connection.
5. Save Override.
6. If local data already exists, use Upload All to push it to the new server. If the server already has data, use Download All carefully.

### Alternative: bundle a config file

Copy the example file:

```bash
cp lib/config/pocketbase_config.example.json lib/config/pocketbase_config.json
```

Edit `lib/config/pocketbase_config.json`:

```json
{
    "url": "https://pb.example.com",
    "email": "user@example.com",
    "password": "change-this-password"
}
```

`lib/config/pocketbase_config.json` is gitignored because it contains credentials. If it exists during `flutter build windows`, those credentials are bundled into the app. Use this only for a dedicated build for that exact user.

## First sync behavior

On first successful PocketBase connection, the app compares local Hive data and remote PocketBase data:

- remote empty + local has data: uploads local data
- local empty + remote has data: downloads remote data
- both empty: marks sync as ready
- both have data: asks the user to choose upload, download, or skip
- already synced before: does not run first-sync detection again

## Windows build and install notes

### Prerequisites on the build machine

- Flutter SDK with Windows desktop support enabled
- Visual Studio Build Tools or Visual Studio with Desktop development with C++
- A valid PocketBase configuration, either entered later in Settings or bundled for this specific user

### Build

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

The release output is under:

```text
build/windows/x64/runner/Release/
```

Distribute the whole `Release` folder or package it with an installer. The `.exe` alone is not enough because Flutter also needs the adjacent DLLs and data files.

### Functional differences on Windows

Most app features are shared with macOS and Linux. The current macOS-only feature is work reminder notifications in `WorkReminderService`; Windows builds skip that service. Time tracking, projects, tasks, reports, invoices, local Hive storage, import/export, system tray, launch at startup, and PocketBase sync are expected to work on Windows.

## Troubleshooting

| Problem | Check |
|---|---|
| Test Connection fails | URL must point to the PocketBase root, not `/_/` or `/api` |
| Auth fails | Confirm the user exists in `users` and the password is correct |
| Sync returns 404 for `day_overrides` | Import the latest `pocketbase/pb_schema.json` |
| Sync works for one user but not another | Verify records have the correct `user` relation and API rules were imported |
| Realtime sync does not update | Check proxy/firewall support for Server-Sent Events |
| Windows app starts without sync | Check Settings -> PocketBase or whether a valid config was bundled |
| Release folder moved and app fails | Keep all generated files in the `Release` folder together |

## Backup

PocketBase stores data in `pb_data`. Back up the whole directory, or at minimum the SQLite database file inside it. When using Coolify, configure a persistent volume and automated backups for that volume.

---

# PocketBase nastavení pro novou instalaci

Tento návod vysvětluje, jak nasadit nový PocketBase server a připojit k němu Timer Counter pro nového uživatele nebo pro čistou zákaznickou instalaci.

## Co aplikace očekává

Aplikace synchronizuje tyto PocketBase kolekce:

- `users` auth kolekce
- `categories`
- `projects`
- `tasks`
- `time_entries`
- `running_timers`
- `monthly_targets`
- `day_overrides`

Každá synchronizovaná kolekce používá pole `item_id` jako UUID z lokální aplikace a povinnou relaci `user` na přihlášeného uživatele PocketBase. API pravidla omezují záznamy pouze na jejich vlastníka, takže jeden PocketBase server může hostovat více uživatelů bez míchání dat.

## Než připravíš build pro jiného uživatele

1. Nikdy nebal reálný `lib/config/pocketbase_config.json` patřící jinému uživateli.
2. Používej `lib/config/pocketbase_config.example.json` jen jako šablonu.
3. Pro zákaznický build buď nech PocketBase nenakonfigurovaný a přihlašovací údaje zadej až v aplikaci, nebo vytvoř nové `lib/config/pocketbase_config.json` s URL serveru a app userem pro konkrétního zákazníka.
4. Po prvním spuštění zkontroluj fakturační nastavení v aplikaci. Výchozí hodnoty jsou schválně prázdné, aby si je každý uživatel doplnil sám.

## Varianta A: nasazení přes Coolify

### 1. Vytvoř VPS

1. Vytvoř server, například na Hetzner Cloud.
2. Pro PocketBase stačí Ubuntu 24.04 na menší instanci.
3. Přidej SSH klíč.
4. Poznamenej si IP adresu serveru.

### 2. Nastav doménu na server

V DNS vytvoř A záznam například:

```text
pb.example.com -> <server-ip>
```

Počkej na propagaci DNS před zapnutím HTTPS.

### 3. Nainstaluj Coolify

Připoj se přes SSH na server a spusť:

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Potom otevři Coolify, vytvoř administrační účet a dokonči inicializační průvodce.

### 4. Přidej PocketBase jako Docker image

1. V Coolify vytvoř projekt.
2. Přidej nový Docker image resource.
3. Použij tento image:

```text
ghcr.io/muchobien/pocketbase:latest
```

4. Otevři port `8090`.
5. Nastav veřejnou doménu na `https://pb.example.com`.
6. Přidej persistentní úložiště:

```text
/pb/pb_data
```

7. Resource nasaď.

### 5. Vytvoř PocketBase admina

Otevři:

```text
https://pb.example.com/_/
```

Při prvním otevření PocketBase požádá o vytvoření admin účtu.

## Varianta B: nasazení přes Docker přímo

Na serveru vytvoř složku a přidej `docker-compose.yml`:

```yaml
services:
  pocketbase:
    image: ghcr.io/muchobien/pocketbase:latest
    restart: unless-stopped
    ports:
      - "8090:8090"
    volumes:
      - ./pb_data:/pb/pb_data
```

Spusť jej:

```bash
docker compose up -d
```

Před produkčním použitím ho dej za HTTPS reverzní proxy jako Caddy, Nginx nebo Traefik. Aplikace by v produkci měla používat HTTPS URL.

## Import aplikačního schématu

Schéma je uložené v `pocketbase/pb_schema.json`.

1. Otevři PocketBase Admin UI.
2. Přejdi do Settings -> Import collections.
3. Vlož celý obsah `pocketbase/pb_schema.json`.
4. Zkontroluj a potvrď import.
5. Ověř, že existuje všech sedm aplikačních kolekcí: `categories`, `projects`, `tasks`, `time_entries`, `running_timers`, `monthly_targets` a `day_overrides`.

Schéma obsahuje API pravidla, takže přihlášení uživatelé mohou číst, upravovat a mazat jen své vlastní záznamy.

## Vytvoření app uživatele

1. V Admin UI otevři kolekci `users`.
2. Vytvoř záznam pro člověka, který bude aplikaci používat.
3. Nastav e-mail a heslo.
4. Tyto údaje si ponech pro konfiguraci aplikace.

Pro více uživatelů vytvářej samostatné záznamy ve stejné kolekci `users`. Jejich synchronizovaná data zůstávají oddělená pomocí relace `user` a API pravidel.

## Připojení aplikace

### Doporučeno: konfigurace přímo v aplikaci

1. Spusť aplikaci.
2. Otevři Settings -> PocketBase.
3. Zadej:
   - URL: `https://pb.example.com`
   - Email: e-mail app uživatele
   - Password: heslo app uživatele
4. Použij Test Connection.
5. Ulož Override.
6. Pokud už existují lokální data, použij Upload All a pošli je na nový server. Pokud už data jsou na serveru, používej Download All opatrně.

### Alternativa: zabalení config souboru

Zkopíruj šablonu:

```bash
cp lib/config/pocketbase_config.example.json lib/config/pocketbase_config.json
```

Uprav `lib/config/pocketbase_config.json`:

```json
{
    "url": "https://pb.example.com",
    "email": "user@example.com",
    "password": "change-this-password"
}
```

`lib/config/pocketbase_config.json` je v `.gitignore`, protože obsahuje přihlašovací údaje. Pokud existuje při `flutter build windows`, tyto údaje se zabalí přímo do aplikace. Používej to jen pro dedikovaný build pro konkrétního uživatele.

## Chování při první synchronizaci

Při prvním úspěšném připojení k PocketBase aplikace porovná lokální Hive data a vzdálená PocketBase data:

- remote prázdný + local má data: nahraje lokální data
- local prázdný + remote má data: stáhne vzdálená data
- oba prázdné: označí sync jako připravený
- oba mají data: nabídne uživateli upload, download nebo přeskočení
- už synchronizováno dříve: první sync kontrola se už nespustí

## Poznámky k instalaci a buildu na Windows

### Požadavky na build stroji

- Flutter SDK s podporou Windows desktopu
- Visual Studio Build Tools nebo Visual Studio s workloadem Desktop development with C++
- platná PocketBase konfigurace, buď zadaná později v aplikaci, nebo zabalená jen pro konkrétního uživatele

### Build

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

Výstup releasu je v:

```text
build/windows/x64/runner/Release/
```

Distribuuj celou složku `Release`, nebo ji zabal do instalátoru. Samotné `.exe` nestačí, protože Flutter potřebuje i sousední DLL soubory a data.

### Funkční rozdíly na Windows

Většina funkcí je společná pro macOS, Windows i Linux. Aktuální macOS-only funkce jsou work reminder notifikace v `WorkReminderService`; Windows build tuto službu přeskočí. Sledování času, projekty, úkoly, reporty, faktury, lokální Hive storage, import/export, systémová lišta, spuštění při startu a PocketBase sync by na Windows měly fungovat.

## Troubleshooting

| Problém | Kontrola |
|---|---|
| Test Connection selže | URL musí ukazovat na root PocketBase, ne na `/_/` nebo `/api` |
| Auth selže | Ověř, že uživatel existuje v `users` a heslo je správné |
| Sync vrací 404 pro `day_overrides` | Naimportuj nejnovější `pocketbase/pb_schema.json` |
| Sync funguje pro jednoho uživatele, ale ne pro jiného | Ověř správnou relaci `user` a importovaná API pravidla |
| Realtime sync se neupdatuje | Zkontroluj proxy/firewall a podporu pro Server-Sent Events |
| Windows aplikace se spustí bez syncu | Zkontroluj Settings -> PocketBase nebo jestli byl zabalený validní config |
| Po přesunutí Release složky aplikace nefunguje | Ponech všechny generované soubory ve složce `Release` pohromadě |

## Záloha

PocketBase ukládá data do `pb_data`. Zálohuj celou složku, nebo minimálně SQLite databázový soubor uvnitř. Při použití Coolify nastav persistentní volume a automatické zálohy pro tento volume.
