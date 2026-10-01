# Aseprite Build Helper

**Version 1.2.9 · Windows x64 · Unofficial**  
Created and maintained by **Etzio**  
Project: https://github.com/tvetzio/aseprite-build-helper

> [!IMPORTANT]
> **Extract the package into its own writable folder before running it.**
> Do not leave the four files loose on the Desktop. ABH creates an `ABH\` working folder next to `aseprite-build-helper.bat` for its launcher, updater, configuration, logs, backups and other runtime data.
>
> Example:
>
> ```text
> C:\Users\<YOU>\AsepriteBuildHelper\
> ```

[English](#english) · [Deutsch](#deutsch)

---

<a id="english"></a>
## English

Aseprite Build Helper (ABH) is an unofficial Windows x64 helper for compiling Aseprite from the official source repository and maintaining the resulting local build.

ABH does **not** distribute a compiled `aseprite.exe`. Aseprite is cloned from the official repository and compiled locally on your computer.

### Current v1.2.9 behavior

The current runtime is based on the stable v1.2 flow and incorporates the fixes made during the v1.2.x test cycle: the builder remains the setup/compiler component, the **Aseprite Build Updater** owns maintenance and manual updates, the normal launcher performs scheduled checks invisibly, interactive progress stays in the same console, ABH self-update failures do not block Aseprite/theme/add-on checks, the uninstaller is launched from a temporary copy so it can remove the managed runtime folder, and bug-report diagnostics are generated locally before the GitHub issue page is opened.

### Package contents

The release ZIP contains only:

```text
aseprite-build-helper.bat
README.md
LICENSE
THIRD_PARTY_NOTICES.md
```

Everything under `ABH\` is generated after setup.

### Quick setup

1. Create a dedicated writable folder.
2. Extract all four package files into that folder.
3. Run `aseprite-build-helper.bat`.
4. Complete the prerequisite check once.
5. The remaining setup runs automatically.

First setup performs:

```text
Check prerequisites
→ Prepare Aseprite source
→ Validate Skia
→ Build Aseprite
→ Install/sync themes and add-ons
→ Create launcher, updater and uninstaller
→ Create desktop shortcuts
→ Finish
```

A short Windows system sound is played after a successful setup and Aseprite is started.

If the package files are placed directly on the Desktop, ABH warns before continuing because the helper creates several working folders beside the BAT file.

### Prerequisites

ABH checks for:

- Git for Windows
- CMake
- Ninja
- Visual Studio C++ toolchain
- Windows SDK
- required Skia files
- sufficient free disk space

The current initial build expects Skia at:

```text
C:\deps\skia\out\Release-x64\skia.lib
```

Initial Skia package:

https://github.com/aseprite/skia/releases/download/m124-08a5439a6b/Skia-Windows-Release-x64.zip

### Language

ABH detects the Windows UI language automatically:

- `de-*` → German
- all other languages → English

The builder also supports:

```text
aseprite-build-helper.bat --lang=de
aseprite-build-helper.bat --lang=en
```

The generated updater and uninstaller use the same language detection.

### What is created after setup?

ABH keeps generated data in a single `ABH\` folder beside the original package files:

```text
ABH\
├─ launcher\
│  ├─ aseprite-launcher.vbs
│  └─ helper_icon.ico
├─ updater\
│  ├─ aseprite-build-updater.bat
│  ├─ force_update.ico
│  └─ backup\                 # previous ABH package files after self-updates
├─ uninstaller\
│  ├─ uninstall-abh.bat
│  └─ uninstall.ico
├─ support\                   # internal PowerShell/Lua helper components
├─ config\
│  ├─ settings.ini
│  └─ sources\
│     ├─ themes\
│     ├─ addons\
│     └─ mixed\
├─ logs\
│  ├─ user\
│  └─ dev\
├─ reports\
├─ backups\
├─ manifest\
├─ state\
└─ managed\
```

Do not use ABH-managed directories as personal storage. Destructive uninstall options can remove complete managed folders, including files that you manually placed inside them.

### Desktop shortcuts

ABH creates only two desktop shortcuts:

- **Aseprite** — normal everyday launch
- **Aseprite Build Updater** — updates, maintenance, configuration, diagnostics and uninstall access

There is intentionally **no separate uninstall shortcut**. The uninstaller stays inside `ABH\uninstaller\` and is opened from Aseprite Build Updater.

Old v1.1 shortcuts such as `Aseprite - Force Update Check` and `Aseprite Build Helper - Uninstall` are removed when v1.2 runtime files are repaired/generated.

### Builder vs. launcher vs. updater vs. uninstaller

The components have separate responsibilities.

#### `aseprite-build-helper.bat`

The original package BAT is primarily the compiler/setup component:

- first setup
- prerequisite validation
- initial source clone
- Skia validation
- compile/recompile Aseprite
- check/build a new Aseprite release
- repair the generated launcher/updater/uninstaller

After setup, double-clicking it shows only compiler-related choices. Normal maintenance has been moved out of the builder.

#### `ABH\launcher\aseprite-launcher.vbs`

The launcher is used by the **Aseprite** shortcut. It starts the updater silently in scheduled mode. If no check is due, Aseprite starts without a visible maintenance window.

#### `ABH\updater\aseprite-build-updater.bat`

This is the central maintenance application and is opened by **Aseprite Build Updater**.

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
[M] Show files and folders managed by ABH
[D] Export diagnostic package for a bug report
[R] Report a bug
[U] Uninstall
[0] Exit
```

