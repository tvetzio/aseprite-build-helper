ASEPRITE BUILD HELPER
=====================

Release: v1.0
Platform: Windows x64
Repository: https://github.com/tvetzio/aseprite-build-helper

English
-------


Project attribution
~~~~~~~~~~~~~~~~~~~
This helper is its own project. If you publish it or share it with friends,
put your credit here rather than implying that you created Aseprite or any of
the third-party extensions.

Suggested wording:

  Aseprite Personal Build Helper
  Created and maintained by: Etzio
  Project page: https://github.com/tvetzio/aseprite-build-helper

Aseprite itself is created by Igara Studio / the Aseprite contributors and is
subject to Aseprite's own EULA. Third-party themes, scripts and extensions stay
credited to their respective authors.

If you publish this on GitHub, a good place for your name is:
- this "Project attribution" section
- the repository description/about box
- the copyright header of the BAT/VBS helper files

Do not remove the original project/source links below.

Repository license
~~~~~~~~~~~~~~~~~~
The original helper code in this repository is licensed under the MIT License;
see LICENSE. Aseprite, Skia, themes, extensions, scripts, build tools and all
other third-party projects are not relicensed by this repository. Their own
licenses, EULAs and terms continue to apply. See THIRD_PARTY_NOTICES.md.

What this is
~~~~~~~~~~~~
This is a small personal build helper for Aseprite on Windows. It is not an
Aseprite distribution and it does not contain a compiled copy of Aseprite.

On a first-time setup it checks the machine, points you to the official pages
for anything that is missing, clones the official Aseprite source code, and
builds Aseprite locally on that computer.

After that, the hidden launcher is the normal way to start Aseprite. It keeps
the usual launch quick and only performs network checks when they are due.

Files in this package
~~~~~~~~~~~~~~~~~~~~~
1. aseprite_personal_build_helper.bat
   The actual builder, updater and launcher. It also contains the small support
   scripts used by the helper and extracts them locally when needed.

2. aseprite_personal_build_helper_hidden.vbs
   Starts the helper without a console window. If Aseprite has not been built
   yet, the BAT automatically opens a visible first-time setup instead.

3. README.md
   Project documentation, setup notes, maintenance commands and source links.

4. LICENSE
   MIT License for the original Aseprite Build Helper code maintained by Etzio.

5. THIRD_PARTY_NOTICES.md
   Lists third-party projects referenced or downloaded by the helper and clarifies
   that their own licenses and terms remain applicable.

Quick setup
~~~~~~~~~~~
Put all five files in the same folder, for example:

  C:\AsepriteBuildHelper\

For the first run, double-click:

  aseprite_personal_build_helper_hidden.vbs

The setup window checks:
- Git for Windows
- CMake
- Ninja
- Visual Studio C++ toolchain
- Windows SDK
- Skia m124 Windows x64 Release
- the Aseprite source target folder
- free disk space

If something is missing, the setup window shows what is wrong and provides
buttons to the official download pages. It does not silently continue with a
broken build.

Skia
~~~~
The helper expects:

  C:\deps\skia\out\Release-x64\skia.lib

Official direct download used by this helper:

  https://github.com/aseprite/skia/releases/download/m124-08a5439a6b/Skia-Windows-Release-x64.zip

Extract the archive so that the path above exists. Do not create an extra
Skia-Windows-Release-x64 folder level around it.

Desktop shortcuts
~~~~~~~~~~~~~~~~~
On first run, the helper automatically creates two desktop shortcuts if they do
not exist yet:
- Aseprite
- Aseprite Personal Build Helper

Both shortcuts use the embedded pixel icon from this package. This is the most
reliable way to give the hidden launcher and the helper a proper Windows icon,
because BAT/VBS files themselves cannot carry a custom Explorer icon in a
portable way.

Where Aseprite is built
~~~~~~~~~~~~~~~~~~~~~~~
Source:
  C:\aseprite

Executable after a successful build:
  C:\aseprite\build\bin\aseprite.exe

The helper starts from Aseprite v1.3.18.6 and later checks stable version tags.

