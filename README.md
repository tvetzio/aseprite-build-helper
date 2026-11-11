# Aseprite Build Helper (ABH)

**Windows:** v1.3.11 · Windows 10/11 x64  
**Linux:** v1.2.0 · Linux x86_64  
**Repository:** https://github.com/tvetzio/aseprite-build-helper

ABH builds Aseprite locally from the official source repository and provides a guided setup, launcher, updater/maintenance tools, optional themes/add-ons/scripts, diagnostics and uninstall options on Windows and Linux.

> ABH does **not** distribute a precompiled Aseprite executable. Aseprite is downloaded from the official source repository and compiled locally on your system.

## Downloads

| Platform | Version | Package |
|---|---:|---|
| Windows x64 | v1.3.11 | `abh-win64-v1.3.11.zip` |
| Linux x86_64 | v1.2.0 | `abh-linux-x64-v1.2.0.tar.gz` / `abh-linux-x64-v1.2.0.zip` |

**Download releases:**  
https://github.com/tvetzio/aseprite-build-helper/releases

### Supported platforms

**Windows**
- Windows 10 x64
- Windows 11 x64

**Linux x86_64**
- Ubuntu / Debian
- Fedora
- Arch Linux
- openSUSE
- Void Linux

Ubuntu/Debian-based distributions may also work, but are not necessarily tested individually.

## Main features

Windows and Linux provide the same core ABH workflow:

- Guided first-time setup
- Local Aseprite build from the official source
- Aseprite launcher
- Aseprite Build Updater / maintenance tool
- Aseprite update detection and rebuild
- ABH self-update support
- Optional recommended theme/add-on/script pack
- Custom theme/add-on/script repositories
- Scheduled maintenance checks
- Configurable update interval
- Developer logs and diagnostics
- Bug-report package generation
- Desktop/application integration
- Safe uninstall