#### `ABH\uninstaller\uninstall-abh.bat`

The uninstaller has its own folder and is only launched from the updater or manually from that folder.

### Scheduled update checks

Default interval: **12 hours**.

The scheduled launcher checks:

1. ABH itself
2. Aseprite
3. themes
4. add-ons/scripts

The interval can be changed from **Aseprite Build Updater → Change update interval**:

```text
1 hour
3 hours
6 hours
12 hours (default)
24 hours
custom value (minimum 1 hour)
```

The selected value is stored in:

```text
ABH\config\settings.ini
```

### ABH self-update

Aseprite Build Updater can check the official project releases for a newer ABH version:

https://github.com/tvetzio/aseprite-build-helper

Self-update behavior:

1. Check the latest official GitHub Release.
2. Compare it with the locally installed ABH version.
3. Show the new version when one is available.
4. Ask for confirmation before installing it.
5. Download the matching `abh-win64-v*.zip` release asset.
6. Validate that the required package files exist in the ZIP.
7. Back up the current four package files.
8. Replace only the package files.
9. Regenerate the v1.2 runtime components.
10. Restart Aseprite Build Updater.

ABH configuration, source INIs, logs, reports and backups under `ABH\` are preserved.

If applying the update fails, ABH attempts to restore the previous package files and regenerate the previous runtime components.

Self-update never installs a release without user confirmation. A scheduled background check can detect that an update exists, but installation remains a user decision.

> Self-update requires the GitHub repository/release to be reachable. If it is private or GitHub cannot be reached, ABH simply keeps the installed version and continues.

### Progress, colors and completion sound

First setup and interactive update operations show progress directly in the current console window. Scheduled checks from the Aseprite launcher stay hidden.

Interactive setup and updater operations show their current step directly in the same console window. Scheduled checks started by the normal **Aseprite** shortcut stay hidden.

Colors indicate the current operation:

- **Blue/Cyan** — checks and Aseprite-related operations
- **Purple** — theme operations
- **Green** — add-ons/scripts and successful completion
- **Orange/Yellow** — configure/build/compile operations
- **Yellow** — warnings
- **Red** — errors

Some operations such as compilation or cloning cannot provide a trustworthy exact percentage. ABH therefore shows phase/step progress instead of inventing an exact value.

ABH plays a short built-in Windows system sound after a **successful interactive completion** of:

- first-time setup
- a manual update run
- a manual theme/add-on/script synchronization
- a successful repair/resync or rebuild operation

Scheduled background checks stay silent. No additional audio file is included in the package. The completion sound is not intentionally played for an aborted or failed operation.

### Source configuration: one INI per repository

Every theme/add-on source has its own INI file:

```text
ABH\config\sources\themes\
ABH\config\sources\addons\
ABH\config\sources\mixed\
```

Example:

```ini
[Source]
name=My custom add-on
type=addon
repository=https://github.com/USER/REPOSITORY.git
enabled=true
auto_update=false
install_mode=both
managed_by=user
```

Important values:

- `enabled=true` — ABH uses the source
- `enabled=false` — ABH ignores the source
- `auto_update=true` — ABH may pull new revisions automatically
- `auto_update=false` — ABH keeps the cached copy and does not pull it automatically
- `install_mode=scripts` — scripts
- `install_mode=extensions` — Aseprite extensions
- `install_mode=both` — both mechanisms

User-added repositories should normally start with `auto_update=false`. Enable automatic updates only for repositories you trust.

ABH creates user templates that can be copied and edited. Mixed repositories belong in `sources\mixed\`.

### Backups, logs and bug reports

Aseprite Build Updater can:

- back up `%APPDATA%\Aseprite`
- restore the newest ABH-created Aseprite configuration backup
- open user/developer logs
- export a diagnostic ZIP
- open the GitHub issue page

Diagnostic files are created locally and are **not uploaded automatically**.

ABH attempts to redact common sensitive values from diagnostic exports, but you should still review a diagnostic package before attaching it publicly.

Found a bug?

https://github.com/tvetzio/aseprite-build-helper/issues

### Uninstaller

Open:

```text
Aseprite Build Updater
→ [U] Uninstall
```

The generated uninstaller currently offers:

```text
[1] Remove helper runtime files only
[2] Remove helper runtime files + generated shortcuts
[3] Remove helper runtime, shortcuts and ABH backups
[4] Remove local Aseprite source/build folders
[5] REMOVE ALL ABH-managed content
[6] REMOVE ALL + export source configurations to ZIP
[0] Cancel
```

Options **4, 5 and 6** show additional warnings before destructive actions.

ABH explicitly warns that complete managed folders can contain your own files, themes, scripts, patches or source modifications. Those files can be deleted together with the managed folder.

`REMOVE ALL` requires an additional typed confirmation.

Option 6 first exports:

```text
ABH\config\sources\
```

into a ZIP such as:

```text
ABH-source-config-backup-YYYYMMDD-HHMMSS.zip
```

next to the original package files. A later setup can detect this backup and offer to restore the source configurations.

Skia is intentionally not removed by `REMOVE ALL`, because ABH does not automatically install Skia.

After a complete uninstall, the original downloaded package files remain untouched unless you delete them yourself.

### License and third-party software

The MIT license in this repository applies to original ABH code. It does not relicense Aseprite, Skia, themes, add-ons or other third-party projects.

See `THIRD_PARTY_NOTICES.md` for third-party project links and notices.

---

<a id="deutsch"></a>
## Deutsch

Aseprite Build Helper (ABH) ist ein inoffizieller Windows-x64-Helfer, der Aseprite aus dem offiziellen Quellcode lokal kompiliert und den daraus entstandenen Build verwaltet.

ABH verteilt **keine kompilierte `aseprite.exe`**. Der Aseprite-Quellcode wird aus dem offiziellen Repository geklont und auf deinem Computer kompiliert.

### Aktuelles Verhalten in v1.2.9

Die aktuelle Runtime basiert wieder auf dem stabilen v1.2-Ablauf und enthält die während der v1.2.x-Testphase vorgenommenen Korrekturen: Der Builder bleibt Setup-/Compiler-Komponente, der **Aseprite Build Updater** übernimmt Wartung und manuelle Updates, der normale Launcher führt geplante Prüfungen unsichtbar aus, interaktiver Fortschritt bleibt im selben Konsolenfenster, ein nicht erreichbares ABH-Self-Update blockiert keine Aseprite-/Theme-/Add-on-Prüfungen, der Uninstaller wird aus einer temporären Kopie gestartet, damit der verwaltete Runtime-Ordner entfernt werden kann, und Bugreport-Diagnosen werden lokal erzeugt, bevor die GitHub-Issue-Seite geöffnet wird.

### Inhalt der ZIP

Die Release-ZIP enthält nur:

```text
aseprite-build-helper.bat
README.md
LICENSE
THIRD_PARTY_NOTICES.md
```

Alle Dateien im Ordner `ABH\` werden erst nach der Einrichtung erzeugt.

### Schnelleinrichtung

1. Erstelle einen eigenen beschreibbaren Ordner.
2. Entpacke alle vier Paketdateien gemeinsam dort hinein.
3. Starte `aseprite-build-helper.bat`.
4. Führe die Prüfung der Voraussetzungen einmal durch.
5. Der restliche Ablauf erfolgt danach automatisch.

Die Ersteinrichtung führt folgende Schritte aus:

```text
Voraussetzungen prüfen
→ Aseprite-Quellcode vorbereiten
→ Skia prüfen
→ Aseprite kompilieren
→ Themes und Add-ons installieren/synchronisieren
→ Launcher, Updater und Uninstaller erzeugen
→ Desktop-Verknüpfungen erstellen
→ Abschluss
```

Nach erfolgreicher Ersteinrichtung ertönt ein kurzer Windows-Systemsound und Aseprite wird gestartet.

Liegen die Paketdateien lose direkt auf dem Desktop, warnt ABH vorher. Der Grund ist, dass ABH neben der BAT mehrere Arbeitsordner erzeugt.

### Voraussetzungen

ABH prüft unter anderem:

- Git for Windows
- CMake
- Ninja
- Visual-Studio-C++-Toolchain
- Windows SDK
- erforderliche Skia-Dateien
- freien Speicherplatz

Für den derzeitigen initialen Build wird Skia hier erwartet:

```text
C:\deps\skia\out\Release-x64\skia.lib
```

Skia-Paket:

https://github.com/aseprite/skia/releases/download/m124-08a5439a6b/Skia-Windows-Release-x64.zip

### Sprache

ABH erkennt automatisch die Windows-Oberflächensprache:

- `de-*` → Deutsch
- alle anderen Sprachen → Englisch

Manuelle Auswahl beim Builder:

```text
aseprite-build-helper.bat --lang=de
aseprite-build-helper.bat --lang=en
```

Updater und Uninstaller verwenden dieselbe Spracherkennung.

### Erzeugte Ordnerstruktur

Nach der Einrichtung liegt alles, was ABH selbst erzeugt, im Ordner `ABH\`:

```text
ABH\
├─ launcher\
│  ├─ aseprite-launcher.vbs
│  └─ helper_icon.ico
├─ updater\
│  ├─ aseprite-build-updater.bat
│  ├─ force_update.ico
│  └─ backup\
├─ uninstaller\
│  ├─ uninstall-abh.bat
│  └─ uninstall.ico
├─ support\
├─ config\
│  ├─ settings.ini
│  └─ sources\
│     ├─ themes\
│     ├─ addons\
│     └─ mixed\
├─ logs\
│  ├─ user\
│  └─ dev\
├─ reports\
├─ backups\
├─ manifest\
├─ state\
└─ managed\
```

ABH-verwaltete Ordner sollten nicht als persönlicher Speicherort verwendet werden. Bei destruktiven Deinstallationsoptionen können komplette verwaltete Ordner entfernt werden – einschließlich Dateien, die du selbst darin abgelegt hast.

### Desktop-Verknüpfungen

ABH erstellt nur noch zwei Verknüpfungen:

- **Aseprite** — normaler Start
- **Aseprite Build Updater** — Updates, Wartung, Konfiguration, Diagnose und Zugriff auf die Deinstallation

Es gibt bewusst **keine eigene Uninstall-Verknüpfung**. Der Uninstaller bleibt unter `ABH\uninstaller\` und wird über den Aseprite Build Updater geöffnet.

Alte v1.1-Verknüpfungen wie `Aseprite - Force Update Check` oder `Aseprite Build Helper - Uninstall` werden bei der v1.2-Runtime-Reparatur entfernt.

### Aufgaben der einzelnen Komponenten

#### `aseprite-build-helper.bat`

Die ursprüngliche BAT ist der Setup-/Compiler-Teil:

- Ersteinrichtung
- Prüfung der Build-Voraussetzungen
- initiales Klonen des Quellcodes
- Skia-Prüfung
- Aseprite kompilieren/neu kompilieren
- neue Aseprite-Releases prüfen und gegebenenfalls bauen
- Launcher, Updater und Uninstaller reparieren

Nach der Einrichtung zeigt ein direkter Start nur noch compilerbezogene Funktionen. Die laufende Wartung liegt nicht mehr im Builder.

#### `ABH\launcher\aseprite-launcher.vbs`

Diese Datei wird von der Verknüpfung **Aseprite** verwendet. Sie startet den Updater unsichtbar im geplanten Prüfmodus. Ist keine Prüfung fällig, startet Aseprite ohne sichtbares Wartungsmenü.

#### `ABH\updater\aseprite-build-updater.bat`

Der Aseprite Build Updater ist die zentrale Verwaltungsoberfläche.

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
[M] Von ABH verwaltete Dateien und Ordner anzeigen
[D] Diagnosepaket für Bugreport erstellen
[R] Bug melden
[U] Deinstallieren
[0] Beenden
```