Updates
~~~~~~~
Aseprite:
- checks for a newer stable tag at most every 6 hours
- if there is no update, the installed executable starts normally
- if GitHub is unavailable, the installed executable still starts
- if a newer Aseprite release needs a different Skia revision, the existing
  build is kept instead of blindly breaking it

Themes and third-party add-ons:
- checked at most every 24 hours
- updated in the background
- cloned from their original GitHub repositories
- not bundled as third-party source code inside this package

Local GameDev helpers:
- Game Pixel Starter
- Game Asset Template Generator
- Game Export Pack
- Autotile Template Generator
- Game Collision / Pivot Metadata
- Pivot / Origin Presets

These are copied into Aseprite's Scripts folder by the helper.


Maintenance / repair
~~~~~~~~~~~~~~~~~~~~
The visible BAT also has maintenance commands:

  aseprite_personal_build_helper.bat --maintenance
      Opens a small maintenance menu.

  aseprite_personal_build_helper.bat --status
      Shows the helper version, Aseprite state, Skia state and script counts.

  aseprite_personal_build_helper.bat --force-update
      Clears the 6/24-hour timers so all normal update checks are due again.

  aseprite_personal_build_helper.bat --repair
      Reinstalls local helper scripts and immediately resyncs themes/add-ons.

  aseprite_personal_build_helper.bat --backup
      Backs up %APPDATA%\Aseprite to:
      Documents\AsepritePersonalBuildHelper\Backups

  aseprite_personal_build_helper.bat --restore
      Restores the newest configuration backup. Before restoring, the helper
      also creates a safety backup of the current configuration.

The maintenance menu also provides shortcuts to the logs, extensions, scripts
and build folders.

Logs
~~~~
Main build/start log:
  %LOCALAPPDATA%\AsepriteBuild\aseprite_boot.log

Theme log:
  %LOCALAPPDATA%\AsepriteBuild\aseprite_themes.log

Add-on log:
  %LOCALAPPDATA%\AsepriteBuild\aseprite_addons.log

Language
~~~~~~~~
The first-time setup uses the Windows UI language:
- German Windows -> German setup
- everything else -> English setup

Manual override:
  aseprite_personal_build_helper.bat --lang=de
  aseprite_personal_build_helper.bat --lang=en

Aseprite license note
~~~~~~~~~~~~~~~~~~~~~
Aseprite's own license terms apply to Aseprite. This helper does not replace
or modify those terms.

The Aseprite FAQ says the source code may be downloaded, compiled and used for
personal purposes, while compiled versions must not be redistributed to third
parties. The current EULA also says the source code may only be compiled or
modified for your own personal purpose or to propose a contribution.

Official references:
- Aseprite FAQ:
  https://www.aseprite.org/faq/
- Aseprite EULA:
  https://github.com/aseprite/aseprite/blob/main/EULA.txt
- Aseprite source:
  https://github.com/aseprite/aseprite

There is also an open Aseprite issue discussing possible clarification around
fully automated compilation solutions. If you plan to publish this helper
publicly, review the current Aseprite EULA/FAQ yourself before doing so:
  https://github.com/aseprite/aseprite/issues/4424

This README is not legal advice.

Official prerequisite links
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Git for Windows:
  https://git-scm.com/download/win

CMake:
  https://cmake.org/download/

Visual Studio Community:
  https://visualstudio.microsoft.com/vs/community/

Ninja:
  https://github.com/ninja-build/ninja/releases

Skia m124 x64 Release:
  https://github.com/aseprite/skia/releases/download/m124-08a5439a6b/Skia-Windows-Release-x64.zip

Aseprite:
  https://github.com/aseprite/aseprite

Third-party theme/add-on sources
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The helper fetches these projects from their original repositories. Their own
licenses and terms remain applicable. They are listed here so there is no
mystery about what the helper contacts:

