@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Aseprite Build Helper (ABH)
rem Author/maintainer: Etzio
rem Project: https://github.com/tvetzio/aseprite-build-helper
rem
rem ABH does not contain or distribute a compiled copy of Aseprite.
rem Aseprite is cloned from the official repository and compiled locally.
rem ============================================================================

set "HELPER_VERSION=1.2.9"
set "PROJECT_URL=https://github.com/tvetzio/aseprite-build-helper"
set "ISSUES_URL=https://github.com/tvetzio/aseprite-build-helper/issues/new"
set "ROOT=C:\aseprite"
set "BUILD=%ROOT%\build"
set "EXE=%BUILD%\bin\aseprite.exe"
set "SKIA=C:\deps\skia"
set "REPO=https://github.com/aseprite/aseprite.git"
set "INITIAL_TAG=v1.3.18.6"
set "EXPECTED_SKIA=m124-08a5439a6b"
set "STARTER_DIR=%~dp0"
set "README_FILE=%STARTER_DIR%README.md"

set "ABH_DIR=%STARTER_DIR%ABH"
set "SUPPORT_DIR=%ABH_DIR%\support"
set "LAUNCHER_DIR=%ABH_DIR%\launcher"
set "UPDATER_DIR=%ABH_DIR%\updater"
set "UNINSTALLER_DIR=%ABH_DIR%\uninstaller"
set "USER_LOG_DIR=%ABH_DIR%\logs\user"
set "DEV_LOG_DIR=%ABH_DIR%\logs\dev"
set "REPORT_DIR=%ABH_DIR%\reports"
set "BACKUP_DIR=%ABH_DIR%\backups"
set "MANIFEST_DIR=%ABH_DIR%\manifest"
set "STATE_DIR=%ABH_DIR%\state"
set "MANAGED_DIR=%ABH_DIR%\managed"
set "CONFIG_DIR=%ABH_DIR%\config"
set "SOURCE_CONFIG_DIR=%CONFIG_DIR%\sources"
set "SETTINGS_FILE=%CONFIG_DIR%\settings.ini"
set "PROGRESS_SCRIPT=%SUPPORT_DIR%\progress_ui.ps1"
set "SOURCE_CONFIG_SCRIPT=%SUPPORT_DIR%\source_config.ps1"
set "PROGRESS_STATE=%STATE_DIR%\progress.state"
set "LOG=%USER_LOG_DIR%\abh.log"
set "UPDATE_STAMP=%STATE_DIR%\last_aseprite_check.txt"
set "THEME_STAMP=%STATE_DIR%\last_theme_check.txt"
set "ADDON_STAMP=%STATE_DIR%\last_addon_check.txt"
set "SUPPORT_VERSION_FILE=%STATE_DIR%\support-version.txt"
set "PREFLIGHT_SCRIPT=%SUPPORT_DIR%\aseprite_preflight.ps1"
set "THEME_SCRIPT=%SUPPORT_DIR%\aseprite_themes.ps1"
set "ADDON_SCRIPT=%SUPPORT_DIR%\aseprite_addons.ps1"
set "LOCAL_TOOLS_SCRIPT=%SUPPORT_DIR%\aseprite_local_tools.ps1"
set "LAUNCHER=%LAUNCHER_DIR%\aseprite-launcher.vbs"
set "UPDATER=%UPDATER_DIR%\aseprite-build-updater.bat"
set "UNINSTALLER=%UNINSTALLER_DIR%\uninstall-abh.bat"
set "ICON_MAIN=%LAUNCHER_DIR%\helper_icon.ico"
set "ICON_UPDATER=%UPDATER_DIR%\force_update.ico"
set "ICON_UNINSTALL=%UNINSTALLER_DIR%\uninstall.ico"
set "UPDATE_INTERVAL_HOURS=12"
set "THEME_INTERVAL_HOURS=12"
set "ADDON_INTERVAL_HOURS=12"
set "ABH_DATA_ROOT=%ABH_DIR%"

set "MODE_ASE_UPDATE=0"
set "MODE_REFRESH_RUNTIME=0"
set "MODE_REBUILD=0"
set "UI_LANG="
for %%A in (%*) do (
  if /I "%%~A"=="--aseprite-update" set "MODE_ASE_UPDATE=1"
  if /I "%%~A"=="--refresh-runtime" set "MODE_REFRESH_RUNTIME=1"
  if /I "%%~A"=="--rebuild" set "MODE_REBUILD=1"
  if /I "%%~A"=="--lang=de" set "UI_LANG=de"
  if /I "%%~A"=="--lang=en" set "UI_LANG=en"
)
if not defined UI_LANG for /f "usebackq delims=" %%L in (`powershell.exe -NoLogo -NoProfile -Command "$c=(Get-UICulture).Name; if($c -like 'de-*'){'de'}else{'en'}"`) do set "UI_LANG=%%L"
if not defined UI_LANG set "UI_LANG=en"

rem Warn only for interactive builder use, not for updater/self-update backend calls.
if "%MODE_ASE_UPDATE%"=="0" if "%MODE_REFRESH_RUNTIME%"=="0" if "%MODE_REBUILD%"=="0" (
  call :check_package_location
  if errorlevel 1 exit /b 1
)

rem ABH intentionally keeps generated data beside this BAT.
mkdir "%ABH_DIR%" "%SUPPORT_DIR%" "%LAUNCHER_DIR%" "%UPDATER_DIR%" "%UNINSTALLER_DIR%" "%USER_LOG_DIR%" "%DEV_LOG_DIR%" "%REPORT_DIR%" "%BACKUP_DIR%" "%MANIFEST_DIR%" "%STATE_DIR%" "%MANAGED_DIR%" "%CONFIG_DIR%" "%SOURCE_CONFIG_DIR%" >nul 2>&1
if not exist "%ABH_DIR%" (
  if /I "%UI_LANG%"=="de" (
    echo FEHLER: ABH kann im aktuellen Ordner keine Dateien erstellen.
    echo Verschieben Sie das Paket in einen beschreibbaren Ordner und versuchen Sie es erneut.
  ) else (
    echo ERROR: ABH cannot create files in the current folder.
    echo Move the package to a writable folder and try again.
  )
  pause
  exit /b 1
)

call :extract_core_support
if errorlevel 1 exit /b 1
call :restore_source_backup_if_available
call :ensure_source_configs
call :load_settings

rem Ninja fallback next to CMake.
where ninja.exe >nul 2>&1
if errorlevel 1 if exist "C:\Program Files\CMake\bin\ninja.exe" set "PATH=C:\Program Files\CMake\bin;%PATH%"

call :log "------------------------------------------------------------"
call :log "START helper=%HELPER_VERSION% mode=%*"

if "%MODE_REFRESH_RUNTIME%"=="1" (
  call :install_runtime_files
  if errorlevel 1 exit /b 1
  call :create_shortcuts
  exit /b %errorlevel%
)
if "%MODE_ASE_UPDATE%"=="1" (
  call :check_aseprite_update
  exit /b %errorlevel%
)
if "%MODE_REBUILD%"=="1" (
  call :quick_build_prerequisites
  if errorlevel 1 exit /b 1
  call :build
  exit /b %errorlevel%
)

if not exist "%EXE%" goto first_install
goto builder_menu

:first_install
call :log "No Aseprite executable found. Starting first-time setup."
call :progress_start setup
call :progress_update 5 check "1/6" "Checking prerequisites..."
cls
if /I "%UI_LANG%"=="de" (
  echo ============================================================
  echo   ASEPRITE BUILD HELPER v%HELPER_VERSION% - SCHNELLEINRICHTUNG
  echo ============================================================
  echo.
  echo Der Helper richtet Aseprite jetzt in einem zusammenhängenden
  echo Ablauf ein. Nach der Bestätigung läuft die Einrichtung automatisch.
  echo.
  echo Paketordner: %STARTER_DIR%
  echo Laufzeitdaten: %ABH_DIR%
  echo.
  echo [1/6] Voraussetzungen prüfen
) else (
  echo ============================================================
  echo   ASEPRITE BUILD HELPER v%HELPER_VERSION% - QUICK SETUP
  echo ============================================================
  echo.
  echo ABH will set up Aseprite in one continuous flow. After the
  echo confirmation, the remaining setup runs automatically.
  echo.
  echo Package folder: %STARTER_DIR%
  echo Runtime data:   %ABH_DIR%
  echo.
  echo [1/6] Checking prerequisites
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PREFLIGHT_SCRIPT%" -ReadmePath "%README_FILE%" -SkiaRoot "%SKIA%" -AsepriteRoot "%ROOT%" -Language "%UI_LANG%"
if errorlevel 1 (
  call :record_error "ABH-E001" "prerequisite_check" "First-time prerequisite check was cancelled or failed."
  call :progress_stop
  exit /b 1
)
call :validate_skia_files
if errorlevel 1 (
  call :record_error "ABH-E201" "skia_validation" "Skia is missing or incomplete."
  call :fatal "Skia is missing or incomplete: C:\deps\skia\out\Release-x64\skia.lib"
  exit /b 1
)

call :progress_update 20 aseprite "2/6" "Preparing Aseprite source..."
if /I "%UI_LANG%"=="de" (echo [2/6] Aseprite-Quellcode vorbereiten) else (echo [2/6] Preparing Aseprite source)
if not exist "%ROOT%\.git" (
  if exist "%ROOT%" (
    call :record_error "ABH-E101" "source_clone" "C:\aseprite exists but is not an Aseprite Git repository."
    call :fatal "C:\aseprite already exists but is not a Git repository."
    exit /b 1
  )
  call :log "Cloning official Aseprite source tag %INITIAL_TAG%."
  git clone --recursive --branch "%INITIAL_TAG%" "%REPO%" "%ROOT%" >>"%LOG%" 2>&1
  if errorlevel 1 (
    call :record_error "ABH-E101" "source_clone" "git clone failed."
    call :fatal "Aseprite source clone failed."
    exit /b 1
  )
)

call :validate_skia_for_source
if errorlevel 1 (
  call :record_error "ABH-E201" "skia_revision" "The checked-out Aseprite source expects another Skia revision."
  call :fatal "The Aseprite source expects a different Skia revision."
  exit /b 1
)

call :progress_update -1 build "3/6" "Building Aseprite..."
if /I "%UI_LANG%"=="de" (echo [3/6] Aseprite kompilieren - dies kann einige Minuten dauern) else (echo [3/6] Building Aseprite - this can take several minutes)
call :build
if errorlevel 1 (
  call :fatal "The Aseprite build failed. Use Aseprite Build Updater ^> Report a bug if prerequisites are OK."
  exit /b 1
)

call :progress_update 65 theme "4/6" "Installing themes..."
if /I "%UI_LANG%"=="de" (echo [4/6] Themes, Add-ons und GameDev-Werkzeuge einrichten) else (echo [4/6] Setting up themes, add-ons and GameDev tools)
call :install_local_tools
call :sync_themes_now
call :progress_update 78 addon "4/6" "Installing add-ons and scripts..."
call :sync_addons_now

call :progress_update 90 check "5/6" "Creating runtime components and shortcuts..."
if /I "%UI_LANG%"=="de" (echo [5/6] Launcher, Updater und Uninstaller erstellen) else (echo [5/6] Creating launcher, updater and uninstaller)
call :install_runtime_files
if errorlevel 1 (
  call :record_error "ABH-E900" "runtime_install" "Build succeeded but launcher/uninstaller creation failed."
  call :fatal "Aseprite was built, but ABH could not create its launcher files."
  exit /b 1
)
call :create_shortcuts
if errorlevel 1 (
  call :record_error "ABH-E901" "shortcut_creation" "Runtime files were created but one or more shortcuts could not be created."
)
call :write_update_stamps

call :progress_update 100 success "6/6" "Setup completed successfully."
if /I "%UI_LANG%"=="de" (echo [6/6] Einrichtung abschließen) else (echo [6/6] Finishing setup)
call :log "First installation completed successfully."
call :play_setup_complete_sound
call :progress_stop

echo.
if /I "%UI_LANG%"=="de" (
  echo ============================================================
  echo   EINRICHTUNG ERFOLGREICH ABGESCHLOSSEN
  echo ============================================================
  echo Aseprite wurde erfolgreich erstellt.
  echo Die Verknüpfungen wurden auf dem Desktop angelegt.
  echo ABH-Daten befinden sich unter:
  echo   %ABH_DIR%
  echo.
  echo Aseprite wird jetzt gestartet.
) else (
  echo ============================================================
  echo   SETUP COMPLETED SUCCESSFULLY
  echo ============================================================
  echo Aseprite was built successfully.
  echo The desktop shortcuts have been created.
  echo ABH data is stored under:
  echo   %ABH_DIR%
  echo.
  echo Aseprite will start now.
)
call :launch_aseprite
goto builder_menu


:builder_menu
call :ensure_runtime
cls
if /I "%UI_LANG%"=="de" (
  echo ============================================================
  echo   Aseprite Build Helper v%HELPER_VERSION% - Compiler
  echo ============================================================
  echo.
  echo Aseprite ist bereits eingerichtet.
  echo Für Updates, Wartung, Logs und Deinstallation verwenden Sie bitte
  echo "Aseprite Build Updater".
  echo.
  echo [1] Aktuellen Aseprite-Build neu kompilieren
  echo [2] Aseprite-Release prüfen und bei Bedarf neu bauen
  echo [3] Launcher / Updater / Uninstaller reparieren
  echo [0] Beenden
  echo.
  set /p "BUILDSEL=Auswahl: "
) else (
  echo ============================================================
  echo   Aseprite Build Helper v%HELPER_VERSION% - Compiler
  echo ============================================================
  echo.
  echo Aseprite is already set up.
  echo For updates, maintenance, logs and uninstall use
  echo "Aseprite Build Updater".
  echo.
  echo [1] Recompile the current Aseprite build
  echo [2] Check the Aseprite release and rebuild if required
  echo [3] Repair launcher / updater / uninstaller
  echo [0] Exit
  echo.
  set /p "BUILDSEL=Selection: "
)
if "%BUILDSEL%"=="0" exit /b 0
if "%BUILDSEL%"=="1" (
  call :quick_build_prerequisites
  if errorlevel 1 (call :fatal "Build prerequisites are incomplete." & exit /b 1)
  call :progress_start setup
  call :progress_update -1 build "Build" "Compiling Aseprite with Ninja..."
  call :build
  set "RC=!errorlevel!"
  call :progress_stop
  if "!RC!"=="0" call :play_setup_complete_sound
  pause
  goto builder_menu
)
if "%BUILDSEL%"=="2" (
  call :progress_start update
  call :progress_update 20 aseprite "Aseprite" "Checking Aseprite updates..."
  call :check_aseprite_update
  set "RC=!errorlevel!"
  call :progress_update 100 success "Aseprite" "Update check completed."
  call :progress_stop
  pause
  goto builder_menu
)
if "%BUILDSEL%"=="3" (
  call :install_runtime_files
  if not errorlevel 1 call :create_shortcuts
  pause
  goto builder_menu
)
goto builder_menu
:check_aseprite_update
call :is_due "%UPDATE_STAMP%" %UPDATE_INTERVAL_HOURS%
if not errorlevel 1 (
  call :log "Aseprite update check skipped; cache is fresh (%UPDATE_INTERVAL_HOURS% hour interval)."
  exit /b 0
)
call :log "Checking GitHub for stable Aseprite release tags."
git -C "%ROOT%" fetch --tags --prune --quiet origin >>"%LOG%" 2>&1
>"%UPDATE_STAMP%" echo %date% %time%
if errorlevel 1 exit /b 2
set "LATEST_TAG="
for /f "usebackq delims=" %%V in (`powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$tags=@(& git -C '%ROOT%' tag --list 'v*'); $items=foreach($t in $tags){if($t -match '^v(\d+\.\d+\.\d+(?:\.\d+)?)$'){try{[pscustomobject]@{Tag=$t;Ver=[version]$Matches[1]}}catch{}}}; ($items|Sort-Object Ver -Descending|Select-Object -First 1).Tag"`) do set "LATEST_TAG=%%V"
if not defined LATEST_TAG exit /b 2
set "CURRENT_COMMIT="
set "LATEST_COMMIT="
for /f "delims=" %%H in ('git -C "%ROOT%" rev-parse HEAD 2^>nul') do set "CURRENT_COMMIT=%%H"
for /f "delims=" %%H in ('git -C "%ROOT%" rev-list -n 1 "!LATEST_TAG!" 2^>nul') do set "LATEST_COMMIT=%%H"
if /I "!CURRENT_COMMIT!"=="!LATEST_COMMIT!" (
  call :log "No Aseprite update. Current stable release: !LATEST_TAG!"
  exit /b 0
)
call :log "Aseprite update found: !LATEST_TAG!"
set "OLD_COMMIT=!CURRENT_COMMIT!"

rem Full build prerequisites are checked only when an actual Aseprite update exists.
call :quick_build_prerequisites
if errorlevel 1 (
  call :record_error "ABH-E001" "update_prerequisites" "An update was found but build prerequisites are incomplete."
  exit /b 2
)

git -C "%ROOT%" checkout --force "!LATEST_TAG!" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :record_error "ABH-E102" "source_checkout" "Could not check out the new stable tag."
  exit /b 2
)
git -C "%ROOT%" submodule sync --recursive >>"%LOG%" 2>&1
git -C "%ROOT%" submodule update --init --recursive --force >>"%LOG%" 2>&1
if errorlevel 1 (
  call :record_error "ABH-E103" "submodule_update" "Submodule update failed."
  git -C "%ROOT%" checkout --force "!OLD_COMMIT!" >>"%LOG%" 2>&1
  git -C "%ROOT%" submodule update --init --recursive --force >>"%LOG%" 2>&1
  exit /b 2
)
call :validate_skia_for_source
if errorlevel 1 (
  call :record_error "ABH-E201" "skia_revision" "New Aseprite release requires another Skia revision."
  git -C "%ROOT%" checkout --force "!OLD_COMMIT!" >>"%LOG%" 2>&1
  git -C "%ROOT%" submodule update --init --recursive --force >>"%LOG%" 2>&1
  exit /b 2
)
call :build
if errorlevel 1 (
  git -C "%ROOT%" checkout --force "!OLD_COMMIT!" >>"%LOG%" 2>&1
  git -C "%ROOT%" submodule update --init --recursive --force >>"%LOG%" 2>&1
  exit /b 2
)
call :log "Aseprite update build completed successfully: !LATEST_TAG!"
exit /b 1


:check_package_location
set "ABH_DESKTOP="
for /f "usebackq delims=" %%D in (`powershell.exe -NoLogo -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "ABH_DESKTOP=%%D"
if not defined ABH_DESKTOP exit /b 0
set "ABH_CURRENT=%STARTER_DIR%"
if "%ABH_CURRENT:~-1%"=="\" set "ABH_CURRENT=%ABH_CURRENT:~0,-1%"
if /I not "%ABH_CURRENT%"=="%ABH_DESKTOP%" exit /b 0
cls
if /I "%UI_LANG%"=="de" (
  echo ============================================================
  echo   HINWEIS ZUM SPEICHERORT
  echo ============================================================
  echo.
  echo Die ABH-Paketdateien liegen derzeit direkt auf dem Desktop.
  echo ABH erstellt neben der BAT einen eigenen Ordner "ABH" mit Logs,
  echo Support-Dateien, Backups und weiteren Laufzeitdaten.
  echo.
  echo Empfohlen: Erstelle zuerst einen eigenen Ordner, zum Beispiel:
  echo   %USERPROFILE%\AsepriteBuildHelper\
  echo.
  echo Verschiebe alle vier Dateien aus dem ZIP gemeinsam dorthin und
  echo starte aseprite-build-helper.bat anschließend erneut.
  echo.
  echo [F] Trotzdem hier fortfahren
  echo [A] Abbrechen
  echo.
  set /p "ABH_LOC_CHOICE=Auswahl: "
  if /I "!ABH_LOC_CHOICE!"=="F" exit /b 0
) else (
  echo ============================================================
  echo   PACKAGE LOCATION NOTICE
  echo ============================================================
  echo.
  echo The ABH package files are currently placed directly on the Desktop.
  echo ABH creates an "ABH" folder next to the BAT for logs, support files,
  echo backups and other runtime data.
  echo.
  echo Recommended: create a dedicated folder first, for example:
  echo   %USERPROFILE%\AsepriteBuildHelper\
  echo.
  echo Move all four files from the ZIP into that folder together and then
  echo run aseprite-build-helper.bat again.
  echo.
  echo [C] Continue here anyway
  echo [X] Exit
  echo.
  set /p "ABH_LOC_CHOICE=Selection: "
  if /I "!ABH_LOC_CHOICE!"=="C" exit /b 0
)
exit /b 1

:play_setup_complete_sound
powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -Command "try { Add-Type -AssemblyName System; [System.Media.SystemSounds]::Asterisk.Play(); Start-Sleep -Milliseconds 650 } catch {}" >nul 2>&1
exit /b 0

:quick_build_prerequisites
where git.exe >nul 2>&1 || exit /b 1
where cmake.exe >nul 2>&1 || exit /b 1
where ninja.exe >nul 2>&1 || exit /b 1
call :validate_skia_files || exit /b 1
call :load_msvc || exit /b 1
exit /b 0

:build
call :load_msvc
if errorlevel 1 (
  call :record_error "ABH-E001" "msvc_environment" "Visual Studio C++ environment could not be loaded."
  exit /b 1
)
if not exist "%BUILD%" mkdir "%BUILD%" >>"%LOG%" 2>&1
call :progress_update -1 build "Build" "Configuring CMake..."
call :log "Configuring CMake."
cmake.exe -S "%ROOT%" -B "%BUILD%" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLAF_BACKEND=skia -DSKIA_DIR="%SKIA%" -DSKIA_LIBRARY_DIR="%SKIA%\out\Release-x64" -DSKIA_LIBRARY="%SKIA%\out\Release-x64\skia.lib" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :record_error "ABH-E301" "cmake_configure" "CMake configuration failed."
  exit /b 1
)
call :progress_update -1 build "Build" "Compiling Aseprite with Ninja..."
call :log "Building Aseprite with Ninja."
ninja.exe -C "%BUILD%" aseprite >>"%LOG%" 2>&1
if errorlevel 1 (
  call :record_error "ABH-E302" "ninja_build" "Ninja build failed."
  exit /b 1
)
if not exist "%EXE%" (
  call :record_error "ABH-E303" "build_output" "Build completed but aseprite.exe is missing."
  exit /b 1
)
exit /b 0

:load_msvc
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSROOT="
if exist "%VSWHERE%" for /f "usebackq tokens=* delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSROOT=%%I"
if not defined VSROOT if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" set "VSROOT=C:\Program Files\Microsoft Visual Studio\2022\Community"
if not defined VSROOT exit /b 1
set "VCVARS=%VSROOT%\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" exit /b 1
call "%VCVARS%" >nul 2>&1
where cl.exe >nul 2>&1
exit /b %errorlevel%

:validate_skia_files
if not exist "%SKIA%\out\Release-x64\skia.lib" exit /b 1
if not exist "%SKIA%\include" exit /b 1
exit /b 0

:validate_skia_for_source
call :validate_skia_files
if errorlevel 1 exit /b 1
set "SOURCE_SKIA="
for /f "usebackq delims=" %%S in (`powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$files=@('%ROOT%\laf\CMakeLists.txt','%ROOT%\CMakeLists.txt'); foreach($f in $files){if(Test-Path -LiteralPath $f){$x=Select-String -LiteralPath $f -Pattern 'm\d+-[0-9a-f]+' -AllMatches -ErrorAction SilentlyContinue; foreach($m in $x.Matches){if($m.Value -match '^m\d+-[0-9a-f]+$'){$m.Value; exit}}}}"`) do set "SOURCE_SKIA=%%S"
if defined SOURCE_SKIA if /I not "!SOURCE_SKIA!"=="%EXPECTED_SKIA%" exit /b 1
exit /b 0

:install_local_tools
if exist "%LOCAL_TOOLS_SCRIPT%" powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%LOCAL_TOOLS_SCRIPT%" >>"%LOG%" 2>&1
exit /b 0

:sync_themes_now
if not exist "%THEME_SCRIPT%" exit /b 0
call :log "Synchronizing managed themes."
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%THEME_SCRIPT%" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :record_error "ABH-E401" "theme_sync" "Theme synchronization failed."
) else (
  >"%THEME_STAMP%" echo %date% %time%
)
exit /b 0

:sync_addons_now
if not exist "%ADDON_SCRIPT%" exit /b 0
call :log "Synchronizing managed add-ons."
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ADDON_SCRIPT%" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :record_error "ABH-E402" "addon_sync" "Add-on synchronization failed."
) else (
  >"%ADDON_STAMP%" echo %date% %time%
)
exit /b 0


:sync_themes_if_due
call :is_due "%THEME_STAMP%" %THEME_INTERVAL_HOURS%
if errorlevel 1 call :sync_themes_now
exit /b 0

:sync_addons_if_due
call :is_due "%ADDON_STAMP%" %ADDON_INTERVAL_HOURS%
if errorlevel 1 call :sync_addons_now
exit /b 0
:is_due
if not exist "%~1" exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$age=(Get-Date)-(Get-Item -LiteralPath '%~1').LastWriteTime; if($age.TotalHours -lt %~2){exit 0}else{exit 1}" >nul 2>&1
exit /b %errorlevel%

:load_settings
set "UPDATE_INTERVAL_HOURS=12"
if not exist "%SETTINGS_FILE%" (
  >"%SETTINGS_FILE%" echo ; Aseprite Build Helper settings
  >>"%SETTINGS_FILE%" echo ; Update check interval in hours. Minimum: 1
  >>"%SETTINGS_FILE%" echo [General]
  >>"%SETTINGS_FILE%" echo update_interval_hours=12
)
for /f "usebackq tokens=1,* delims==" %%A in ("%SETTINGS_FILE%") do if /I "%%~A"=="update_interval_hours" set "UPDATE_INTERVAL_HOURS=%%~B"
for /f "delims=0123456789" %%X in ("%UPDATE_INTERVAL_HOURS%") do set "UPDATE_INTERVAL_HOURS=12"
if not defined UPDATE_INTERVAL_HOURS set "UPDATE_INTERVAL_HOURS=12"
if %UPDATE_INTERVAL_HOURS% LSS 1 set "UPDATE_INTERVAL_HOURS=1"
set "THEME_INTERVAL_HOURS=%UPDATE_INTERVAL_HOURS%"
set "ADDON_INTERVAL_HOURS=%UPDATE_INTERVAL_HOURS%"
exit /b 0

:configure_update_interval
call :load_settings
set "NEWINT="
cls
if /I "%UI_LANG%"=="de" (
 echo ============================================================
 echo   UPDATE-INTERVALL
 echo ============================================================
 echo Aktuell: %UPDATE_INTERVAL_HOURS% Stunden
 echo.
 echo [1] 1 Stunde
 echo [2] 3 Stunden
 echo [3] 6 Stunden
 echo [4] 12 Stunden ^(Standard^)
 echo [5] 24 Stunden
 echo [6] Benutzerdefiniert
 echo [0] Abbrechen
 echo.
 set /p "INTSEL=Auswahl: "
) else (
 echo ============================================================
 echo   UPDATE INTERVAL
 echo ============================================================
 echo Current: %UPDATE_INTERVAL_HOURS% hours
 echo.
 echo [1] 1 hour
 echo [2] 3 hours
 echo [3] 6 hours
 echo [4] 12 hours ^(default^)
 echo [5] 24 hours
 echo [6] Custom
 echo [0] Cancel
 echo.
 set /p "INTSEL=Selection: "
)
if "%INTSEL%"=="0" exit /b 0
if "%INTSEL%"=="1" set "NEWINT=1"
if "%INTSEL%"=="2" set "NEWINT=3"
if "%INTSEL%"=="3" set "NEWINT=6"
if "%INTSEL%"=="4" set "NEWINT=12"
if "%INTSEL%"=="5" set "NEWINT=24"
if "%INTSEL%"=="6" (
  if /I "%UI_LANG%"=="de" (set /p "NEWINT=Intervall in Stunden ^(mindestens 1^): ") else (set /p "NEWINT=Interval in hours ^(minimum 1^): ")
)
if not defined NEWINT exit /b 1
for /f "delims=0123456789" %%X in ("%NEWINT%") do set "NEWINT="
if not defined NEWINT (
  if /I "%UI_LANG%"=="de" (echo Ungültiger Wert.) else (echo Invalid value.)
  exit /b 1
)
if %NEWINT% LSS 1 set "NEWINT=1"
>"%SETTINGS_FILE%" echo ; Aseprite Build Helper settings
>>"%SETTINGS_FILE%" echo ; Update check interval in hours. Minimum: 1
>>"%SETTINGS_FILE%" echo [General]
>>"%SETTINGS_FILE%" echo update_interval_hours=%NEWINT%
call :load_settings
if /I "%UI_LANG%"=="de" (echo Update-Intervall auf %UPDATE_INTERVAL_HOURS% Stunden gesetzt.) else (echo Update interval set to %UPDATE_INTERVAL_HOURS% hours.)
exit /b 0

:ensure_source_configs
if exist "%SOURCE_CONFIG_SCRIPT%" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SOURCE_CONFIG_SCRIPT%" -Root "%SOURCE_CONFIG_DIR%" >>"%LOG%" 2>&1
exit /b 0

:restore_source_backup_if_available
set "HAS_CONFIG="
for /f "delims=" %%I in ('dir /b /s "%SOURCE_CONFIG_DIR%\*.ini" 2^>nul') do if not defined HAS_CONFIG set "HAS_CONFIG=1"
if defined HAS_CONFIG exit /b 0
set "CFG_BACKUP="
for /f "delims=" %%F in ('dir /b /a-d /o-d "%STARTER_DIR%ABH-source-config-backup-*.zip" 2^>nul') do if not defined CFG_BACKUP set "CFG_BACKUP=%STARTER_DIR%%%F"
if not defined CFG_BACKUP exit /b 0
cls
if /I "%UI_LANG%"=="de" (
 echo ============================================================
 echo   QUELLEN-KONFIGURATION GEFUNDEN
 echo ============================================================
 echo Eine frühere ABH-Quellen-Sicherung wurde gefunden:
 echo   !CFG_BACKUP!
 echo.
 echo Theme-, Add-on- und Mixed-Konfigurationen wiederherstellen? [J/N]
 set /p "RESTCFG=Auswahl: "
 if /I not "!RESTCFG!"=="J" exit /b 0
) else (
 echo ============================================================
 echo   SOURCE CONFIGURATION BACKUP FOUND
 echo ============================================================
 echo A previous ABH source configuration backup was found:
 echo   !CFG_BACKUP!
 echo.
 echo Restore theme, add-on and mixed configurations? [Y/N]
 set /p "RESTCFG=Selection: "
 if /I not "!RESTCFG!"=="Y" exit /b 0
)
mkdir "%CONFIG_DIR%" >nul 2>&1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath $env:CFG_BACKUP -DestinationPath '%CONFIG_DIR%' -Force" >>"%LOG%" 2>&1
exit /b 0

:progress_start
rem v1.2.9: progress stays in the current console window.
exit /b 0

:progress_update
set "ABH_PCT=%~1"
set "ABH_PHASE=%~2"
set "ABH_STEP=%~3"
set "ABH_MSG=%~4"
set "ABH_COLOR=Cyan"
if /I "%ABH_PHASE%"=="theme" set "ABH_COLOR=Magenta"
if /I "%ABH_PHASE%"=="addon" set "ABH_COLOR=Green"
if /I "%ABH_PHASE%"=="success" set "ABH_COLOR=Green"
if /I "%ABH_PHASE%"=="build" set "ABH_COLOR=Yellow"
if /I "%ABH_PHASE%"=="warning" set "ABH_COLOR=Yellow"
if /I "%ABH_PHASE%"=="error" set "ABH_COLOR=Red"
powershell.exe -NoLogo -NoProfile -Command "Write-Host ('['+$env:ABH_STEP+'] '+$env:ABH_MSG) -ForegroundColor $env:ABH_COLOR" 2>nul
exit /b 0

:progress_stop
exit /b 0

:install_runtime_files
mkdir "%LAUNCHER_DIR%" "%UPDATER_DIR%" "%UNINSTALLER_DIR%" >nul 2>&1
call :extract_b64_payload "aseprite-launcher.vbs.b64" "%LAUNCHER%"
if errorlevel 1 exit /b 1
call :extract_b64_payload "aseprite-build-updater.bat.b64" "%UPDATER%"
if errorlevel 1 exit /b 1
call :extract_b64_payload "uninstall-abh.bat.b64" "%UNINSTALLER%"
if errorlevel 1 exit /b 1
rem Clean up runtime files and shortcuts used by ABH v1.1 and earlier.
del /q "%SUPPORT_DIR%\aseprite-launcher.vbs" "%SUPPORT_DIR%\uninstall-abh.bat" >nul 2>&1
exit /b 0