#### `ABH\uninstaller\uninstall-abh.bat`

Der Uninstaller liegt in einem eigenen Ordner. Er wird über den Updater oder bei Bedarf direkt aus diesem Ordner gestartet.

### Automatische Update-Prüfungen

Standardintervall: **12 Stunden**.

Geprüft werden:

1. ABH selbst
2. Aseprite
3. Themes
4. Add-ons/Skripte

Das Intervall kann unter **Aseprite Build Updater → Update-Intervall ändern** gesetzt werden auf:

```text
1 Stunde
3 Stunden
6 Stunden
12 Stunden (Standard)
24 Stunden
benutzerdefiniert (mindestens 1 Stunde)
```

Gespeichert wird der Wert unter:

```text
ABH\config\settings.ini
```

### Self-Update von ABH

Der Aseprite Build Updater kann im offiziellen Projekt nach einer neueren ABH-Version suchen:

https://github.com/tvetzio/aseprite-build-helper

Ablauf eines Self-Updates:

1. Aktuelles offizielles GitHub Release prüfen.
2. Release-Version mit der installierten ABH-Version vergleichen.
3. Neue Version anzeigen.
4. Vor der Installation ausdrücklich nachfragen.
5. Passendes Release-Asset `abh-win64-v*.zip` herunterladen.
6. Inhalt der ZIP auf die erwarteten Paketdateien prüfen.
7. Die vier vorhandenen Paketdateien sichern.
8. Nur diese Paketdateien ersetzen.
9. Launcher, Updater und Uninstaller mit der neuen Version neu erzeugen.
10. Aseprite Build Updater neu starten.