- https://github.com/Beatso/UsefulAsepriteScripts
- https://github.com/Gabinou/tilemap_scripts_aseprite
- https://github.com/IoriBranford/aseprite-import-lpc-character
- https://github.com/JRiggles/Lospec-Palette-Importer
- https://github.com/Limeth/aseprite-iso-scripts
- https://github.com/Lyutria/aseprite-studio-theme
- https://github.com/OpsisKalopsis/aseprite-scripts
- https://github.com/Pixeltica/AsepriteExtensions
- https://github.com/SavuGeorge/Aseprite-scripts-for-normal-map-and-tileset-manipulation
- https://github.com/Snepsid/aseprite-scripts
- https://github.com/TekF/Aseprite-Scripts
- https://github.com/ZachIsAGardner/ZacharyAsepriteScripts
- https://github.com/aseprite/Aseprite-Script-Examples
- https://github.com/behreajj/Aletheia
- https://github.com/carlmartus/aseprite_normalmap
- https://github.com/catppuccin/aseprite
- https://github.com/christopherwk210/aseprite-scripts
- https://github.com/colinlienard/aseprite-scripts
- https://github.com/davebarkeruk/Aseprite_LUA_Scripts
- https://github.com/dominickjohn/aseprite
- https://github.com/dracula/aseprite
- https://github.com/el-falso/monaki-theme
- https://github.com/emhuo/dark-moon-theme
- https://github.com/exokem/aseprite-dithering-brushes
- https://github.com/iNightfaller/aseprite-ez-outline
- https://github.com/jmswrnr/aseprite-themes
- https://github.com/marsn3/aseprite-nord
- https://github.com/mrbrownjeremy/aseprite-scripts
- https://github.com/pancelor/aseprite-puzzlescript-export
- https://github.com/quantumsheep/aseprite-export-layers
- https://github.com/rikfuzz/aseprite-scripts
- https://github.com/sandord/aseprite-scripts
- https://github.com/securas/EdgeNormals
- https://github.com/thkwznk/aseprite-scripts


Deutsch
-------


Projekt / Credits
~~~~~~~~~~~~~~~~~
Wenn du den Helper weitergibst oder auf GitHub stellst, ist hier der richtige
Platz fuer deinen Namen bzw. GitHub-Handle:

  Aseprite Personal Build Helper
  Created and maintained by: Etzio
  Project page: https://github.com/tvetzio/aseprite-build-helper

Damit ist klar, dass du den Build-Helper erstellt/verwaltet hast, aber nicht
Aseprite selbst oder die eingebundenen Drittanbieter-Erweiterungen.

Aseprite und alle Drittanbieter-Projekte behalten natuerlich ihre jeweiligen
Urheber-/Lizenzhinweise und Original-Links.

Lizenz dieses Repositories
~~~~~~~~~~~~~~~~~~~~~~~~~~
Der originale Helper-Code dieses Repositories steht unter der MIT License;
siehe LICENSE. Aseprite, Skia, Themes, Extensions, Scripte, Build-Werkzeuge und
andere Drittanbieter-Projekte werden dadurch nicht neu lizenziert. Fuer sie
gelten weiterhin ihre jeweiligen Lizenzen, EULAs und Bedingungen. Siehe
THIRD_PARTY_NOTICES.md.

Was ist das?
~~~~~~~~~~~~
Das hier ist ein kleiner persoenlicher Build-Helfer fuer Aseprite unter
Windows. Es ist keine Aseprite-Distribution und es ist keine fertig
kompilierte Aseprite-Version enthalten.

Beim ersten Start prueft der Helfer den PC, zeigt bei fehlenden Komponenten die
offiziellen Downloadseiten an, holt den offiziellen Aseprite-Quellcode und
kompiliert Aseprite lokal auf diesem Rechner.

Danach wird normalerweise nur noch die versteckte VBS-Datei gestartet. Der
normale Start bleibt dadurch schnell; Netzwerkpruefungen laufen nur, wenn sie
wirklich faellig sind.

Die Dateien
~~~~~~~~~~~
- aseprite_personal_build_helper.bat
- aseprite_personal_build_helper_hidden.vbs
- README.md
- LICENSE
- THIRD_PARTY_NOTICES.md

Alle Dateien gehoeren in denselben Ordner, zum Beispiel:

  C:\AsepriteBuildHelper\