[English](#english) · [Deutsch](#deutsch)

---

<a id="english"></a>
# English

## Quick Start

### Windows

Before the first setup, install:

- **Visual Studio Community** or **Visual Studio Build Tools**
- Workload: **Desktop development with C++**
- Required MSVC x64/x86 tools
- Windows SDK
- Internet access

ABH can automatically provide the remaining build tools when required:

- Git / MinGit
- CMake
- Ninja
- Skia

If a suitable system installation already exists, ABH prefers it.

1. Download `abh-win64-v1.3.11.zip`.
2. Extract the complete ZIP into its own writable folder.
3. Keep all included release files together.
4. Start:

```text
aseprite-build-helper.bat
```

5. Follow the guided setup.

Recommended layout:

```text
abh-win64-v1.3.11\
├─ aseprite-build-helper.bat
├─ README.md
├─ LICENSE
└─ THIRD_PARTY_NOTICES.md
```

### Linux

The Linux helper detects the supported distribution and checks the required packages.

1. Download either:

```text
abh-linux-x64-v1.2.0.tar.gz
```

or:

```text
abh-linux-x64-v1.2.0.zip
```

2. Extract the archive into its own writable folder.

3. Make the helper executable:

```bash
chmod +x aseprite-build-helper.sh
```

4. Start:

```bash
./aseprite-build-helper.sh
```

5. Choose the guided first-time setup from the menu.

During first-time setup, ABH can offer to install the required system packages using the detected package manager.

The Linux helper currently supports:

- `apt` on Ubuntu / Debian
- `dnf` on Fedora
- `pacman` on Arch Linux
- `zypper` on openSUSE
- `xbps` on Void Linux

## First-time setup

ABH checks and prepares the required build environment before compiling Aseprite.

Typical workflow:

```text
Check prerequisites
Prepare Aseprite source
Prepare Skia
Configure CMake
Build Aseprite
Optional content synchronization
Create launcher / updater integration
Finish
```

Normal interactive output is intentionally kept concise.

Detailed Git, download, CMake and build output is written to developer logs instead of filling the terminal.

When the build completes successfully, ABH reports:

```text
Aseprite build completed successfully.
```

## Optional recommended content pack

During the first setup, ABH can ask whether the recommended optional content pack should be installed.

It can include selected:

- Themes
- Add-ons
- Lua scripts
- Game-development tools

The selection is stored in the ABH settings.

If the pack is declined, scheduled maintenance does not install it later without permission.

It can be enabled or managed later through the updater.

Third-party content is downloaded from its original repository and remains subject to the respective project's license and copyright terms.

## Desktop integration

ABH creates launch entries for:

### Aseprite

Starts the locally compiled Aseprite executable.

The launcher may also trigger a due scheduled maintenance check silently in the background.

### Aseprite Build Updater

Opens the visible maintenance tool.

It is used for:

- ABH self-updates
- Aseprite updates and rebuilds
- Theme/add-on/script synchronization
- Recommended content management
- Status
- Repair / resync
- Update interval
- Source configuration
- Logs and diagnostics
- Bug reports
- Uninstall

There is intentionally no separate uninstall shortcut.

### Windows

Desktop shortcuts are created for:

- `Aseprite`
- `Aseprite Build Updater`

### Linux

ABH creates application-menu entries and attempts to create desktop launchers for:

- `Aseprite`
- `Aseprite Build Updater`

Depending on the desktop environment, Linux may ask the user once to trust or allow launching a newly created `.desktop` file.

## Language

ABH automatically detects the system UI/locale language.

```text
de-* / de_*  → German
everything else → English
```

Manual overrides are available.

### Windows

```text
aseprite-build-helper.bat --lang=de
aseprite-build-helper.bat --lang=en
```

### Linux

```bash
./aseprite-build-helper.sh --lang=de
./aseprite-build-helper.sh --lang=en
```

## Update interval

Default scheduled maintenance interval:

```text
12 hours
```

The interval can be changed in the Aseprite Build Updater.

Scheduled maintenance remains silent and does not open unnecessary interactive windows.

## Add your own themes, add-ons or scripts

ABH uses one INI file per source repository.

Common source folders:

```text
ABH/config/sources/themes/
ABH/config/sources/addons/
ABH/config/sources/mixed/
```

On Windows the same structure uses Windows path separators.

Example:

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

For repositories added manually, keep:

```ini
auto_update=false
```

until you intentionally trust that repository for automatic updates.

## Runtime data

ABH keeps its own runtime data next to the helper package.

Typical structure:

```text
ABH/
├─ launcher/
├─ updater/
├─ uninstaller/
├─ config/
├─ logs/
├─ reports/
├─ backups/
├─ manifest/
├─ state/
├─ managed/
└─ tools/
```

Exact folders can differ slightly between Windows and Linux.

## Logs and diagnostics

ABH keeps normal user logs and more detailed developer logs.

Typical locations:

```text
ABH/logs/user/
ABH/logs/dev/
ABH/reports/
```

Technical output that is hidden from the normal interactive view remains available in the developer logs.

Diagnostic packages are **not uploaded automatically**. Review them before publishing.

Bug reports:

https://github.com/tvetzio/aseprite-build-helper/issues

## Aseprite build

ABH builds Aseprite locally from the official repository:

https://github.com/aseprite/aseprite

Current build configuration uses:

```text
Generator:  Ninja
Build type: RelWithDebInfo
Backend:    Skia
```

The required Skia revision is determined/validated by the helper for the supported Aseprite source.

No compiled Aseprite binary is included in an ABH release.

<details>
<summary><strong>Windows technical details</strong></summary>

Default Windows Aseprite paths:

```text
Source: C:\aseprite
Build:  C:\aseprite\build
EXE:    C:\aseprite\build\bin\aseprite.exe
```

Current expected Skia revision for the Windows build:

```text
m124-08a5439a6b
```

Classic external Skia path:

```text
C:\deps\skia
```

Expected library:

```text
C:\deps\skia\out\Release-x64\skia.lib
```

Portable tools managed by ABH are stored below:

```text
ABH\tools\
```

</details>

<details>
<summary><strong>Linux technical details</strong></summary>

Linux-managed Aseprite source/build and Skia files are kept below the ABH-managed runtime directories.

The helper uses:

- Clang
- CMake
- Ninja
- Skia
- `libstdc++` with the supported prebuilt Skia configuration

Full source/download/CMake/build output is written to developer logs.

Typical logs include:

```text
ABH/logs/dev/source-last.log
ABH/logs/dev/skia-download-last.log
ABH/logs/dev/cmake-last.log
ABH/logs/dev/build-last.log
```

The normal Aseprite user configuration is not replaced by ABH and remains under the platform's normal Aseprite configuration location.

</details>

## Uninstall

Use the **Aseprite Build Updater** and select the uninstall function.

ABH distinguishes between helper-owned runtime data and managed source/build content.

Before using destructive uninstall options, back up personal files stored inside managed folders.

ABH should not blindly remove unrelated external dependencies or normal user configuration that it does not clearly own.

## Third-party software and content

The included MIT license applies only to original ABH code and ABH-owned assets.

Aseprite, Skia, Git, CMake, Ninja, themes, add-ons, scripts and other third-party projects retain their own licenses and copyright terms.

Recommended third-party content is downloaded from the original project repositories.

Projects without sufficiently clear licensing are not intended to be silently treated as ABH-owned content.

See:

```text
THIRD_PARTY_NOTICES.md
```

## License

ABH is distributed under the MIT License.

ABH is an unofficial project and is not affiliated with or endorsed by the Aseprite project.

---

<a id="deutsch"></a>
# Deutsch

## Schnellstart

### Windows

Vor der ersten Einrichtung selbst installieren:

- **Visual Studio Community** oder **Visual Studio Build Tools**
- Workload: **Desktopentwicklung mit C++**
- benötigte MSVC-x64/x86-Buildtools
- Windows SDK
- Internetzugang

Die übrigen Build-Werkzeuge kann ABH bei Bedarf automatisch bereitstellen:

- Git / MinGit
- CMake
- Ninja
- Skia

Ist bereits eine geeignete Systeminstallation vorhanden, verwendet ABH diese bevorzugt.

1. `abh-win64-v1.3.11.zip` herunterladen.
2. Die komplette ZIP in einen eigenen beschreibbaren Ordner entpacken.
3. Alle enthaltenen Release-Dateien zusammenlassen.
4. Starten:

```text
aseprite-build-helper.bat
```

5. Der geführten Einrichtung folgen.

Empfohlene Ablage:

```text
abh-win64-v1.3.11\
├─ aseprite-build-helper.bat
├─ README.md
├─ LICENSE
└─ THIRD_PARTY_NOTICES.md
```

### Linux

Der Linux-Helper erkennt die unterstützte Distribution und prüft die benötigten Pakete.

1. Eine der beiden Dateien herunterladen:

```text
abh-linux-x64-v1.2.0.tar.gz
```

oder:

```text
abh-linux-x64-v1.2.0.zip
```

2. Das Archiv in einen eigenen beschreibbaren Ordner entpacken.

3. Den Helper ausführbar machen:

```bash
chmod +x aseprite-build-helper.sh
```

4. Starten:

```bash
./aseprite-build-helper.sh
```

5. Im Menü die geführte Ersteinrichtung auswählen.

Während der Ersteinrichtung kann ABH anbieten, benötigte Systempakete mit dem erkannten Paketmanager zu installieren.

Unterstützt werden aktuell:

- `apt` unter Ubuntu / Debian
- `dnf` unter Fedora
- `pacman` unter Arch Linux
- `zypper` unter openSUSE
- `xbps` unter Void Linux

## Ersteinrichtung

ABH prüft und vorbereitet zunächst die benötigte Build-Umgebung und kompiliert anschließend Aseprite.

Typischer Ablauf:

```text
Voraussetzungen prüfen
Aseprite-Quellcode vorbereiten
Skia vorbereiten
CMake konfigurieren
Aseprite kompilieren
optionale Inhalte synchronisieren
Launcher / Updater integrieren
Fertig
```

Die normale Anzeige bleibt bewusst übersichtlich.

Ausführliche Git-, Download-, CMake- und Build-Ausgaben werden in Entwickler-Logs geschrieben und nicht dauerhaft im Terminal angezeigt.

Nach erfolgreichem Build meldet ABH:

```text
Aseprite-Build erfolgreich abgeschlossen.
```

## Optionales empfohlenes Inhaltspaket

Bei der Ersteinrichtung kann ABH fragen, ob das optionale empfohlene Inhaltspaket installiert werden soll.

Es kann ausgewählte Inhalte enthalten:

- Themes
- Add-ons
- Lua-Skripte
- Game-Development-Tools

Die Auswahl wird in den ABH-Einstellungen gespeichert.

Wird das Paket abgelehnt, installiert die geplante Hintergrundwartung es später nicht ungefragt.

Das Paket kann später über den Updater aktiviert oder verwaltet werden.

Drittanbieter-Inhalte werden aus ihren ursprünglichen Repositories geladen und unterliegen weiterhin den jeweiligen Lizenz- und Urheberrechtsbedingungen.

## Desktop-Integration

ABH erzeugt Starteinträge für:

### Aseprite

Startet die lokal kompilierte Aseprite-Version.

Der Launcher kann zusätzlich eine fällige geplante Wartungsprüfung still im Hintergrund anstoßen.

### Aseprite Build Updater

Öffnet das sichtbare Wartungswerkzeug.

Darüber können unter anderem verwaltet werden:

- ABH-Self-Updates
- Aseprite-Updates und Rebuilds
- Themes/Add-ons/Skripte
- empfohlenes Inhaltspaket
- Status
- Reparatur / Resync
- Update-Intervall
- Quellen-Konfiguration
- Logs und Diagnose
- Bugreports
- Deinstallation

Es gibt bewusst keine separate Uninstall-Verknüpfung.

### Windows

ABH erzeugt Desktop-Verknüpfungen für:

- `Aseprite`
- `Aseprite Build Updater`

### Linux

ABH erzeugt Einträge im Anwendungsmenü und versucht Desktop-Starter anzulegen für:

- `Aseprite`
- `Aseprite Build Updater`

Je nach Desktop-Umgebung kann Linux einmalig verlangen, eine neu erzeugte `.desktop`-Datei als vertrauenswürdig bzw. startbar zu bestätigen.

## Sprache

ABH erkennt die Sprache automatisch anhand der System-UI bzw. Locale.

```text
de-* / de_* → Deutsch
alles andere → Englisch
```

Manuelle Auswahl:

### Windows

```text
aseprite-build-helper.bat --lang=de
aseprite-build-helper.bat --lang=en
```

### Linux

```bash
./aseprite-build-helper.sh --lang=de
./aseprite-build-helper.sh --lang=en
```

## Update-Intervall

Standardintervall für geplante Wartungsprüfungen:

```text
12 Stunden
```

Das Intervall kann im Aseprite Build Updater geändert werden.

Geplante Hintergrundprüfungen bleiben still und öffnen keine unnötigen interaktiven Fenster.

## Eigene Themes, Add-ons und Skripte

ABH verwendet eine INI-Datei pro Quell-Repository.

Typische Ordner:

```text
ABH/config/sources/themes/
ABH/config/sources/addons/
ABH/config/sources/mixed/
```

Unter Windows wird dieselbe Struktur mit Windows-Pfadtrennern verwendet.

Beispiel:

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

Bei selbst hinzugefügten Quellen zunächst:

```ini
auto_update=false
```

verwenden, bis dem Repository bewusst automatische Updates erlaubt werden sollen.

## Runtime-Daten

ABH hält seine eigenen Runtime-Daten neben dem Helper-Paket.

Typische Struktur:

```text
ABH/
├─ launcher/
├─ updater/
├─ uninstaller/
├─ config/
├─ logs/
├─ reports/
├─ backups/
├─ manifest/
├─ state/
├─ managed/
└─ tools/
```

Die genaue Ordnerstruktur kann sich zwischen Windows und Linux geringfügig unterscheiden.

## Logs und Diagnose

ABH führt normale Benutzer-Logs und ausführlichere Entwickler-Logs.

Typische Pfade:

```text
ABH/logs/user/
ABH/logs/dev/
ABH/reports/
```

Technische Ausgaben, die in der normalen Oberfläche ausgeblendet werden, bleiben in den Entwickler-Logs verfügbar.

Diagnosepakete werden **nicht automatisch hochgeladen**. Vor einer Veröffentlichung bitte selbst prüfen.

Bugreports:

https://github.com/tvetzio/aseprite-build-helper/issues

## Aseprite-Build

ABH kompiliert Aseprite lokal aus dem offiziellen Repository:

https://github.com/aseprite/aseprite

Aktuelle Build-Konfiguration:

```text
Generator:  Ninja
Build-Typ:  RelWithDebInfo
Backend:    Skia
```

Die benötigte Skia-Version wird für den unterstützten Aseprite-Source durch den Helper bestimmt bzw. validiert.

ABH-Releases enthalten keine fertig kompilierte Aseprite-Binärdatei.

<details>
<summary><strong>Technische Details – Windows</strong></summary>

Standardpfade:

```text
Quellcode: C:\aseprite
Build:     C:\aseprite\build
EXE:       C:\aseprite\build\bin\aseprite.exe
```

Aktuell erwartete Skia-Version für den Windows-Build:

```text
m124-08a5439a6b
```

Klassischer externer Skia-Pfad:

```text
C:\deps\skia
```

Erwartete Library:

```text
C:\deps\skia\out\Release-x64\skia.lib
```

Von ABH verwaltete portable Werkzeuge:

```text
ABH\tools\
```

</details>

<details>
<summary><strong>Technische Details – Linux</strong></summary>

Von ABH verwaltete Aseprite-Source-/Build- und Skia-Daten liegen innerhalb der verwalteten ABH-Runtime-Ordner.

Der Helper verwendet:

- Clang
- CMake
- Ninja
- Skia
- `libstdc++` für die unterstützte vorkompilierte Skia-Konfiguration

Ausführliche Source-/Download-/CMake-/Build-Ausgaben werden in Entwickler-Logs geschrieben.

Typische Logs:

```text
ABH/logs/dev/source-last.log
ABH/logs/dev/skia-download-last.log
ABH/logs/dev/cmake-last.log
ABH/logs/dev/build-last.log
```

Die normale Aseprite-Benutzerkonfiguration wird von ABH nicht ersetzt und verbleibt im üblichen Aseprite-Konfigurationspfad des Systems.

</details>

## Deinstallation

Die Deinstallation wird über den **Aseprite Build Updater** gestartet.

ABH unterscheidet zwischen eigenen Runtime-Daten und von ABH verwalteten Source-/Build-Inhalten.

Vor destruktiven Deinstallationsoptionen eigene Dateien sichern, die innerhalb verwalteter Ordner abgelegt wurden.

ABH soll keine fremden externen Abhängigkeiten oder normale Benutzerkonfiguration blind entfernen, wenn diese nicht eindeutig ABH gehören.

## Drittanbieter-Software und Inhalte

Die enthaltene MIT-Lizenz gilt ausschließlich für eigenen ABH-Code und ABH-eigene Assets.

Aseprite, Skia, Git, CMake, Ninja, Themes, Add-ons, Skripte und andere Drittprojekte behalten ihre eigenen Lizenzen und Urheberrechte.

Empfohlene Drittanbieter-Inhalte werden aus den ursprünglichen Projekt-Repositories geladen.

Projekte ohne ausreichend klare Lizenzierung werden nicht stillschweigend als ABH-eigene Inhalte behandelt.

Siehe:

```text
THIRD_PARTY_NOTICES.md
```

## Lizenz

ABH wird unter der MIT-Lizenz veröffentlicht.

ABH ist ein inoffizielles Projekt und steht nicht in Verbindung mit dem Aseprite-Projekt und wird von diesem nicht unterstützt.