Konfigurationen, Quellen-INIs, Logs, Reports und Backups unter `ABH\` bleiben erhalten.

Schlägt das Einspielen fehl, versucht ABH automatisch, die zuvor gesicherten Paketdateien wiederherzustellen und die vorherige Runtime erneut zu erzeugen.

Eine neue ABH-Version wird **niemals ohne Bestätigung installiert**. Eine automatische Hintergrundprüfung darf feststellen, dass ein Update vorhanden ist; die eigentliche Installation bleibt eine Entscheidung des Nutzers.

> Für die Self-Update-Prüfung muss das GitHub-Repository/Release erreichbar sein. Ist das Repository privat oder GitHub nicht erreichbar, bleibt die installierte Version einfach bestehen.

### Fortschritt, Farben und Abschlusston

Interaktive Einrichtung und Updater-Vorgänge zeigen den aktuellen Schritt direkt im selben Konsolenfenster. Geplante Prüfungen über die normale **Aseprite**-Verknüpfung bleiben unsichtbar.

Farben:

- **Blau/Cyan** — Prüfungen und Aseprite-bezogene Vorgänge
- **Violett** — Themes
- **Grün** — Add-ons/Skripte und erfolgreicher Abschluss
- **Orange/Gelb** — Build/Kompilierung
- **Gelb** — Warnungen
- **Rot** — Fehler

Einige Vorgänge wie Kompilieren oder Klonen liefern keinen verlässlichen exakten Prozentwert. ABH zeigt deshalb Phasen-/Schrittfortschritt an, statt einen ungenauen Wert vorzutäuschen.

Nach einem **erfolgreichen interaktiven Abschluss** spielt ABH einen kurzen vorhandenen Windows-Systemton ab, unter anderem nach:

- der Ersteinrichtung
- einem manuellen Update-Durchlauf
- einer manuellen Theme-/Add-on-/Skript-Synchronisierung
- einer erfolgreichen Reparatur/Neusynchronisierung oder einem Rebuild

Geplante Hintergrundprüfungen bleiben stumm. Es wird keine zusätzliche Audiodatei mitgeliefert. Bei einem abgebrochenen oder fehlgeschlagenen Vorgang soll bewusst kein Abschlusston abgespielt werden.

### Eine INI pro Theme/Add-on/Repository

Jede Quelle besitzt ihre eigene INI:

```text
ABH\config\sources\themes\
ABH\config\sources\addons\
ABH\config\sources\mixed\
```

Beispiel:

```ini
[Source]
name=Mein eigenes Add-on
type=addon
repository=https://github.com/USER/REPOSITORY.git
enabled=true
auto_update=false
install_mode=both
managed_by=user
```

Bedeutung:

- `enabled=true` — ABH verwendet die Quelle
- `enabled=false` — Quelle wird ignoriert
- `auto_update=true` — ABH darf automatisch neue Revisionen holen
- `auto_update=false` — vorhandene lokale Kopie wird verwendet, aber nicht automatisch aktualisiert
- `install_mode=scripts` — Skripte
- `install_mode=extensions` — Aseprite-Erweiterungen
- `install_mode=both` — beides

Bei selbst hinzugefügten Repositories sollte `auto_update=false` zunächst beibehalten werden. Aktiviere automatische Updates nur bei Quellen, denen du vertraust.

### Backups, Logs und Bugreports

Der Updater kann:

- `%APPDATA%\Aseprite` sichern
- das neueste von ABH erstellte Konfigurations-Backup wiederherstellen
- User-/Dev-Logs öffnen
- ein Diagnosepaket als ZIP exportieren
- die GitHub-Issue-Seite öffnen

Diagnosedateien werden **niemals automatisch hochgeladen**.

ABH versucht typische sensible Werte im Diagnoseexport zu zensieren. Vor einem öffentlichen Upload solltest du das Paket trotzdem selbst prüfen.

Fehler gefunden?

https://github.com/tvetzio/aseprite-build-helper/issues

### Deinstallation

Aufruf:

```text
Aseprite Build Updater
→ [U] Deinstallieren
```

Der Uninstaller bietet:

```text
[1] Nur Helper-Laufzeitdateien entfernen
[2] Helper-Laufzeitdateien + erzeugte Verknüpfungen entfernen
[3] Helper-Laufzeitdateien, Verknüpfungen und ABH-Backups entfernen
[4] Lokale Aseprite-Quell-/Build-Ordner entfernen
[5] ALLE von ABH verwalteten Inhalte entfernen
[6] ALLES entfernen + Quellen-Konfigurationen als ZIP exportieren
[0] Abbrechen
```

Bei **4, 5 und 6** erscheinen zusätzliche Warnungen.

ABH weist ausdrücklich darauf hin, dass verwaltete Ordner auch eigene Dateien, Themes, Skripte, Patches oder Quellcodeänderungen enthalten können. Beim vollständigen Löschen des Ordners werden diese ebenfalls entfernt.

`ALLES ENTFERNEN` erfordert zusätzlich eine ausgeschriebene Bestätigung.

Option 6 sichert vorher:

```text
ABH\config\sources\
```

in eine Datei wie:

```text
ABH-source-config-backup-YYYYMMDD-HHMMSS.zip
```

neben den ursprünglichen Paketdateien. Eine spätere Einrichtung kann diese ZIP erkennen und die Quellen-Konfigurationen auf Wunsch wiederherstellen.

Skia wird bei `ALLES ENTFERNEN` bewusst nicht gelöscht, da ABH Skia nicht automatisch installiert.

Nach einer vollständigen Deinstallation bleiben die ursprünglichen heruntergeladenen Paketdateien bestehen, bis du sie selbst löschst.

### Lizenz und Drittprojekte

Die MIT-Lizenz dieses Repositories gilt für den eigenen ABH-Code. Sie ändert nicht die Lizenzen oder Bedingungen von Aseprite, Skia, Themes, Add-ons oder anderen Drittprojekten.

Weitere Hinweise stehen in `THIRD_PARTY_NOTICES.md`.