:ensure_runtime
if not exist "%LAUNCHER%" call :install_runtime_files
if not exist "%UPDATER%" call :install_runtime_files
if not exist "%UNINSTALLER%" call :install_runtime_files
call :create_shortcuts
exit /b 0

:create_shortcuts
if not exist "%LAUNCHER%" exit /b 1
if not exist "%UPDATER%" exit /b 1
set "ABH_LAUNCHER=%LAUNCHER%"
set "ABH_UPDATER=%UPDATER%"
set "ABH_ICON_MAIN=%ICON_MAIN%"
set "ABH_ICON_UPDATER=%ICON_UPDATER%"
set "ABH_STARTER=%STARTER_DIR%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); $w=New-Object -ComObject WScript.Shell; foreach($old in @('Aseprite - Force Update Check.lnk','Aseprite Build Helper - Uninstall.lnk')){Remove-Item -LiteralPath (Join-Path $d $old) -Force -ErrorAction SilentlyContinue}; $s=$w.CreateShortcut((Join-Path $d 'Aseprite.lnk')); $s.TargetPath='wscript.exe'; $s.Arguments='\"'+$env:ABH_LAUNCHER+'\"'; $s.WorkingDirectory=$env:ABH_STARTER; $s.IconLocation=$env:ABH_ICON_MAIN+',0'; $s.Save(); $u=$w.CreateShortcut((Join-Path $d 'Aseprite Build Updater.lnk')); $u.TargetPath='cmd.exe'; $u.Arguments='/c \"\"'+$env:ABH_UPDATER+'\"\"'; $u.WorkingDirectory=$env:ABH_STARTER; $u.IconLocation=$env:ABH_ICON_UPDATER+',0'; $u.Save()" >>"%LOG%" 2>&1
exit /b %errorlevel%
:write_update_stamps
>"%UPDATE_STAMP%" echo %date% %time%
>"%THEME_STAMP%" echo %date% %time%
>"%ADDON_STAMP%" echo %date% %time%
exit /b 0

:launch_aseprite
if not exist "%EXE%" exit /b 1
start "" "%EXE%"
exit /b 0

:record_error
set "ERR_CODE=%~1"
set "ERR_STEP=%~2"
set "ERR_MSG=%~3"
for /f "usebackq delims=" %%T in (`powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format 'yyyyMMdd-HHmmss'"`) do set "TS=%%T"
set "DEVLOG=%DEV_LOG_DIR%\abh-dev-%TS%.log"
set "ABH_DEVLOG=%DEVLOG%"
set "ABH_MAINLOG=%LOG%"
set "ABH_ERR_CODE=%ERR_CODE%"
set "ABH_ERR_STEP=%ERR_STEP%"
set "ABH_ERR_MSG=%ERR_MSG%"
set "ABH_HELPER_VERSION=%HELPER_VERSION%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$u=$env:USERNAME; $home=$env:USERPROFILE; $lines=New-Object System.Collections.Generic.List[string]; $lines.Add('Aseprite Build Helper Dev Log'); $lines.Add(''); $lines.Add('Helper version: '+$env:ABH_HELPER_VERSION); $lines.Add('Error code: '+$env:ABH_ERR_CODE); $lines.Add('Failed step: '+$env:ABH_ERR_STEP); $lines.Add('Message: '+$env:ABH_ERR_MSG); $lines.Add('Windows: '+[Environment]::OSVersion.VersionString); $lines.Add('Architecture: '+$env:PROCESSOR_ARCHITECTURE); $lines.Add('UI culture: '+(Get-UICulture).Name); $lines.Add(''); $lines.Add('Relevant log tail:'); if(Test-Path -LiteralPath $env:ABH_MAINLOG){$tail=Get-Content -LiteralPath $env:ABH_MAINLOG -Tail 160; foreach($x in $tail){$x=$x -replace [regex]::Escape($home),'C:\Users\<USER>'; $x=$x -replace '(?i)(authorization|token|password|secret)\s*[:=]\s*\S+','$1=<REDACTED>'; $lines.Add($x)}}; [IO.File]::WriteAllLines($env:ABH_DEVLOG,$lines,(New-Object Text.UTF8Encoding($false)))" >nul 2>&1
call :log "ERROR %ERR_CODE% step=%ERR_STEP% devlog=%DEVLOG%"
exit /b 0

:fatal
call :progress_update 100 error "Error" "%~1"
call :log "FATAL: %~1"
if /I "%UI_LANG%"=="de" (echo FEHLER: %~1) else (echo ERROR: %~1)
echo.
if /I "%UI_LANG%"=="de" echo Logs: %USER_LOG_DIR%  ^|  Bugreport: %PROJECT_URL%/issues
if /I not "%UI_LANG%"=="de" echo Logs: %USER_LOG_DIR%  ^|  Bug report: %PROJECT_URL%/issues
pause
call :progress_stop
exit /b 0

:log
if not exist "%USER_LOG_DIR%" mkdir "%USER_LOG_DIR%" >nul 2>&1
>>"%LOG%" echo [%date% %time%] %~1
exit /b 0

:extract_core_support
set "INSTALLED_VERSION="
if exist "%SUPPORT_VERSION_FILE%" set /p INSTALLED_VERSION=<"%SUPPORT_VERSION_FILE%"
if /I "%INSTALLED_VERSION%"=="%HELPER_VERSION%" if exist "%ICON_MAIN%" if exist "%ICON_UPDATER%" if exist "%ICON_UNINSTALL%" if exist "%PROGRESS_SCRIPT%" if exist "%SOURCE_CONFIG_SCRIPT%" exit /b 0
mkdir "%SUPPORT_DIR%" "%LAUNCHER_DIR%" "%UPDATER_DIR%" "%UNINSTALLER_DIR%" >nul 2>&1
set "ASE_HELPER_SELF=%~f0"
set "ASE_HELPER_SUPPORT=%SUPPORT_DIR%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$raw=[IO.File]::ReadAllText($env:ASE_HELPER_SELF); $out=$env:ASE_HELPER_SUPPORT; $encNoBom=New-Object Text.UTF8Encoding($false); $encBom=New-Object Text.UTF8Encoding($true); $names=@('aseprite_preflight.ps1','aseprite_themes.ps1','aseprite_addons.ps1','aseprite_local_tools.ps1','progress_ui.ps1','source_config.ps1','self_update_apply.ps1','game_pixel_starter.lua','game_export_pack.lua','game_asset_template_generator.lua','autotile_template_generator.lua','game_collision_pivot_metadata.lua','pivot_origin_presets.lua'); foreach($n in $names){$e=[regex]::Escape($n);$m=[regex]::Match($raw,'(?s)###BEGIN:'+$e+'###\r?\n(.*?)\r?\n###END:'+$e+'###');if(-not $m.Success){exit 91};$enc=if($n.EndsWith('.ps1')){$encBom}else{$encNoBom};[IO.File]::WriteAllText((Join-Path $out $n),$m.Groups[1].Value,$enc)}" >nul 2>&1
if errorlevel 1 (
  if /I "%UI_LANG%"=="de" (echo Interne ABH-Supportdateien konnten nicht entpackt werden.) else (echo ABH internal support files could not be extracted.)
  exit /b 1
)
call :extract_b64_payload "helper_icon.ico.b64" "%ICON_MAIN%"
if errorlevel 1 exit /b 1
call :extract_b64_payload "force_update.ico.b64" "%ICON_UPDATER%"
if errorlevel 1 exit /b 1
call :extract_b64_payload "uninstall.ico.b64" "%ICON_UNINSTALL%"
if errorlevel 1 exit /b 1
del /q "%SUPPORT_DIR%\helper_icon.ico" "%SUPPORT_DIR%\force_update.ico" "%SUPPORT_DIR%\uninstall.ico" >nul 2>&1
>"%SUPPORT_VERSION_FILE%" echo %HELPER_VERSION%
exit /b 0
:extract_b64_payload
set "PAYLOAD_NAME=%~1"
set "PAYLOAD_OUT=%~2"
set "ASE_HELPER_SELF=%~f0"
set "ABH_PAYLOAD_NAME=%PAYLOAD_NAME%"
set "ABH_PAYLOAD_OUT=%PAYLOAD_OUT%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$raw=[IO.File]::ReadAllText($env:ASE_HELPER_SELF);$e=[regex]::Escape($env:ABH_PAYLOAD_NAME);$m=[regex]::Match($raw,'(?s)###BEGIN:'+$e+'###\r?\n(.*?)\r?\n###END:'+$e+'###');if(-not $m.Success){exit 1};[IO.File]::WriteAllBytes($env:ABH_PAYLOAD_OUT,[Convert]::FromBase64String($m.Groups[1].Value.Trim()))" >nul 2>&1
exit /b %errorlevel%

rem Never execute embedded payloads as BAT commands.
exit /b 0


###BEGIN:progress_ui.ps1###
param([Parameter(Mandatory=$true)][string]$StatePath,[string]$Language='en',[ValidateSet('setup','update')][string]$Mode='setup')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$isDe=$Language -eq 'de'
$form=New-Object System.Windows.Forms.Form
$form.Text=if($Mode -eq 'setup'){if($isDe){'Aseprite Build Helper - Einrichtung'}else{'Aseprite Build Helper - Setup'}}else{'Aseprite Build Updater - Update'}
$form.Size=New-Object System.Drawing.Size(560,215);$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
$title=New-Object System.Windows.Forms.Label;$title.Location=New-Object System.Drawing.Point(22,18);$title.Size=New-Object System.Drawing.Size(500,28);$title.Font=New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold)
$title.Text=if($Mode -eq 'setup'){if($isDe){'Aseprite wird eingerichtet'}else{'Setting up Aseprite'}}else{if($isDe){'Updates werden geprüft'}else{'Checking for updates'}};$form.Controls.Add($title)
$status=New-Object System.Windows.Forms.Label;$status.Location=New-Object System.Drawing.Point(22,55);$status.Size=New-Object System.Drawing.Size(500,24);$status.Font=New-Object System.Drawing.Font('Segoe UI',9);$form.Controls.Add($status)
$bar=New-Object System.Windows.Forms.ProgressBar;$bar.Location=New-Object System.Drawing.Point(22,88);$bar.Size=New-Object System.Drawing.Size(500,24);$bar.Minimum=0;$bar.Maximum=100;$form.Controls.Add($bar)
$phase=New-Object System.Windows.Forms.Label;$phase.Location=New-Object System.Drawing.Point(22,123);$phase.Size=New-Object System.Drawing.Size(500,22);$phase.Font=New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold);$form.Controls.Add($phase)
$accent=New-Object System.Windows.Forms.Panel;$accent.Location=New-Object System.Drawing.Point(22,153);$accent.Size=New-Object System.Drawing.Size(500,5);$form.Controls.Add($accent)
$colors=@{check=[Drawing.Color]::FromArgb(45,125,210);aseprite=[Drawing.Color]::FromArgb(45,125,210);theme=[Drawing.Color]::FromArgb(138,74,190);addon=[Drawing.Color]::FromArgb(45,160,90);build=[Drawing.Color]::FromArgb(225,135,40);warning=[Drawing.Color]::FromArgb(210,165,30);error=[Drawing.Color]::FromArgb(200,55,55);success=[Drawing.Color]::FromArgb(45,160,90)}
$de=@{'Checking prerequisites...'='Voraussetzungen werden geprüft...';'Preparing Aseprite source...'='Aseprite-Quellcode wird vorbereitet...';'Building Aseprite...'='Aseprite wird kompiliert...';'Installing themes...'='Themes werden installiert...';'Installing add-ons and scripts...'='Add-ons und Skripte werden installiert...';'Creating runtime components and shortcuts...'='Launcher, Updater und Verknüpfungen werden erstellt...';'Setup completed successfully.'='Einrichtung erfolgreich abgeschlossen.';'Checking ABH updates...'='ABH-Updates werden geprüft...';'Checking Aseprite updates...'='Aseprite-Updates werden geprüft...';'Aseprite update check failed; installed build will be kept.'='Aseprite-Updateprüfung fehlgeschlagen; die installierte Version bleibt erhalten.';'Checking themes...'='Themes werden geprüft...';'Checking add-ons and scripts...'='Add-ons und Skripte werden geprüft...';'Update check completed.'='Updateprüfung abgeschlossen.';'Configuring CMake...'='CMake wird konfiguriert...';'Compiling Aseprite with Ninja...'='Aseprite wird mit Ninja kompiliert...'}
$script:last=''
$timer=New-Object System.Windows.Forms.Timer;$timer.Interval=250
$timer.Add_Tick({try{if(-not(Test-Path -LiteralPath $StatePath)){return};$raw=[IO.File]::ReadAllText($StatePath,[Text.Encoding]::UTF8).Trim();if(-not $raw -or $raw -eq $script:last){return};$script:last=$raw;$p=$raw.Split('|',4);if($p.Count -lt 4){return};if($p[0]-eq'CLOSE'){$timer.Stop();$form.Close();return};$pct=0;[int]::TryParse($p[0],[ref]$pct)|Out-Null;$kind=$p[1];$step=$p[2];$msg=$p[3];if($isDe -and $de.ContainsKey($msg)){$msg=$de[$msg]};$status.Text=$msg;$phase.Text=$step;if($colors.ContainsKey($kind)){$phase.ForeColor=$colors[$kind];$title.ForeColor=$colors[$kind];$accent.BackColor=$colors[$kind]};if($pct -lt 0){$bar.Style='Marquee';$bar.MarqueeAnimationSpeed=25}else{$bar.Style='Continuous';$bar.Value=[Math]::Max(0,[Math]::Min(100,$pct))}}catch{}})
$form.Add_Shown({$timer.Start()});[void]$form.ShowDialog()

###END:progress_ui.ps1###