Zum Starten einfach:

  aseprite_personal_build_helper_hidden.vbs

Beim allerersten Start wird die Einrichtung automatisch sichtbar geoeffnet.
Wenn etwas fehlt, bekommst du eine konkrete Meldung und passende offizielle
Links. Der Build wird nicht einfach blind fortgesetzt.

Skia muss nach dem Entpacken hier liegen:

  C:\deps\skia\out\Release-x64\skia.lib

Direkter offizieller Download, den der Helfer verwendet:

  https://github.com/aseprite/skia/releases/download/m124-08a5439a6b/Skia-Windows-Release-x64.zip

Desktop-Verknuepfungen
~~~~~~~~~~~~~~~~~~~~~~~~
Beim ersten Start legt der Helfer automatisch zwei Desktop-Verknuepfungen an,
falls sie noch nicht vorhanden sind:
- Aseprite
- Aseprite Personal Build Helper

Beide Verknuepfungen verwenden das in diesem Paket eingebettete Pixel-Icon.
Das ist die zuverlaessigste portable Methode, weil BAT- und VBS-Dateien selbst
unter Windows nicht sinnvoll direkt ein eigenes Explorer-Icon tragen koennen.

Der Aseprite-Quellcode liegt danach unter:

  C:\aseprite

Die gebaute EXE liegt unter:

  C:\aseprite\build\bin\aseprite.exe


Wartung / Reparatur
~~~~~~~~~~~~~~~~~~~
Die sichtbare BAT kann auch als kleines Wartungswerkzeug benutzt werden:

  aseprite_personal_build_helper.bat --maintenance
      Oeffnet ein Wartungsmenue.

  aseprite_personal_build_helper.bat --status
      Zeigt Helper-Version, Aseprite-/Skia-Status und Script-Anzahl.

  aseprite_personal_build_helper.bat --force-update
      Setzt die 6-/24-Stunden-Timer zurueck, damit alle Update-Pruefungen
      beim naechsten normalen Start sofort faellig sind.

  aseprite_personal_build_helper.bat --repair
      Installiert die lokalen Helper-Scripte neu und synchronisiert Themes
      und Add-ons sofort.

  aseprite_personal_build_helper.bat --backup
      Sichert %APPDATA%\Aseprite nach:
      Documents\AsepritePersonalBuildHelper\Backups

  aseprite_personal_build_helper.bat --restore
      Stellt das neueste Backup wieder her. Vorher wird vorsichtshalber noch
      ein Backup des aktuellen Zustands angelegt.

Update-Verhalten
~~~~~~~~~~~~~~~~
- Aseprite: maximal alle 6 Stunden pruefen
- Themes: maximal alle 24 Stunden im Hintergrund
- Erweiterungen/Skripte: maximal alle 24 Stunden im Hintergrund
- kein Internet: vorhandenes Aseprite trotzdem starten

Lizenzhinweis
~~~~~~~~~~~~~
Fuer Aseprite gelten die Bedingungen von Aseprite selbst. Laut FAQ darf der
Quellcode fuer persoenliche Zwecke selbst kompiliert werden; fertig
kompilierte Aseprite-Versionen duerfen nicht an Dritte weitergegeben werden.

FAQ:
  https://www.aseprite.org/faq/

EULA:
  https://github.com/aseprite/aseprite/blob/main/EULA.txt

Aseprite-Repository:
  https://github.com/aseprite/aseprite

Es gibt ausserdem eine offene Diskussion zur genaueren Regelung vollautomatischer
Build-Loesungen:
  https://github.com/aseprite/aseprite/issues/4424

Wenn du das Projekt oeffentlich auf GitHub stellen willst, pruefe die dann
aktuelle EULA/FAQ bitte selbst noch einmal. Dieser Hinweis ist keine
Rechtsberatung.

Die verwendeten Themes und Erweiterungen werden nicht in diesem Paket
mitgeliefert. Der Helfer holt sie direkt aus den oben aufgefuehrten
Original-Repositories; deren jeweilige Lizenzen gelten weiterhin.
