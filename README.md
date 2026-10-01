# Aseprite Build Helper (ABH)

**Current version: v1.3.2**  
**Platform: Windows 10/11 x64**  
**Repository:** https://github.com/tvetzio/aseprite-build-helper

ABH builds Aseprite locally from the official source repository and provides a launcher, updater/maintenance tool, theme/add-on management, backups, diagnostics and uninstall options.

> ABH does **not** ship a precompiled Aseprite executable. Aseprite is downloaded from the official repository and compiled locally on your PC.

[English](#english) · [Deutsch](#deutsch)

---

<a id="english"></a>
# English

## What you need

For a normal first setup, install only:

- Windows 10 or Windows 11 x64
- **Visual Studio Community** or **Visual Studio Build Tools**
- Visual Studio workload: **Desktop development with C++**
- Internet access for the first setup

The workload should include the required MSVC x64/x86 tools and Windows SDK.

ABH can automatically provide the remaining tools when needed:

- Git / MinGit
- CMake
- Ninja
- Skia

If a suitable system installation already exists, ABH prefers it.

## Quick Start

1. Download the latest ABH release ZIP.
2. Extract the **complete ZIP into its own folder**.
3. Keep the release files together in that folder.
4. Run:

```text
aseprite-build-helper.bat
```

5. Follow the helper step by step.

Recommended layout:

```text
abh-win64-v1.3.2\
├─ aseprite-build-helper.bat
├─ README.md
├─ LICENSE
└─ THIRD_PARTY_NOTICES.md
```

Do not move only the BAT file somewhere else and delete the other package files.

Typical first setup:

```text
[1/6] Check prerequisites
[2/6] Prepare Aseprite source
[3/6] Build Aseprite
[4/6] Sync themes / add-ons
[5/6] Create runtime and shortcuts
[6/6] Finish
```

ABH guides you through the complete process.

## What ABH creates

After setup, ABH creates its runtime folder next to the release files:

```text
ABH\
├─ launcher\
├─ updater\
├─ uninstaller\
├─ support\
├─ config\
├─ logs\
├─ reports\
├─ backups\
├─ manifest\
├─ state\
├─ managed\
└─ tools\
```

Default Aseprite paths:

```text
Source: C:\aseprite
Build:  C:\aseprite\build
EXE:    C:\aseprite\build\bin\aseprite.exe
```

Current default Aseprite tag:

```text
v1.3.18.6
```

## Desktop shortcuts

ABH creates two shortcuts:

### Aseprite

Starts the locally built Aseprite executable.

The launcher can also trigger the scheduled update check silently in the background.

### Aseprite Build Updater

Opens the visible maintenance tool.

Use it for:

- ABH self-updates
- Aseprite updates
- themes / add-ons / scripts
- status
- repair / resync
- update interval
- source configuration
- backups
- logs and diagnostics
- bug reports
- uninstall

There is intentionally **no separate uninstall shortcut**. Uninstall is available through the updater.

## Aseprite Build Updater

Current menu:

```text
[1] Check all updates now
[2] Check ABH self-update only
[3] Check Aseprite update only
[4] Sync themes / add-ons / scripts
[5] Show status
[6] Repair / resync
[7] Change update interval
[8] Open source configurations
[9] Back up Aseprite configuration
[A] Restore newest configuration backup
[L] Open logs
[M] Show files/folders managed by ABH
[D] Create diagnostic package
[R] Report a bug
[U] Uninstall
[0] Exit
```

Manual maintenance stays visible in the same console window. Scheduled launcher checks remain hidden.

## Settings

Default update interval:

```text
12 hours
```

Change it via:

```text
Aseprite Build Updater
→ [7] Change update interval
```

Settings are stored in:

```text
ABH\config\settings.ini
```

Language detection:

```text
de-*   → German
other  → English
```

Manual override:

```text
aseprite-build-helper.bat --lang=de
aseprite-build-helper.bat --lang=en
```

Confirmations use **Y/N in both languages**:

```text
Y = Yes / Ja
N = No / Nein
```

## Add your own themes, add-ons or scripts

ABH uses one INI file per Git repository.

Folders:

```text
ABH\config\sources\themes\
ABH\config\sources\addons\
ABH\config\sources\mixed\
```

Theme example:

```ini
[Source]
name=My Theme
type=theme
repository=https://github.com/USER/REPOSITORY.git
enabled=true
auto_update=false
install_mode=auto
managed_by=user
```

Add-on example:

```ini
[Source]
name=My Add-on
type=addon
repository=https://github.com/USER/REPOSITORY.git
enabled=true
auto_update=false
install_mode=auto
managed_by=user
```

Use the `mixed` folder if one repository contains multiple content types.

For repositories you add yourself, keep:

```ini
auto_update=false
```

until you intentionally trust the repository for automatic updates.

To enable automatic updates:

```ini
auto_update=true
```

Only enable automatic updates for repositories you trust.

Open the source configuration folders with:

```text
[8] Open source configurations
```

Synchronize configured sources with:

```text
[4] Sync themes / add-ons / scripts
```

## Backups

ABH can back up the Aseprite configuration from:

```text
%APPDATA%\Aseprite
```

Use:

```text
[9] Back up Aseprite configuration
[A] Restore newest configuration backup
```

Source configuration files can also be exported during a full uninstall.

## Logs, diagnostics and bug reports

Logs:

```text
ABH\logs\user\
ABH\logs\dev\
```

Reports:

```text
ABH\reports\
```

Useful actions:

```text
[L] Open logs
[D] Create diagnostic package
[R] Report a bug
```

Issues:

```text
https://github.com/tvetzio/aseprite-build-helper/issues
```

Diagnostic files are not uploaded automatically. Review them before publishing.

## Repair

Use:

```text
[6] Repair / resync
```

to recreate/resynchronize ABH runtime files and managed content.

If the actual Aseprite Git checkout is damaged, runtime repair may not be enough.

## Uninstall

Open:

```text
Aseprite Build Updater
→ [U] Uninstall
```

Options:

```text
[1] Remove helper runtime only
[2] Remove runtime + shortcuts
[3] Remove runtime + shortcuts + backups
[4] Remove Aseprite source/build
[5] REMOVE ALL
[6] REMOVE ALL + export source configurations as ZIP
[0] Cancel
```

Before destructive options, back up any personal files stored inside managed folders.

An external Skia installation such as `C:\deps\skia` is not blindly deleted if it is not clearly ABH-managed.

## What each tool does

**`aseprite-build-helper.bat`**
- first setup
- prerequisite checks
- source preparation
- build/rebuild
- runtime creation

**Aseprite shortcut**
- starts locally compiled Aseprite
- can trigger the silent scheduled update check

**Aseprite Build Updater shortcut**
- ABH/Aseprite updates
- themes/add-ons/scripts
- update settings
- repair
- backup/restore
- logs/diagnostics
- uninstall

**`ABH\uninstaller\uninstall-abh.bat`**
- performs the selected uninstall operation
- normally started through the updater

## Technical details

Build configuration:

```text
Generator:   Ninja
Build type:  RelWithDebInfo
Backend:     Skia
```

Expected Skia revision:

```text
m124-08a5439a6b
```

Classic Skia path:

```text
C:\deps\skia
```

Library:

```text
C:\deps\skia\out\Release-x64\skia.lib
```

Portable tools are stored under `ABH\tools\`.

## Troubleshooting

If Visual Studio is not detected, verify this workload in Visual Studio Installer:

```text
Desktop development with C++
```

If setup fails, check:

```text
ABH\logs\dev\
ABH\logs\user\
```

If `C:\aseprite` is a damaged checkout from an older failed test, back it up or rename it before a completely fresh test. Check for your own uncommitted changes first.

## License

The included MIT license applies only to the original ABH code.

Aseprite, Skia, Git, CMake, Ninja, themes, add-ons, scripts and other third-party projects keep their own licenses.

See `THIRD_PARTY_NOTICES.md`.

---

<a id="deutsch"></a>
# Deutsch

## Was brauche ich?

Für die normale Ersteinrichtung musst du nur Folgendes selbst installieren:

- Windows 10 oder Windows 11 x64
- **Visual Studio Community** oder **Visual Studio Build Tools**
- Visual-Studio-Workload: **Desktopentwicklung mit C++**
- Internetverbindung für die Ersteinrichtung

Die Workload sollte die benötigten MSVC-x64/x86-Buildtools und ein Windows SDK enthalten.

Den Rest kann ABH bei Bedarf automatisch bereitstellen:

- Git / MinGit
- CMake
- Ninja
- Skia

Ist bereits eine passende Systeminstallation vorhanden, verwendet ABH diese bevorzugt.

## Schnellstart

1. Die aktuelle ABH-Release-ZIP herunterladen.
2. Die **komplette ZIP in einen eigenen Ordner entpacken**.
3. Alle Release-Dateien zusammen in diesem Ordner lassen.
4. Starten:

```text
aseprite-build-helper.bat
```

5. Danach einfach Schritt für Schritt den Anweisungen des Helpers folgen.

Empfohlene Ablage:

```text
abh-win64-v1.3.2\
├─ aseprite-build-helper.bat
├─ README.md
├─ LICENSE
└─ THIRD_PARTY_NOTICES.md
```

Nicht nur die BAT-Datei aus dem entpackten Ordner verschieben und den Rest löschen.

Typischer Ablauf:

```text
[1/6] Voraussetzungen prüfen
[2/6] Aseprite-Quellcode vorbereiten
[3/6] Aseprite kompilieren
[4/6] Themes / Add-ons synchronisieren
[5/6] Runtime und Verknüpfungen erzeugen
[6/6] Fertig
```

Der Helper führt dich Schritt für Schritt durch die komplette Einrichtung.

## Was ABH erstellt

Nach dem Setup entsteht neben den Release-Dateien:

```text
ABH\
├─ launcher\
├─ updater\
├─ uninstaller\
├─ support\
├─ config\
├─ logs\
├─ reports\
├─ backups\
├─ manifest\
├─ state\
├─ managed\
└─ tools\
```

Standardpfade:

```text
Quellcode: C:\aseprite
Build:     C:\aseprite\build
EXE:       C:\aseprite\build\bin\aseprite.exe
```

Aktuell verwendeter Aseprite-Tag:

```text
v1.3.18.6
```

## Desktop-Verknüpfungen

ABH erstellt zwei Desktop-Verknüpfungen:

### Aseprite

Startet deine lokal kompilierte Aseprite-Version.

Der Launcher kann zusätzlich im Hintergrund die geplante Update-Prüfung anstoßen.

### Aseprite Build Updater

Öffnet das sichtbare Wartungsmenü.

Darüber kannst du:

- ABH aktualisieren
- Aseprite aktualisieren
- Themes/Add-ons/Skripte synchronisieren
- Status anzeigen
- Reparatur/Resync ausführen
- Update-Intervall ändern
- Quellen konfigurieren
- Backups erstellen/wiederherstellen
- Logs und Diagnose öffnen
- Bugs melden
- deinstallieren

Es gibt bewusst **keine eigene Uninstall-Verknüpfung**. Die Deinstallation wird über den Updater gestartet.

## Aseprite Build Updater

Aktuelles Menü:

```text
[1] Alle Updates jetzt prüfen
[2] Nur ABH-Self-Update prüfen
[3] Nur Aseprite-Update prüfen
[4] Themes / Add-ons / Skripte synchronisieren
[5] Status anzeigen
[6] Reparatur / neu synchronisieren
[7] Update-Intervall ändern
[8] Quellen-Konfigurationen öffnen
[9] Aseprite-Konfiguration sichern
[A] Neuestes Konfigurations-Backup wiederherstellen
[L] Logs öffnen
[M] Von ABH verwaltete Dateien/Ordner anzeigen
[D] Diagnosepaket erstellen
[R] Bug melden
[U] Deinstallieren
[0] Beenden
```

Der manuelle Updater bleibt sichtbar und zeigt den Fortschritt im selben Konsolenfenster. Hintergrundprüfungen über den Launcher bleiben unsichtbar.

## Einstellungen

Standard-Updateintervall:

```text
12 Stunden
```

Ändern über:

```text
Aseprite Build Updater
→ [7] Update-Intervall ändern
```

Gespeichert in:

```text
ABH\config\settings.ini
```

Spracherkennung:

```text
de-*   → Deutsch
sonst  → Englisch
```

Manuell:

```text
aseprite-build-helper.bat --lang=de
aseprite-build-helper.bat --lang=en
```

Bestätigungen verwenden **in beiden Sprachen Y/N**:

```text
Y = Yes / Ja
N = No / Nein
```

## Eigene Themes, Add-ons und Skripte hinzufügen

ABH verwendet eine INI-Datei pro Git-Repository.

Ordner:

```text
ABH\config\sources\themes\
ABH\config\sources\addons\
ABH\config\sources\mixed\
```

Theme-Beispiel:

```ini
[Source]
name=Mein Theme
type=theme
repository=https://github.com/USER/REPOSITORY.git
enabled=true
auto_update=false
install_mode=auto
managed_by=user
```

Add-on-Beispiel:

```ini
[Source]
name=Mein Add-on
type=addon
repository=https://github.com/USER/REPOSITORY.git
enabled=true
auto_update=false
install_mode=auto
managed_by=user
```

Für Repositories mit mehreren Inhaltstypen den Ordner `mixed` verwenden.

Bei selbst hinzugefügten Quellen zunächst:

```ini
auto_update=false
```

verwenden.

Wenn du dem Repository vertraust und ABH es automatisch aktualisieren darf:

```ini
auto_update=true
```

Automatische Updates nur für Quellen aktivieren, denen du vertraust.

Quellen-Konfiguration öffnen:

```text
[8] Quellen-Konfigurationen öffnen
```

Quellen synchronisieren/aktualisieren:

```text
[4] Themes / Add-ons / Skripte synchronisieren
```

## Backups

ABH kann die Aseprite-Konfiguration sichern:

```text
%APPDATA%\Aseprite
```

Aktionen:

```text
[9] Aseprite-Konfiguration sichern
[A] Neuestes Konfigurations-Backup wiederherstellen
```

Beim vollständigen Uninstall können außerdem die Quellen-Konfigurationen separat exportiert werden.

## Logs, Diagnose und Bugreports

Logs:

```text
ABH\logs\user\
ABH\logs\dev\
```

Reports:

```text
ABH\reports\
```

Nützliche Aktionen:

```text
[L] Logs öffnen
[D] Diagnosepaket erstellen
[R] Bug melden
```

GitHub Issues:

```text
https://github.com/tvetzio/aseprite-build-helper/issues
```

Diagnosedateien werden nicht automatisch hochgeladen. Vor dem öffentlichen Teilen bitte selbst prüfen.

## Reparatur

Mit:

```text
[6] Reparatur / neu synchronisieren
```

können erzeugte ABH-Runtime-Dateien und verwaltete Inhalte repariert bzw. neu synchronisiert werden.

Ist das eigentliche Aseprite-Git-Repository beschädigt, reicht eine normale Runtime-Reparatur möglicherweise nicht aus.

## Deinstallation

Aufruf:

```text
Aseprite Build Updater
→ [U] Deinstallieren
```

Optionen:

```text
[1] Nur Helper-Runtime entfernen
[2] Runtime + Verknüpfungen entfernen
[3] Runtime + Verknüpfungen + Backups entfernen
[4] Aseprite Source/Build entfernen
[5] REMOVE ALL
[6] REMOVE ALL + Quellen-Konfigurationen als ZIP exportieren
[0] Abbrechen
```

Vor destruktiven Optionen eigene Dateien in verwalteten Ordnern sichern.

Eine externe Skia-Installation wie `C:\deps\skia` wird nicht blind gelöscht, wenn sie nicht eindeutig von ABH verwaltet wird.

## Was machen die einzelnen Tools?

**`aseprite-build-helper.bat`**
- Ersteinrichtung
- Prüfung der Voraussetzungen
- Source-Vorbereitung
- Build/Rebuild
- Runtime-Erzeugung

**Desktop-Verknüpfung `Aseprite`**
- startet die lokal kompilierte Aseprite-Version
- kann die stille geplante Update-Prüfung anstoßen

**Desktop-Verknüpfung `Aseprite Build Updater`**
- ABH-/Aseprite-Updates
- Themes/Add-ons/Skripte
- Update-Einstellungen
- Reparatur
- Backup/Restore
- Logs/Diagnose
- Uninstall

**`ABH\uninstaller\uninstall-abh.bat`**
- führt die gewählte Deinstallationsoption aus
- normalerweise über den Updater starten

## Technische Informationen

Build-Konfiguration:

```text
Generator:   Ninja
Build-Typ:   RelWithDebInfo
Backend:     Skia
```

Erwartete Skia-Version:

```text
m124-08a5439a6b
```

Klassischer Skia-Pfad:

```text
C:\deps\skia
```

Library:

```text
C:\deps\skia\out\Release-x64\skia.lib
```

Portable Werkzeuge liegen unter `ABH\tools\`.

## Fehlerbehebung

Wird Visual Studio nicht erkannt, im Visual Studio Installer prüfen:

```text
Desktopentwicklung mit C++
```

Bei Setup-Fehlern prüfen:

```text
ABH\logs\dev\
ABH\logs\user\
```

Ist `C:\aseprite` ein beschädigter Checkout aus einem älteren Test, den Ordner vor einem komplett frischen Test sichern oder umbenennen. Vorher eigene/nicht commitete Änderungen prüfen.

## Lizenz

Die MIT-Lizenz gilt ausschließlich für den eigenen ABH-Code.

Aseprite, Skia, Git, CMake, Ninja, Themes, Add-ons, Skripte und andere Drittprojekte behalten ihre eigenen Lizenzen.

Siehe `THIRD_PARTY_NOTICES.md`.