###BEGIN:source_config.ps1###
param([Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference='Stop'
$themeDir=Join-Path $Root 'themes';$addonDir=Join-Path $Root 'addons';$mixedDir=Join-Path $Root 'mixed'
New-Item -ItemType Directory -Force -Path $Root,$themeDir,$addonDir,$mixedDir|Out-Null
function Ensure-File([string]$Relative,[string]$Content){$p=Join-Path $Root $Relative;if(-not(Test-Path -LiteralPath $p)){$d=Split-Path $p -Parent;New-Item -ItemType Directory -Force -Path $d|Out-Null;Set-Content -LiteralPath $p -Value $Content -Encoding UTF8}}
Ensure-File 'themes/catppuccin.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Catppuccin
type=theme
repository=https://github.com/catppuccin/aseprite.git
enabled=true
auto_update=true
install_mode=auto
managed_by=ABH
'@
Ensure-File 'themes/nord.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Nord
type=theme
repository=https://github.com/marsn3/aseprite-nord.git
enabled=true
auto_update=true
install_mode=auto
managed_by=ABH
'@
Ensure-File 'themes/dracula.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Dracula
type=theme
repository=https://github.com/dracula/aseprite.git
enabled=true
auto_update=true
install_mode=auto
managed_by=ABH
'@
Ensure-File 'themes/studio.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Studio
type=theme
repository=https://github.com/Lyutria/aseprite-studio-theme.git
enabled=true
auto_update=true
install_mode=auto
managed_by=ABH
'@
Ensure-File 'themes/monaki.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Monaki
type=theme
repository=https://github.com/el-falso/monaki-theme.git
enabled=true
auto_update=true
install_mode=auto
managed_by=ABH
'@
Ensure-File 'themes/jmswrnr.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=JMSWRNR Themes
type=theme
repository=https://github.com/jmswrnr/aseprite-themes.git
enabled=true
auto_update=true
install_mode=auto
managed_by=ABH
'@
Ensure-File 'themes/dark-moon.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Dark Moon
type=theme
repository=https://github.com/emhuo/dark-moon-theme.git
enabled=true
auto_update=true
install_mode=auto
managed_by=ABH
'@
Ensure-File 'themes/aletheia.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Aletheia
type=theme
repository=https://github.com/behreajj/Aletheia.git
enabled=true
auto_update=true
install_mode=auto
managed_by=ABH
'@
Ensure-File 'addons/thkwznk.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=thkwznk Aseprite Scripts
type=addon
repository=https://github.com/thkwznk/aseprite-scripts.git
enabled=true
auto_update=true
install_mode=both
managed_by=ABH
'@
Ensure-File 'addons/pixeltica.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Pixeltica AsepriteExtensions
type=addon
repository=https://github.com/Pixeltica/AsepriteExtensions.git
enabled=true
auto_update=true
install_mode=both
managed_by=ABH
'@
Ensure-File 'addons/snepsid.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Snepsid Scripts
type=addon
repository=https://github.com/Snepsid/aseprite-scripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/christopherwk210.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=christopherwk210 Scripts
type=addon
repository=https://github.com/christopherwk210/aseprite-scripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/sandord.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=sandord Scripts
type=addon
repository=https://github.com/sandord/aseprite-scripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/mrbrownjeremy.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=mrbrownjeremy Scripts
type=addon
repository=https://github.com/mrbrownjeremy/aseprite-scripts.git
enabled=true
auto_update=true
install_mode=both
managed_by=ABH
'@
Ensure-File 'addons/colinlienard.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=colinlienard Scripts
type=addon
repository=https://github.com/colinlienard/aseprite-scripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/aseprite-examples.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Aseprite Script Examples
type=addon
repository=https://github.com/aseprite/Aseprite-Script-Examples.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/opsis-isometric.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=OpsisKalopsis Scripts
type=addon
repository=https://github.com/OpsisKalopsis/aseprite-scripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/gabinou-tilemap.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Gabinou Tilemap Scripts
type=addon
repository=https://github.com/Gabinou/tilemap_scripts_aseprite.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/dominickjohn-shading.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=DominickJohn Scripts
type=addon
repository=https://github.com/dominickjohn/aseprite.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/limeth-iso.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Limeth Isometric Scripts
type=addon
repository=https://github.com/Limeth/aseprite-iso-scripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/quantumsheep-export.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=QuantumSheep Export Layers
type=addon
repository=https://github.com/quantumsheep/aseprite-export-layers.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/lospec-importer.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Lospec Palette Importer
type=addon
repository=https://github.com/JRiggles/Lospec-Palette-Importer.git
enabled=true
auto_update=true
install_mode=both
managed_by=ABH
'@
Ensure-File 'addons/dithering-brushes.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Dithering Brushes
type=addon
repository=https://github.com/exokem/aseprite-dithering-brushes.git
enabled=true
auto_update=true
install_mode=both
managed_by=ABH
'@
Ensure-File 'addons/edge-normals.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=EdgeNormals
type=addon
repository=https://github.com/securas/EdgeNormals.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/height-normalmap.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Aseprite Normalmap
type=addon
repository=https://github.com/carlmartus/aseprite_normalmap.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/beatso-tools.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Useful Aseprite Scripts
type=addon
repository=https://github.com/Beatso/UsefulAsepriteScripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/ez-outline.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=EZ Outline
type=addon
repository=https://github.com/iNightfaller/aseprite-ez-outline.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/zachary-tools.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Zachary Aseprite Scripts
type=addon
repository=https://github.com/ZachIsAGardner/ZacharyAsepriteScripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/normal-tileset-tools.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Normal Map and Tileset Tools
type=addon
repository=https://github.com/SavuGeorge/Aseprite-scripts-for-normal-map-and-tileset-manipulation.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/rikfuzz-tools.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=rikfuzz Scripts
type=addon
repository=https://github.com/rikfuzz/aseprite-scripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/puzzlescript-export.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=PuzzleScript Export
type=addon
repository=https://github.com/pancelor/aseprite-puzzlescript-export.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/davebarker-animation.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=Dave Barker Animation Scripts
type=addon
repository=https://github.com/davebarkeruk/Aseprite_LUA_Scripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/tekf-parallax.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=TekF Parallax
type=addon
repository=https://github.com/TekF/Aseprite-Scripts.git
enabled=true
auto_update=true
install_mode=scripts
managed_by=ABH
'@
Ensure-File 'addons/lpc2ase.ini' @'
; Source managed by Aseprite Build Helper (ABH)
; enabled=true      -> ABH installs/uses this source
; auto_update=true  -> ABH may pull updates automatically
; auto_update=false -> ABH keeps the cached copy and does not pull automatically
; Change auto_update only for repositories you trust.
[Source]
name=LPC2ASE
type=addon
repository=https://github.com/IoriBranford/aseprite-import-lpc-character.git
enabled=true
auto_update=true
install_mode=both
managed_by=ABH
'@
Ensure-File 'themes/_USER_THEME_TEMPLATE.ini' @'
; Copy this file to another .ini filename inside themes\ and edit the values.
; auto_update=false is the safe default for user-added repositories.
[Source]
name=My custom theme
type=theme
repository=https://github.com/USER/REPOSITORY.git
enabled=true
auto_update=false
install_mode=auto
managed_by=user
'@
Ensure-File 'addons/_USER_ADDON_TEMPLATE.ini' @'
; Copy this file to another .ini filename inside addons\ and edit the values.
; install_mode may be scripts, extensions, or both.
; auto_update=false is the safe default for user-added repositories.
[Source]
name=My custom add-on
type=addon
repository=https://github.com/USER/REPOSITORY.git
enabled=true
auto_update=false
install_mode=both
managed_by=user
'@
Ensure-File 'mixed/_USER_SOURCE_TEMPLATE.ini' @'
; Copy this file to a new .ini file and edit the values.
; User-added repositories default to auto_update=false.
; Set auto_update=true only for repositories you trust.
[Source]
name=My custom Aseprite source
type=mixed
repository=https://github.com/USER/REPOSITORY.git
enabled=true
auto_update=false
install_mode=both
managed_by=user
'@

###END:source_config.ps1###

###BEGIN:aseprite_preflight.ps1###
param(
  [string]$ReadmePath = "",
  [string]$SkiaRoot = "C:\deps\skia",
  [string]$AsepriteRoot = "C:\aseprite",
  [string]$Language = ""
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "SilentlyContinue"

if ([string]::IsNullOrWhiteSpace($Language)) {
  try { $Language = (Get-UICulture).TwoLetterISOLanguageName } catch { $Language = "en" }
}
$Language = $Language.ToLowerInvariant()
if ($Language -ne "de") { $Language = "en" }

$T = if ($Language -eq "de") {
  @{
    Title="Aseprite Build Helper - Schnelleinrichtung"
    AllGood="Alle Voraussetzungen sind vorhanden."
    MissingFmt="Es fehlen {0} Voraussetzung(en)."
    Found="OK"
    Missing="FEHLT"
    HelpHeader="HILFE / OFFIZIELLE QUELLEN"
    Expected="Erwartet"
    NotFound="Nicht gefunden"
    NotInPath="Nicht gefunden oder nicht im PATH"
    VsMissing="Visual Studio C++-Toolchain fehlt. Im Visual Studio Installer die Workload 'Desktopentwicklung mit C++' und ein Windows SDK installieren."
    SdkMissing="Windows SDK nicht gefunden."
    SourceGood="Ziel ist frei oder bereits ein gültiges Git-Repository."
    SourceBadFmt="{0} existiert, ist aber kein Git-Repository. Den Ordner bitte umbenennen oder entfernen."
    SpaceFmt="{0} GB frei (empfohlen: mindestens 4 GB)"
    SpaceName="Freier Speicher auf C:"
    Ready="Alles bereit. Mit einem Klick startet die vollständige Einrichtung; danach läuft der Rest automatisch."
    NoBinary="Fehlende Voraussetzungen müssen zuerst installiert werden. ABH liefert keine fertige Aseprite-Binary mit; Aseprite wird lokal aus dem offiziellen Quellcode gebaut."
    Sources="Offizielle Seiten:"
    SkiaHint="Skia muss so entpackt sein, dass diese Datei existiert:"
    OpenReadme="README öffnen"
    Exit="Beenden"
    Retry="Erneut prüfen"
    Build="Einrichtung starten"
    OpenFolder="Skia-Ordner öffnen"
    Eula="Aseprite EULA"
    Ack="Ich verstehe, dass Aseprite lokal für meinen eigenen persönlichen Gebrauch gebaut wird und dass dieses Toolkit keine fertige Aseprite-Version verteilt."
    NeedAck="Bitte den Hinweis zur persönlichen Nutzung bestätigen, bevor der Build gestartet wird."
    Git="Git for Windows"
    CMake="CMake"
    Ninja="Ninja"
    VS="Visual Studio C++ Toolchain"
    SDK="Windows SDK"
    Skia="Skia m124 Windows x64 Release"
    Target="Aseprite Zielordner"
  }
} else {
  @{
    Title="Aseprite Build Helper - Quick Setup"
    AllGood="All prerequisites are available."
    MissingFmt="{0} prerequisite(s) are missing."
    Found="OK"
    Missing="MISSING"
    HelpHeader="HELP / OFFICIAL SOURCES"
    Expected="Expected"
    NotFound="Not found"
    NotInPath="Not found or not available in PATH"
    VsMissing="Visual Studio C++ toolchain is missing. In Visual Studio Installer, install the 'Desktop development with C++' workload and a Windows SDK."
    SdkMissing="Windows SDK not found."
    SourceGood="Target is free or already a valid Git repository."
    SourceBadFmt="{0} exists but is not a Git repository. Rename or remove that folder first."
    SpaceFmt="{0} GB free (recommended: at least 4 GB)"
    SpaceName="Free space on C:"
    Ready="Everything is ready. One click starts the complete setup; the remaining steps then run automatically."
    NoBinary="Missing prerequisites must be installed first. ABH does not ship a compiled Aseprite binary; Aseprite is built locally from the official source code."
    Sources="Official pages:"
    SkiaHint="Skia must be extracted so this file exists:"
    OpenReadme="Open README"
    Exit="Exit"
    Retry="Check again"
    Build="Start setup"
    OpenFolder="Open Skia folder"
    Eula="Aseprite EULA"
    Ack="I understand that Aseprite will be built locally for my own personal use and that this toolkit does not distribute a compiled copy of Aseprite."
    NeedAck="Please confirm the personal-use notice before starting the build."
    Git="Git for Windows"
    CMake="CMake"
    Ninja="Ninja"
    VS="Visual Studio C++ Toolchain"
    SDK="Windows SDK"
    Skia="Skia m124 Windows x64 Release"
    Target="Aseprite target folder"
  }
}

$Urls = @{
  Git = "https://git-scm.com/download/win"
  CMake = "https://cmake.org/download/"
  VisualStudio = "https://visualstudio.microsoft.com/vs/community/"
  Ninja = "https://github.com/ninja-build/ninja/releases"
  Skia = "https://github.com/aseprite/skia/releases/download/m124-08a5439a6b/Skia-Windows-Release-x64.zip"
  Aseprite = "https://github.com/aseprite/aseprite"
  Eula = "https://github.com/aseprite/aseprite/blob/main/EULA.txt"
}

function Get-Checks {
  $checks = New-Object System.Collections.Generic.List[object]

  $git = Get-Command git.exe -ErrorAction SilentlyContinue
  $checks.Add([pscustomobject]@{
    Name=$T.Git; Ok=[bool]$git
    Detail=if($git){$git.Source}else{$T.NotFound}
    Help="Git"
  })

  $cmake = Get-Command cmake.exe -ErrorAction SilentlyContinue
  $checks.Add([pscustomobject]@{
    Name=$T.CMake; Ok=[bool]$cmake
    Detail=if($cmake){$cmake.Source}else{$T.NotInPath}
    Help="CMake"
  })

  $ninja = Get-Command ninja.exe -ErrorAction SilentlyContinue
  if(-not $ninja) {
    $candidate = "C:\Program Files\CMake\bin\ninja.exe"
    if(Test-Path $candidate) { $ninja = Get-Item $candidate }
  }
  $checks.Add([pscustomobject]@{
    Name=$T.Ninja; Ok=[bool]$ninja
    Detail=if($ninja){$ninja.FullName}else{"ninja.exe: " + $T.NotFound}
    Help="Ninja"
  })

  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  $vsPath = $null
  if(Test-Path $vswhere) {
    $vsPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null | Select-Object -First 1)
  }
  $vcvars = if($vsPath){ Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat" } else { $null }
  $vsOk = $vsPath -and (Test-Path $vcvars)
  $checks.Add([pscustomobject]@{
    Name=$T.VS; Ok=[bool]$vsOk
    Detail=if($vsOk){$vcvars}else{$T.VsMissing}
    Help="VisualStudio"
  })

  $sdkRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\Include"
  $sdkOk = Test-Path $sdkRoot
  $checks.Add([pscustomobject]@{
    Name=$T.SDK; Ok=$sdkOk
    Detail=if($sdkOk){$sdkRoot}else{$T.SdkMissing}
    Help="VisualStudio"
  })

  $skiaLib = Join-Path $SkiaRoot "out\Release-x64\skia.lib"
  $skiaInclude = Join-Path $SkiaRoot "include"
  $skiaOk = (Test-Path $skiaLib) -and (Test-Path $skiaInclude)
  $checks.Add([pscustomobject]@{
    Name=$T.Skia; Ok=$skiaOk
    Detail=if($skiaOk){$skiaLib}else{"$($T.Expected): $skiaLib"}
    Help="Skia"
  })

  $sourceOk = $true
  $sourceDetail = $T.SourceGood
  if((Test-Path $AsepriteRoot) -and -not (Test-Path (Join-Path $AsepriteRoot ".git"))) {
    $sourceOk = $false
    $sourceDetail = [string]::Format($T.SourceBadFmt, $AsepriteRoot)
  }
  $checks.Add([pscustomobject]@{
    Name=$T.Target; Ok=$sourceOk; Detail=$sourceDetail; Help="Aseprite"
  })

  try {
    $drive = Get-PSDrive -Name C
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
    $spaceOk = $freeGB -ge 4
    $checks.Add([pscustomobject]@{
      Name=$T.SpaceName; Ok=$spaceOk
      Detail=[string]::Format($T.SpaceFmt, $freeGB)
      Help=""
    })
  } catch {}

  return $checks
}

function Open-Link([string]$key) {
  if($Urls.ContainsKey($key)) { Start-Process $Urls[$key] }
}

function Show-Preflight([object[]]$checks) {
  $missing = @($checks | Where-Object { -not $_.Ok })

  $form = New-Object System.Windows.Forms.Form
  $form.Text = $T.Title
  $form.StartPosition = "CenterScreen"
  $form.Size = New-Object System.Drawing.Size(900, 735)
  $form.MinimumSize = New-Object System.Drawing.Size(820, 650)
  $form.TopMost = $true

  $title = New-Object System.Windows.Forms.Label
  $title.Location = New-Object System.Drawing.Point(18, 14)
  $title.Size = New-Object System.Drawing.Size(840, 40)
  $title.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
  $title.Text = if($missing.Count -eq 0) { $T.AllGood } else { [string]::Format($T.MissingFmt, $missing.Count) }
  $form.Controls.Add($title)

  $box = New-Object System.Windows.Forms.TextBox
  $box.Multiline = $true
  $box.ReadOnly = $true
  $box.ScrollBars = "Vertical"
  $box.Font = New-Object System.Drawing.Font("Consolas", 9.3)
  $box.Location = New-Object System.Drawing.Point(18, 58)
  $box.Size = New-Object System.Drawing.Size(846, 370)
  $box.Anchor = "Top,Bottom,Left,Right"

  $lines = New-Object System.Collections.Generic.List[string]
  foreach($c in $checks) {
    $state = if($c.Ok){"[ $($T.Found) ]"}else{"[$($T.Missing)]"}
    $lines.Add("$state $($c.Name)")
    $lines.Add("    $($c.Detail)")
    $lines.Add("")
  }

  $lines.Add($T.HelpHeader)
  $lines.Add("Git:           " + $Urls.Git)
  $lines.Add("CMake:         " + $Urls.CMake)
  $lines.Add("Visual Studio: " + $Urls.VisualStudio)
  $lines.Add("Ninja:         " + $Urls.Ninja)
  $lines.Add("Skia m124:     " + $Urls.Skia)
  $lines.Add("Aseprite:      " + $Urls.Aseprite)
  $lines.Add("EULA:          " + $Urls.Eula)
  $lines.Add("")
  $lines.Add($T.SkiaHint)
  $lines.Add("C:\deps\skia\out\Release-x64\skia.lib")
  $lines.Add("")
  $lines.Add(if($missing.Count -eq 0){$T.Ready}else{$T.NoBinary})

  $box.Text = ($lines -join [Environment]::NewLine)
  $form.Controls.Add($box)

  $y = 445
  $helpLabel = New-Object System.Windows.Forms.Label
  $helpLabel.Location = New-Object System.Drawing.Point(18, $y)
  $helpLabel.Size = New-Object System.Drawing.Size(840, 22)
  $helpLabel.Text = $T.Sources
  $helpLabel.Anchor = "Bottom,Left"
  $form.Controls.Add($helpLabel)
  $y += 25

  $buttons = @(
    @("Git","Git"), @("CMake","CMake"), @("Visual Studio","VisualStudio"),
    @("Ninja","Ninja"), @("Skia","Skia"), @($T.Eula,"Eula")
  )
  $x = 18
  foreach($b in $buttons) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $b[0]
    $btn.Tag = $b[1]
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size(130, 30)
    $btn.Anchor = "Bottom,Left"
    $btn.Add_Click({ Open-Link $this.Tag })
    $form.Controls.Add($btn)
    $x += 138
  }

  $y += 40
  $folder = New-Object System.Windows.Forms.Button
  $folder.Text = $T.OpenFolder
  $folder.Location = New-Object System.Drawing.Point(18, $y)
  $folder.Size = New-Object System.Drawing.Size(175, 30)
  $folder.Anchor = "Bottom,Left"
  $folder.Add_Click({
    $parent = Split-Path $SkiaRoot -Parent
    if(-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Start-Process explorer.exe -ArgumentList ('"' + $parent + '"')
  })
  $form.Controls.Add($folder)

  if($ReadmePath -and (Test-Path $ReadmePath)) {
    $readme = New-Object System.Windows.Forms.Button
    $readme.Text = $T.OpenReadme
    $readme.Location = New-Object System.Drawing.Point(202, $y)
    $readme.Size = New-Object System.Drawing.Size(145, 30)
    $readme.Anchor = "Bottom,Left"
    $readme.Add_Click({ Start-Process notepad.exe -ArgumentList ('"' + $ReadmePath + '"') })
    $form.Controls.Add($readme)
  }

  $ack = New-Object System.Windows.Forms.CheckBox
  $ack.Location = New-Object System.Drawing.Point(18, ($y + 40))
  $ack.Size = New-Object System.Drawing.Size(840, 54)
  $ack.Text = $T.Ack
  $ack.Checked = $false
  $ack.Anchor = "Bottom,Left,Right"
  $form.Controls.Add($ack)

  $bottomY = $y + 102

  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = $T.Exit
  $cancel.Location = New-Object System.Drawing.Point(605, $bottomY)
  $cancel.Size = New-Object System.Drawing.Size(120, 34)
  $cancel.Anchor = "Bottom,Right"
  $cancel.Add_Click({ $form.Tag="cancel"; $form.Close() })
  $form.Controls.Add($cancel)

  $action = New-Object System.Windows.Forms.Button
  $action.Text = if($missing.Count -eq 0){$T.Build}else{$T.Retry}
  $action.Location = New-Object System.Drawing.Point(734, $bottomY)
  $action.Size = New-Object System.Drawing.Size(130, 34)
  $action.Anchor = "Bottom,Right"
  $action.Add_Click({
    if($missing.Count -eq 0) {
      if(-not $ack.Checked) {
        [System.Windows.Forms.MessageBox]::Show($T.NeedAck, $T.Title, "OK", "Information") | Out-Null
        return
      }
      $form.Tag="continue"
    } else {
      $form.Tag="retry"
    }
    $form.Close()
  })
  $form.Controls.Add($action)
  $form.AcceptButton = $action
  $form.CancelButton = $cancel

  [void]$form.ShowDialog()
  return [string]$form.Tag
}

while($true) {
  $checks = @(Get-Checks)
  $result = Show-Preflight $checks
  if($result -eq "continue") { exit 0 }
  if($result -eq "retry") { continue }
  exit 2
}
###END:aseprite_preflight.ps1###

###BEGIN:aseprite_themes.ps1###
param(
  [switch]$Force
)

$ErrorActionPreference = "Continue"

$ManagerRoot = Join-Path $env:ABH_DATA_ROOT "managed\themes"
$RepoRoot = Join-Path $ManagerRoot "repos"
$LogDir = Join-Path $env:ABH_DATA_ROOT "logs\user"
$LogFile = Join-Path $LogDir "aseprite_themes.log"
$ExtensionRoot = Join-Path $env:APPDATA "Aseprite\extensions"
$ManifestRoot = Join-Path $env:ABH_DATA_ROOT "manifest"
$ManagedManifest = Join-Path $ManifestRoot "managed-theme-extensions.txt"
New-Item -ItemType Directory -Force -Path $ManifestRoot | Out-Null
Remove-Item -LiteralPath $ManagedManifest -Force -ErrorAction SilentlyContinue
function Register-ManagedExtension([string]$Path) {
  if ($Path) { Add-Content -LiteralPath $ManagedManifest -Value $Path -Encoding UTF8 }
}

New-Item -ItemType Directory -Force -Path $ManagerRoot, $RepoRoot, $LogDir, $ExtensionRoot | Out-Null

function Write-Log([string]$Text) {
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content -LiteralPath $LogFile -Value "[$stamp] $Text"
}

function Safe-Name([string]$Text) {
  $s = $Text -replace '[^A-Za-z0-9._-]', '-'
  $s = $s.Trim('-')
  if ([string]::IsNullOrWhiteSpace($s)) { $s = "theme" }
  return $s
}

function Sync-Repo {
  param(
    [string]$Id,
    [string]$Url
  )

  $repoPath = Join-Path $RepoRoot $Id

  try {
    if (-not (Test-Path (Join-Path $repoPath ".git"))) {
      if (Test-Path $repoPath) {
        Remove-Item -LiteralPath $repoPath -Recurse -Force -ErrorAction SilentlyContinue
      }

      Write-Log "CLONE $Id <- $Url"
      & git clone --depth 1 --quiet $Url $repoPath 2>> $LogFile
      if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR clone failed: $Id"
        return $null
      }
    }
    else {
      Write-Log "UPDATE $Id"
      & git -C $repoPath pull --ff-only --quiet 2>> $LogFile
      if ($LASTEXITCODE -ne 0) {
        Write-Log "WARNING pull failed; using installed/cached copy: $Id"
      }
    }

    return $repoPath
  }
  catch {
    Write-Log "ERROR repo $Id : $($_.Exception.Message)"
    return $null
  }
}

function Copy-ExtensionRoot {
  param(
    [string]$SourcePath,
    [string]$DestinationName
  )

  $dest = Join-Path $ExtensionRoot ("auto-" + (Safe-Name $DestinationName))
  Register-ManagedExtension $dest

  try {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null

    # /MIR keeps an already installed theme in sync with its Git repository.
    # Git metadata and screenshots/docs that are not needed by Aseprite are harmless,
    # but .git/.github are excluded.
    & robocopy $SourcePath $dest /MIR /NFL /NDL /NJH /NJS /NP /XD ".git" ".github" 1>> $LogFile 2>&1
    $rc = $LASTEXITCODE

    # Robocopy 0..7 are success/informational return codes.
    if ($rc -ge 8) {
      Write-Log "ERROR robocopy failed ($rc): $SourcePath -> $dest"
      return $false
    }

    Write-Log "INSTALLED/SYNCED $DestinationName -> $dest"
    return $true
  }
  catch {
    Write-Log "ERROR copy $DestinationName : $($_.Exception.Message)"
    return $false
  }
}

function Install-ThemePackagesFromRepo {
  param(
    [string]$RepoId,
    [string]$RepoPath
  )

  if (-not $RepoPath -or -not (Test-Path $RepoPath)) {
    return
  }

  $coveredRoots = New-Object System.Collections.Generic.List[string]
  $installed = 0

  # Preferred path: a real Aseprite extension package.json with contributes.themes.
  $packageFiles = Get-ChildItem -LiteralPath $RepoPath -Filter "package.json" -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\\.git\\' }

  foreach ($pkgFile in $packageFiles) {
    try {
      $pkg = Get-Content -LiteralPath $pkgFile.FullName -Raw | ConvertFrom-Json
      if ($null -eq $pkg.contributes -or $null -eq $pkg.contributes.themes) {
        continue
      }

      $pkgRoot = $pkgFile.Directory.FullName
      $pkgName =
        if ($pkg.name) { [string]$pkg.name }
        elseif ($pkg.displayName) { [string]$pkg.displayName }
        else { $pkgFile.Directory.Name }

      $destName = "$RepoId-$pkgName"
      if (Copy-ExtensionRoot -SourcePath $pkgRoot -DestinationName $destName) {
        $coveredRoots.Add($pkgRoot.TrimEnd('\')) | Out-Null
        $installed++
      }
    }
    catch {
      Write-Log "WARNING bad package.json: $($pkgFile.FullName)"
    }
  }

  # Fallback for repositories that contain unpacked theme folders but no package.json
  # for each individual theme. We generate a tiny Aseprite package manifest locally.
  $themeFiles = Get-ChildItem -LiteralPath $RepoPath -Filter "theme.xml" -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\\.git\\' }

  foreach ($themeFile in $themeFiles) {
    $themeDir = $themeFile.Directory.FullName

    $alreadyCovered = $false
    foreach ($root in $coveredRoots) {
      if ($themeDir.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $alreadyCovered = $true
        break
      }
    }
    if ($alreadyCovered) { continue }

    if (-not (Test-Path (Join-Path $themeDir "sheet.png"))) {
      Write-Log "SKIP theme.xml without sheet.png: $themeDir"
      continue
    }

    $relative = $themeDir.Substring($RepoPath.Length).Trim('\')
    if ([string]::IsNullOrWhiteSpace($relative)) {
      $relative = $themeFile.Directory.Name
    }

    $themeId = Safe-Name "$RepoId-$relative"
    $dest = Join-Path $ExtensionRoot ("auto-" + $themeId)
    Register-ManagedExtension $dest

    try {
      New-Item -ItemType Directory -Force -Path $dest | Out-Null
      & robocopy $themeDir $dest /MIR /NFL /NDL /NJH /NJS /NP /XD ".git" ".github" 1>> $LogFile 2>&1
      $rc = $LASTEXITCODE
      if ($rc -ge 8) {
        Write-Log "ERROR fallback robocopy failed ($rc): $themeDir"
        continue
      }

      $manifest = [ordered]@{
        name = $themeId
        displayName = "$RepoId - $relative"
        description = "Automatically managed Aseprite theme"
        version = "1.0"
        publisher = "auto-theme-manager"
        categories = @("Themes")
        contributes = @{
          themes = @(
            @{
              id = $themeId
              path = "."
              variant = "Dark"
            }
          )
        }
      }

      $manifest | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath (Join-Path $dest "package.json") -Encoding UTF8

      Write-Log "INSTALLED/SYNCED generated theme $themeId -> $dest"
      $installed++
    }
    catch {
      Write-Log "ERROR generated theme $themeId : $($_.Exception.Message)"
    }
  }

  Write-Log "Repo $RepoId produced $installed installable theme package(s)."
}

Write-Log "============================================================"
Write-Log "THEME SYNC START"

$ConfigRoot = Join-Path $env:ABH_DATA_ROOT "config\sources\themes"
function Read-IniSource([string]$Path) {
  $data = @{}
  foreach ($line in Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue) {
    $t = $line.Trim()
    if (-not $t -or $t.StartsWith(';') -or $t.StartsWith('#') -or $t.StartsWith('[')) { continue }
    $i = $t.IndexOf('=')
    if ($i -gt 0) { $data[$t.Substring(0,$i).Trim().ToLowerInvariant()] = $t.Substring($i+1).Trim() }
  }
  return $data
}

$configFiles = @(Get-ChildItem -LiteralPath $ConfigRoot -Filter '*.ini' -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notlike '_*' } | Sort-Object Name)

foreach ($cfg in $configFiles) {
  $c = Read-IniSource $cfg.FullName
  if (($c['enabled'] -as [string]) -notmatch '^(?i:true|1|yes)$') { continue }
  $url = $c['repository']
  if ([string]::IsNullOrWhiteSpace($url)) { Write-Log "SKIP config without repository: $($cfg.FullName)"; continue }

  $id = $cfg.BaseName
  $auto = (($c['auto_update'] -as [string]) -match '^(?i:true|1|yes)$')
  $repoPath = Join-Path $RepoRoot $id

  if (-not (Test-Path (Join-Path $repoPath '.git'))) {
    $repo = Sync-Repo -Id $id -Url $url
  }
  elseif ($auto) {
    $repo = Sync-Repo -Id $id -Url $url
  }
  else {
    Write-Log "AUTO-UPDATE disabled; using cached theme repo: $id"
    $repo = $repoPath
  }

  if ($repo) { Install-ThemePackagesFromRepo -RepoId $id -RepoPath $repo }
}

Write-Log "THEME SYNC END"
exit 0
###END:aseprite_themes.ps1###

###BEGIN:aseprite_addons.ps1###
$ErrorActionPreference = "Continue"

$ManagerRoot = Join-Path $env:ABH_DATA_ROOT "managed\addons"
$RepoRoot = Join-Path $ManagerRoot "repos"
$LogDir = Join-Path $env:ABH_DATA_ROOT "logs\user"
$LogFile = Join-Path $LogDir "aseprite_addons.log"

$ScriptsRoot = Join-Path $env:APPDATA "Aseprite\scripts\auto-managed"
$ExtensionsRoot = Join-Path $env:APPDATA "Aseprite\extensions"

New-Item -ItemType Directory -Force -Path `
  $ManagerRoot, $RepoRoot, $LogDir, $ScriptsRoot, $ExtensionsRoot | Out-Null

function Write-Log([string]$Text) {
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content -LiteralPath $LogFile -Value "[$stamp] $Text"
}

function Safe-Name([string]$Text) {
  $s = $Text -replace '[^A-Za-z0-9._-]', '-'
  $s = $s.Trim('-')
  if ([string]::IsNullOrWhiteSpace($s)) { $s = "addon" }
  return $s
}

function Sync-Repo {
  param(
    [string]$Id,
    [string]$Url
  )

  $repoPath = Join-Path $RepoRoot $Id

  try {
    if (-not (Test-Path (Join-Path $repoPath ".git"))) {
      if (Test-Path $repoPath) {
        Remove-Item -LiteralPath $repoPath -Recurse -Force -ErrorAction SilentlyContinue
      }

      Write-Log "CLONE $Id <- $Url"
      & git clone --depth 1 --quiet $Url $repoPath 2>> $LogFile

      if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR clone failed: $Id"
        return $null
      }
    }
    else {
      Write-Log "UPDATE $Id"
      & git -C $repoPath pull --ff-only --quiet 2>> $LogFile

      if ($LASTEXITCODE -ne 0) {
        Write-Log "WARNING pull failed; keeping cached copy: $Id"
      }
    }

    return $repoPath
  }
  catch {
    Write-Log "ERROR repo $Id : $($_.Exception.Message)"
    return $null
  }
}

function Mirror-Folder {
  param(
    [string]$Source,
    [string]$Destination
  )

  New-Item -ItemType Directory -Force -Path $Destination | Out-Null

  & robocopy $Source $Destination /MIR /NFL /NDL /NJH /NJS /NP `
    /XD ".git" ".github" ".idea" ".vscode" "__pycache__" `
    /XF ".gitignore" ".gitattributes" 1>> $LogFile 2>&1

  $rc = $LASTEXITCODE
  if ($rc -ge 8) {
    Write-Log "ERROR robocopy ($rc): $Source -> $Destination"
    return $false
  }

  return $true
}

function Install-ScriptRepo {
  param(
    [string]$Id,
    [string]$RepoPath
  )

  $luaFiles = @(Get-ChildItem -LiteralPath $RepoPath -Recurse -File -Filter "*.lua" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\\.git\\' })

  if ($luaFiles.Count -eq 0) {
    Write-Log "No Lua scripts found in $Id"
    return
  }

  $dest = Join-Path $ScriptsRoot (Safe-Name $Id)

  if (Mirror-Folder -Source $RepoPath -Destination $dest) {
    Write-Log "SCRIPTS synced: $Id ($($luaFiles.Count) Lua file(s)) -> $dest"
  }
}

function Test-AsepritePackage {
  param([string]$PackageJson)

  try {
    $pkg = Get-Content -LiteralPath $PackageJson -Raw | ConvertFrom-Json
    if ($null -eq $pkg) { return $false }

    # Aseprite extensions may contribute scripts/plugins, themes, palettes,
    # keys, languages, dithering matrices, etc.
    if ($null -ne $pkg.contributes) { return $true }

    # Some older packages are minimal but still identify Aseprite.
    $raw = Get-Content -LiteralPath $PackageJson -Raw
    if ($raw -match '(?i)aseprite') { return $true }

    return $false
  }
  catch {
    return $false
  }
}

function Install-ExtensionPackageFolder {
  param(
    [string]$RepoId,
    [string]$PackageRoot
  )

  $pkgFile = Join-Path $PackageRoot "package.json"
  if (-not (Test-Path $pkgFile)) { return }

  try {
    $pkg = Get-Content -LiteralPath $pkgFile -Raw | ConvertFrom-Json
    $pkgName =
      if ($pkg.name) { [string]$pkg.name }
      elseif ($pkg.displayName) { [string]$pkg.displayName }
      else { Split-Path $PackageRoot -Leaf }

    $destName = "auto-" + (Safe-Name "$RepoId-$pkgName")
    $dest = Join-Path $ExtensionsRoot $destName

    if (Mirror-Folder -Source $PackageRoot -Destination $dest) {
      Write-Log "EXTENSION synced: $RepoId / $pkgName -> $dest"
    }
  }
  catch {
    Write-Log "ERROR package install $pkgFile : $($_.Exception.Message)"
  }
}

function Install-ExtensionArchives {
  param(
    [string]$RepoId,
    [string]$RepoPath
  )

  $archives = @(Get-ChildItem -LiteralPath $RepoPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @(".aseprite-extension", ".zip") -and $_.FullName -notmatch '\\\.git\\' })

  foreach ($archive in $archives) {
    try {
      $name = Safe-Name ($RepoId + "-" + $archive.BaseName)
      $dest = Join-Path $ExtensionsRoot ("auto-" + $name)
      $tempZip = Join-Path $env:TEMP ("aseprite-addon-" + [guid]::NewGuid().ToString() + ".zip")

      Copy-Item -LiteralPath $archive.FullName -Destination $tempZip -Force
      if (Test-Path $dest) {
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
      }
      New-Item -ItemType Directory -Force -Path $dest | Out-Null

      Expand-Archive -LiteralPath $tempZip -DestinationPath $dest -Force
      Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue

      $pkg = Get-ChildItem -LiteralPath $dest -Recurse -File -Filter "package.json" -ErrorAction SilentlyContinue |
        Select-Object -First 1

      if ($pkg) {
        # If archive has one unnecessary top-level directory, flatten it.
        $pkgDir = $pkg.Directory.FullName
        if ($pkgDir -ne $dest) {
          $children = @(Get-ChildItem -LiteralPath $dest -Force)
          if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
            $nested = $children[0].FullName
            $tmp = $dest + ".flatten"
            Move-Item -LiteralPath $nested -Destination $tmp
            Remove-Item -LiteralPath $dest -Recurse -Force
            Move-Item -LiteralPath $tmp -Destination $dest
          }
        }

        Write-Log "EXTENSION archive installed: $($archive.Name) -> $dest"
      }
      else {
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "SKIP archive without Aseprite package.json: $($archive.FullName)"
      }
    }
    catch {
      Write-Log "WARNING archive install failed $($archive.FullName): $($_.Exception.Message)"
    }
  }
}

function Install-ExtensionsFromRepo {
  param(
    [string]$RepoId,
    [string]$RepoPath
  )

  $packageFiles = @(Get-ChildItem -LiteralPath $RepoPath -Recurse -File -Filter "package.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\\.git\\' })

  foreach ($pkg in $packageFiles) {
    if (Test-AsepritePackage -PackageJson $pkg.FullName) {
      Install-ExtensionPackageFolder -RepoId $RepoId -PackageRoot $pkg.Directory.FullName
    }
  }

  Install-ExtensionArchives -RepoId $RepoId -RepoPath $RepoPath
}

Write-Log "============================================================"
Write-Log "ADD-ON SYNC START"

$ConfigRoots = @(
  (Join-Path $env:ABH_DATA_ROOT "config\sources\addons")
  (Join-Path $env:ABH_DATA_ROOT "config\sources\mixed")
)
$ManifestRoot = Join-Path $env:ABH_DATA_ROOT "manifest"
$ManagedManifest = Join-Path $ManifestRoot "managed-addon-extensions.txt"
New-Item -ItemType Directory -Force -Path $ManifestRoot | Out-Null
Remove-Item -LiteralPath $ManagedManifest -Force -ErrorAction SilentlyContinue

function Read-IniSource([string]$Path) {
  $data = @{}
  foreach ($line in Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue) {
    $t = $line.Trim()
    if (-not $t -or $t.StartsWith(';') -or $t.StartsWith('#') -or $t.StartsWith('[')) { continue }
    $i = $t.IndexOf('=')
    if ($i -gt 0) { $data[$t.Substring(0,$i).Trim().ToLowerInvariant()] = $t.Substring($i+1).Trim() }
  }
  return $data
}

foreach ($cfgRoot in $ConfigRoots) {
  $configFiles = @(Get-ChildItem -LiteralPath $cfgRoot -Filter '*.ini' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '_*' } | Sort-Object Name)

  foreach ($cfg in $configFiles) {
    $c = Read-IniSource $cfg.FullName
    if (($c['enabled'] -as [string]) -notmatch '^(?i:true|1|yes)$') { continue }
    $url = $c['repository']
    if ([string]::IsNullOrWhiteSpace($url)) { Write-Log "SKIP config without repository: $($cfg.FullName)"; continue }

    $kind = Split-Path $cfgRoot -Leaf
    $id = $cfg.BaseName
    if ($kind -eq 'mixed') { $id = 'mixed-' + $id }
    $mode = ($c['install_mode'] -as [string])
    if ($mode -notin @('scripts','extensions','both')) { $mode = 'both' }
    $auto = (($c['auto_update'] -as [string]) -match '^(?i:true|1|yes)$')
    $repoPath = Join-Path $RepoRoot $id

    if (-not (Test-Path (Join-Path $repoPath '.git'))) {
      $repo = Sync-Repo -Id $id -Url $url
    }
    elseif ($auto) {
      $repo = Sync-Repo -Id $id -Url $url
    }
    else {
      Write-Log "AUTO-UPDATE disabled; using cached add-on repo: $id"
      $repo = $repoPath
    }
    if (-not $repo) { continue }

    if ($mode -in @('scripts','both')) { Install-ScriptRepo -Id $id -RepoPath $repo }
    if ($mode -in @('extensions','both')) {
      Install-ExtensionsFromRepo -RepoId $id -RepoPath $repo
      Get-ChildItem -LiteralPath $ExtensionsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like ('auto-' + $id + '-*') } |
        ForEach-Object { Add-Content -LiteralPath $ManagedManifest -Value $_.FullName -Encoding UTF8 }
    }
  }
}

Write-Log "ADD-ON SYNC END"
exit 0
###END:aseprite_addons.ps1###

###BEGIN:aseprite_local_tools.ps1###
$ErrorActionPreference = "SilentlyContinue"

$ScriptsRoot = Join-Path $env:APPDATA "Aseprite\scripts\auto-managed-local"
New-Item -ItemType Directory -Force -Path $ScriptsRoot | Out-Null

$src = Join-Path $PSScriptRoot "game_pixel_starter.lua"
$dst = Join-Path $ScriptsRoot "Game Pixel Starter.lua"

if (Test-Path $src) {
  Copy-Item -LiteralPath $src -Destination $dst -Force
}


$exportSrc = Join-Path $PSScriptRoot "game_export_pack.lua"
$exportDst = Join-Path $ScriptsRoot "Game Export Pack.lua"
if (Test-Path $exportSrc) {
  Copy-Item -LiteralPath $exportSrc -Destination $exportDst -Force
}


$templateSrc = Join-Path $PSScriptRoot "game_asset_template_generator.lua"
$templateDst = Join-Path $ScriptsRoot "Game Asset Template Generator.lua"
if (Test-Path $templateSrc) {
  Copy-Item -LiteralPath $templateSrc -Destination $templateDst -Force
}


$autotileSrc = Join-Path $PSScriptRoot "autotile_template_generator.lua"
$autotileDst = Join-Path $ScriptsRoot "Autotile Template Generator.lua"
if (Test-Path $autotileSrc) {
  Copy-Item -LiteralPath $autotileSrc -Destination $autotileDst -Force
}

$collisionSrc = Join-Path $PSScriptRoot "game_collision_pivot_metadata.lua"
$collisionDst = Join-Path $ScriptsRoot "Game Collision Pivot Metadata.lua"
if (Test-Path $collisionSrc) {
  Copy-Item -LiteralPath $collisionSrc -Destination $collisionDst -Force
}

$pivotSrc = Join-Path $PSScriptRoot "pivot_origin_presets.lua"
$pivotDst = Join-Path $ScriptsRoot "Pivot Origin Presets.lua"
if (Test-Path $pivotSrc) {
  Copy-Item -LiteralPath $pivotSrc -Destination $pivotDst -Force
}
###END:aseprite_local_tools.ps1###

###BEGIN:game_pixel_starter.lua###
-- Game Pixel Starter
-- Local helper included with the automated Aseprite pack.
-- Creates common game-art canvas sizes quickly.

local options = {
  ["Icon 16x16"] = {16, 16},
  ["Icon 24x24"] = {24, 24},
  ["Icon 32x32"] = {32, 32},
  ["Sprite 32x32"] = {32, 32},
  ["Sprite 48x48"] = {48, 48},
  ["Sprite 64x64"] = {64, 64},
  ["Sprite 96x96"] = {96, 96},
  ["Sprite 128x128"] = {128, 128},
  ["Tile 16x16"] = {16, 16},
  ["Tile 32x32"] = {32, 32},
  ["Tile 48x48"] = {48, 48},
  ["Tile 64x64"] = {64, 64},
}

local dlg = Dialog("Game Pixel Starter")
dlg:combobox{
  id="preset",
  label="Preset:",
  options={
    "Icon 16x16",
    "Icon 24x24",
    "Icon 32x32",
    "Sprite 32x32",
    "Sprite 48x48",
    "Sprite 64x64",
    "Sprite 96x96",
    "Sprite 128x128",
    "Tile 16x16",
    "Tile 32x32",
    "Tile 48x48",
    "Tile 64x64"
  },
  option="Sprite 32x32"
}
dlg:number{id="customW", label="Custom W:", text="32", decimals=0}
dlg:number{id="customH", label="Custom H:", text="32", decimals=0}
dlg:check{id="custom", label="Use custom size", selected=false}

dlg:button{
  id="create",
  text="Create",
  onclick=function()
    local w, h
    if dlg.data.custom then
      w = math.max(1, math.floor(dlg.data.customW or 32))
      h = math.max(1, math.floor(dlg.data.customH or 32))
    else
      local p = options[dlg.data.preset]
      if p then
        w, h = p[1], p[2]
      else
        w, h = 32, 32
      end
    end

    local spr = Sprite(w, h, ColorMode.RGB)
    spr.filename = "game-sprite-" .. tostring(w) .. "x" .. tostring(h) .. ".aseprite"
    if spr.layers and #spr.layers > 0 then
      spr.layers[1].name = "Art"
    end
    app.activeSprite = spr
    app.refresh()
    dlg:close()
  end
}
dlg:button{id="cancel", text="Cancel"}
dlg:show{wait=false}
###END:game_pixel_starter.lua###

###BEGIN:game_export_pack.lua###
-- Game Export Pack
-- Exports the active sprite into a clean game-ready folder structure.
-- Uses Aseprite's own ExportSpriteSheet command/API.

local spr = app.activeSprite
if not spr then
  app.alert("No active sprite.")
  return
end

if spr.filename == nil or spr.filename == "" then
  app.alert("Please save the .aseprite file first, then run Game Export Pack again.")
  return
end

local function dirname(path)
  return app.fs.filePath(path)
end

local function title(path)
  return app.fs.fileTitle(path)
end

local function join(...)
  local parts = {...}
  local p = parts[1] or ""
  for i=2,#parts do
    p = app.fs.joinPath(p, parts[i])
  end
  return p
end

local function safeName(s)
  s = tostring(s or "")
  s = s:gsub("[<>:\"/\\|%?%*]", "_")
  s = s:gsub("%s+", "_")
  if s == "" then s = "untitled" end
  return s
end

local function ensureDir(path)
  app.fs.makeDirectory(path)
end

local baseDir = dirname(spr.filename)
local spriteName = safeName(title(spr.filename))

local dlg = Dialog("Game Export Pack")
dlg:combobox{
  id="preset",
  label="Preset:",
  options={"Generic", "Godot", "Unity", "GameMaker"},
  option="Generic"
}
dlg:combobox{
  id="layout",
  label="Sheet layout:",
  options={"Packed", "Rows", "Horizontal"},
  option="Packed"
}
dlg:check{
  id="atlas",
  label="Master atlas + JSON",
  selected=true
}
dlg:check{
  id="perTag",
  label="Separate sheet + JSON per animation tag",
  selected=true
}
dlg:check{
  id="listSlices",
  label="Include slices/pivots in JSON",
  selected=true
}
dlg:check{
  id="listLayers",
  label="Include layer metadata in JSON",
  selected=true
}
dlg:check{
  id="trim",
  label="Trim transparent borders",
  selected=false
}
dlg:check{
  id="extrude",
  label="Extrude 1px edges",
  selected=false
}
dlg:entry{
  id="root",
  label="Output folder:",
  text=join(baseDir, "export", spriteName)
}

dlg:button{
  id="export",
  text="Export",
  onclick=function()
    local data = dlg.data
    local root = data.root
    if root == nil or root == "" then
      app.alert("Output folder is empty.")
      return
    end

    ensureDir(root)
    local atlasDir = join(root, "atlas")
    local animDir = join(root, "animations")
    local metaDir = join(root, "meta")
    ensureDir(atlasDir)
    ensureDir(animDir)
    ensureDir(metaDir)

    local sheetType = SpriteSheetType.PACKED
    if data.layout == "Rows" then
      sheetType = SpriteSheetType.ROWS
    elseif data.layout == "Horizontal" then
      sheetType = SpriteSheetType.HORIZONTAL
    end

    -- Master atlas
    if data.atlas then
      local png = join(atlasDir, spriteName .. ".png")
      local jsn = join(atlasDir, spriteName .. ".json")

      app.command.ExportSpriteSheet{
        ui=false,
        askOverwrite=false,
        type=sheetType,
        textureFilename=png,
        dataFilename=jsn,
        dataFormat=SpriteSheetDataFormat.JSON_HASH,
        trim=data.trim,
        extrude=data.extrude,
        ignoreEmpty=true,
        mergeDuplicates=false,
        listLayers=data.listLayers,
        listTags=true,
        listSlices=data.listSlices,
        splitLayers=false,
        splitTags=false,
        openGenerated=false
      }
    end

    -- One sheet per animation tag.
    if data.perTag and #spr.tags > 0 then
      for _, tag in ipairs(spr.tags) do
        local tagName = safeName(tag.name)
        local tagDir = join(animDir, tagName)
        ensureDir(tagDir)

        local png = join(tagDir, tagName .. ".png")
        local jsn = join(tagDir, tagName .. ".json")

        app.command.ExportSpriteSheet{
          ui=false,
          askOverwrite=false,
          type=sheetType,
          textureFilename=png,
          dataFilename=jsn,
          dataFormat=SpriteSheetDataFormat.JSON_HASH,
          tag=tag.name,
          trim=data.trim,
          extrude=data.extrude,
          ignoreEmpty=true,
          mergeDuplicates=false,
          listLayers=data.listLayers,
          listTags=true,
          listSlices=data.listSlices,
          openGenerated=false
        }
      end
    end

    -- Engine/import notes + manifest.
    local preset = tostring(data.preset or "Generic")
    local manifest = {
      exporter = "Aseprite Game Export Pack",
      preset = preset,
      source = spr.filename,
      sprite = spriteName,
      atlas = data.atlas and ("atlas/" .. spriteName .. ".png") or nil,
      atlasData = data.atlas and ("atlas/" .. spriteName .. ".json") or nil,
      animationsFolder = data.perTag and "animations/" or nil,
      notes = {
        "Aseprite JSON contains frame rectangles and animation tag timing.",
        "Slices/pivots are included when enabled.",
        "Animation tag direction is preserved in frameTags metadata."
      }
    }

    if preset == "Godot" then
      manifest.engineHint = "Use the PNG as texture and JSON frame rectangles/tags for AnimatedSprite2D/SpriteFrames tooling."
    elseif preset == "Unity" then
      manifest.engineHint = "Import PNG as Multiple sprite mode; JSON can drive editor/import tooling for frame rects and animation tags."
    elseif preset == "GameMaker" then
      manifest.engineHint = "Use per-tag sheets or atlas PNG; JSON provides frame rectangles and tag ranges for custom import pipelines."
    else
      manifest.engineHint = "Generic atlas + Aseprite JSON suitable for custom engines/importers."
    end

    -- Tiny JSON encoder adequate for this manifest.
    local function esc(s)
      s = tostring(s)
      s = s:gsub("\\", "\\\\")
      s = s:gsub("\"", "\\\"")
      s = s:gsub("\n", "\\n")
      return "\"" .. s .. "\""
    end

    local function encode(v, depth)
      depth = depth or 0
      local t = type(v)
      if t == "nil" then return "null" end
      if t == "boolean" or t == "number" then return tostring(v) end
      if t == "string" then return esc(v) end
      if t == "table" then
        local isArray = (#v > 0)
        local pad = string.rep("  ", depth)
        local npad = string.rep("  ", depth+1)
        local out = {}
        if isArray then
          for i=1,#v do
            table.insert(out, npad .. encode(v[i], depth+1))
          end
          return "[\n" .. table.concat(out, ",\n") .. "\n" .. pad .. "]"
        else
          for k,val in pairs(v) do
            if val ~= nil then
              table.insert(out, npad .. esc(k) .. ": " .. encode(val, depth+1))
            end
          end
          table.sort(out)
          return "{\n" .. table.concat(out, ",\n") .. "\n" .. pad .. "}"
        end
      end
      return esc(tostring(v))
    end

    local mf = io.open(join(metaDir, "manifest.json"), "w")
    if mf then
      mf:write(encode(manifest, 0))
      mf:close()
    end

    local guide = io.open(join(metaDir, "README.txt"), "w")
    if guide then
      guide:write(
        "Aseprite Game Export Pack\n\n" ..
        "Preset: " .. preset .. "\n" ..
        "Source: " .. spr.filename .. "\n\n" ..
        "atlas/       Master sprite sheet + JSON\n" ..
        "animations/  One folder per animation tag\n" ..
        "meta/        Manifest and notes\n\n" ..
        "Recommended tag names for game characters:\n" ..
        "idle, walk, run, jump, fall, attack, hurt, death\n"
      )
      guide:close()
    end

    dlg:close()
    app.alert("Export complete:\n" .. root)
  end
}

dlg:button{id="cancel", text="Cancel"}
dlg:show{wait=false}
###END:game_export_pack.lua###

###BEGIN:game_asset_template_generator.lua###
-- Game Asset Template Generator
-- Creates game-ready sprite documents with grid, frames and animation tags.

local presets = {
  ["Top-Down 4-dir 32x32"] = {
    width=32, height=32, grid=32,
    tags={
      {"idle_down", 4, 0.16}, {"idle_left", 4, 0.16},
      {"idle_right",4,0.16}, {"idle_up",4,0.16},
      {"walk_down", 6, 0.10}, {"walk_left", 6, 0.10},
      {"walk_right",6,0.10}, {"walk_up",6,0.10},
      {"attack_down",6,0.08}, {"attack_left",6,0.08},
      {"attack_right",6,0.08}, {"attack_up",6,0.08},
      {"hurt",3,0.10}, {"death",8,0.12},
    }
  },

  ["Top-Down 8-dir 32x32"] = {
    width=32, height=32, grid=32,
    tags={
      {"idle_s",4,0.16},{"idle_sw",4,0.16},{"idle_w",4,0.16},{"idle_nw",4,0.16},
      {"idle_n",4,0.16},{"idle_ne",4,0.16},{"idle_e",4,0.16},{"idle_se",4,0.16},
      {"walk_s",6,0.10},{"walk_sw",6,0.10},{"walk_w",6,0.10},{"walk_nw",6,0.10},
      {"walk_n",6,0.10},{"walk_ne",6,0.10},{"walk_e",6,0.10},{"walk_se",6,0.10},
      {"attack_s",6,0.08},{"attack_sw",6,0.08},{"attack_w",6,0.08},{"attack_nw",6,0.08},
      {"attack_n",6,0.08},{"attack_ne",6,0.08},{"attack_e",6,0.08},{"attack_se",6,0.08},
      {"hurt",3,0.10},{"death",8,0.12},
    }
  },

  ["Platformer Character 32x48"] = {
    width=32, height=48, grid=16,
    tags={
      {"idle",6,0.14},
      {"walk",8,0.10},
      {"run",8,0.08},
      {"jump",4,0.10},
      {"fall",4,0.10},
      {"land",3,0.08},
      {"attack",6,0.08},
      {"hurt",3,0.10},
      {"death",8,0.12},
    }
  },

  ["Platformer Character 64x64"] = {
    width=64, height=64, grid=32,
    tags={
      {"idle",6,0.14},
      {"walk",8,0.10},
      {"run",8,0.08},
      {"jump",4,0.10},
      {"fall",4,0.10},
      {"land",3,0.08},
      {"attack",8,0.08},
      {"hurt",3,0.10},
      {"death",10,0.12},
    }
  },

  ["RPG Battle Character 64x64"] = {
    width=64, height=64, grid=32,
    tags={
      {"idle",6,0.15},
      {"ready",4,0.12},
      {"attack",8,0.08},
      {"cast",8,0.10},
      {"block",4,0.10},
      {"hurt",4,0.10},
      {"death",10,0.12},
    }
  },

  ["Enemy / Creature 48x48"] = {
    width=48, height=48, grid=16,
    tags={
      {"idle",6,0.15},
      {"move",6,0.10},
      {"attack",6,0.08},
      {"hurt",3,0.10},
      {"death",8,0.12},
    }
  },

  ["Effect / VFX 64x64"] = {
    width=64, height=64, grid=16,
    tags={
      {"spawn",6,0.06},
      {"loop",8,0.08},
      {"end",6,0.06},
    }
  },

  ["UI Icon 32x32"] = {
    width=32, height=32, grid=16,
    tags={}
  },

  ["Tileset 16x16"] = {
    width=256, height=256, grid=16,
    tags={}
  },

  ["Tileset 32x32"] = {
    width=512, height=512, grid=32,
    tags={}
  }
}

local function addNamedLayer(spr, name)
  local layer = spr:newLayer()
  layer.name = name
  return layer
end

local function ensureFrames(spr, count)
  while #spr.frames < count do
    spr:newEmptyFrame(#spr.frames + 1)
  end
end

local function buildTemplate(name, cfg, customW, customH, customGrid)
  local w = customW or cfg.width
  local h = customH or cfg.height
  local g = customGrid or cfg.grid

  local spr = Sprite(w, h, ColorMode.RGB)
  spr.filename = "game-template-" .. tostring(w) .. "x" .. tostring(h) .. ".aseprite"
  spr.gridBounds = Rectangle(0, 0, g, g)

  -- Rename default layer and add useful game-art layers.
  if #spr.layers > 0 then
    spr.layers[1].name = "Base"
  end

  addNamedLayer(spr, "Shading")
  addNamedLayer(spr, "Highlights")
  addNamedLayer(spr, "FX")

  local totalFrames = 1
  for _, t in ipairs(cfg.tags) do
    totalFrames = totalFrames + t[2]
  end
  if #cfg.tags > 0 then
    totalFrames = totalFrames - 1
  end

  ensureFrames(spr, totalFrames)

  local cursor = 1
  for _, t in ipairs(cfg.tags) do
    local tagName = t[1]
    local frameCount = t[2]
    local duration = t[3]

    local first = cursor
    local last = cursor + frameCount - 1

    for i=first,last do
      spr.frames[i].duration = duration
    end

    local tag = spr:newTag(first, last)
    tag.name = tagName

    cursor = last + 1
  end

  app.activeSprite = spr
  app.frame = 1
  app.refresh()
end

local presetNames = {}
for name,_ in pairs(presets) do
  table.insert(presetNames, name)
end
table.sort(presetNames)

local dlg = Dialog("Game Asset Template Generator")

dlg:combobox{
  id="preset",
  label="Template:",
  options=presetNames,
  option="Top-Down 4-dir 32x32"
}

dlg:separator{text="Optional override"}

dlg:check{
  id="custom",
  label="Use custom size/grid",
  selected=false
}

dlg:number{id="w", label="Width:", text="32", decimals=0}
dlg:number{id="h", label="Height:", text="32", decimals=0}
dlg:number{id="g", label="Grid:", text="16", decimals=0}

dlg:separator{text="Create"}

dlg:button{
  id="create",
  text="Create Template",
  onclick=function()
    local cfg = presets[dlg.data.preset]
    if not cfg then
      app.alert("Unknown template.")
      return
    end

    local cw, ch, cg = nil, nil, nil
    if dlg.data.custom then
      cw = math.max(1, math.floor(dlg.data.w or cfg.width))
      ch = math.max(1, math.floor(dlg.data.h or cfg.height))
      cg = math.max(1, math.floor(dlg.data.g or cfg.grid))
    end

    buildTemplate(dlg.data.preset, cfg, cw, ch, cg)
    dlg:close()
  end
}

dlg:button{id="cancel", text="Cancel"}
dlg:show{wait=false}
###END:game_asset_template_generator.lua###

###BEGIN:autotile_template_generator.lua###
-- Autotile Template Generator
-- Creates common grid-based autotile canvases for game artwork.
-- It intentionally does not invent engine-specific Wang metadata; it creates
-- clean Aseprite-native art templates that can be exported to any engine.

local presets = {
  ["16-mask autotile - 16x16"] = { tile=16, cols=4, rows=4, count=16 },
  ["16-mask autotile - 32x32"] = { tile=32, cols=4, rows=4, count=16 },
  ["47-tile blob set - 16x16"] = { tile=16, cols=8, rows=6, count=47 },
  ["47-tile blob set - 32x32"] = { tile=32, cols=8, rows=6, count=47 },
  ["Terrain strip - 16x16"] = { tile=16, cols=8, rows=4, count=32 },
  ["Terrain strip - 32x32"] = { tile=32, cols=8, rows=4, count=32 },
}

local names = {}
for k,_ in pairs(presets) do table.insert(names, k) end
table.sort(names)

local dlg = Dialog("Autotile / Wang Template Generator")
dlg:combobox{
  id="preset",
  label="Template:",
  options=names,
  option="16-mask autotile - 16x16"
}
dlg:check{
  id="referenceSlices",
  label="Create numbered tile slices",
  selected=true
}
dlg:button{
  id="create",
  text="Create",
  onclick=function()
    local cfg = presets[dlg.data.preset]
    if not cfg then
      app.alert("Unknown template.")
      return
    end

    local w = cfg.cols * cfg.tile
    local h = cfg.rows * cfg.tile
    local spr = Sprite(w, h, ColorMode.RGB)
    spr.filename = "autotile-" .. tostring(cfg.tile) .. "px.aseprite"
    spr.gridBounds = Rectangle(0, 0, cfg.tile, cfg.tile)

    if #spr.layers > 0 then
      spr.layers[1].name = "Tiles"
    end

    local ref = spr:newLayer()
    ref.name = "Reference"
    ref.isVisible = false

    if dlg.data.referenceSlices then
      for i=0,cfg.count-1 do
        local col = i % cfg.cols
        local row = math.floor(i / cfg.cols)
        local sl = spr:newSlice(Rectangle(
          col * cfg.tile,
          row * cfg.tile,
          cfg.tile,
          cfg.tile
        ))
        sl.name = string.format("tile_%02d", i)
        sl.data = "autotile-index=" .. tostring(i)
      end
    end

    app.activeSprite = spr
    app.refresh()
    dlg:close()

    app.alert(
      "Template created.\n\n" ..
      "Grid: " .. cfg.tile .. "x" .. cfg.tile .. "\n" ..
      "Slots: " .. cfg.count .. "\n\n" ..
      "This is an engine-neutral art template.\n" ..
      "Map the tile indices to your engine's autotile/Wang rules."
    )
  end
}
dlg:button{id="cancel", text="Cancel"}
dlg:show{wait=false}
###END:autotile_template_generator.lua###

###BEGIN:game_collision_pivot_metadata.lua###
-- Game Collision / Pivot Metadata
-- Creates or updates Aseprite slices for origin, hurtbox, hitbox and interaction.
-- These slices can be exported in sprite-sheet JSON by Game Export Pack.

local spr = app.activeSprite
if not spr then
  app.alert("No active sprite.")
  return
end

local function findSlice(name)
  for _, s in ipairs(spr.slices) do
    if s.name == name then return s end
  end
  return nil
end

local function upsertSlice(name, bounds, data)
  local s = findSlice(name)
  if not s then
    s = spr:newSlice(bounds)
    s.name = name
  else
    s.bounds = bounds
  end
  s.data = data or ""
  return s
end

local function pivotPoint(mode, w, h)
  if mode == "Bottom Center" then
    return Point(math.floor(w/2), h-1)
  elseif mode == "Center" then
    return Point(math.floor(w/2), math.floor(h/2))
  elseif mode == "Top Center" then
    return Point(math.floor(w/2), 0)
  elseif mode == "Bottom Left" then
    return Point(0, h-1)
  elseif mode == "Bottom Right" then
    return Point(w-1, h-1)
  end
  return Point(math.floor(w/2), h-1)
end

local dlg = Dialog("Game Collision / Pivot Metadata")

dlg:combobox{
  id="kind",
  label="Asset:",
  options={"Character", "Enemy", "Projectile", "Effect", "UI"},
  option="Character"
}

dlg:combobox{
  id="pivot",
  label="Origin/Pivot:",
  options={"Bottom Center", "Center", "Top Center", "Bottom Left", "Bottom Right"},
  option="Bottom Center"
}

dlg:check{id="hurtbox", label="Create hurtbox", selected=true}
dlg:check{id="hitbox", label="Create hitbox", selected=true}
dlg:check{id="interaction", label="Create interaction box", selected=false}

dlg:button{
  id="apply",
  text="Create / Update",
  onclick=function()
    local w = spr.width
    local h = spr.height

    -- Origin slice spans the sprite; its pivot is the actual origin marker.
    local origin = upsertSlice(
      "origin",
      Rectangle(0, 0, w, h),
      "type=origin;asset=" .. tostring(dlg.data.kind)
    )
    origin.pivot = pivotPoint(dlg.data.pivot, w, h)

    if dlg.data.hurtbox then
      local x = math.floor(w * 0.20)
      local y = math.floor(h * 0.15)
      local bw = math.max(1, math.floor(w * 0.60))
      local bh = math.max(1, math.floor(h * 0.75))
      upsertSlice(
        "hurtbox",
        Rectangle(x, y, bw, bh),
        "type=hurtbox;edit-me=true"
      )
    end

    if dlg.data.hitbox then
      local x = math.floor(w * 0.55)
      local y = math.floor(h * 0.30)
      local bw = math.max(1, math.floor(w * 0.40))
      local bh = math.max(1, math.floor(h * 0.35))
      upsertSlice(
        "hitbox",
        Rectangle(x, y, bw, bh),
        "type=hitbox;edit-me=true"
      )
    end

    if dlg.data.interaction then
      local x = math.floor(w * 0.15)
      local y = math.floor(h * 0.55)
      local bw = math.max(1, math.floor(w * 0.70))
      local bh = math.max(1, math.floor(h * 0.40))
      upsertSlice(
        "interaction",
        Rectangle(x, y, bw, bh),
        "type=interaction;edit-me=true"
      )
    end

    app.refresh()
    dlg:close()

    app.alert(
      "Metadata created.\n\n" ..
      "IMPORTANT: hurtbox/hitbox rectangles are sensible STARTING values.\n" ..
      "Adjust them with Aseprite's Slice tool for the actual sprite.\n\n" ..
      "Game Export Pack can include these slices/pivots in JSON."
    )
  end
}

dlg:button{id="cancel", text="Cancel"}
dlg:show{wait=false}
###END:game_collision_pivot_metadata.lua###

###BEGIN:pivot_origin_presets.lua###
-- Pivot / Origin Presets
-- Quick helper for setting the pivot of the "origin" slice.

local spr = app.activeSprite
if not spr then
  app.alert("No active sprite.")
  return
end

local function getOrigin()
  for _, s in ipairs(spr.slices) do
    if s.name == "origin" then return s end
  end
  local s = spr:newSlice(Rectangle(0, 0, spr.width, spr.height))
  s.name = "origin"
  s.data = "type=origin"
  return s
end

local dlg = Dialog("Pivot / Origin Presets")
dlg:combobox{
  id="preset",
  label="Preset:",
  options={
    "Bottom Center",
    "Center",
    "Top Center",
    "Bottom Left",
    "Bottom Right",
    "Left Center",
    "Right Center"
  },
  option="Bottom Center"
}

dlg:button{
  id="apply",
  text="Apply",
  onclick=function()
    local s = getOrigin()
    s.bounds = Rectangle(0, 0, spr.width, spr.height)

    local w, h = spr.width, spr.height
    local x, y = math.floor(w/2), h-1

    if dlg.data.preset == "Center" then
      x, y = math.floor(w/2), math.floor(h/2)
    elseif dlg.data.preset == "Top Center" then
      x, y = math.floor(w/2), 0
    elseif dlg.data.preset == "Bottom Left" then
      x, y = 0, h-1
    elseif dlg.data.preset == "Bottom Right" then
      x, y = w-1, h-1
    elseif dlg.data.preset == "Left Center" then
      x, y = 0, math.floor(h/2)
    elseif dlg.data.preset == "Right Center" then
      x, y = w-1, math.floor(h/2)
    end

    s.pivot = Point(x, y)
    s.data = "type=origin;preset=" .. tostring(dlg.data.preset)

    app.refresh()
    dlg:close()
    app.alert("Origin pivot set to: " .. tostring(dlg.data.preset))
  end
}
dlg:button{id="cancel", text="Cancel"}
dlg:show{wait=false}
###END:pivot_origin_presets.lua###

###BEGIN:self_update_apply.ps1###
param(
  [Parameter(Mandatory=$true)][string]$Project,
  [Parameter(Mandatory=$true)][string]$New,
  [Parameter(Mandatory=$true)][string]$Backup,
  [ValidateSet('de','en')][string]$Lang='en'
)

$ErrorActionPreference = 'Stop'
$files = @('aseprite-build-helper.bat','README.md','LICENSE','THIRD_PARTY_NOTICES.md')
Start-Sleep -Milliseconds 1200

try {
  foreach ($f in $files) {
    $src = Join-Path $New $f
    if (-not (Test-Path -LiteralPath $src)) { throw "Missing update file: $f" }
    Copy-Item -LiteralPath $src -Destination (Join-Path $Project $f) -Force
  }

  $builder = Join-Path $Project 'aseprite-build-helper.bat'
  $args = '/c ""' + $builder + '" --refresh-runtime --lang=' + $Lang + '"'
  $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList $args -Wait -PassThru
  if ($proc.ExitCode -ne 0) { throw "Runtime refresh failed with exit code $($proc.ExitCode)" }

  [System.Media.SystemSounds]::Asterisk.Play()
  $updater = Join-Path $Project 'ABH\updater\aseprite-build-updater.bat'
  if (Test-Path -LiteralPath $updater) { Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ""' + $updater + '""') }
}
catch {
  foreach ($f in $files) {
    $old = Join-Path $Backup $f
    if (Test-Path -LiteralPath $old) {
      Copy-Item -LiteralPath $old -Destination (Join-Path $Project $f) -Force
    }
  }

  $builder = Join-Path $Project 'aseprite-build-helper.bat'
  if (Test-Path -LiteralPath $builder) {
    $args = '/c ""' + $builder + '" --refresh-runtime --lang=' + $Lang + '"'
    Start-Process -FilePath 'cmd.exe' -ArgumentList $args -Wait | Out-Null
  }

  Add-Type -AssemblyName System.Windows.Forms
  $message = if ($Lang -eq 'de') {
    'Das ABH-Self-Update ist fehlgeschlagen. Die vorherigen Paketdateien wurden wiederhergestellt.'
  } else {
    'ABH self-update failed. The previous package files were restored.'
  }
  [System.Windows.Forms.MessageBox]::Show(
    $message,
    'Aseprite Build Updater',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Error
  ) | Out-Null
}
finally {
  try { Remove-Item -LiteralPath (Split-Path $New -Parent) -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}
###END:self_update_apply.ps1###

###BEGIN:helper_icon.ico.b64###
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
###END:helper_icon.ico.b64###

###BEGIN:force_update.ico.b64###
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
###END:force_update.ico.b64###

###BEGIN:uninstall.ico.b64###
QGVjaG8gb2ZmCnNldGxvY2FsIEVuYWJsZUV4dGVuc2lvbnMgRW5hYmxlRGVsYXllZEV4cGFuc2lvbgpmb3IgJSVJIGluICgiJX5kcDAuLiIpIGRvIHNldCAiQUJIX0RJUj0lJX5mSSIKZm9yICUlSSBpbiAoIiVBQkhfRElSJVwuLiIpIGRvIHNldCAiUFJPSkVDVF9ESVI9JSV+ZkkiCnNldCAiUk9PVD1DOlxhc2Vwcml0ZSIKc2V0ICJCQUNLVVBTPSVBQkhfRElSJVxiYWNrdXBzIgpzZXQgIk1BTklGRVNUPSVBQkhfRElSJVxtYW5pZmVzdCIKc2V0ICJBUFBfQVNFPSVBUFBEQVRBJVxBc2Vwcml0ZSIKc2V0ICJBRERPTl9TQ1JJUFRTPSVBUFBfQVNFJVxzY3JpcHRzXGF1dG8tbWFuYWdlZCIKc2V0ICJMT0NBTF9TQ1JJUFRTPSVBUFBfQVNFJVxzY3JpcHRzXGF1dG8tbWFuYWdlZC1sb2NhbCIKc2V0ICJBRERPTl9NQU5BR0VSPSVBQkhfRElSJVxtYW5hZ2VkXGFkZG9ucyIKc2V0ICJUSEVNRV9NQU5BR0VSPSVBQkhfRElSJVxtYW5hZ2VkXHRoZW1lcyIKc2V0ICJMQU5HVUFHRT1lbiIKZm9yIC9mICJ1c2ViYWNrcSBkZWxpbXM9IiAlJUwgaW4gKGBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLUNvbW1hbmQgIiRjPShHZXQtVUlDdWx0dXJlKS5OYW1lOyBpZigkYyAtbGlrZSAnZGUtKicpeydkZSd9ZWxzZXsnZW4nfSJgKSBkbyBzZXQgIkxBTkdVQUdFPSUlTCIKZm9yICUlQSBpbiAoJSopIGRvICgKICBpZiAvSSAiJSV+QSI9PSItLWxhbmc9ZGUiIHNldCAiTEFOR1VBR0U9ZGUiCiAgaWYgL0kgIiUlfkEiPT0iLS1sYW5nPWVuIiBzZXQgIkxBTkdVQUdFPWVuIgopCmZvciAvZiAidXNlYmFja3EgZGVsaW1zPSIgJSVEIGluIChgcG93ZXJzaGVsbC5leGUgLU5vTG9nbyAtTm9Qcm9maWxlIC1Db21tYW5kICJbRW52aXJvbm1lbnRdOjpHZXRGb2xkZXJQYXRoKCdEZXNrdG9wJykiYCkgZG8gc2V0ICJERVNLVE9QPSUlRCIKCjptZW51CmNscwppZiAvSSAiJUxBTkdVQUdFJSI9PSJkZSIgZ290byBtZW51X2RlCjptZW51X2VuCmVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8gICBBc2Vwcml0ZSBCdWlsZCBIZWxwZXIgLSBVbmluc3RhbGxlcgplY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQplY2hvLgplY2hvIFsxXSBSZW1vdmUgaGVscGVyIHJ1bnRpbWUgZmlsZXMgb25seQplY2hvIFsyXSBSZW1vdmUgaGVscGVyIHJ1bnRpbWUgZmlsZXMgKyBnZW5lcmF0ZWQgc2hvcnRjdXRzCmVjaG8gWzNdIFJlbW92ZSBoZWxwZXIgcnVudGltZSwgc2hvcnRjdXRzIGFuZCBBQkggYmFja3VwcwplY2hvIFs0XSBSZW1vdmUgbG9jYWwgQXNlcHJpdGUgc291cmNlL2J1aWxkIGZvbGRlcnMKZWNobyBbNV0gUkVNT1ZFIEFMTCBBQkgtbWFuYWdlZCBjb250ZW50CmVjaG8gWzBdIENhbmNlbAplY2hvLgpzZXQgL3AgIlNFTD1TZWxlY3Rpb246ICIKZ290byBkaXNwYXRjaAo6bWVudV9kZQplY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQplY2hvICAgQXNlcHJpdGUgQnVpbGQgSGVscGVyIC0gRGVpbnN0YWxsYXRpb24KZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KZWNoby4KZWNobyBbMV0gTnVyIEhlbHBlci1MYXVmemVpdGRhdGVpZW4gZW50ZmVybmVuCmVjaG8gWzJdIEhlbHBlci1MYXVmemVpdGRhdGVpZW4gKyBlcnpldWd0ZSBWZXJrbnVlcGZ1bmdlbiBlbnRmZXJuZW4KZWNobyBbM10gSGVscGVyLUxhdWZ6ZWl0ZGF0ZWllbiwgVmVya251ZXBmdW5nZW4gdW5kIEFCSC1CYWNrdXBzIGVudGZlcm5lbgplY2hvIFs0XSBMb2thbGUgQXNlcHJpdGUtUXVlbGwtL0J1aWxkLU9yZG5lciBlbnRmZXJuZW4KZWNobyBbNV0gQUxMRSB2b24gQUJIIHZlcndhbHRldGVuIEluaGFsdGUgZW50ZmVybmVuCmVjaG8gWzBdIEFiYnJlY2hlbgplY2hvLgpzZXQgL3AgIlNFTD1BdXN3YWhsOiAiCgo6ZGlzcGF0Y2gKaWYgIiVTRUwlIj09IjAiIGV4aXQgL2IgMAppZiAiJVNFTCUiPT0iMSIgZ290byBvcHQxCmlmICIlU0VMJSI9PSIyIiBnb3RvIG9wdDIKaWYgIiVTRUwlIj09IjMiIGdvdG8gb3B0MwppZiAiJVNFTCUiPT0iNCIgZ290byBvcHQ0CmlmICIlU0VMJSI9PSI1IiBnb3RvIG9wdDUKZ290byBtZW51Cgo6d2Fybl9ydW50aW1lCmlmIC9JICIlTEFOR1VBR0UlIj09ImRlIiAoCiBlY2hvLgogZWNobyBEaWUgQUJILUxhdWZ6ZWl0ZGF0ZW4gaW0gT3JkbmVyICIlQUJIX0RJUiUiIHdlcmRlbiBlbnRmZXJudC4KIGVjaG8gRGF0ZWllbiwgZGllIFNpZSBzZWxic3QgaW5uZXJoYWxiIGRpZXNlciBBQkgtT3JkbmVyIGFiZ2VsZWd0IGhhYmVuLAogZWNobyBrb2VubmVuIGRhYmVpIGViZW5mYWxscyBnZWxvZXNjaHQgd2VyZGVuLgogZWNoby4KIHNldCAvcCAiQU5TPUZvcnRmYWhyZW4/IFtKL05dOiAiCiBpZiAvSSBub3QgIiFBTlMhIj09IkoiIGV4aXQgL2IgMQopIGVsc2UgKAogZWNoby4KIGVjaG8gQUJIIHJ1bnRpbWUgZGF0YSB1bmRlciAiJUFCSF9ESVIlIiB3aWxsIGJlIHJlbW92ZWQuCiBlY2hvIEZpbGVzIHlvdSBtYW51YWxseSBwbGFjZWQgaW5zaWRlIHRoZXNlIEFCSCBmb2xkZXJzIG1heSBhbHNvIGJlIGRlbGV0ZWQuCiBlY2hvLgogc2V0IC9wICJBTlM9Q29udGludWU/IFtZL05dOiAiCiBpZiAvSSBub3QgIiFBTlMhIj09IlkiIGV4aXQgL2IgMQopCmV4aXQgL2IgMAoKOndhcm5fc291cmNlCmNscwppZiAvSSAiJUxBTkdVQUdFJSI9PSJkZSIgKAogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIGVjaG8gICBXQVJOVU5HIC0gQVNFUFJJVEUgU09VUkNFL0JVSUxEIExPRVNDSEVOCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQogZWNoby4KIGVjaG8gRGVyIGtvbXBsZXR0ZSBPcmRuZXIgIiVST09UJSIgd2lyZCBnZWxvZXNjaHQuCiBlY2hvLgogZWNobyBXSUNIVElHOgogZWNobyBFaWdlbmUgRGF0ZWllbiwgVGhlbWVzLCBTa3JpcHRlLCBQYXRjaGVzLCBRdWVsbGNvZGUtQWVuZGVydW5nZW4gb2RlcgogZWNobyBzb25zdGlnZSBEYXRlaWVuLCBkaWUgU2llIGlubmVyaGFsYiBkaWVzZXMgT3JkbmVycyBoaW56dWdlZnVlZ3QgaGFiZW4sCiBlY2hvIHdlcmRlbiBlYmVuZmFsbHMgZ2Vsb2VzY2h0LgogZWNoby4KIGVjaG8gSWhyZSBBc2Vwcml0ZS1FaW5zdGVsbHVuZ2VuIGF1c3NlcmhhbGIgZGllc2VzIE9yZG5lcnMgYmxlaWJlbiBlcmhhbHRlbi4KIGVjaG8gUHJ1ZWZlbiBvZGVyIHNpY2hlcm4gU2llIGRlbiBPcmRuZXIgdm9yIGRlbSBGb3J0ZmFocmVuLgogZWNoby4KIGVjaG8gW09dIEJldHJvZmZlbmVuIE9yZG5lciBvZWZmbmVuCiBlY2hvIFtKXSBJY2ggdmVyc3RlaGUgZGFzIHVuZCBtb2VjaHRlIGZvcnRmYWhyZW4KIGVjaG8gW05dIEFiYnJlY2hlbgogZWNoby4KIHNldCAvcCAiQU5TPUF1c3dhaGw6ICIKIGlmIC9JICIhQU5TISI9PSJPIiBzdGFydCAiIiBleHBsb3Jlci5leGUgIiVST09UJSIgJiBwYXVzZSAmIGdvdG8gd2Fybl9zb3VyY2UKIGlmIC9JIG5vdCAiIUFOUyEiPT0iSiIgZXhpdCAvYiAxCikgZWxzZSAoCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQogZWNobyAgIFdBUk5JTkcgLSBSRU1PVkUgQVNFUFJJVEUgU09VUkNFL0JVSUxECiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQogZWNoby4KIGVjaG8gVGhlIGNvbXBsZXRlIGZvbGRlciAiJVJPT1QlIiB3aWxsIGJlIGRlbGV0ZWQuCiBlY2hvLgogZWNobyBJTVBPUlRBTlQ6CiBlY2hvIFlvdXIgb3duIGZpbGVzLCB0aGVtZXMsIHNjcmlwdHMsIHBhdGNoZXMsIHNvdXJjZSBtb2RpZmljYXRpb25zIG9yIG90aGVyCiBlY2hvIGZpbGVzIGFkZGVkIGluc2lkZSB0aGlzIGZvbGRlciB3aWxsIGJlIGRlbGV0ZWQgYXMgd2VsbC4KIGVjaG8uCiBlY2hvIEFzZXByaXRlIHNldHRpbmdzIG91dHNpZGUgdGhpcyBmb2xkZXIgYXJlIG5vdCByZW1vdmVkLgogZWNobyBSZXZpZXcgb3IgYmFjayB1cCB0aGUgZm9sZGVyIGJlZm9yZSBjb250aW51aW5nLgogZWNoby4KIGVjaG8gW09dIE9wZW4gYWZmZWN0ZWQgZm9sZGVyCiBlY2hvIFtZXSBJIHVuZGVyc3RhbmQgYW5kIHdhbnQgdG8gY29udGludWUKIGVjaG8gW05dIENhbmNlbAogZWNoby4KIHNldCAvcCAiQU5TPVNlbGVjdGlvbjogIgogaWYgL0kgIiFBTlMhIj09Ik8iIHN0YXJ0ICIiIGV4cGxvcmVyLmV4ZSAiJVJPT1QlIiAmIHBhdXNlICYgZ290byB3YXJuX3NvdXJjZQogaWYgL0kgbm90ICIhQU5TISI9PSJZIiBleGl0IC9iIDEKKQpleGl0IC9iIDAKCjp3YXJuX2FsbApjbHMKaWYgL0kgIiVMQU5HVUFHRSUiPT0iZGUiICgKIGVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiBlY2hvICAgV0FSTlVORyAtIEFMTEVTIEVOVEZFUk5FTgogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIGVjaG8uCiBlY2hvIERhZHVyY2ggd2VyZGVuIGFsbGUgdm9uIEFCSCBlcnN0ZWxsdGVuIG9kZXIgdmVyd2FsdGV0ZW4gSW5oYWx0ZSBlbnRmZXJudDoKIGVjaG8gLSBBQkggTGF1ZnplaXQtL1N1cHBvcnQtRGF0ZWllbiwgTG9ncyB1bmQgRGlhZ25vc2ViZXJpY2h0ZQogZWNobyAtIEJhY2t1cHMgdW5kIFN0YXR1cy0vVXBkYXRlLURhdGVpZW4KIGVjaG8gLSBlcnpldWd0ZXIgTGF1bmNoZXIgdW5kIGVyemV1Z3RlIFZlcmtudWVwZnVuZ2VuCiBlY2hvIC0gbG9rYWwgZ2VrbG9udGVyIEFzZXByaXRlIFNvdXJjZS0vQnVpbGQtT3JkbmVyOiAlUk9PVCUKIGVjaG8gLSB2b24gQUJIIHZlcndhbHRldGUgVGhlbWVzLCBBZGQtb25zIHVuZCBTa3JpcHRlCiBlY2hvLgogZWNobyBBQ0hUVU5HOgogZWNobyBWZXJ3YWx0ZXRlIE9yZG5lciB3ZXJkZW4gdm9sbHN0YWVuZGlnIGVudGZlcm50LiBFaWdlbmUgRGF0ZWllbiBvZGVyCiBlY2hvIEFlbmRlcnVuZ2VuIGlubmVyaGFsYiBkaWVzZXIgT3JkbmVyIHdlcmRlbiBlYmVuZmFsbHMgZ2Vsb2VzY2h0LCB6LkIuCiBlY2hvIGVpZ2VuZSBUaGVtZXMvU2tyaXB0ZSwgUGF0Y2hlcyBvZGVyIHp1c2FldHpsaWNoZSBTb3VyY2UtL0J1aWxkLURhdGVpZW4uCiBlY2hvLgogZWNobyBNYW51ZWxsIGluc3RhbGxpZXJ0ZSBJbmhhbHRlIGF1c3NlcmhhbGIgZGVyIEFCSC12ZXJ3YWx0ZXRlbiBQZmFkZSB3ZXJkZW4KIGVjaG8gbmljaHQgYWJzaWNodGxpY2ggZW50ZmVybnQuIFNraWEgd2lyZCBuaWNodCBnZWxvZXNjaHQsIGRhIEFCSCBlcyBuaWNodAogZWNobyBhdXRvbWF0aXNjaCBpbnN0YWxsaWVydCBoYXQuCiBlY2hvLgogZWNobyBEaWVzZSBBa3Rpb24ga2FubiBuaWNodCBydWVja2dhZW5naWcgZ2VtYWNodCB3ZXJkZW4uCiBlY2hvLgogZWNobyBbT10gQmV0cm9mZmVuZSBPcmRuZXIgb2VmZm5lbgogZWNobyBbQ10gV2VpdGVyIHp1ciBmaW5hbGVuIEJlc3RhZXRpZ3VuZwogZWNobyBbTl0gQWJicmVjaGVuCiBlY2hvLgogc2V0IC9wICJBTlM9QXVzd2FobDogIgogaWYgL0kgIiFBTlMhIj09Ik8iIGNhbGwgOm9wZW5fYWZmZWN0ZWQgJiBwYXVzZSAmIGdvdG8gd2Fybl9hbGwKIGlmIC9JIG5vdCAiIUFOUyEiPT0iQyIgZXhpdCAvYiAxCiBlY2hvLgogc2V0IC9wICJDT05GPVp1bSBCZXN0YWV0aWdlbiBleGFrdCBBTExFUyBFTlRGRVJORU4gZWluZ2ViZW46ICIKIGlmIC9JIG5vdCAiIUNPTkYhIj09IkFMTEVTIEVOVEZFUk5FTiIgZXhpdCAvYiAxCikgZWxzZSAoCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQogZWNobyAgIFdBUk5JTkcgLSBSRU1PVkUgQUxMCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQogZWNoby4KIGVjaG8gVGhpcyByZW1vdmVzIGFsbCBjb250ZW50IGNyZWF0ZWQgb3IgbWFuYWdlZCBieSBBQkg6CiBlY2hvIC0gQUJIIHJ1bnRpbWUvc3VwcG9ydCBmaWxlcywgbG9ncyBhbmQgZGlhZ25vc3RpY3MKIGVjaG8gLSBiYWNrdXBzIGFuZCBzdGF0ZS91cGRhdGUgZmlsZXMKIGVjaG8gLSBnZW5lcmF0ZWQgbGF1bmNoZXIgYW5kIHNob3J0Y3V0cwogZWNobyAtIGxvY2FsIEFzZXByaXRlIHNvdXJjZS9idWlsZCBmb2xkZXI6ICVST09UJQogZWNobyAtIEFCSC1tYW5hZ2VkIHRoZW1lcywgYWRkLW9ucyBhbmQgc2NyaXB0cwogZWNoby4KIGVjaG8gSU1QT1JUQU5UOgogZWNobyBNYW5hZ2VkIGZvbGRlcnMgYXJlIHJlbW92ZWQgY29tcGxldGVseS4gWW91ciBvd24gZmlsZXMgb3IgY2hhbmdlcyBpbnNpZGUKIGVjaG8gdGhvc2UgZm9sZGVycyB3aWxsIGFsc28gYmUgZGVsZXRlZCwgaW5jbHVkaW5nIGN1c3RvbSB0aGVtZXMvc2NyaXB0cywKIGVjaG8gcGF0Y2hlcywgb3IgYWRkaXRpb25hbCBzb3VyY2UvYnVpbGQgZmlsZXMuCiBlY2hvLgogZWNobyBNYW51YWxseSBpbnN0YWxsZWQgY29udGVudCBvdXRzaWRlIEFCSC1tYW5hZ2VkIHBhdGhzIGlzIG5vdCBpbnRlbnRpb25hbGx5CiBlY2hvIHJlbW92ZWQuIFNraWEgaXMgbm90IHJlbW92ZWQgYmVjYXVzZSBBQkggZGlkIG5vdCBpbnN0YWxsIGl0IGF1dG9tYXRpY2FsbHkuCiBlY2hvLgogZWNobyBUaGlzIGFjdGlvbiBjYW5ub3QgYmUgdW5kb25lLgogZWNoby4KIGVjaG8gW09dIE9wZW4gYWZmZWN0ZWQgZm9sZGVycwogZWNobyBbQ10gQ29udGludWUgdG8gZmluYWwgY29uZmlybWF0aW9uCiBlY2hvIFtOXSBDYW5jZWwKIGVjaG8uCiBzZXQgL3AgIkFOUz1TZWxlY3Rpb246ICIKIGlmIC9JICIhQU5TISI9PSJPIiBjYWxsIDpvcGVuX2FmZmVjdGVkICYgcGF1c2UgJiBnb3RvIHdhcm5fYWxsCiBpZiAvSSBub3QgIiFBTlMhIj09IkMiIGV4aXQgL2IgMQogZWNoby4KIHNldCAvcCAiQ09ORj1UeXBlIFJFTU9WRSBBTEwgZXhhY3RseSB0byBjb25maXJtOiAiCiBpZiAvSSBub3QgIiFDT05GISI9PSJSRU1PVkUgQUxMIiBleGl0IC9iIDEKKQpleGl0IC9iIDAKCjpvcGVuX2FmZmVjdGVkCmlmIGV4aXN0ICIlUk9PVCUiIHN0YXJ0ICIiIGV4cGxvcmVyLmV4ZSAiJVJPT1QlIgppZiBleGlzdCAiJUFQUF9BU0UlXGV4dGVuc2lvbnMiIHN0YXJ0ICIiIGV4cGxvcmVyLmV4ZSAiJUFQUF9BU0UlXGV4dGVuc2lvbnMiCmlmIGV4aXN0ICIlQVBQX0FTRSVcc2NyaXB0cyIgc3RhcnQgIiIgZXhwbG9yZXIuZXhlICIlQVBQX0FTRSVcc2NyaXB0cyIKaWYgZXhpc3QgIiVBQkhfRElSJSIgc3RhcnQgIiIgZXhwbG9yZXIuZXhlICIlQUJIX0RJUiUiCmV4aXQgL2IgMAoKOnJlbW92ZV9zaG9ydGN1dHMKZGVsIC9xICIlREVTS1RPUCVcQXNlcHJpdGUubG5rIiA+bnVsIDI+JjEKZGVsIC9xICIlREVTS1RPUCVcQXNlcHJpdGUgLSBGb3JjZSBVcGRhdGUgQ2hlY2subG5rIiA+bnVsIDI+JjEKZGVsIC9xICIlREVTS1RPUCVcQXNlcHJpdGUgQnVpbGQgSGVscGVyIC0gVW5pbnN0YWxsLmxuayIgPm51bCAyPiYxCmV4aXQgL2IgMAoKOnJlbW92ZV9tYW5hZ2VkX2V4dGVuc2lvbnMKcG93ZXJzaGVsbC5leGUgLU5vTG9nbyAtTm9Qcm9maWxlIC1FeGVjdXRpb25Qb2xpY3kgQnlwYXNzIC1Db21tYW5kICIkZmlsZXM9QCgnJU1BTklGRVNUJVxtYW5hZ2VkLXRoZW1lLWV4dGVuc2lvbnMudHh0JywnJU1BTklGRVNUJVxtYW5hZ2VkLWFkZG9uLWV4dGVuc2lvbnMudHh0Jyk7IGZvcmVhY2goJGYgaW4gJGZpbGVzKXtpZihUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRmKXtHZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJGYgfCBGb3JFYWNoLU9iamVjdCB7aWYoJF8gLWFuZCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkXykpe1JlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkXyAtUmVjdXJzZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWV9fX19IiA+bnVsIDI+JjEKaWYgZXhpc3QgIiVBRERPTl9TQ1JJUFRTJSIgcm1kaXIgL3MgL3EgIiVBRERPTl9TQ1JJUFRTJSIKaWYgZXhpc3QgIiVMT0NBTF9TQ1JJUFRTJSIgcm1kaXIgL3MgL3EgIiVMT0NBTF9TQ1JJUFRTJSIKZXhpdCAvYiAwCgo6c2VsZl9yZW1vdmVfYWJoZGlyZWN0b3J5CnNldCAiVEFSR0VUPSVBQkhfRElSJSIKc3RhcnQgIiIgL2IgY21kLmV4ZSAvZCAvYyAicGluZyAxMjcuMC4wLjEgLW4gMyBePm51bCBeJiBybWRpciAvcyAvcSBcIiVUQVJHRVQlXCIiCmV4aXQgL2IgMAoKOm9wdDEKY2FsbCA6d2Fybl9ydW50aW1lCmlmIGVycm9ybGV2ZWwgMSBnb3RvIG1lbnUKaWYgZXhpc3QgIiVBQkhfRElSJVxiYWNrdXBzIiAoCiAgZm9yICUlSSBpbiAoIiVBQkhfRElSJVxiYWNrdXBzIikgZG8gc2V0ICJLRUVQX0JBQ0tVUFM9JSV+ZkkiCiAgc2V0ICJUTVBCQUNLPSVURU1QJVxBQkgtYmFja3Vwcy0lUkFORE9NJSVSQU5ET00lIgogIG1vdmUgIiVBQkhfRElSJVxiYWNrdXBzIiAiIVRNUEJBQ0shIiA+bnVsIDI+JjEKKQpjYWxsIDpzZWxmX3JlbW92ZV9hYmhkaXJlY3RvcnkKaWYgZGVmaW5lZCBUTVBCQUNLIHN0YXJ0ICIiIC9iIGNtZC5leGUgL2QgL2MgInBpbmcgMTI3LjAuMC4xIC1uIDQgXj5udWwgXiYgbWtkaXIgXCIlQUJIX0RJUiVcYmFja3Vwc1wiIDJePm51bCBeJiBtb3ZlIFwiIVRNUEJBQ0shXCIgXCIlQUJIX0RJUiVcYmFja3Vwc1wiIF4+bnVsIDJePl4mMSIKZXhpdCAvYiAwCgo6b3B0MgpjYWxsIDp3YXJuX3J1bnRpbWUKaWYgZXJyb3JsZXZlbCAxIGdvdG8gbWVudQpjYWxsIDpyZW1vdmVfc2hvcnRjdXRzCmlmIGV4aXN0ICIlQUJIX0RJUiVcYmFja3VwcyIgKAogIHNldCAiVE1QQkFDSz0lVEVNUCVcQUJILWJhY2t1cHMtJVJBTkRPTSUlUkFORE9NJSIKICBtb3ZlICIlQUJIX0RJUiVcYmFja3VwcyIgIiFUTVBCQUNLISIgPm51bCAyPiYxCikKY2FsbCA6c2VsZl9yZW1vdmVfYWJoZGlyZWN0b3J5CmlmIGRlZmluZWQgVE1QQkFDSyBzdGFydCAiIiAvYiBjbWQuZXhlIC9kIC9jICJwaW5nIDEyNy4wLjAuMSAtbiA0IF4+bnVsIF4mIG1rZGlyIFwiJUFCSF9ESVIlXGJhY2t1cHNcIiAyXj5udWwgXiYgbW92ZSBcIiFUTVBCQUNLIVwiIFwiJUFCSF9ESVIlXGJhY2t1cHNcIiBePm51bCAyXj5eJjEiCmV4aXQgL2IgMAoKOm9wdDMKY2FsbCA6d2Fybl9ydW50aW1lCmlmIGVycm9ybGV2ZWwgMSBnb3RvIG1lbnUKY2FsbCA6cmVtb3ZlX3Nob3J0Y3V0cwpjYWxsIDpzZWxmX3JlbW92ZV9hYmhkaXJlY3RvcnkKZXhpdCAvYiAwCgo6b3B0NApjYWxsIDp3YXJuX3NvdXJjZQppZiBlcnJvcmxldmVsIDEgZ290byBtZW51CmlmIGV4aXN0ICIlUk9PVCUiIHJtZGlyIC9zIC9xICIlUk9PVCUiCmlmIC9JICIlTEFOR1VBR0UlIj09ImRlIiAoZWNobyBBc2Vwcml0ZSBTb3VyY2UvQnVpbGQgd3VyZGUgZW50ZmVybnQuKSBlbHNlIChlY2hvIEFzZXByaXRlIHNvdXJjZS9idWlsZCB3YXMgcmVtb3ZlZC4pCnBhdXNlCmdvdG8gbWVudQoKOm9wdDUKY2FsbCA6d2Fybl9hbGwKaWYgZXJyb3JsZXZlbCAxIGdvdG8gbWVudQpjYWxsIDpyZW1vdmVfc2hvcnRjdXRzCmNhbGwgOnJlbW92ZV9tYW5hZ2VkX2V4dGVuc2lvbnMKaWYgZXhpc3QgIiVST09UJSIgcm1kaXIgL3MgL3EgIiVST09UJSIKY2FsbCA6c2VsZl9yZW1vdmVfYWJoZGlyZWN0b3J5CmV4aXQgL2IgMAo=
###END:uninstall.ico.b64###

###BEGIN:aseprite-launcher.vbs.b64###
T3B0aW9uIEV4cGxpY2l0DQpEaW0gc2hlbGwsIGZzbywgc2NyaXB0RGlyLCBhYmhEaXIsIHByb2pl
Y3REaXIsIHVwZGF0ZXIsIGJ1aWxkZXIsIGNtZCwgcSwgdWlMYW5nLCBtc2cNClNldCBzaGVsbCA9
IENyZWF0ZU9iamVjdCgiV1NjcmlwdC5TaGVsbCIpDQpTZXQgZnNvID0gQ3JlYXRlT2JqZWN0KCJT
Y3JpcHRpbmcuRmlsZVN5c3RlbU9iamVjdCIpDQpxID0gQ2hyKDM0KQ0Kc2NyaXB0RGlyID0gZnNv
LkdldFBhcmVudEZvbGRlck5hbWUoV1NjcmlwdC5TY3JpcHRGdWxsTmFtZSkNCmFiaERpciA9IGZz
by5HZXRQYXJlbnRGb2xkZXJOYW1lKHNjcmlwdERpcikNCnByb2plY3REaXIgPSBmc28uR2V0UGFy
ZW50Rm9sZGVyTmFtZShhYmhEaXIpDQp1cGRhdGVyID0gZnNvLkJ1aWxkUGF0aChmc28uQnVpbGRQ
YXRoKGFiaERpciwgInVwZGF0ZXIiKSwgImFzZXByaXRlLWJ1aWxkLXVwZGF0ZXIuYmF0IikNCmJ1
aWxkZXIgPSBmc28uQnVpbGRQYXRoKHByb2plY3REaXIsICJhc2Vwcml0ZS1idWlsZC1oZWxwZXIu
YmF0IikNCg0KSWYgTm90IGZzby5GaWxlRXhpc3RzKHVwZGF0ZXIpIFRoZW4NCiAgSWYgZnNvLkZp
bGVFeGlzdHMoYnVpbGRlcikgVGhlbg0KICAgIGNtZCA9ICJjbWQuZXhlIC9kIC9jICIgJiBxICYg
cSAmIGJ1aWxkZXIgJiBxICYgIiAtLXJlZnJlc2gtcnVudGltZSIgJiBxDQogICAgc2hlbGwuUnVu
IGNtZCwgMCwgVHJ1ZQ0KICBFbmQgSWYNCkVuZCBJZg0KDQpJZiBOb3QgZnNvLkZpbGVFeGlzdHMo
dXBkYXRlcikgVGhlbg0KICB1aUxhbmcgPSAiZW4iDQogIE9uIEVycm9yIFJlc3VtZSBOZXh0DQog
IHVpTGFuZyA9IExDYXNlKHNoZWxsLlJlZ1JlYWQoIkhLRVlfQ1VSUkVOVF9VU0VSXENvbnRyb2wg
UGFuZWxcSW50ZXJuYXRpb25hbFxMb2NhbGVOYW1lIikpDQogIE9uIEVycm9yIEdvVG8gMA0KICBJ
ZiBMZWZ0KHVpTGFuZywgMikgPSAiZGUiIFRoZW4NCiAgICBtc2cgPSAiQXNlcHJpdGUgQnVpbGQg
VXBkYXRlciBrb25udGUgbmljaHQgZ2VmdW5kZW4gd2VyZGVuLiBCaXR0ZSBzdGFydGUgYXNlcHJp
dGUtYnVpbGQtaGVscGVyLmJhdCB6dXIgUmVwYXJhdHVyLiINCiAgRWxzZQ0KICAgIG1zZyA9ICJB
c2Vwcml0ZSBCdWlsZCBVcGRhdGVyIGNvdWxkIG5vdCBiZSBmb3VuZC4gUGxlYXNlIHJ1biBhc2Vw
cml0ZS1idWlsZC1oZWxwZXIuYmF0IHRvIHJlcGFpciBpdC4iDQogIEVuZCBJZg0KICBNc2dCb3gg
bXNnLCB2YkNyaXRpY2FsLCAiQXNlcHJpdGUgQnVpbGQgSGVscGVyIg0KICBXU2NyaXB0LlF1aXQg
Mg0KRW5kIElmDQoNCmNtZCA9ICJjbWQuZXhlIC9kIC9jICIgJiBxICYgcSAmIHVwZGF0ZXIgJiBx
ICYgIiAtLXNjaGVkdWxlZCAtLWxhdW5jaCIgJiBxDQpzaGVsbC5SdW4gY21kLCAwLCBGYWxzZQ0K
###END:aseprite-launcher.vbs.b64###

###BEGIN:uninstall-abh.bat.b64###
QGVjaG8gb2ZmDQpjaGNwIDY1MDAxID5udWwNCnNldGxvY2FsIEVuYWJsZUV4dGVuc2lvbnMgRW5h
YmxlRGVsYXllZEV4cGFuc2lvbg0KZm9yICUlSSBpbiAoIiV+ZHAwLi4iKSBkbyBzZXQgIkFCSF9E
SVI9JSV+ZkkiDQpmb3IgJSVJIGluICgiJUFCSF9ESVIlXC4uIikgZG8gc2V0ICJQUk9KRUNUX0RJ
Uj0lJX5mSSINCnNldCAiUk9PVD1DOlxhc2Vwcml0ZSINCnNldCAiQ09ORklHPSVBQkhfRElSJVxj
b25maWciDQpzZXQgIlNPVVJDRVM9JUNPTkZJRyVcc291cmNlcyINCnNldCAiQkFDS1VQUz0lQUJI
X0RJUiVcYmFja3VwcyINCnNldCAiTUFOSUZFU1Q9JUFCSF9ESVIlXG1hbmlmZXN0Ig0Kc2V0ICJB
UFBfQVNFPSVBUFBEQVRBJVxBc2Vwcml0ZSINCnNldCAiQURET05fU0NSSVBUUz0lQVBQX0FTRSVc
c2NyaXB0c1xhdXRvLW1hbmFnZWQiDQpzZXQgIkxPQ0FMX1NDUklQVFM9JUFQUF9BU0UlXHNjcmlw
dHNcYXV0by1tYW5hZ2VkLWxvY2FsIg0Kc2V0ICJMQU5HVUFHRT1lbiINCmZvciAvZiAidXNlYmFj
a3EgZGVsaW1zPSIgJSVMIGluIChgcG93ZXJzaGVsbC5leGUgLU5vTG9nbyAtTm9Qcm9maWxlIC1D
b21tYW5kICIkYz0oR2V0LVVJQ3VsdHVyZSkuTmFtZTsgaWYoJGMgLWxpa2UgJ2RlLSonKXsnZGUn
fWVsc2V7J2VuJ30iYCkgZG8gc2V0ICJMQU5HVUFHRT0lJUwiDQpmb3IgJSVBIGluICglKikgZG8g
KA0KICBpZiAvSSAiJSV+QSI9PSItLWxhbmc9ZGUiIHNldCAiTEFOR1VBR0U9ZGUiDQogIGlmIC9J
ICIlJX5BIj09Ii0tbGFuZz1lbiIgc2V0ICJMQU5HVUFHRT1lbiINCikNCmZvciAvZiAidXNlYmFj
a3EgZGVsaW1zPSIgJSVEIGluIChgcG93ZXJzaGVsbC5leGUgLU5vTG9nbyAtTm9Qcm9maWxlIC1D
b21tYW5kICJbRW52aXJvbm1lbnRdOjpHZXRGb2xkZXJQYXRoKCdEZXNrdG9wJykiYCkgZG8gc2V0
ICJERVNLVE9QPSUlRCINCg0KOm1lbnUNCmNscw0KaWYgL0kgIiVMQU5HVUFHRSUiPT0iZGUiICgN
CiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PQ0KIGVjaG8gICBBc2Vwcml0ZSBCdWlsZCBIZWxwZXIgLSBEZWluc3RhbGxhdGlv
bg0KIGVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09DQogZWNoby4NCiBlY2hvIFsxXSBOdXIgSGVscGVyLUxhdWZ6ZWl0ZGF0ZWll
biBlbnRmZXJuZW4NCiBlY2hvIFsyXSBIZWxwZXItTGF1ZnplaXRkYXRlaWVuICsgZXJ6ZXVndGUg
VmVya27DvHBmdW5nZW4gZW50ZmVybmVuDQogZWNobyBbM10gSGVscGVyLUxhdWZ6ZWl0ZGF0ZWll
biwgVmVya27DvHBmdW5nZW4gdW5kIEFCSC1CYWNrdXBzIGVudGZlcm5lbg0KIGVjaG8gWzRdIExv
a2FsZSBBc2Vwcml0ZS1RdWVsbC0vQnVpbGQtT3JkbmVyIGVudGZlcm5lbg0KIGVjaG8gWzVdIEFM
TEUgdm9uIEFCSCB2ZXJ3YWx0ZXRlbiBJbmhhbHRlIGVudGZlcm5lbg0KIGVjaG8gWzZdIEFMTEVT
IGVudGZlcm5lbiArIFF1ZWxsZW4tS29uZmlndXJhdGlvbmVuIGFscyBaSVAgZXhwb3J0aWVyZW4N
CiBlY2hvIFswXSBBYmJyZWNoZW4NCiBlY2hvLg0KIHNldCAvcCAiU0VMPUF1c3dhaGw6ICINCikg
ZWxzZSAoDQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT0NCiBlY2hvICAgQXNlcHJpdGUgQnVpbGQgSGVscGVyIC0gVW5pbnN0
YWxsZXINCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PQ0KIGVjaG8uDQogZWNobyBbMV0gUmVtb3ZlIGhlbHBlciBydW50aW1l
IGZpbGVzIG9ubHkNCiBlY2hvIFsyXSBSZW1vdmUgaGVscGVyIHJ1bnRpbWUgZmlsZXMgKyBnZW5l
cmF0ZWQgc2hvcnRjdXRzDQogZWNobyBbM10gUmVtb3ZlIGhlbHBlciBydW50aW1lLCBzaG9ydGN1
dHMgYW5kIEFCSCBiYWNrdXBzDQogZWNobyBbNF0gUmVtb3ZlIGxvY2FsIEFzZXByaXRlIHNvdXJj
ZS9idWlsZCBmb2xkZXJzDQogZWNobyBbNV0gUkVNT1ZFIEFMTCBBQkgtbWFuYWdlZCBjb250ZW50
DQogZWNobyBbNl0gUkVNT1ZFIEFMTCArIGV4cG9ydCBzb3VyY2UgY29uZmlndXJhdGlvbnMgdG8g
WklQDQogZWNobyBbMF0gQ2FuY2VsDQogZWNoby4NCiBzZXQgL3AgIlNFTD1TZWxlY3Rpb246ICIN
CikNCmlmICIlU0VMJSI9PSIwIiBleGl0IC9iIDANCmlmICIlU0VMJSI9PSIxIiBnb3RvIG9wdDEN
CmlmICIlU0VMJSI9PSIyIiBnb3RvIG9wdDINCmlmICIlU0VMJSI9PSIzIiBnb3RvIG9wdDMNCmlm
ICIlU0VMJSI9PSI0IiBnb3RvIG9wdDQNCmlmICIlU0VMJSI9PSI1IiBnb3RvIG9wdDUNCmlmICIl
U0VMJSI9PSI2IiBnb3RvIG9wdDYNCmdvdG8gbWVudQ0KDQo6d2Fybl9ydW50aW1lDQppZiAvSSAi
JUxBTkdVQUdFJSI9PSJkZSIgKA0KIGVjaG8uDQogZWNobyBEaWUgQUJILUxhdWZ6ZWl0ZGF0ZW4g
d2VyZGVuIGVudGZlcm50Lg0KIGVjaG8gRWlnZW5lIERhdGVpZW4gaW5uZXJoYWxiIHZvbiBBQkgt
T3JkbmVybiBrw7ZubmVuIGViZW5mYWxscyBnZWzDtnNjaHQgd2VyZGVuLg0KIGVjaG8uDQogc2V0
IC9wICJBTlM9Rm9ydGZhaHJlbj8gW0ovTl06ICINCiBpZiAvSSBub3QgIiFBTlMhIj09IkoiIGV4
aXQgL2IgMQ0KKSBlbHNlICgNCiBlY2hvLg0KIGVjaG8gQUJIIHJ1bnRpbWUgZGF0YSB3aWxsIGJl
IHJlbW92ZWQuDQogZWNobyBGaWxlcyB5b3UgbWFudWFsbHkgcGxhY2VkIGluc2lkZSBBQkggZm9s
ZGVycyBtYXkgYWxzbyBiZSBkZWxldGVkLg0KIGVjaG8uDQogc2V0IC9wICJBTlM9Q29udGludWU/
IFtZL05dOiAiDQogaWYgL0kgbm90ICIhQU5TISI9PSJZIiBleGl0IC9iIDENCikNCmV4aXQgL2Ig
MA0KDQo6d2Fybl9zb3VyY2UNCmNscw0KaWYgL0kgIiVMQU5HVUFHRSUiPT0iZGUiICgNCiBlY2hv
ID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PQ0KIGVjaG8gICBXQVJOVU5HIC0gQVNFUFJJVEUgU09VUkNFL0JVSUxEIEzDllNDSEVODQog
ZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT0NCiBlY2hvLg0KIGVjaG8gRGVyIGtvbXBsZXR0ZSBPcmRuZXIgIiVST09UJSIgd2ly
ZCBnZWzDtnNjaHQuDQogZWNoby4NCiBlY2hvIFdJQ0hUSUc6DQogZWNobyBFaWdlbmUgRGF0ZWll
biwgVGhlbWVzLCBTa3JpcHRlLCBQYXRjaGVzLCBRdWVsbGNvZGUtw4RuZGVydW5nZW4gb2Rlcg0K
IGVjaG8gc29uc3RpZ2UgRGF0ZWllbiBpbm5lcmhhbGIgZGllc2VzIE9yZG5lcnMgd2VyZGVuIGVi
ZW5mYWxscyBnZWzDtnNjaHQuDQogZWNobyBQcsO8ZmVuIG9kZXIgc2ljaGVybiBTaWUgZGVuIE9y
ZG5lciB2b3IgZGVtIEZvcnRmYWhyZW4uDQogZWNoby4NCiBlY2hvIFtPXSBCZXRyb2ZmZW5lbiBP
cmRuZXIgw7ZmZm5lbg0KIGVjaG8gW0pdIEljaCB2ZXJzdGVoZSBkYXMgdW5kIG3DtmNodGUgZm9y
dGZhaHJlbg0KIGVjaG8gW05dIEFiYnJlY2hlbg0KIHNldCAvcCAiQU5TPUF1c3dhaGw6ICINCiBp
ZiAvSSAiIUFOUyEiPT0iTyIgc3RhcnQgIiIgZXhwbG9yZXIuZXhlICIlUk9PVCUiICYgcGF1c2Ug
JiBnb3RvIHdhcm5fc291cmNlDQogaWYgL0kgbm90ICIhQU5TISI9PSJKIiBleGl0IC9iIDENCikg
ZWxzZSAoDQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT0NCiBlY2hvICAgV0FSTklORyAtIFJFTU9WRSBBU0VQUklURSBTT1VS
Q0UvQlVJTEQNCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PQ0KIGVjaG8uDQogZWNobyBUaGUgY29tcGxldGUgZm9sZGVyICIl
Uk9PVCUiIHdpbGwgYmUgZGVsZXRlZC4NCiBlY2hvLg0KIGVjaG8gSU1QT1JUQU5UOg0KIGVjaG8g
WW91ciBvd24gZmlsZXMsIHRoZW1lcywgc2NyaXB0cywgcGF0Y2hlcywgc291cmNlIG1vZGlmaWNh
dGlvbnMgb3Igb3RoZXINCiBlY2hvIGZpbGVzIGluc2lkZSB0aGlzIGZvbGRlciB3aWxsIGJlIGRl
bGV0ZWQgYXMgd2VsbC4NCiBlY2hvIFJldmlldyBvciBiYWNrIHVwIHRoaXMgZm9sZGVyIGJlZm9y
ZSBjb250aW51aW5nLg0KIGVjaG8uDQogZWNobyBbT10gT3BlbiBhZmZlY3RlZCBmb2xkZXINCiBl
Y2hvIFtZXSBJIHVuZGVyc3RhbmQgYW5kIHdhbnQgdG8gY29udGludWUNCiBlY2hvIFtOXSBDYW5j
ZWwNCiBzZXQgL3AgIkFOUz1TZWxlY3Rpb246ICINCiBpZiAvSSAiIUFOUyEiPT0iTyIgc3RhcnQg
IiIgZXhwbG9yZXIuZXhlICIlUk9PVCUiICYgcGF1c2UgJiBnb3RvIHdhcm5fc291cmNlDQogaWYg
L0kgbm90ICIhQU5TISI9PSJZIiBleGl0IC9iIDENCikNCmV4aXQgL2IgMA0KDQo6d2Fybl9hbGwN
CmNscw0KaWYgL0kgIiVMQU5HVUFHRSUiPT0iZGUiICgNCiBlY2hvID09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KIGVjaG8gICBXQVJO
VU5HIC0gQUxMRVMgRU5URkVSTkVODQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiBlY2hvLg0KIGVjaG8gRW50ZmVybnQg
d2VyZGVuIHVudGVyIGFuZGVyZW06DQogZWNobyAtIEFCSC1MYXVmemVpdC0vU3VwcG9ydC1EYXRl
aWVuLCBMb2dzIHVuZCBEaWFnbm9zZWJlcmljaHRlDQogZWNobyAtIEJhY2t1cHMsIFN0YXR1cy0v
VXBkYXRlLURhdGVpZW4gdW5kIFF1ZWxsZW4tS29uZmlndXJhdGlvbmVuDQogZWNobyAtIGVyemV1
Z3RlciBMYXVuY2hlciB1bmQgZXJ6ZXVndGUgVmVya27DvHBmdW5nZW4NCiBlY2hvIC0gbG9rYWwg
Z2VrbG9udGVyIEFzZXByaXRlIFNvdXJjZS0vQnVpbGQtT3JkbmVyOiAlUk9PVCUNCiBlY2hvIC0g
dm9uIEFCSCB2ZXJ3YWx0ZXRlIFRoZW1lcywgQWRkLW9ucyB1bmQgU2tyaXB0ZQ0KIGVjaG8uDQog
ZWNobyBBQ0hUVU5HOg0KIGVjaG8gVmVyd2FsdGV0ZSBPcmRuZXIgd2VyZGVuIHZvbGxzdMOkbmRp
ZyBnZWzDtnNjaHQuIEVpZ2VuZSBEYXRlaWVuIG9kZXINCiBlY2hvIMOEbmRlcnVuZ2VuIGlubmVy
aGFsYiBkaWVzZXIgT3JkbmVyIHdlcmRlbiBlYmVuZmFsbHMgZ2Vsw7ZzY2h0Lg0KIGVjaG8gU2tp
YSB3aXJkIG5pY2h0IGdlbMO2c2NodCwgZGEgQUJIIGVzIG5pY2h0IGF1dG9tYXRpc2NoIGluc3Rh
bGxpZXJ0IGhhdC4NCiBlY2hvLg0KIGVjaG8gW09dIEJldHJvZmZlbmUgT3JkbmVyIMO2ZmZuZW4N
CiBlY2hvIFtDXSBXZWl0ZXIgenVyIGZpbmFsZW4gQmVzdMOkdGlndW5nDQogZWNobyBbTl0gQWJi
cmVjaGVuDQogc2V0IC9wICJBTlM9QXVzd2FobDogIg0KIGlmIC9JICIhQU5TISI9PSJPIiBjYWxs
IDpvcGVuX2FmZmVjdGVkICYgcGF1c2UgJiBnb3RvIHdhcm5fYWxsDQogaWYgL0kgbm90ICIhQU5T
ISI9PSJDIiBleGl0IC9iIDENCiBlY2hvLg0KIHNldCAvcCAiQ09ORj1adW0gQmVzdMOkdGlnZW4g
ZXhha3QgQUxMRVMgRU5URkVSTkVOIGVpbmdlYmVuOiAiDQogaWYgL0kgbm90ICIhQ09ORiEiPT0i
QUxMRVMgRU5URkVSTkVOIiBleGl0IC9iIDENCikgZWxzZSAoDQogZWNobyA9PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiBlY2hvICAg
V0FSTklORyAtIFJFTU9WRSBBTEwNCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KIGVjaG8uDQogZWNobyBUaGlzIHJlbW92
ZXMsIGFtb25nIG90aGVyIHRoaW5nczoNCiBlY2hvIC0gQUJIIHJ1bnRpbWUvc3VwcG9ydCBmaWxl
cywgbG9ncyBhbmQgZGlhZ25vc3RpY3MNCiBlY2hvIC0gYmFja3Vwcywgc3RhdGUvdXBkYXRlIGZp
bGVzIGFuZCBzb3VyY2UgY29uZmlndXJhdGlvbnMNCiBlY2hvIC0gZ2VuZXJhdGVkIGxhdW5jaGVy
IGFuZCBzaG9ydGN1dHMNCiBlY2hvIC0gbG9jYWwgQXNlcHJpdGUgc291cmNlL2J1aWxkIGZvbGRl
cjogJVJPT1QlDQogZWNobyAtIEFCSC1tYW5hZ2VkIHRoZW1lcywgYWRkLW9ucyBhbmQgc2NyaXB0
cw0KIGVjaG8uDQogZWNobyBJTVBPUlRBTlQ6DQogZWNobyBNYW5hZ2VkIGZvbGRlcnMgYXJlIHJl
bW92ZWQgY29tcGxldGVseS4gWW91ciBvd24gZmlsZXMgb3IgY2hhbmdlcyBpbnNpZGUNCiBlY2hv
IHRob3NlIGZvbGRlcnMgd2lsbCBhbHNvIGJlIGRlbGV0ZWQuDQogZWNobyBTa2lhIGlzIG5vdCBy
ZW1vdmVkIGJlY2F1c2UgQUJIIGRpZCBub3QgaW5zdGFsbCBpdCBhdXRvbWF0aWNhbGx5Lg0KIGVj
aG8uDQogZWNobyBbT10gT3BlbiBhZmZlY3RlZCBmb2xkZXJzDQogZWNobyBbQ10gQ29udGludWUg
dG8gZmluYWwgY29uZmlybWF0aW9uDQogZWNobyBbTl0gQ2FuY2VsDQogc2V0IC9wICJBTlM9U2Vs
ZWN0aW9uOiAiDQogaWYgL0kgIiFBTlMhIj09Ik8iIGNhbGwgOm9wZW5fYWZmZWN0ZWQgJiBwYXVz
ZSAmIGdvdG8gd2Fybl9hbGwNCiBpZiAvSSBub3QgIiFBTlMhIj09IkMiIGV4aXQgL2IgMQ0KIGVj
aG8uDQogc2V0IC9wICJDT05GPVR5cGUgUkVNT1ZFIEFMTCBleGFjdGx5IHRvIGNvbmZpcm06ICIN
CiBpZiAvSSBub3QgIiFDT05GISI9PSJSRU1PVkUgQUxMIiBleGl0IC9iIDENCikNCmV4aXQgL2Ig
MA0KDQo6d2Fybl9leHBvcnRfYWxsDQpjbHMNCmlmIC9JICIlTEFOR1VBR0UlIj09ImRlIiAoDQog
ZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT0NCiBlY2hvICAgQUxMRVMgRU5URkVSTkVOICsgUVVFTExFTi1LT05GSUdVUkFUSU9O
RU4gRVhQT1JUSUVSRU4NCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PQ0KIGVjaG8uDQogZWNobyBWb3IgZGVyIHZvbGxzdMOk
bmRpZ2VuIEVudGZlcm51bmcgd2VyZGVuIGFsbGUgSU5JLURhdGVpZW4gYXVzDQogZWNobyAiJVNP
VVJDRVMlIiBhbHMgWklQIG5lYmVuIGRlbiB1cnNwcsO8bmdsaWNoZW4gUGFrZXRkYXRlaWVuIGdl
c3BlaWNoZXJ0Lg0KIGVjaG8gRW50aGFsdGVuIHNpbmQgVGhlbWUtLCBBZGQtb24tIHVuZCBNaXhl
ZC1Lb25maWd1cmF0aW9uZW4gc293aWUgSWhyZQ0KIGVjaG8gZWlnZW5lbiBSZXBvc2l0b3J5LUVp
bnRyw6RnZSB1bmQgQXV0by1VcGRhdGUtRWluc3RlbGx1bmdlbi4NCiBlY2hvLg0KIGVjaG8gRGFu
YWNoIHdpcmQgZGVyc2VsYmUgSW5oYWx0IHdpZSBiZWkgT3B0aW9uIFs1XSBlbnRmZXJudC4NCiBl
Y2hvIEVpZ2VuZSBEYXRlaWVuIGlubmVyaGFsYiB2ZXJ3YWx0ZXRlciBPcmRuZXIgd2VyZGVuIGVi
ZW5mYWxscyBnZWzDtnNjaHQuDQogZWNoby4NCiBlY2hvIFtPXSBCZXRyb2ZmZW5lIE9yZG5lciDD
tmZmbmVuDQogZWNobyBbQ10gRXhwb3J0aWVyZW4gdW5kIHdlaXRlciB6dXIgZmluYWxlbiBCZXN0
w6R0aWd1bmcNCiBlY2hvIFtOXSBBYmJyZWNoZW4NCiBzZXQgL3AgIkFOUz1BdXN3YWhsOiAiDQog
aWYgL0kgIiFBTlMhIj09Ik8iIGNhbGwgOm9wZW5fYWZmZWN0ZWQgJiBwYXVzZSAmIGdvdG8gd2Fy
bl9leHBvcnRfYWxsDQogaWYgL0kgbm90ICIhQU5TISI9PSJDIiBleGl0IC9iIDENCiBlY2hvLg0K
IHNldCAvcCAiQ09ORj1adW0gQmVzdMOkdGlnZW4gZXhha3QgS09ORklHIEVYUE9SVElFUkVOIGVp
bmdlYmVuOiAiDQogaWYgL0kgbm90ICIhQ09ORiEiPT0iS09ORklHIEVYUE9SVElFUkVOIiBleGl0
IC9iIDENCikgZWxzZSAoDQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiBlY2hvICAgUkVNT1ZFIEFMTCArIEVYUE9SVCBT
T1VSQ0UgQ09ORklHVVJBVElPTlMNCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KIGVjaG8uDQogZWNobyBCZWZvcmUgcmVt
b3ZhbCwgYWxsIElOSSBmaWxlcyB1bmRlcg0KIGVjaG8gIiVTT1VSQ0VTJSIgd2lsbCBiZSBzYXZl
ZCBhcyBhIFpJUCBuZXh0IHRvIHRoZSBvcmlnaW5hbCBwYWNrYWdlIGZpbGVzLg0KIGVjaG8gSXQg
Y29udGFpbnMgdGhlbWUsIGFkZC1vbiBhbmQgbWl4ZWQgY29uZmlndXJhdGlvbnMsIGluY2x1ZGlu
ZyB5b3VyIG93bg0KIGVjaG8gcmVwb3NpdG9yeSBlbnRyaWVzIGFuZCBhdXRvLXVwZGF0ZSBzZXR0
aW5ncy4NCiBlY2hvLg0KIGVjaG8gVGhlIHNhbWUgY29udGVudCBhcyBvcHRpb24gWzVdIGlzIHRo
ZW4gcmVtb3ZlZC4NCiBlY2hvIFlvdXIgb3duIGZpbGVzIGluc2lkZSBtYW5hZ2VkIGZvbGRlcnMg
d2lsbCBhbHNvIGJlIGRlbGV0ZWQuDQogZWNoby4NCiBlY2hvIFtPXSBPcGVuIGFmZmVjdGVkIGZv
bGRlcnMNCiBlY2hvIFtDXSBFeHBvcnQgYW5kIGNvbnRpbnVlIHRvIGZpbmFsIGNvbmZpcm1hdGlv
bg0KIGVjaG8gW05dIENhbmNlbA0KIHNldCAvcCAiQU5TPVNlbGVjdGlvbjogIg0KIGlmIC9JICIh
QU5TISI9PSJPIiBjYWxsIDpvcGVuX2FmZmVjdGVkICYgcGF1c2UgJiBnb3RvIHdhcm5fZXhwb3J0
X2FsbA0KIGlmIC9JIG5vdCAiIUFOUyEiPT0iQyIgZXhpdCAvYiAxDQogZWNoby4NCiBzZXQgL3Ag
IkNPTkY9VHlwZSBFWFBPUlQgQ09ORklHUyBleGFjdGx5IHRvIGNvbmZpcm06ICINCiBpZiAvSSBu
b3QgIiFDT05GISI9PSJFWFBPUlQgQ09ORklHUyIgZXhpdCAvYiAxDQopDQpleGl0IC9iIDANCg0K
OmV4cG9ydF9zb3VyY2VzDQppZiBub3QgZXhpc3QgIiVTT1VSQ0VTJSIgZXhpdCAvYiAxDQpmb3Ig
L2YgInVzZWJhY2txIGRlbGltcz0iICUlVCBpbiAoYHBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5v
UHJvZmlsZSAtQ29tbWFuZCAiR2V0LURhdGUgLUZvcm1hdCAneXl5eU1NZGQtSEhtbXNzJyJgKSBk
byBzZXQgIlRTPSUlVCINCnNldCAiT1VUWklQPSVQUk9KRUNUX0RJUiVcQUJILXNvdXJjZS1jb25m
aWctYmFja3VwLSVUUyUuemlwIg0Kc2V0ICJBQkhfRVhQT1JUX1NSQz0lU09VUkNFUyUiDQpzZXQg
IkFCSF9FWFBPUlRfWklQPSVPVVRaSVAlIg0KcG93ZXJzaGVsbC5leGUgLU5vTG9nbyAtTm9Qcm9m
aWxlIC1FeGVjdXRpb25Qb2xpY3kgQnlwYXNzIC1Db21tYW5kICIkdG1wPUpvaW4tUGF0aCAkZW52
OlRFTVAgKCdhYmgtc291cmNlLWV4cG9ydC0nK1tndWlkXTo6TmV3R3VpZCgpKTtOZXctSXRlbSAt
SXRlbVR5cGUgRGlyZWN0b3J5IC1Gb3JjZSAtUGF0aCAoSm9pbi1QYXRoICR0bXAgJ3NvdXJjZXMn
KXxPdXQtTnVsbDtDb3B5LUl0ZW0gLVBhdGggKCRlbnY6QUJIX0VYUE9SVF9TUkMrJ1wqJykgLURl
c3RpbmF0aW9uIChKb2luLVBhdGggJHRtcCAnc291cmNlcycpIC1SZWN1cnNlIC1Gb3JjZTtAKCdB
c2Vwcml0ZSBCdWlsZCBIZWxwZXIgU291cmNlIENvbmZpZ3VyYXRpb24gQmFja3VwJywnQ3JlYXRl
ZDogJysoR2V0LURhdGUgLUZvcm1hdCAneXl5eS1NTS1kZCBISDptbTpzcycpLCdDb250YWlucyBz
b3VyY2UgSU5JIGZpbGVzIG9ubHkuIE5vIHJlcG9zaXRvcmllcyBvciBiaW5hcmllcyBhcmUgaW5j
bHVkZWQuJyl8U2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoIChKb2luLVBhdGggJHRtcCAnYmFja3Vw
LWluZm8udHh0JykgLUVuY29kaW5nIFVURjg7Q29tcHJlc3MtQXJjaGl2ZSAtUGF0aCAoJHRtcCsn
XConKSAtRGVzdGluYXRpb25QYXRoICRlbnY6QUJIX0VYUE9SVF9aSVAgLUZvcmNlO1JlbW92ZS1J
dGVtIC1MaXRlcmFsUGF0aCAkdG1wIC1SZWN1cnNlIC1Gb3JjZSIgPm51bCAyPiYxDQppZiBub3Qg
ZXhpc3QgIiVPVVRaSVAlIiBleGl0IC9iIDENCmlmIC9JICIlTEFOR1VBR0UlIj09ImRlIiAoZWNo
byBRdWVsbGVuLUtvbmZpZ3VyYXRpb25lbiBnZXNpY2hlcnQ6ICVPVVRaSVAlKSBlbHNlIChlY2hv
IFNvdXJjZSBjb25maWd1cmF0aW9ucyBleHBvcnRlZDogJU9VVFpJUCUpDQpleGl0IC9iIDANCg0K
Om9wZW5fYWZmZWN0ZWQNCmlmIGV4aXN0ICIlUk9PVCUiIHN0YXJ0ICIiIGV4cGxvcmVyLmV4ZSAi
JVJPT1QlIg0KaWYgZXhpc3QgIiVBUFBfQVNFJVxleHRlbnNpb25zIiBzdGFydCAiIiBleHBsb3Jl
ci5leGUgIiVBUFBfQVNFJVxleHRlbnNpb25zIg0KaWYgZXhpc3QgIiVBUFBfQVNFJVxzY3JpcHRz
IiBzdGFydCAiIiBleHBsb3Jlci5leGUgIiVBUFBfQVNFJVxzY3JpcHRzIg0KaWYgZXhpc3QgIiVB
QkhfRElSJSIgc3RhcnQgIiIgZXhwbG9yZXIuZXhlICIlQUJIX0RJUiUiDQpleGl0IC9iIDANCg0K
OnJlbW92ZV9zaG9ydGN1dHMNCmRlbCAvcSAiJURFU0tUT1AlXEFzZXByaXRlLmxuayIgPm51bCAy
PiYxDQpkZWwgL3EgIiVERVNLVE9QJVxBc2Vwcml0ZSBCdWlsZCBVcGRhdGVyLmxuayIgPm51bCAy
PiYxDQpyZW0gTGVnYWN5IHNob3J0Y3V0cyBmcm9tIEFCSCB2MS4xIGFuZCBlYXJsaWVyLg0KZGVs
IC9xICIlREVTS1RPUCVcQXNlcHJpdGUgLSBGb3JjZSBVcGRhdGUgQ2hlY2subG5rIiA+bnVsIDI+
JjENCmRlbCAvcSAiJURFU0tUT1AlXEFzZXByaXRlIEJ1aWxkIEhlbHBlciAtIFVuaW5zdGFsbC5s
bmsiID5udWwgMj4mMQ0KZXhpdCAvYiAwDQoNCjpyZW1vdmVfbWFuYWdlZF9jb250ZW50DQpwb3dl
cnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLUV4ZWN1dGlvblBvbGljeSBCeXBhc3MgLUNv
bW1hbmQgIiRmaWxlcz1AKCclTUFOSUZFU1QlXG1hbmFnZWQtdGhlbWUtZXh0ZW5zaW9ucy50eHQn
LCclTUFOSUZFU1QlXG1hbmFnZWQtYWRkb24tZXh0ZW5zaW9ucy50eHQnKTtmb3JlYWNoKCRmIGlu
ICRmaWxlcyl7aWYoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZil7R2V0LUNvbnRlbnQgLUxpdGVy
YWxQYXRoICRmfEZvckVhY2gtT2JqZWN0e2lmKCRfIC1hbmQgKFRlc3QtUGF0aCAtTGl0ZXJhbFBh
dGggJF8pKXtSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJF8gLVJlY3Vyc2UgLUZvcmNlIC1FcnJv
ckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlfX19fSIgPm51bCAyPiYxDQppZiBleGlzdCAiJUFERE9O
X1NDUklQVFMlIiBybWRpciAvcyAvcSAiJUFERE9OX1NDUklQVFMlIg0KaWYgZXhpc3QgIiVMT0NB
TF9TQ1JJUFRTJSIgcm1kaXIgL3MgL3EgIiVMT0NBTF9TQ1JJUFRTJSINCmV4aXQgL2IgMA0KDQo6
c2VsZl9yZW1vdmVfYWJoZGlyZWN0b3J5DQpzZXQgIlRBUkdFVD0lQUJIX0RJUiUiDQpzdGFydCAi
IiAvYiBjbWQuZXhlIC9kIC9jICJwaW5nIDEyNy4wLjAuMSAtbiAzIF4+bnVsIF4mIHJtZGlyIC9z
IC9xIFwiJVRBUkdFVCVcIiINCmV4aXQgL2IgMA0KDQo6cHJlc2VydmVfY29uZmlnc19hbmRfYmFj
a3Vwcw0Kc2V0ICJUTVBLRUVQPSVURU1QJVxBQkgta2VlcC0lUkFORE9NJSVSQU5ET00lIg0KbWtk
aXIgIiFUTVBLRUVQISIgPm51bCAyPiYxDQppZiBleGlzdCAiJUJBQ0tVUFMlIiBtb3ZlICIlQkFD
S1VQUyUiICIhVE1QS0VFUCFcYmFja3VwcyIgPm51bCAyPiYxDQppZiBleGlzdCAiJUNPTkZJRyUi
IG1vdmUgIiVDT05GSUclIiAiIVRNUEtFRVAhXGNvbmZpZyIgPm51bCAyPiYxDQpleGl0IC9iIDAN
Cg0KOnJlc3RvcmVfcHJlc2VydmVkDQppZiBub3QgZGVmaW5lZCBUTVBLRUVQIGV4aXQgL2IgMA0K
c3RhcnQgIiIgL2IgY21kLmV4ZSAvZCAvYyAicGluZyAxMjcuMC4wLjEgLW4gNCBePm51bCBeJiBt
a2RpciBcIiVBQkhfRElSJVwiIDJePm51bCBeJiBpZiBleGlzdCBcIiFUTVBLRUVQIVxiYWNrdXBz
XCIgbW92ZSBcIiFUTVBLRUVQIVxiYWNrdXBzXCIgXCIlQUJIX0RJUiVcYmFja3Vwc1wiIF4+bnVs
IDJePl4mMSBeJiBpZiBleGlzdCBcIiFUTVBLRUVQIVxjb25maWdcIiBtb3ZlIFwiIVRNUEtFRVAh
XGNvbmZpZ1wiIFwiJUFCSF9ESVIlXGNvbmZpZ1wiIF4+bnVsIDJePl4mMSBeJiBybWRpciAvcyAv
cSBcIiFUTVBLRUVQIVwiIg0KZXhpdCAvYiAwDQoNCjpvcHQxDQpjYWxsIDp3YXJuX3J1bnRpbWUN
CmlmIGVycm9ybGV2ZWwgMSBnb3RvIG1lbnUNCmNhbGwgOnByZXNlcnZlX2NvbmZpZ3NfYW5kX2Jh
Y2t1cHMNCmNhbGwgOnNlbGZfcmVtb3ZlX2FiaGRpcmVjdG9yeQ0KY2FsbCA6cmVzdG9yZV9wcmVz
ZXJ2ZWQNCmV4aXQgL2IgMA0KDQo6b3B0Mg0KY2FsbCA6d2Fybl9ydW50aW1lDQppZiBlcnJvcmxl
dmVsIDEgZ290byBtZW51DQpjYWxsIDpyZW1vdmVfc2hvcnRjdXRzDQpjYWxsIDpwcmVzZXJ2ZV9j
b25maWdzX2FuZF9iYWNrdXBzDQpjYWxsIDpzZWxmX3JlbW92ZV9hYmhkaXJlY3RvcnkNCmNhbGwg
OnJlc3RvcmVfcHJlc2VydmVkDQpleGl0IC9iIDANCg0KOm9wdDMNCmNhbGwgOndhcm5fcnVudGlt
ZQ0KaWYgZXJyb3JsZXZlbCAxIGdvdG8gbWVudQ0KY2FsbCA6cmVtb3ZlX3Nob3J0Y3V0cw0KY2Fs
bCA6c2VsZl9yZW1vdmVfYWJoZGlyZWN0b3J5DQpleGl0IC9iIDANCg0KOm9wdDQNCmNhbGwgOndh
cm5fc291cmNlDQppZiBlcnJvcmxldmVsIDEgZ290byBtZW51DQppZiBleGlzdCAiJVJPT1QlIiBy
bWRpciAvcyAvcSAiJVJPT1QlIg0KaWYgL0kgIiVMQU5HVUFHRSUiPT0iZGUiIChlY2hvIEFzZXBy
aXRlIFNvdXJjZS9CdWlsZCB3dXJkZSBlbnRmZXJudC4pIGVsc2UgKGVjaG8gQXNlcHJpdGUgc291
cmNlL2J1aWxkIHdhcyByZW1vdmVkLikNCnBhdXNlDQpnb3RvIG1lbnUNCg0KOm9wdDUNCmNhbGwg
Ondhcm5fYWxsDQppZiBlcnJvcmxldmVsIDEgZ290byBtZW51DQpjYWxsIDpyZW1vdmVfc2hvcnRj
dXRzDQpjYWxsIDpyZW1vdmVfbWFuYWdlZF9jb250ZW50DQppZiBleGlzdCAiJVJPT1QlIiBybWRp
ciAvcyAvcSAiJVJPT1QlIg0KY2FsbCA6c2VsZl9yZW1vdmVfYWJoZGlyZWN0b3J5DQpleGl0IC9i
IDANCg0KOm9wdDYNCmNhbGwgOndhcm5fZXhwb3J0X2FsbA0KaWYgZXJyb3JsZXZlbCAxIGdvdG8g
bWVudQ0KY2FsbCA6ZXhwb3J0X3NvdXJjZXMNCmlmIGVycm9ybGV2ZWwgMSAoDQogaWYgL0kgIiVM
QU5HVUFHRSUiPT0iZGUiIChlY2hvIEZFSExFUjogRGllIFF1ZWxsZW4tS29uZmlndXJhdGlvbmVu
IGtvbm50ZW4gbmljaHQgZXhwb3J0aWVydCB3ZXJkZW4uKSBlbHNlIChlY2hvIEVSUk9SOiBTb3Vy
Y2UgY29uZmlndXJhdGlvbnMgY291bGQgbm90IGJlIGV4cG9ydGVkLikNCiBwYXVzZQ0KIGdvdG8g
bWVudQ0KKQ0KY2FsbCA6cmVtb3ZlX3Nob3J0Y3V0cw0KY2FsbCA6cmVtb3ZlX21hbmFnZWRfY29u
dGVudA0KaWYgZXhpc3QgIiVST09UJSIgcm1kaXIgL3MgL3EgIiVST09UJSINCmNhbGwgOnNlbGZf
cmVtb3ZlX2FiaGRpcmVjdG9yeQ0KZXhpdCAvYiAwDQo=
###END:uninstall-abh.bat.b64###

###BEGIN:aseprite-build-updater.bat.b64###
QGVjaG8gb2ZmDQpjaGNwIDY1MDAxID5udWwNCnNldGxvY2FsIEVuYWJsZUV4dGVuc2lvbnMgRW5h
YmxlRGVsYXllZEV4cGFuc2lvbg0KDQpyZW0gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KcmVtIEFzZXBy
aXRlIEJ1aWxkIFVwZGF0ZXIgLSBnZW5lcmF0ZWQgYnkgQXNlcHJpdGUgQnVpbGQgSGVscGVyDQpy
ZW0gUHJvamVjdDogaHR0cHM6Ly9naXRodWIuY29tL3R2ZXR6aW8vYXNlcHJpdGUtYnVpbGQtaGVs
cGVyDQpyZW0gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KDQpzZXQgIlVQREFURVJfVkVSU0lPTj0xLjIu
OSINCnNldCAiUFJPSkVDVF9VUkw9aHR0cHM6Ly9naXRodWIuY29tL3R2ZXR6aW8vYXNlcHJpdGUt
YnVpbGQtaGVscGVyIg0Kc2V0ICJBUElfTEFURVNUPWh0dHBzOi8vYXBpLmdpdGh1Yi5jb20vcmVw
b3MvdHZldHppby9hc2Vwcml0ZS1idWlsZC1oZWxwZXIvcmVsZWFzZXMvbGF0ZXN0Ig0KZm9yICUl
SSBpbiAoIiV+ZHAwLi4iKSBkbyBzZXQgIkFCSF9ESVI9JSV+ZkkiDQpmb3IgJSVJIGluICgiJUFC
SF9ESVIlXC4uIikgZG8gc2V0ICJQUk9KRUNUX0RJUj0lJX5mSSINCnNldCAiQlVJTERFUj0lUFJP
SkVDVF9ESVIlXGFzZXByaXRlLWJ1aWxkLWhlbHBlci5iYXQiDQpzZXQgIlJPT1Q9QzpcYXNlcHJp
dGUiDQpzZXQgIkVYRT0lUk9PVCVcYnVpbGRcYmluXGFzZXByaXRlLmV4ZSINCnNldCAiU1VQUE9S
VF9ESVI9JUFCSF9ESVIlXHN1cHBvcnQiDQpzZXQgIlVOSU5TVEFMTEVSPSVBQkhfRElSJVx1bmlu
c3RhbGxlclx1bmluc3RhbGwtYWJoLmJhdCINCnNldCAiQ09ORklHX0RJUj0lQUJIX0RJUiVcY29u
ZmlnIg0Kc2V0ICJTT1VSQ0VfQ09ORklHX0RJUj0lQ09ORklHX0RJUiVcc291cmNlcyINCnNldCAi
U0VUVElOR1NfRklMRT0lQ09ORklHX0RJUiVcc2V0dGluZ3MuaW5pIg0Kc2V0ICJTVEFURV9ESVI9
JUFCSF9ESVIlXHN0YXRlIg0Kc2V0ICJVU0VSX0xPR19ESVI9JUFCSF9ESVIlXGxvZ3NcdXNlciIN
CnNldCAiREVWX0xPR19ESVI9JUFCSF9ESVIlXGxvZ3NcZGV2Ig0Kc2V0ICJSRVBPUlRfRElSPSVB
QkhfRElSJVxyZXBvcnRzIg0Kc2V0ICJCQUNLVVBfRElSPSVBQkhfRElSJVxiYWNrdXBzIg0Kc2V0
ICJNQU5JRkVTVF9ESVI9JUFCSF9ESVIlXG1hbmlmZXN0Ig0Kc2V0ICJQUk9HUkVTU19TQ1JJUFQ9
JVNVUFBPUlRfRElSJVxwcm9ncmVzc191aS5wczEiDQpzZXQgIlBST0dSRVNTX1NUQVRFPSVTVEFU
RV9ESVIlXHByb2dyZXNzLnN0YXRlIg0Kc2V0ICJUSEVNRV9TQ1JJUFQ9JVNVUFBPUlRfRElSJVxh
c2Vwcml0ZV90aGVtZXMucHMxIg0Kc2V0ICJBRERPTl9TQ1JJUFQ9JVNVUFBPUlRfRElSJVxhc2Vw
cml0ZV9hZGRvbnMucHMxIg0Kc2V0ICJMT0NBTF9UT09MU19TQ1JJUFQ9JVNVUFBPUlRfRElSJVxh
c2Vwcml0ZV9sb2NhbF90b29scy5wczEiDQpzZXQgIlNPVVJDRV9DT05GSUdfU0NSSVBUPSVTVVBQ
T1JUX0RJUiVcc291cmNlX2NvbmZpZy5wczEiDQpzZXQgIlVQREFURV9TVEFNUD0lU1RBVEVfRElS
JVxsYXN0X2FzZXByaXRlX2NoZWNrLnR4dCINCnNldCAiVEhFTUVfU1RBTVA9JVNUQVRFX0RJUiVc
bGFzdF90aGVtZV9jaGVjay50eHQiDQpzZXQgIkFERE9OX1NUQU1QPSVTVEFURV9ESVIlXGxhc3Rf
YWRkb25fY2hlY2sudHh0Ig0Kc2V0ICJTRUxGX1NUQU1QPSVTVEFURV9ESVIlXGxhc3RfYWJoX2No
ZWNrLnR4dCINCnNldCAiU0VMRl9BVkFJTEFCTEU9JVNUQVRFX0RJUiVcYWJoLXVwZGF0ZS1hdmFp
bGFibGUudHh0Ig0Kc2V0ICJMT0c9JVVTRVJfTE9HX0RJUiVcYWJoLXVwZGF0ZXIubG9nIg0Kc2V0
ICJBQkhfREFUQV9ST09UPSVBQkhfRElSJSINCnNldCAiVVBEQVRFUl9WRVJTSU9OX0VOVj0lVVBE
QVRFUl9WRVJTSU9OJSINCg0KbWtkaXIgIiVTVEFURV9ESVIlIiAiJVVTRVJfTE9HX0RJUiUiICIl
REVWX0xPR19ESVIlIiAiJVJFUE9SVF9ESVIlIiAiJUJBQ0tVUF9ESVIlIiAiJUNPTkZJR19ESVIl
IiAiJVNPVVJDRV9DT05GSUdfRElSJSIgPm51bCAyPiYxDQoNCnNldCAiVUlfTEFORz0iDQpzZXQg
Ik1PREVfU0NIRURVTEVEPTAiDQpzZXQgIk1PREVfTEFVTkNIPTAiDQpzZXQgIk1PREVfRk9SQ0U9
MCINCmZvciAlJUEgaW4gKCUqKSBkbyAoDQogIGlmIC9JICIlJX5BIj09Ii0tc2NoZWR1bGVkIiBz
ZXQgIk1PREVfU0NIRURVTEVEPTEiDQogIGlmIC9JICIlJX5BIj09Ii0tbGF1bmNoIiBzZXQgIk1P
REVfTEFVTkNIPTEiDQogIGlmIC9JICIlJX5BIj09Ii0tZm9yY2UiIHNldCAiTU9ERV9GT1JDRT0x
Ig0KICBpZiAvSSAiJSV+QSI9PSItLWxhbmc9ZGUiIHNldCAiVUlfTEFORz1kZSINCiAgaWYgL0kg
IiUlfkEiPT0iLS1sYW5nPWVuIiBzZXQgIlVJX0xBTkc9ZW4iDQopDQppZiBub3QgZGVmaW5lZCBV
SV9MQU5HIGZvciAvZiAidXNlYmFja3EgZGVsaW1zPSIgJSVMIGluIChgcG93ZXJzaGVsbC5leGUg
LU5vTG9nbyAtTm9Qcm9maWxlIC1Db21tYW5kICIkYz0oR2V0LVVJQ3VsdHVyZSkuTmFtZTsgaWYo
JGMgLWxpa2UgJ2RlLSonKXsnZGUnfWVsc2V7J2VuJ30iYCkgZG8gc2V0ICJVSV9MQU5HPSUlTCIN
CmlmIG5vdCBkZWZpbmVkIFVJX0xBTkcgc2V0ICJVSV9MQU5HPWVuIg0KDQpjYWxsIDpsb2FkX3Nl
dHRpbmdzDQpjYWxsIDpsb2cgIlNUQVJUIHVwZGF0ZXI9JVVQREFURVJfVkVSU0lPTiUgYXJncz0l
KiINCg0KaWYgIiVNT0RFX1NDSEVEVUxFRCUiPT0iMSIgZ290byBzY2hlZHVsZWQNCmlmICIlTU9E
RV9GT1JDRSUiPT0iMSIgZ290byBmb3JjZV9hbGwNCg0KZ290byBtZW51DQoNCjpzY2hlZHVsZWQN
CnNldCAiQU5ZX0RVRT0wIg0KY2FsbCA6aXNfZHVlICIlU0VMRl9TVEFNUCUiICVVUERBVEVfSU5U
RVJWQUxfSE9VUlMlDQppZiBlcnJvcmxldmVsIDEgc2V0ICJBTllfRFVFPTEiDQpjYWxsIDppc19k
dWUgIiVVUERBVEVfU1RBTVAlIiAlVVBEQVRFX0lOVEVSVkFMX0hPVVJTJQ0KaWYgZXJyb3JsZXZl
bCAxIHNldCAiQU5ZX0RVRT0xIg0KY2FsbCA6aXNfZHVlICIlVEhFTUVfU1RBTVAlIiAlVVBEQVRF
X0lOVEVSVkFMX0hPVVJTJQ0KaWYgZXJyb3JsZXZlbCAxIHNldCAiQU5ZX0RVRT0xIg0KY2FsbCA6
aXNfZHVlICIlQURET05fU1RBTVAlIiAlVVBEQVRFX0lOVEVSVkFMX0hPVVJTJQ0KaWYgZXJyb3Js
ZXZlbCAxIHNldCAiQU5ZX0RVRT0xIg0KaWYgIiVBTllfRFVFJSI9PSIxIiAoDQogIGNhbGwgOnBy
b2dyZXNzX3N0YXJ0DQogIGNhbGwgOnByb2dyZXNzX3VwZGF0ZSA4IGNoZWNrICIxLzQiICJDaGVj
a2luZyBBQkggdXBkYXRlcy4uLiINCiAgY2FsbCA6Y2hlY2tfc2VsZl91cGRhdGUgMA0KICBjYWxs
IDpwcm9ncmVzc191cGRhdGUgMjggYXNlcHJpdGUgIjIvNCIgIkNoZWNraW5nIEFzZXByaXRlIHVw
ZGF0ZXMuLi4iDQogIGNhbGwgOmNoZWNrX2FzZXByaXRlX2lmX2R1ZQ0KICBjYWxsIDpwcm9ncmVz
c191cGRhdGUgNTggdGhlbWUgIjMvNCIgIkNoZWNraW5nIHRoZW1lcy4uLiINCiAgY2FsbCA6c3lu
Y190aGVtZXNfaWZfZHVlDQogIGNhbGwgOnByb2dyZXNzX3VwZGF0ZSA4MCBhZGRvbiAiNC80IiAi
Q2hlY2tpbmcgYWRkLW9ucyBhbmQgc2NyaXB0cy4uLiINCiAgY2FsbCA6c3luY19hZGRvbnNfaWZf
ZHVlDQogIGNhbGwgOnByb2dyZXNzX3VwZGF0ZSAxMDAgc3VjY2VzcyAiNC80IiAiVXBkYXRlIGNo
ZWNrIGNvbXBsZXRlZC4iDQogIHBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtQ29t
bWFuZCAiU3RhcnQtU2xlZXAgLU1pbGxpc2Vjb25kcyA0NTAiID5udWwgMj4mMQ0KICBjYWxsIDpw
cm9ncmVzc19zdG9wDQopDQppZiAiJU1PREVfTEFVTkNIJSI9PSIxIiBjYWxsIDpsYXVuY2hfYXNl
cHJpdGUNCmV4aXQgL2IgMA0KDQo6Zm9yY2VfYWxsDQpjYWxsIDpydW5fYWxsX3VwZGF0ZXMgMQ0K
ZXhpdCAvYiAlZXJyb3JsZXZlbCUNCg0KOm1lbnUNCmNscw0KaWYgL0kgIiVVSV9MQU5HJSI9PSJk
ZSIgKA0KIGVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09DQogZWNobyAgIEFzZXByaXRlIEJ1aWxkIFVwZGF0ZXIgdiVVUERBVEVS
X1ZFUlNJT04lDQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT0NCiBlY2hvLg0KIGVjaG8gWzFdIEFsbGUgVXBkYXRlcyBqZXR6
dCBwcsO8ZmVuDQogZWNobyBbMl0gTnVyIEFCSC1TZWxmLVVwZGF0ZSBwcsO8ZmVuDQogZWNobyBb
M10gTnVyIEFzZXByaXRlLVVwZGF0ZSBwcsO8ZmVuDQogZWNobyBbNF0gVGhlbWVzIC8gQWRkLW9u
cyAvIFNrcmlwdGUgc3luY2hyb25pc2llcmVuDQogZWNobyBbNV0gU3RhdHVzIGFuemVpZ2VuDQog
ZWNobyBbNl0gUmVwYXJhdHVyIC8gbmV1IHN5bmNocm9uaXNpZXJlbg0KIGVjaG8gWzddIFVwZGF0
ZS1JbnRlcnZhbGwgw6RuZGVybg0KIGVjaG8gWzhdIFF1ZWxsZW4tS29uZmlndXJhdGlvbmVuIMO2
ZmZuZW4NCiBlY2hvIFs5XSBBc2Vwcml0ZS1Lb25maWd1cmF0aW9uIHNpY2hlcm4NCiBlY2hvIFtB
XSBOZXVlc3RlcyBLb25maWd1cmF0aW9ucy1CYWNrdXAgd2llZGVyaGVyc3RlbGxlbg0KIGVjaG8g
W0xdIExvZ3Mgw7ZmZm5lbg0KIGVjaG8gW01dIFZvbiBBQkggdmVyd2FsdGV0ZSBEYXRlaWVuIHVu
ZCBPcmRuZXIgYW56ZWlnZW4NCiBlY2hvIFtEXSBEaWFnbm9zZXBha2V0IGbDvHIgQnVncmVwb3J0
IGVyc3RlbGxlbg0KIGVjaG8gW1JdIEJ1ZyBtZWxkZW4NCiBlY2hvIFtVXSBEZWluc3RhbGxpZXJl
bg0KIGVjaG8gWzBdIEJlZW5kZW4NCiBlY2hvLg0KIHNldCAvcCAiU0VMPUF1c3dhaGw6ICINCikg
ZWxzZSAoDQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT0NCiBlY2hvICAgQXNlcHJpdGUgQnVpbGQgVXBkYXRlciB2JVVQREFU
RVJfVkVSU0lPTiUNCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PQ0KIGVjaG8uDQogZWNobyBbMV0gQ2hlY2sgYWxsIHVwZGF0
ZXMgbm93DQogZWNobyBbMl0gQ2hlY2sgQUJIIHNlbGYtdXBkYXRlIG9ubHkNCiBlY2hvIFszXSBD
aGVjayBBc2Vwcml0ZSB1cGRhdGUgb25seQ0KIGVjaG8gWzRdIFN5bmMgdGhlbWVzIC8gYWRkLW9u
cyAvIHNjcmlwdHMNCiBlY2hvIFs1XSBTaG93IHN0YXR1cw0KIGVjaG8gWzZdIFJlcGFpciAvIHJl
c3luYw0KIGVjaG8gWzddIENoYW5nZSB1cGRhdGUgaW50ZXJ2YWwNCiBlY2hvIFs4XSBPcGVuIHNv
dXJjZSBjb25maWd1cmF0aW9ucw0KIGVjaG8gWzldIEJhY2sgdXAgQXNlcHJpdGUgY29uZmlndXJh
dGlvbg0KIGVjaG8gW0FdIFJlc3RvcmUgbmV3ZXN0IGNvbmZpZ3VyYXRpb24gYmFja3VwDQogZWNo
byBbTF0gT3BlbiBsb2dzDQogZWNobyBbTV0gU2hvdyBmaWxlcyBhbmQgZm9sZGVycyBtYW5hZ2Vk
IGJ5IEFCSA0KIGVjaG8gW0RdIEV4cG9ydCBkaWFnbm9zdGljIHBhY2thZ2UgZm9yIGEgYnVnIHJl
cG9ydA0KIGVjaG8gW1JdIFJlcG9ydCBhIGJ1Zw0KIGVjaG8gW1VdIFVuaW5zdGFsbA0KIGVjaG8g
WzBdIEV4aXQNCiBlY2hvLg0KIHNldCAvcCAiU0VMPVNlbGVjdGlvbjogIg0KKQ0KaWYgIiVTRUwl
Ij09IjAiIGV4aXQgL2IgMA0KaWYgIiVTRUwlIj09IjEiICgNCiAgY2FsbCA6cnVuX2FsbF91cGRh
dGVzIDENCiAgaWYgIiFTRUxGX1VQREFURV9TVEFSVEVEISI9PSIxIiBleGl0IC9iIDANCiAgcGF1
c2UNCiAgZ290byBtZW51DQopDQppZiAiJVNFTCUiPT0iMiIgKA0KICBjYWxsIDpjaGVja19zZWxm
X3VwZGF0ZSAxDQogIGlmICIhU0VMRl9VUERBVEVfU1RBUlRFRCEiPT0iMSIgZXhpdCAvYiAwDQog
IGNhbGwgOnBsYXlfY29tcGxldGVfc291bmQNCiAgcGF1c2UNCiAgZ290byBtZW51DQopDQppZiAi
JVNFTCUiPT0iMyIgKA0KICBjYWxsIDpwcm9ncmVzc19zdGFydA0KICBjYWxsIDpwcm9ncmVzc191
cGRhdGUgMjAgYXNlcHJpdGUgIkFzZXByaXRlIiAiQ2hlY2tpbmcgQXNlcHJpdGUgdXBkYXRlcy4u
LiINCiAgY2FsbCA6Y2hlY2tfYXNlcHJpdGVfZm9yY2UNCiAgY2FsbCA6cHJvZ3Jlc3NfdXBkYXRl
IDEwMCBzdWNjZXNzICJBc2Vwcml0ZSIgIlVwZGF0ZSBjaGVjayBjb21wbGV0ZWQuIg0KICBjYWxs
IDpwcm9ncmVzc19zdG9wDQogIGNhbGwgOnBsYXlfY29tcGxldGVfc291bmQNCiAgcGF1c2UNCiAg
Z290byBtZW51DQopDQppZiAiJVNFTCUiPT0iNCIgKA0KICBjYWxsIDpzeW5jX2FsbF9zb3VyY2Vz
X2ZvcmNlDQogIHBhdXNlDQogIGdvdG8gbWVudQ0KKQ0KaWYgIiVTRUwlIj09IjUiICgNCiAgY2Fs
bCA6c2hvd19zdGF0dXMNCiAgcGF1c2UNCiAgZ290byBtZW51DQopDQppZiAiJVNFTCUiPT0iNiIg
KA0KICBjYWxsIDpyZXBhaXINCiAgcGF1c2UNCiAgZ290byBtZW51DQopDQppZiAiJVNFTCUiPT0i
NyIgKA0KICBjYWxsIDpjb25maWd1cmVfdXBkYXRlX2ludGVydmFsDQogIHBhdXNlDQogIGdvdG8g
bWVudQ0KKQ0KaWYgIiVTRUwlIj09IjgiICgNCiAgc3RhcnQgIiIgZXhwbG9yZXIuZXhlICIlU09V
UkNFX0NPTkZJR19ESVIlIg0KICBnb3RvIG1lbnUNCikNCmlmICIlU0VMJSI9PSI5IiAoDQogIGNh
bGwgOmJhY2t1cA0KICBwYXVzZQ0KICBnb3RvIG1lbnUNCikNCmlmIC9JICIlU0VMJSI9PSJBIiAo
DQogIGNhbGwgOnJlc3RvcmUNCiAgcGF1c2UNCiAgZ290byBtZW51DQopDQppZiAvSSAiJVNFTCUi
PT0iTCIgKA0KICBzdGFydCAiIiBleHBsb3Jlci5leGUgIiVBQkhfRElSJVxsb2dzIg0KICBnb3Rv
IG1lbnUNCikNCmlmIC9JICIlU0VMJSI9PSJNIiAoDQogIGNhbGwgOnNob3dfbWFuYWdlZA0KICBw
YXVzZQ0KICBnb3RvIG1lbnUNCikNCmlmIC9JICIlU0VMJSI9PSJEIiAoDQogIGNhbGwgOmV4cG9y
dF9kaWFnbm9zdGljcw0KICBwYXVzZQ0KICBnb3RvIG1lbnUNCikNCmlmIC9JICIlU0VMJSI9PSJS
IiAoDQogIGNhbGwgOnJlcG9ydF9idWcNCiAgZ290byBtZW51DQopDQppZiAvSSAiJVNFTCUiPT0i
VSIgKA0KICBjYWxsIDpydW5fdW5pbnN0YWxsDQogIGV4aXQgL2IgMA0KKQ0KZ290byBtZW51DQpp
ZiAiJVNFTCUiPT0iMiIgY2FsbCA6Y2hlY2tfc2VsZl91cGRhdGUgMSAmIGlmICIhU0VMRl9VUERB
VEVfU1RBUlRFRCEiPT0iMSIgZXhpdCAvYiAwICYgcGF1c2UgJiBnb3RvIG1lbnUNCmlmICIlU0VM
JSI9PSIzIiBjYWxsIDpwcm9ncmVzc19zdGFydCAmIGNhbGwgOnByb2dyZXNzX3VwZGF0ZSAyMCBh
c2Vwcml0ZSAiQXNlcHJpdGUiICJDaGVja2luZyBBc2Vwcml0ZSB1cGRhdGVzLi4uIiAmIGNhbGwg
OmNoZWNrX2FzZXByaXRlX2ZvcmNlICYgY2FsbCA6cHJvZ3Jlc3NfdXBkYXRlIDEwMCBzdWNjZXNz
ICJBc2Vwcml0ZSIgIlVwZGF0ZSBjaGVjayBjb21wbGV0ZWQuIiAmIGNhbGwgOnByb2dyZXNzX3N0
b3AgJiBwYXVzZSAmIGdvdG8gbWVudQ0KaWYgIiVTRUwlIj09IjQiIGNhbGwgOnN5bmNfYWxsX3Nv
dXJjZXNfZm9yY2UgJiBwYXVzZSAmIGdvdG8gbWVudQ0KaWYgIiVTRUwlIj09IjUiIGNhbGwgOnNo
b3dfc3RhdHVzICYgcGF1c2UgJiBnb3RvIG1lbnUNCmlmICIlU0VMJSI9PSI2IiBjYWxsIDpyZXBh
aXIgJiBwYXVzZSAmIGdvdG8gbWVudQ0KaWYgIiVTRUwlIj09IjciIGNhbGwgOmNvbmZpZ3VyZV91
cGRhdGVfaW50ZXJ2YWwgJiBwYXVzZSAmIGdvdG8gbWVudQ0KaWYgIiVTRUwlIj09IjgiIHN0YXJ0
ICIiIGV4cGxvcmVyLmV4ZSAiJVNPVVJDRV9DT05GSUdfRElSJSIgJiBnb3RvIG1lbnUNCmlmICIl
U0VMJSI9PSI5IiBjYWxsIDpiYWNrdXAgJiBwYXVzZSAmIGdvdG8gbWVudQ0KaWYgL0kgIiVTRUwl
Ij09IkEiIGNhbGwgOnJlc3RvcmUgJiBwYXVzZSAmIGdvdG8gbWVudQ0KaWYgL0kgIiVTRUwlIj09
IkwiIHN0YXJ0ICIiIGV4cGxvcmVyLmV4ZSAiJUFCSF9ESVIlXGxvZ3MiICYgZ290byBtZW51DQpp
ZiAvSSAiJVNFTCUiPT0iTSIgY2FsbCA6c2hvd19tYW5hZ2VkICYgcGF1c2UgJiBnb3RvIG1lbnUN
CmlmIC9JICIlU0VMJSI9PSJEIiBjYWxsIDpleHBvcnRfZGlhZ25vc3RpY3MgJiBwYXVzZSAmIGdv
dG8gbWVudQ0KaWYgL0kgIiVTRUwlIj09IlIiIGNhbGwgOnJlcG9ydF9idWcgJiBnb3RvIG1lbnUN
CmlmIC9JICIlU0VMJSI9PSJVIiBjYWxsIDpydW5fdW5pbnN0YWxsICYgZXhpdCAvYiAwDQpnb3Rv
IG1lbnUNCg0KOnJ1bl9hbGxfdXBkYXRlcw0Kc2V0ICJJTlRFUkFDVElWRT0lfjEiDQpzZXQgIlNF
TEZfVVBEQVRFX1NUQVJURUQ9MCINCmNhbGwgOnByb2dyZXNzX3N0YXJ0DQpjYWxsIDpwcm9ncmVz
c191cGRhdGUgOCBjaGVjayAiMS80IiAiQ2hlY2tpbmcgQUJIIHVwZGF0ZXMuLi4iDQpjYWxsIDpj
aGVja19zZWxmX3VwZGF0ZSAlSU5URVJBQ1RJVkUlDQppZiAiIVNFTEZfVVBEQVRFX1NUQVJURUQh
Ij09IjEiIChjYWxsIDpwcm9ncmVzc19zdG9wICYgZXhpdCAvYiAwKQ0KY2FsbCA6cHJvZ3Jlc3Nf
dXBkYXRlIDI4IGFzZXByaXRlICIyLzQiICJDaGVja2luZyBBc2Vwcml0ZSB1cGRhdGVzLi4uIg0K
Y2FsbCA6Y2hlY2tfYXNlcHJpdGVfZm9yY2UNCmNhbGwgOnByb2dyZXNzX3VwZGF0ZSA1OCB0aGVt
ZSAiMy80IiAiQ2hlY2tpbmcgdGhlbWVzLi4uIg0KY2FsbCA6c3luY190aGVtZXNfZm9yY2UNCmNh
bGwgOnByb2dyZXNzX3VwZGF0ZSA4MCBhZGRvbiAiNC80IiAiQ2hlY2tpbmcgYWRkLW9ucyBhbmQg
c2NyaXB0cy4uLiINCmNhbGwgOnN5bmNfYWRkb25zX2ZvcmNlDQpjYWxsIDpwcm9ncmVzc191cGRh
dGUgMTAwIHN1Y2Nlc3MgIjQvNCIgIlVwZGF0ZSBjaGVjayBjb21wbGV0ZWQuIg0KcG93ZXJzaGVs
bC5leGUgLU5vTG9nbyAtTm9Qcm9maWxlIC1Db21tYW5kICJTdGFydC1TbGVlcCAtTWlsbGlzZWNv
bmRzIDQ1MCIgPm51bCAyPiYxDQpjYWxsIDpwcm9ncmVzc19zdG9wDQppZiAiJUlOVEVSQUNUSVZF
JSI9PSIxIiBjYWxsIDpwbGF5X2NvbXBsZXRlX3NvdW5kDQpleGl0IC9iIDANCg0KOmNoZWNrX3Nl
bGZfdXBkYXRlDQpzZXQgIklOVEVSQUNUSVZFPSV+MSINCnNldCAiU0VMRl9VUERBVEVfU1RBUlRF
RD0wIg0Kc2V0ICJMQVRFU1RfQUJIPSINCnNldCAiTEFURVNUX0FTU0VUPSINCnNldCAiQUJIX0NV
UlJFTlRfVkVSU0lPTj0lVVBEQVRFUl9WRVJTSU9OJSINCnNldCAiQUJIX0FQST0lQVBJX0xBVEVT
VCUiDQpmb3IgL2YgInVzZWJhY2txIHRva2Vucz0xLCogZGVsaW1zPXwiICUlQSBpbiAoYHBvd2Vy
c2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtQ29t
bWFuZCAiJEVycm9yQWN0aW9uUHJlZmVyZW5jZT0nU3RvcCc7dHJ5eyRoPUB7J1VzZXItQWdlbnQn
PSdBc2Vwcml0ZS1CdWlsZC1IZWxwZXInfTskcj1JbnZva2UtUmVzdE1ldGhvZCAtVXJpICRlbnY6
QUJIX0FQSSAtSGVhZGVycyAkaCAtVGltZW91dFNlYyAxNTskdGFnPVtzdHJpbmddJHIudGFnX25h
bWU7JHY9JHRhZy5UcmltU3RhcnQoJ3YnKTskYT0kci5hc3NldHN8V2hlcmUtT2JqZWN0eyRfLm5h
bWUgLW1hdGNoICdeYWJoLXdpbjY0LXYuKlwuemlwJCd9fFNlbGVjdC1PYmplY3QgLUZpcnN0IDE7
aWYoLW5vdCAkYSl7ZXhpdCA0fTtXcml0ZS1PdXRwdXQgKCR2Kyd8JyskYS5icm93c2VyX2Rvd25s
b2FkX3VybCl9Y2F0Y2h7ZXhpdCAzfSJgKSBkbyAoDQogIHNldCAiTEFURVNUX0FCSD0lJUEiDQog
IHNldCAiTEFURVNUX0FTU0VUPSUlQiINCikNCj4iJVNFTEZfU1RBTVAlIiBlY2hvICVkYXRlJSAl
dGltZSUNCmlmIG5vdCBkZWZpbmVkIExBVEVTVF9BQkggKA0KICBjYWxsIDpsb2cgIkFCSCBzZWxm
LXVwZGF0ZSBjaGVjayB1bmF2YWlsYWJsZS4iDQogIGlmICIlSU5URVJBQ1RJVkUlIj09IjEiICgN
CiAgICBpZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBBQkgtU2VsZi1VcGRhdGUga29ubnRl
IGRlcnplaXQgbmljaHQgZ2VwcsO8ZnQgd2VyZGVuLikgZWxzZSAoZWNobyBBQkggc2VsZi11cGRh
dGUgY291bGQgbm90IGJlIGNoZWNrZWQgcmlnaHQgbm93LikNCiAgKQ0KICBleGl0IC9iIDINCikN
CnNldCAiQUJIX0xBVEVTVF9WRVJTSU9OPSVMQVRFU1RfQUJIJSINCnBvd2Vyc2hlbGwuZXhlIC1O
b0xvZ28gLU5vUHJvZmlsZSAtQ29tbWFuZCAidHJ5e2lmKFt2ZXJzaW9uXSRlbnY6QUJIX0xBVEVT
VF9WRVJTSU9OIC1ndCBbdmVyc2lvbl0kZW52OkFCSF9DVVJSRU5UX1ZFUlNJT04pe2V4aXQgMX1l
bHNle2V4aXQgMH19Y2F0Y2h7ZXhpdCAyfSIgPm51bCAyPiYxDQpzZXQgIkNNUD0lZXJyb3JsZXZl
bCUiDQppZiAiJUNNUCUiPT0iMCIgKA0KICBkZWwgL3EgIiVTRUxGX0FWQUlMQUJMRSUiID5udWwg
Mj4mMQ0KICBjYWxsIDpsb2cgIkFCSCBpcyB1cCB0byBkYXRlOiAlVVBEQVRFUl9WRVJTSU9OJS4i
DQogIGlmICIlSU5URVJBQ1RJVkUlIj09IjEiIGlmIC9JICIlVUlfTEFORyUiPT0iZGUiIChlY2hv
IEFCSCBpc3QgYWt0dWVsbDogdiVVUERBVEVSX1ZFUlNJT04lLikgZWxzZSAoZWNobyBBQkggaXMg
dXAgdG8gZGF0ZTogdiVVUERBVEVSX1ZFUlNJT04lLikNCiAgZXhpdCAvYiAwDQopDQppZiBub3Qg
IiVDTVAlIj09IjEiIGV4aXQgL2IgMg0KPiIlU0VMRl9BVkFJTEFCTEUlIiBlY2hvICVMQVRFU1Rf
QUJIJQ0KY2FsbCA6bG9nICJBQkggdXBkYXRlIGF2YWlsYWJsZTogJUxBVEVTVF9BQkglLiINCmlm
ICIlSU5URVJBQ1RJVkUlIj09IjAiIGV4aXQgL2IgMQ0KDQppZiAvSSAiJVVJX0xBTkclIj09ImRl
IiAoDQogIGVjaG8uDQogIGVjaG8gTmV1ZSBBQkgtVmVyc2lvbiBnZWZ1bmRlbjogdiVMQVRFU1Rf
QUJIJSBeKGluc3RhbGxpZXJ0OiB2JVVQREFURVJfVkVSU0lPTiVeKQ0KICBlY2hvIERhcyBVcGRh
dGUgd2lyZCBhdXNzY2hsaWXDn2xpY2ggYXVzIGRlbSBvZmZpemllbGxlbiBHaXRIdWItUmVsZWFz
ZSBnZWxhZGVuLg0KICBlY2hvIElocmUgQUJILUtvbmZpZ3VyYXRpb25lbiwgUXVlbGxlbi1JTklz
LCBMb2dzIHVuZCBCYWNrdXBzIGJsZWliZW4gZXJoYWx0ZW4uDQogIGVjaG8gVm9yIGRlbSBBdXN0
YXVzY2ggd2VyZGVuIGRpZSBha3R1ZWxsZW4gUGFrZXRkYXRlaWVuIGdlc2ljaGVydC4NCiAgZWNo
by4NCiAgc2V0IC9wICJTRUxGQU5TPUpldHp0IGFrdHVhbGlzaWVyZW4/IFtKL05dOiAiDQogIGlm
IC9JIG5vdCAiIVNFTEZBTlMhIj09IkoiIGV4aXQgL2IgMQ0KKSBlbHNlICgNCiAgZWNoby4NCiAg
ZWNobyBOZXcgQUJIIHZlcnNpb24gZm91bmQ6IHYlTEFURVNUX0FCSCUgXihpbnN0YWxsZWQ6IHYl
VVBEQVRFUl9WRVJTSU9OJV4pDQogIGVjaG8gVGhlIHVwZGF0ZSBpcyBkb3dubG9hZGVkIG9ubHkg
ZnJvbSB0aGUgb2ZmaWNpYWwgR2l0SHViIHJlbGVhc2UuDQogIGVjaG8gWW91ciBBQkggY29uZmln
dXJhdGlvbiwgc291cmNlIElOSXMsIGxvZ3MgYW5kIGJhY2t1cHMgYXJlIHByZXNlcnZlZC4NCiAg
ZWNobyBDdXJyZW50IHBhY2thZ2UgZmlsZXMgYXJlIGJhY2tlZCB1cCBiZWZvcmUgcmVwbGFjZW1l
bnQuDQogIGVjaG8uDQogIHNldCAvcCAiU0VMRkFOUz1VcGRhdGUgbm93PyBbWS9OXTogIg0KICBp
ZiAvSSBub3QgIiFTRUxGQU5TISI9PSJZIiBleGl0IC9iIDENCikNCmNhbGwgOnBlcmZvcm1fc2Vs
Zl91cGRhdGUNCmV4aXQgL2IgJWVycm9ybGV2ZWwlDQoNCjpwZXJmb3JtX3NlbGZfdXBkYXRlDQpz
ZXQgIlNFTEZfVVBEQVRFX1NUQVJURUQ9MCINCmZvciAvZiAidXNlYmFja3EgZGVsaW1zPSIgJSVU
IGluIChgcG93ZXJzaGVsbC5leGUgLU5vTG9nbyAtTm9Qcm9maWxlIC1Db21tYW5kICJHZXQtRGF0
ZSAtRm9ybWF0ICd5eXl5TU1kZC1ISG1tc3MnImApIGRvIHNldCAiVFM9JSVUIg0Kc2V0ICJTRUxG
X1RNUD0lVEVNUCVcYWJoLXNlbGYtdXBkYXRlLSVSQU5ET00lLSVSQU5ET00lIg0Kc2V0ICJTRUxG
X1pJUD0lU0VMRl9UTVAlXHVwZGF0ZS56aXAiDQpzZXQgIlNFTEZfRVhUUkFDVD0lU0VMRl9UTVAl
XHBhY2thZ2UiDQpzZXQgIlNFTEZfQkFDS1VQPSVVUERBVEVSX0RJUiVcYmFja3VwXHYlVVBEQVRF
Ul9WRVJTSU9OJS0lVFMlIg0KbWtkaXIgIiVTRUxGX1RNUCUiICIlU0VMRl9FWFRSQUNUJSIgIiVT
RUxGX0JBQ0tVUCUiID5udWwgMj4mMQ0Kc2V0ICJBQkhfREw9JUxBVEVTVF9BU1NFVCUiDQpzZXQg
IkFCSF9aSVA9JVNFTEZfWklQJSINCnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAt
RXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtQ29tbWFuZCAiJEVycm9yQWN0aW9uUHJlZmVyZW5jZT0n
U3RvcCc7JGg9QHsnVXNlci1BZ2VudCc9J0FzZXByaXRlLUJ1aWxkLUhlbHBlcid9O0ludm9rZS1X
ZWJSZXF1ZXN0IC1VcmkgJGVudjpBQkhfREwgLUhlYWRlcnMgJGggLU91dEZpbGUgJGVudjpBQkhf
WklQIC1Vc2VCYXNpY1BhcnNpbmc7RXhwYW5kLUFyY2hpdmUgLUxpdGVyYWxQYXRoICRlbnY6QUJI
X1pJUCAtRGVzdGluYXRpb25QYXRoICclU0VMRl9FWFRSQUNUJScgLUZvcmNlOyRyZXE9QCgnYXNl
cHJpdGUtYnVpbGQtaGVscGVyLmJhdCcsJ1JFQURNRS5tZCcsJ0xJQ0VOU0UnLCdUSElSRF9QQVJU
WV9OT1RJQ0VTLm1kJyk7Zm9yZWFjaCgkbiBpbiAkcmVxKXtpZigtbm90KFRlc3QtUGF0aCAtTGl0
ZXJhbFBhdGggKEpvaW4tUGF0aCAnJVNFTEZfRVhUUkFDVCUnICRuKSkpe3Rocm93ICgnTWlzc2lu
ZyBwYWNrYWdlIGZpbGU6ICcrJG4pfX0iID4+IiVMT0clIiAyPiYxDQppZiBlcnJvcmxldmVsIDEg
KA0KICBpZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBGRUhMRVI6IEFCSC1VcGRhdGUga29u
bnRlIG5pY2h0IGhlcnVudGVyZ2VsYWRlbiBvZGVyIGdlcHLDvGZ0IHdlcmRlbi4pIGVsc2UgKGVj
aG8gRVJST1I6IEFCSCB1cGRhdGUgY291bGQgbm90IGJlIGRvd25sb2FkZWQgb3IgdmFsaWRhdGVk
LikNCiAgcm1kaXIgL3MgL3EgIiVTRUxGX1RNUCUiID5udWwgMj4mMQ0KICBleGl0IC9iIDENCikN
CmZvciAlJUYgaW4gKGFzZXByaXRlLWJ1aWxkLWhlbHBlci5iYXQgUkVBRE1FLm1kIExJQ0VOU0Ug
VEhJUkRfUEFSVFlfTk9USUNFUy5tZCkgZG8gaWYgZXhpc3QgIiVQUk9KRUNUX0RJUiVcJSVGIiBj
b3B5IC95ICIlUFJPSkVDVF9ESVIlXCUlRiIgIiVTRUxGX0JBQ0tVUCVcJSVGIiA+bnVsDQpzZXQg
IkFQUExZX1BTPSVTRUxGX1RNUCVcYXBwbHktdXBkYXRlLnBzMSINCmlmIG5vdCBleGlzdCAiJVNV
UFBPUlRfRElSJVxzZWxmX3VwZGF0ZV9hcHBseS5wczEiICgNCiAgaWYgL0kgIiVVSV9MQU5HJSI9
PSJkZSIgKGVjaG8gRkVITEVSOiBJbnRlcm5lIFNlbGYtVXBkYXRlLUtvbXBvbmVudGUgZmVobHQu
KSBlbHNlIChlY2hvIEVSUk9SOiBJbnRlcm5hbCBzZWxmLXVwZGF0ZSBjb21wb25lbnQgaXMgbWlz
c2luZy4pDQogIGV4aXQgL2IgMQ0KKQ0KY29weSAveSAiJVNVUFBPUlRfRElSJVxzZWxmX3VwZGF0
ZV9hcHBseS5wczEiICIlQVBQTFlfUFMlIiA+bnVsDQppZiBlcnJvcmxldmVsIDEgZXhpdCAvYiAx
DQpzdGFydCAiIiBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLVdpbmRvd1N0eWxl
IEhpZGRlbiAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtRmlsZSAiJUFQUExZX1BTJSIgLVByb2pl
Y3QgIiVQUk9KRUNUX0RJUiUiIC1OZXcgIiVTRUxGX0VYVFJBQ1QlIiAtQmFja3VwICIlU0VMRl9C
QUNLVVAlIiAtTGFuZyAiJVVJX0xBTkclIg0Kc2V0ICJTRUxGX1VQREFURV9TVEFSVEVEPTEiDQpp
ZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBBQkgtVXBkYXRlIHdpcmQgYW5nZXdlbmRldC4g
RGVyIFVwZGF0ZXIgc3RhcnRldCBhbnNjaGxpZcOfZW5kIG5ldS4pIGVsc2UgKGVjaG8gQUJIIHVw
ZGF0ZSBpcyBiZWluZyBhcHBsaWVkLiBUaGUgdXBkYXRlciB3aWxsIHJlc3RhcnQgYWZ0ZXJ3YXJk
cy4pDQpleGl0IC9iIDANCg0KOmNoZWNrX2FzZXByaXRlX2lmX2R1ZQ0KY2FsbCA6aXNfZHVlICIl
VVBEQVRFX1NUQU1QJSIgJVVQREFURV9JTlRFUlZBTF9IT1VSUyUNCmlmIG5vdCBlcnJvcmxldmVs
IDEgZXhpdCAvYiAwDQpjYWxsIDpjaGVja19hc2Vwcml0ZV9mb3JjZQ0KZXhpdCAvYiAlZXJyb3Js
ZXZlbCUNCg0KOmNoZWNrX2FzZXByaXRlX2ZvcmNlDQppZiBub3QgZXhpc3QgIiVCVUlMREVSJSIg
ZXhpdCAvYiAyDQpkZWwgL3EgIiVVUERBVEVfU1RBTVAlIiA+bnVsIDI+JjENCmNhbGwgIiVCVUlM
REVSJSIgLS1hc2Vwcml0ZS11cGRhdGUgLS1sYW5nPSVVSV9MQU5HJQ0KZXhpdCAvYiAlZXJyb3Js
ZXZlbCUNCg0KOnN5bmNfdGhlbWVzX2lmX2R1ZQ0KY2FsbCA6aXNfZHVlICIlVEhFTUVfU1RBTVAl
IiAlVVBEQVRFX0lOVEVSVkFMX0hPVVJTJQ0KaWYgbm90IGVycm9ybGV2ZWwgMSBleGl0IC9iIDAN
CmNhbGwgOnN5bmNfdGhlbWVzX2ZvcmNlDQpleGl0IC9iIDANCg0KOnN5bmNfYWRkb25zX2lmX2R1
ZQ0KY2FsbCA6aXNfZHVlICIlQURET05fU1RBTVAlIiAlVVBEQVRFX0lOVEVSVkFMX0hPVVJTJQ0K
aWYgbm90IGVycm9ybGV2ZWwgMSBleGl0IC9iIDANCmNhbGwgOnN5bmNfYWRkb25zX2ZvcmNlDQpl
eGl0IC9iIDANCg0KOnN5bmNfdGhlbWVzX2ZvcmNlDQppZiBub3QgZXhpc3QgIiVUSEVNRV9TQ1JJ
UFQlIiBleGl0IC9iIDANCnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtRXhlY3V0
aW9uUG9saWN5IEJ5cGFzcyAtRmlsZSAiJVRIRU1FX1NDUklQVCUiID4+IiVMT0clIiAyPiYxDQpp
ZiBub3QgZXJyb3JsZXZlbCAxID4iJVRIRU1FX1NUQU1QJSIgZWNobyAlZGF0ZSUgJXRpbWUlDQpl
eGl0IC9iIDANCg0KOnN5bmNfYWRkb25zX2ZvcmNlDQppZiBub3QgZXhpc3QgIiVBRERPTl9TQ1JJ
UFQlIiBleGl0IC9iIDANCnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtRXhlY3V0
aW9uUG9saWN5IEJ5cGFzcyAtRmlsZSAiJUFERE9OX1NDUklQVCUiID4+IiVMT0clIiAyPiYxDQpp
ZiBub3QgZXJyb3JsZXZlbCAxID4iJUFERE9OX1NUQU1QJSIgZWNobyAlZGF0ZSUgJXRpbWUlDQpl
eGl0IC9iIDANCg0KOnN5bmNfYWxsX3NvdXJjZXNfZm9yY2UNCmNhbGwgOnByb2dyZXNzX3N0YXJ0
DQpjYWxsIDpwcm9ncmVzc191cGRhdGUgMjAgdGhlbWUgIjEvMiIgIkNoZWNraW5nIHRoZW1lcy4u
LiINCmNhbGwgOnN5bmNfdGhlbWVzX2ZvcmNlDQpjYWxsIDpwcm9ncmVzc191cGRhdGUgNjUgYWRk
b24gIjIvMiIgIkNoZWNraW5nIGFkZC1vbnMgYW5kIHNjcmlwdHMuLi4iDQpjYWxsIDpzeW5jX2Fk
ZG9uc19mb3JjZQ0KaWYgZXhpc3QgIiVMT0NBTF9UT09MU19TQ1JJUFQlIiBwb3dlcnNoZWxsLmV4
ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLVdpbmRvd1N0eWxlIEhpZGRlbiAtRXhlY3V0aW9uUG9saWN5
IEJ5cGFzcyAtRmlsZSAiJUxPQ0FMX1RPT0xTX1NDUklQVCUiID4+IiVMT0clIiAyPiYxDQpjYWxs
IDpwcm9ncmVzc191cGRhdGUgMTAwIHN1Y2Nlc3MgIjIvMiIgIlN5bmNocm9uaXphdGlvbiBjb21w
bGV0ZWQuIg0KY2FsbCA6cHJvZ3Jlc3Nfc3RvcA0KY2FsbCA6cGxheV9jb21wbGV0ZV9zb3VuZA0K
ZXhpdCAvYiAwDQoNCjpyZXBhaXINCmlmIGV4aXN0ICIlU09VUkNFX0NPTkZJR19TQ1JJUFQlIiBw
b3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLUV4ZWN1dGlvblBvbGljeSBCeXBhc3Mg
LUZpbGUgIiVTT1VSQ0VfQ09ORklHX1NDUklQVCUiIC1Sb290ICIlU09VUkNFX0NPTkZJR19ESVIl
IiA+PiIlTE9HJSIgMj4mMQ0KaWYgZXhpc3QgIiVMT0NBTF9UT09MU19TQ1JJUFQlIiBwb3dlcnNo
ZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLVdpbmRvd1N0eWxlIEhpZGRlbiAtRXhlY3V0aW9u
UG9saWN5IEJ5cGFzcyAtRmlsZSAiJUxPQ0FMX1RPT0xTX1NDUklQVCUiID4+IiVMT0clIiAyPiYx
DQpjYWxsIDpzeW5jX3RoZW1lc19mb3JjZQ0KY2FsbCA6c3luY19hZGRvbnNfZm9yY2UNCmlmIGV4
aXN0ICIlQlVJTERFUiUiIGNhbGwgIiVCVUlMREVSJSIgLS1yZWZyZXNoLXJ1bnRpbWUgLS1sYW5n
PSVVSV9MQU5HJQ0KaWYgL0kgIiVVSV9MQU5HJSI9PSJkZSIgKGVjaG8gUmVwYXJhdHVyIGFiZ2Vz
Y2hsb3NzZW4uKSBlbHNlIChlY2hvIFJlcGFpciBjb21wbGV0ZWQuKQ0KY2FsbCA6cGxheV9jb21w
bGV0ZV9zb3VuZA0KZXhpdCAvYiAwDQoNCjpzaG93X3N0YXR1cw0KY2FsbCA6bG9hZF9zZXR0aW5n
cw0KZWNoby4NCmVjaG8gQUJIIC8gVXBkYXRlciB2ZXJzaW9uOiAlVVBEQVRFUl9WRVJTSU9OJQ0K
ZWNobyBQcm9qZWN0IGZvbGRlcjogJVBST0pFQ1RfRElSJQ0KZWNobyBBQkggZGF0YTogJUFCSF9E
SVIlDQplY2hvIFVwZGF0ZSBpbnRlcnZhbDogJVVQREFURV9JTlRFUlZBTF9IT1VSUyUgaG91cnMN
CmlmIGV4aXN0ICIlRVhFJSIgKGVjaG8gQXNlcHJpdGU6IE9LKSBlbHNlIChlY2hvIEFzZXByaXRl
OiBNSVNTSU5HKQ0Kc2V0ICJDVVJUQUc9dW5rbm93biINCmlmIGV4aXN0ICIlUk9PVCVcLmdpdCIg
Zm9yIC9mICJkZWxpbXM9IiAlJVQgaW4gKCdnaXQgLUMgIiVST09UJSIgZGVzY3JpYmUgLS10YWdz
IC0tZXhhY3QtbWF0Y2ggSEVBRCAyXj5udWwnKSBkbyBzZXQgIkNVUlRBRz0lJVQiDQplY2hvIEFz
ZXByaXRlIHRhZzogIUNVUlRBRyENCmlmIGV4aXN0ICIlU0VMRl9BVkFJTEFCTEUlIiAoc2V0IC9w
IEFWQUlMPTwiJVNFTEZfQVZBSUxBQkxFJSIgJiBlY2hvIEFCSCB1cGRhdGUgYXZhaWxhYmxlOiB2
IUFWQUlMISkgZWxzZSAoZWNobyBBQkggc2VsZi11cGRhdGU6IG5vIGtub3duIHBlbmRpbmcgdXBk
YXRlKQ0KZWNobyBMb2dzOiAlQUJIX0RJUiVcbG9ncw0KZXhpdCAvYiAwDQoNCjpzaG93X21hbmFn
ZWQNCmlmIC9JICIlVUlfTEFORyUiPT0iZGUiICgNCiBlY2hvLg0KIGVjaG8gQUJILWVpZ2VuZSBC
ZXJlaWNoZToNCikgZWxzZSAoDQogZWNoby4NCiBlY2hvIEFCSC1vd25lZCBsb2NhdGlvbnM6DQop
DQplY2hvICAgJUFCSF9ESVIlDQplY2hvICAgTGF1bmNoZXI6ICVBQkhfRElSJVxsYXVuY2hlcg0K
ZWNobyAgIFVwZGF0ZXI6ICVBQkhfRElSJVx1cGRhdGVyDQplY2hvICAgVW5pbnN0YWxsZXI6ICVB
QkhfRElSJVx1bmluc3RhbGxlcg0KZWNobyAgIFNvdXJjZSBjb25maWd1cmF0aW9uczogJVNPVVJD
RV9DT05GSUdfRElSJQ0KZWNobyAgIEFzZXByaXRlIHNvdXJjZS9idWlsZDogJVJPT1QlDQplY2hv
ICAgTWFuYWdlZCB0aGVtZXM6ICVBQkhfRElSJVxtYW5hZ2VkXHRoZW1lcw0KZWNobyAgIE1hbmFn
ZWQgYWRkLW9uczogJUFCSF9ESVIlXG1hbmFnZWRcYWRkb25zDQplY2hvICAgTWFuYWdlZCBzY3Jp
cHRzOiAlQVBQREFUQSVcQXNlcHJpdGVcc2NyaXB0c1xhdXRvLW1hbmFnZWQNCmV4aXQgL2IgMA0K
DQo6bG9hZF9zZXR0aW5ncw0Kc2V0ICJVUERBVEVfSU5URVJWQUxfSE9VUlM9MTIiDQppZiBub3Qg
ZXhpc3QgIiVTRVRUSU5HU19GSUxFJSIgKA0KID4iJVNFVFRJTkdTX0ZJTEUlIiBlY2hvIDsgQXNl
cHJpdGUgQnVpbGQgSGVscGVyIHNldHRpbmdzDQogPj4iJVNFVFRJTkdTX0ZJTEUlIiBlY2hvIFtH
ZW5lcmFsXQ0KID4+IiVTRVRUSU5HU19GSUxFJSIgZWNobyB1cGRhdGVfaW50ZXJ2YWxfaG91cnM9
MTINCikNCmZvciAvZiAidXNlYmFja3EgdG9rZW5zPTEsKiBkZWxpbXM9PSIgJSVBIGluICgiJVNF
VFRJTkdTX0ZJTEUlIikgZG8gaWYgL0kgIiUlfkEiPT0idXBkYXRlX2ludGVydmFsX2hvdXJzIiBz
ZXQgIlVQREFURV9JTlRFUlZBTF9IT1VSUz0lJX5CIg0KZm9yIC9mICJkZWxpbXM9MDEyMzQ1Njc4
OSIgJSVYIGluICgiJVVQREFURV9JTlRFUlZBTF9IT1VSUyUiKSBkbyBzZXQgIlVQREFURV9JTlRF
UlZBTF9IT1VSUz0xMiINCmlmIG5vdCBkZWZpbmVkIFVQREFURV9JTlRFUlZBTF9IT1VSUyBzZXQg
IlVQREFURV9JTlRFUlZBTF9IT1VSUz0xMiINCmlmICVVUERBVEVfSU5URVJWQUxfSE9VUlMlIExT
UyAxIHNldCAiVVBEQVRFX0lOVEVSVkFMX0hPVVJTPTEiDQpleGl0IC9iIDANCg0KOmNvbmZpZ3Vy
ZV91cGRhdGVfaW50ZXJ2YWwNCmNhbGwgOmxvYWRfc2V0dGluZ3MNCnNldCAiTkVXSU5UPSINCmNs
cw0KaWYgL0kgIiVVSV9MQU5HJSI9PSJkZSIgKA0KIGVjaG8gPT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogZWNobyAgIFVQREFURS1J
TlRFUlZBTEwNCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PQ0KIGVjaG8gQWt0dWVsbDogJVVQREFURV9JTlRFUlZBTF9IT1VS
UyUgU3R1bmRlbg0KIGVjaG8uDQogZWNobyBbMV0gMSBTdHVuZGUNCiBlY2hvIFsyXSAzIFN0dW5k
ZW4NCiBlY2hvIFszXSA2IFN0dW5kZW4NCiBlY2hvIFs0XSAxMiBTdHVuZGVuIF4oU3RhbmRhcmRe
KQ0KIGVjaG8gWzVdIDI0IFN0dW5kZW4NCiBlY2hvIFs2XSBCZW51dHplcmRlZmluaWVydA0KIGVj
aG8gWzBdIEFiYnJlY2hlbg0KIHNldCAvcCAiSU5UU0VMPUF1c3dhaGw6ICINCikgZWxzZSAoDQog
ZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT0NCiBlY2hvICAgVVBEQVRFIElOVEVSVkFMDQogZWNobyA9PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiBlY2hvIEN1cnJl
bnQ6ICVVUERBVEVfSU5URVJWQUxfSE9VUlMlIGhvdXJzDQogZWNoby4NCiBlY2hvIFsxXSAxIGhv
dXINCiBlY2hvIFsyXSAzIGhvdXJzDQogZWNobyBbM10gNiBob3Vycw0KIGVjaG8gWzRdIDEyIGhv
dXJzIF4oZGVmYXVsdF4pDQogZWNobyBbNV0gMjQgaG91cnMNCiBlY2hvIFs2XSBDdXN0b20NCiBl
Y2hvIFswXSBDYW5jZWwNCiBzZXQgL3AgIklOVFNFTD1TZWxlY3Rpb246ICINCikNCmlmICIlSU5U
U0VMJSI9PSIwIiBleGl0IC9iIDANCmlmICIlSU5UU0VMJSI9PSIxIiBzZXQgIk5FV0lOVD0xIg0K
aWYgIiVJTlRTRUwlIj09IjIiIHNldCAiTkVXSU5UPTMiDQppZiAiJUlOVFNFTCUiPT0iMyIgc2V0
ICJORVdJTlQ9NiINCmlmICIlSU5UU0VMJSI9PSI0IiBzZXQgIk5FV0lOVD0xMiINCmlmICIlSU5U
U0VMJSI9PSI1IiBzZXQgIk5FV0lOVD0yNCINCmlmICIlSU5UU0VMJSI9PSI2IiBpZiAvSSAiJVVJ
X0xBTkclIj09ImRlIiAoc2V0IC9wICJORVdJTlQ9SW50ZXJ2YWxsIGluIFN0dW5kZW4gXihtaW5k
ZXN0ZW5zIDFeKTogIikgZWxzZSAoc2V0IC9wICJORVdJTlQ9SW50ZXJ2YWwgaW4gaG91cnMgXiht
aW5pbXVtIDFeKTogIikNCmlmIG5vdCBkZWZpbmVkIE5FV0lOVCBleGl0IC9iIDENCmZvciAvZiAi
ZGVsaW1zPTAxMjM0NTY3ODkiICUlWCBpbiAoIiVORVdJTlQlIikgZG8gc2V0ICJORVdJTlQ9Ig0K
aWYgbm90IGRlZmluZWQgTkVXSU5UIGV4aXQgL2IgMQ0KaWYgJU5FV0lOVCUgTFNTIDEgc2V0ICJO
RVdJTlQ9MSINCj4iJVNFVFRJTkdTX0ZJTEUlIiBlY2hvIDsgQXNlcHJpdGUgQnVpbGQgSGVscGVy
IHNldHRpbmdzDQo+PiIlU0VUVElOR1NfRklMRSUiIGVjaG8gW0dlbmVyYWxdDQo+PiIlU0VUVElO
R1NfRklMRSUiIGVjaG8gdXBkYXRlX2ludGVydmFsX2hvdXJzPSVORVdJTlQlDQpjYWxsIDpsb2Fk
X3NldHRpbmdzDQppZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBVcGRhdGUtSW50ZXJ2YWxs
IGF1ZiAlVVBEQVRFX0lOVEVSVkFMX0hPVVJTJSBTdHVuZGVuIGdlc2V0enQuKSBlbHNlIChlY2hv
IFVwZGF0ZSBpbnRlcnZhbCBzZXQgdG8gJVVQREFURV9JTlRFUlZBTF9IT1VSUyUgaG91cnMuKQ0K
ZXhpdCAvYiAwDQoNCjppc19kdWUNCmlmIG5vdCBleGlzdCAiJX4xIiBleGl0IC9iIDENCnBvd2Vy
c2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtQ29t
bWFuZCAiJGFnZT0oR2V0LURhdGUpLShHZXQtSXRlbSAtTGl0ZXJhbFBhdGggJyV+MScpLkxhc3RX
cml0ZVRpbWU7IGlmKCRhZ2UuVG90YWxIb3VycyAtbHQgJX4yKXtleGl0IDB9ZWxzZXtleGl0IDF9
IiA+bnVsIDI+JjENCmV4aXQgL2IgJWVycm9ybGV2ZWwlDQoNCjpiYWNrdXANCmlmIG5vdCBleGlz
dCAiJUFQUERBVEElXEFzZXByaXRlIiAoDQogaWYgL0kgIiVVSV9MQU5HJSI9PSJkZSIgKGVjaG8g
S2VpbmUgQXNlcHJpdGUtS29uZmlndXJhdGlvbiBnZWZ1bmRlbi4pIGVsc2UgKGVjaG8gTm8gQXNl
cHJpdGUgY29uZmlndXJhdGlvbiB3YXMgZm91bmQuKQ0KIGV4aXQgL2IgMQ0KKQ0KZm9yIC9mICJ1
c2ViYWNrcSBkZWxpbXM9IiAlJVQgaW4gKGBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2Zp
bGUgLUNvbW1hbmQgIkdldC1EYXRlIC1Gb3JtYXQgJ3l5eXlNTWRkLUhIbW1zcyciYCkgZG8gc2V0
ICJUUz0lJVQiDQpzZXQgIkRFU1Q9JUJBQ0tVUF9ESVIlXCVUUyVcQXNlcHJpdGUiDQpta2RpciAi
JURFU1QlIiA+bnVsIDI+JjENCnJvYm9jb3B5ICIlQVBQREFUQSVcQXNlcHJpdGUiICIlREVTVCUi
IC9NSVIgL1I6MSAvVzoxID5udWwNCmlmIC9JICIlVUlfTEFORyUiPT0iZGUiIChlY2hvIEJhY2t1
cCBlcnN0ZWxsdDogJURFU1QlKSBlbHNlIChlY2hvIEJhY2t1cCBjcmVhdGVkOiAlREVTVCUpDQpl
eGl0IC9iIDANCg0KOnJlc3RvcmUNCnNldCAiTEFURVNUX0JBQ0tVUD0iDQpmb3IgL2YgImRlbGlt
cz0iICUlRCBpbiAoJ2RpciAvYiAvYWQgL28tbiAiJUJBQ0tVUF9ESVIlIiAyXj5udWwnKSBkbyBp
ZiBub3QgZGVmaW5lZCBMQVRFU1RfQkFDS1VQIHNldCAiTEFURVNUX0JBQ0tVUD0lQkFDS1VQX0RJ
UiVcJSVEXEFzZXByaXRlIg0KaWYgbm90IGRlZmluZWQgTEFURVNUX0JBQ0tVUCAoDQogaWYgL0kg
IiVVSV9MQU5HJSI9PSJkZSIgKGVjaG8gS2VpbiBCYWNrdXAgZ2VmdW5kZW4uKSBlbHNlIChlY2hv
IE5vIGJhY2t1cCBmb3VuZC4pDQogZXhpdCAvYiAxDQopDQpjYWxsIDpiYWNrdXAgPm51bCAyPiYx
DQpta2RpciAiJUFQUERBVEElXEFzZXByaXRlIiA+bnVsIDI+JjENCnJvYm9jb3B5ICIlTEFURVNU
X0JBQ0tVUCUiICIlQVBQREFUQSVcQXNlcHJpdGUiIC9NSVIgL1I6MSAvVzoxID5udWwNCmlmIC9J
ICIlVUlfTEFORyUiPT0iZGUiIChlY2hvIFdpZWRlcmhlcmdlc3RlbGx0OiAlTEFURVNUX0JBQ0tV
UCUpIGVsc2UgKGVjaG8gUmVzdG9yZWQ6ICVMQVRFU1RfQkFDS1VQJSkNCmV4aXQgL2IgMA0KDQo6
ZXhwb3J0X2RpYWdub3N0aWNzDQpmb3IgL2YgInVzZWJhY2txIGRlbGltcz0iICUlVCBpbiAoYHBv
d2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtQ29tbWFuZCAiR2V0LURhdGUgLUZvcm1h
dCAneXl5eU1NZGQtSEhtbXNzJyJgKSBkbyBzZXQgIlRTPSUlVCINCnNldCAiT1VUPSVSRVBPUlRf
RElSJVxhYmgtZGlhZ25vc3RpY3MtJVRTJS56aXAiDQpzZXQgIkFCSF9ESUFHX09VVD0lT1VUJSIN
CnNldCAiQUJIX0RJQUdfUk9PVD0lQUJIX0RJUiUiDQpzZXQgIkFCSF9ESUFHX1BST0pFQ1Q9JVBS
T0pFQ1RfRElSJSINCnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtRXhlY3V0aW9u
UG9saWN5IEJ5cGFzcyAtQ29tbWFuZCAiJHRtcD1Kb2luLVBhdGggJGVudjpURU1QICgnYWJoLWRp
YWctJytbZ3VpZF06Ok5ld0d1aWQoKSk7TmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtRm9y
Y2UgLVBhdGggJHRtcHxPdXQtTnVsbDskaG9tZT0kZW52OlVTRVJQUk9GSUxFO2ZvcmVhY2goJHN1
YiBpbiBAKCdsb2dzXFx1c2VyJywnbG9nc1xcZGV2Jywnc3RhdGUnKSl7JHNyYz1Kb2luLVBhdGgg
JGVudjpBQkhfRElBR19ST09UICRzdWI7aWYoVGVzdC1QYXRoICRzcmMpeyRkc3Q9Sm9pbi1QYXRo
ICR0bXAgKCRzdWIgLXJlcGxhY2UgJ1xcJywnLScpO05ldy1JdGVtIC1JdGVtVHlwZSBEaXJlY3Rv
cnkgLUZvcmNlIC1QYXRoICRkc3R8T3V0LU51bGw7R2V0LUNoaWxkSXRlbSAkc3JjIC1GaWxlIC1F
cnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlfEZvckVhY2gtT2JqZWN0eyR0eHQ9R2V0LUNvbnRl
bnQgJF8uRnVsbE5hbWUgLVJhdyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTskdHh0PSR0
eHQgLXJlcGxhY2UgW3JlZ2V4XTo6RXNjYXBlKCRob21lKSwnQzpcXFVzZXJzXFw8VVNFUj4nOyR0
eHQ9JHR4dCAtcmVwbGFjZSAnKD9pKShhdXRob3JpemF0aW9ufGJlYXJlcnx0b2tlbnxwYXNzd29y
ZHxzZWNyZXQpXHMqWzo9XVxzKlxTKycsJyQxPTxSRURBQ1RFRD4nO1NldC1Db250ZW50IC1MaXRl
cmFsUGF0aCAoSm9pbi1QYXRoICRkc3QgJF8uTmFtZSkgLVZhbHVlICR0eHQgLUVuY29kaW5nIFVU
Rjh9fX07QCgnQUJIIHZlcnNpb246ICcrJGVudjpVUERBVEVSX1ZFUlNJT05fRU5WLCdXaW5kb3dz
OiAnK1tFbnZpcm9ubWVudF06Ok9TVmVyc2lvbi5WZXJzaW9uU3RyaW5nLCdBcmNoaXRlY3R1cmU6
ICcrJGVudjpQUk9DRVNTT1JfQVJDSElURUNUVVJFLCdVSSBjdWx0dXJlOiAnKyhHZXQtVUlDdWx0
dXJlKS5OYW1lKXxTZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggKEpvaW4tUGF0aCAkdG1wICdlbnZp
cm9ubWVudC50eHQnKSAtRW5jb2RpbmcgVVRGODtDb21wcmVzcy1BcmNoaXZlIC1QYXRoICgkdG1w
KydcXConKSAtRGVzdGluYXRpb25QYXRoICRlbnY6QUJIX0RJQUdfT1VUIC1Gb3JjZTtSZW1vdmUt
SXRlbSAkdG1wIC1SZWN1cnNlIC1Gb3JjZSIgPm51bCAyPiYxDQppZiBleGlzdCAiJU9VVCUiICgN
CiBpZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBEaWFnbm9zZXBha2V0IGVyc3RlbGx0OiAl
T1VUJSkgZWxzZSAoZWNobyBEaWFnbm9zdGljIHBhY2thZ2UgY3JlYXRlZDogJU9VVCUpDQogc3Rh
cnQgIiIgZXhwbG9yZXIuZXhlIC9zZWxlY3QsIiVPVVQlIg0KIGV4aXQgL2IgMA0KKQ0KZXhpdCAv
YiAxDQoNCjpyZXBvcnRfYnVnDQpjYWxsIDpleHBvcnRfZGlhZ25vc3RpY3MgPm51bCAyPiYxDQpz
dGFydCAiIiAiJVBST0pFQ1RfVVJMJS9pc3N1ZXMvbmV3Ig0KZXhpdCAvYiAwDQoNCjpydW5fdW5p
bnN0YWxsDQppZiBub3QgZXhpc3QgIiVVTklOU1RBTExFUiUiICgNCiBpZiAvSSAiJVVJX0xBTkcl
Ij09ImRlIiAoZWNobyBVbmluc3RhbGxlciBmZWhsdC4gQml0dGUgenVlcnN0IFJlcGFyYXR1ciBh
dXNmw7xocmVuLikgZWxzZSAoZWNobyBVbmluc3RhbGxlciBpcyBtaXNzaW5nLiBSdW4gUmVwYWly
IGZpcnN0LikNCiBleGl0IC9iIDENCikNCnNldCAiVEVNUF9VTklOU1RBTExFUj0lVEVNUCVcQUJI
LXVuaW5zdGFsbC0lUkFORE9NJS0lUkFORE9NJS5iYXQiDQpjb3B5IC95ICIlVU5JTlNUQUxMRVIl
IiAiJVRFTVBfVU5JTlNUQUxMRVIlIiA+bnVsIDI+JjENCmlmIG5vdCBleGlzdCAiJVRFTVBfVU5J
TlNUQUxMRVIlIiBleGl0IC9iIDENCnN0YXJ0ICJBc2Vwcml0ZSBCdWlsZCBIZWxwZXIgVW5pbnN0
YWxsZXIiIGNtZC5leGUgL2QgL2MgIiIlVEVNUF9VTklOU1RBTExFUiUiIC0tbGFuZz0lVUlfTEFO
RyUiDQpleGl0IC9iIDANCg0KOnBsYXlfY29tcGxldGVfc291bmQNCnBvd2Vyc2hlbGwuZXhlIC1O
b0xvZ28gLU5vUHJvZmlsZSAtV2luZG93U3R5bGUgSGlkZGVuIC1Db21tYW5kICJ0cnkgeyBbU3lz
dGVtLk1lZGlhLlN5c3RlbVNvdW5kc106OkFzdGVyaXNrLlBsYXkoKTsgU3RhcnQtU2xlZXAgLU1p
bGxpc2Vjb25kcyA2NTAgfSBjYXRjaCB7fSIgPm51bCAyPiYxDQpleGl0IC9iIDANCg0KOnByb2dy
ZXNzX3N0YXJ0DQpyZW0gdjEuMi45OiBpbnRlcmFjdGl2ZSBwcm9ncmVzcyBzdGF5cyBpbiB0aGlz
IENNRCB3aW5kb3cuDQpleGl0IC9iIDANCg0KOnByb2dyZXNzX3VwZGF0ZQ0Kc2V0ICJBQkhfUENU
PSV+MSINCnNldCAiQUJIX1BIQVNFPSV+MiINCnNldCAiQUJIX1NURVA9JX4zIg0Kc2V0ICJBQkhf
TVNHPSV+NCINCnNldCAiQUJIX0NPTE9SPUN5YW4iDQppZiAvSSAiJUFCSF9QSEFTRSUiPT0idGhl
bWUiIHNldCAiQUJIX0NPTE9SPU1hZ2VudGEiDQppZiAvSSAiJUFCSF9QSEFTRSUiPT0iYWRkb24i
IHNldCAiQUJIX0NPTE9SPUdyZWVuIg0KaWYgL0kgIiVBQkhfUEhBU0UlIj09InN1Y2Nlc3MiIHNl
dCAiQUJIX0NPTE9SPUdyZWVuIg0KaWYgL0kgIiVBQkhfUEhBU0UlIj09ImJ1aWxkIiBzZXQgIkFC
SF9DT0xPUj1ZZWxsb3ciDQppZiAvSSAiJUFCSF9QSEFTRSUiPT0id2FybmluZyIgc2V0ICJBQkhf
Q09MT1I9WWVsbG93Ig0KaWYgL0kgIiVBQkhfUEhBU0UlIj09ImVycm9yIiBzZXQgIkFCSF9DT0xP
Uj1SZWQiDQppZiAiJU1PREVfU0NIRURVTEVEJSI9PSIwIiBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dv
IC1Ob1Byb2ZpbGUgLUNvbW1hbmQgIldyaXRlLUhvc3QgKCdbJyskZW52OkFCSF9TVEVQKyddICcr
JGVudjpBQkhfTVNHKSAtRm9yZWdyb3VuZENvbG9yICRlbnY6QUJIX0NPTE9SIiAyPm51bA0KZXhp
dCAvYiAwDQoNCjpwcm9ncmVzc19zdG9wDQpleGl0IC9iIDANCg0KOmxhdW5jaF9hc2Vwcml0ZQ0K
aWYgZXhpc3QgIiVFWEUlIiBzdGFydCAiIiAiJUVYRSUiDQpleGl0IC9iIDANCg0KOmxvZw0KPj4i
JUxPRyUiIGVjaG8gWyVkYXRlJSAldGltZSVdICV+MQ0KZXhpdCAvYiAwDQo=
###END:aseprite-build-updater.bat.b64###
