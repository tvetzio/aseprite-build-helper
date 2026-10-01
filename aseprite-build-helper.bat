@echo off
chcp 65001 >nul
@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Aseprite Build Helper (ABH)
rem Author/maintainer: Etzio
rem Project: https://github.com/tvetzio/aseprite-build-helper
rem
rem ABH does not contain or distribute a compiled copy of Aseprite.
rem Aseprite is cloned from the official repository and compiled locally.
rem ============================================================================

set "HELPER_VERSION=1.3.10"
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
set "TOOLS_DIR=%ABH_DIR%\tools"
set "PORTABLE_GIT_DIR=%TOOLS_DIR%\git"
set "PORTABLE_CMAKE_DIR=%TOOLS_DIR%\cmake"
set "PORTABLE_NINJA_DIR=%TOOLS_DIR%\ninja"
set "PORTABLE_SKIA_DIR=%TOOLS_DIR%\skia"
set "BOOTSTRAP_SCRIPT=%SUPPORT_DIR%\portable_prereqs.ps1"

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
mkdir "%ABH_DIR%" "%SUPPORT_DIR%" "%LAUNCHER_DIR%" "%UPDATER_DIR%" "%UNINSTALLER_DIR%" "%USER_LOG_DIR%" "%DEV_LOG_DIR%" "%REPORT_DIR%" "%BACKUP_DIR%" "%MANIFEST_DIR%" "%STATE_DIR%" "%MANAGED_DIR%" "%CONFIG_DIR%" "%SOURCE_CONFIG_DIR%" "%TOOLS_DIR%" >nul 2>&1
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
call :activate_portable_tools

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

if /I "%UI_LANG%"=="de" (
  echo.
  echo ABH bereitet fehlende portable Build-Werkzeuge aus offiziellen Quellen vor...
) else (
  echo.
  echo ABH is preparing missing portable build tools from official sources...
)
call :bootstrap_portable_prerequisites
if errorlevel 1 (
  call :record_error "ABH-E002" "portable_prerequisites" "Automatic preparation of Git/CMake/Ninja/Skia failed."
  call :fatal "Portable prerequisite preparation failed. See the ABH log for details."
  exit /b 1
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
) else (
  call :log "Existing Aseprite Git repository found. Initializing submodules."
  git -C "%ROOT%" submodule sync --recursive >>"%LOG%" 2>&1
  if errorlevel 1 (
    call :record_error "ABH-E103" "submodule_sync" "Existing Aseprite checkout has invalid or incomplete submodule metadata."
    call :fatal "The existing C:\aseprite checkout is incomplete. Rename or remove C:\aseprite and run setup again."
    exit /b 1
  )
  git -C "%ROOT%" submodule update --init --recursive >>"%LOG%" 2>&1
  if errorlevel 1 (
    call :record_error "ABH-E103" "submodule_update" "Existing Aseprite checkout could not initialize all required submodules."
    call :fatal "The existing C:\aseprite checkout is incomplete. Rename or remove C:\aseprite and run setup again."
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

:activate_portable_tools
rem Prefer existing system tools. Use ABH-managed portable copies only when needed.
where git.exe >nul 2>&1
if errorlevel 1 if exist "%PORTABLE_GIT_DIR%\cmd\git.exe" set "PATH=%PORTABLE_GIT_DIR%\cmd;%PORTABLE_GIT_DIR%\mingw64\bin;%PATH%"
where cmake.exe >nul 2>&1
if errorlevel 1 if exist "%PORTABLE_CMAKE_DIR%\bin\cmake.exe" set "PATH=%PORTABLE_CMAKE_DIR%\bin;%PATH%"
where ninja.exe >nul 2>&1
if errorlevel 1 if exist "%PORTABLE_NINJA_DIR%\ninja.exe" set "PATH=%PORTABLE_NINJA_DIR%;%PATH%"
if not exist "C:\deps\skia\out\Release-x64\skia.lib" if exist "%PORTABLE_SKIA_DIR%\out\Release-x64\skia.lib" set "SKIA=%PORTABLE_SKIA_DIR%"
exit /b 0

:bootstrap_portable_prerequisites
if not exist "%BOOTSTRAP_SCRIPT%" exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%BOOTSTRAP_SCRIPT%" -ToolsRoot "%TOOLS_DIR%" -SystemSkiaRoot "C:\deps\skia" -ExpectedSkia "%EXPECTED_SKIA%" -Language "%UI_LANG%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
call :activate_portable_tools
where git.exe >nul 2>&1 || exit /b 1
where cmake.exe >nul 2>&1 || exit /b 1
where ninja.exe >nul 2>&1 || exit /b 1
call :validate_skia_files || exit /b 1
exit /b 0

:quick_build_prerequisites
call :activate_portable_tools
where git.exe >nul 2>&1
if errorlevel 1 call :bootstrap_portable_prerequisites
where cmake.exe >nul 2>&1
if errorlevel 1 call :bootstrap_portable_prerequisites
where ninja.exe >nul 2>&1
if errorlevel 1 call :bootstrap_portable_prerequisites
call :validate_skia_files
if errorlevel 1 call :bootstrap_portable_prerequisites
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
 echo Theme-, Add-on- und Mixed-Konfigurationen wiederherstellen? [Y/N]
 set /p "RESTCFG=Auswahl: "
 if /I not "!RESTCFG!"=="Y" exit /b 0
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
rem Progress stays in the current console window.
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
set "RUNTIME_REFRESH=0"
if not exist "%LAUNCHER%" set "RUNTIME_REFRESH=1"
if not exist "%UPDATER%" set "RUNTIME_REFRESH=1"
if not exist "%UNINSTALLER%" set "RUNTIME_REFRESH=1"

if "%RUNTIME_REFRESH%"=="0" (
  findstr /L /C:"ABH_RUNTIME_VERSION=%HELPER_VERSION%" "%LAUNCHER%" >nul 2>&1 || set "RUNTIME_REFRESH=1"
  findstr /L /C:"UPDATER_VERSION=%HELPER_VERSION%" "%UPDATER%" >nul 2>&1 || set "RUNTIME_REFRESH=1"
  findstr /L /C:"UNINSTALLER_VERSION=%HELPER_VERSION%" "%UNINSTALLER%" >nul 2>&1 || set "RUNTIME_REFRESH=1"
)

if "%RUNTIME_REFRESH%"=="1" (
  call :install_runtime_files
  if errorlevel 1 exit /b 1
)

call :create_shortcuts
exit /b %errorlevel%

:create_shortcuts
rem Keep programs in ABH\launcher, ABH\updater and ABH\uninstaller.
rem Create all three user-facing shortcuts on the actual Windows Desktop.

set "ABH_SC_LAUNCHER=%LAUNCHER%"
set "ABH_SC_UPDATER_TARGET=%UPDATER%"
set "ABH_SC_UNINSTALL_TARGET=%UNINSTALLER%"
set "ABH_SC_ICON_MAIN=%ICON_MAIN%"
set "ABH_SC_ICON_UPDATER=%ICON_UPDATER%"
set "ABH_SC_ICON_UNINSTALL=%ICON_UNINSTALL%"
set "ABH_SC_EXE=%EXE%"
set "ABH_SC_PROJECT=%PROJECT_DIR%"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); $w=New-Object -ComObject WScript.Shell; $p=Join-Path $d 'Aseprite.lnk'; $s=$w.CreateShortcut($p); $s.TargetPath='wscript.exe'; $s.Arguments='""'+$env:ABH_SC_LAUNCHER+'""'; $s.WorkingDirectory=(Split-Path -Parent $env:ABH_SC_EXE); if(Test-Path -LiteralPath $env:ABH_SC_ICON_MAIN){$s.IconLocation=$env:ABH_SC_ICON_MAIN}; $s.Save(); $p=Join-Path $d 'Aseprite Build Updater.lnk'; $s=$w.CreateShortcut($p); $s.TargetPath=$env:ComSpec; $s.Arguments='/d /c ""'+$env:ABH_SC_UPDATER_TARGET+'""'; $s.WorkingDirectory=$env:ABH_SC_PROJECT; if(Test-Path -LiteralPath $env:ABH_SC_ICON_UPDATER){$s.IconLocation=$env:ABH_SC_ICON_UPDATER}; $s.Save(); $p=Join-Path $d 'Aseprite Build Helper - Uninstall.lnk'; $s=$w.CreateShortcut($p); $s.TargetPath=$env:ComSpec; $s.Arguments='/d /c ""'+$env:ABH_SC_UNINSTALL_TARGET+'""'; $s.WorkingDirectory=$env:ABH_SC_PROJECT; if(Test-Path -LiteralPath $env:ABH_SC_ICON_UNINSTALL){$s.IconLocation=$env:ABH_SC_ICON_UNINSTALL}; $s.Save()" >nul 2>&1
if errorlevel 1 (
  call :log "Desktop shortcut creation failed."
  exit /b 1
)

call :log "Desktop shortcuts created: Aseprite / Updater / Uninstall."
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
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$raw=[IO.File]::ReadAllText($env:ASE_HELPER_SELF); $out=$env:ASE_HELPER_SUPPORT; $encNoBom=New-Object Text.UTF8Encoding($false); $encBom=New-Object Text.UTF8Encoding($true); $names=@('aseprite_preflight.ps1','portable_prereqs.ps1','aseprite_themes.ps1','aseprite_addons.ps1','aseprite_local_tools.ps1','progress_ui.ps1','source_config.ps1','self_update_apply.ps1','game_pixel_starter.lua','game_export_pack.lua','game_asset_template_generator.lua','autotile_template_generator.lua','game_collision_pivot_metadata.lua','pivot_origin_presets.lua'); foreach($n in $names){$e=[regex]::Escape($n);$m=[regex]::Match($raw,'(?s)###BEGIN:'+$e+'###\r?\n(.*?)\r?\n###END:'+$e+'###');if(-not $m.Success){exit 91};$enc=if($n.EndsWith('.ps1')){$encBom}else{$encNoBom};[IO.File]::WriteAllText((Join-Path $out $n),$m.Groups[1].Value,$enc)}" >nul 2>&1
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
  [void]$checks.Add([pscustomobject]@{
    Name=$T.Git; Ok=[bool]$git
    Detail=if($git){$git.Source}else{$T.NotFound}
    Help="Git"
  })

  $cmake = Get-Command cmake.exe -ErrorAction SilentlyContinue
  [void]$checks.Add([pscustomobject]@{
    Name=$T.CMake; Ok=[bool]$cmake
    Detail=if($cmake){$cmake.Source}else{$T.NotInPath}
    Help="CMake"
  })

  $ninja = Get-Command ninja.exe -ErrorAction SilentlyContinue
  if(-not $ninja) {
    $candidate = "C:\Program Files\CMake\bin\ninja.exe"
    if(Test-Path $candidate) { $ninja = Get-Item $candidate }
  }
  [void]$checks.Add([pscustomobject]@{
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
  [void]$checks.Add([pscustomobject]@{
    Name=$T.VS; Ok=[bool]$vsOk
    Detail=if($vsOk){$vcvars}else{$T.VsMissing}
    Help="VisualStudio"
  })

  $sdkRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\Include"
  $sdkOk = Test-Path $sdkRoot
  [void]$checks.Add([pscustomobject]@{
    Name=$T.SDK; Ok=$sdkOk
    Detail=if($sdkOk){$sdkRoot}else{$T.SdkMissing}
    Help="VisualStudio"
  })

  $skiaLib = Join-Path $SkiaRoot "out\Release-x64\skia.lib"
  $skiaInclude = Join-Path $SkiaRoot "include"
  $skiaOk = (Test-Path $skiaLib) -and (Test-Path $skiaInclude)
  [void]$checks.Add([pscustomobject]@{
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
  [void]$checks.Add([pscustomobject]@{
    Name=$T.Target; Ok=$sourceOk; Detail=$sourceDetail; Help="Aseprite"
  })

  try {
    $drive = Get-PSDrive -Name C
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
    $spaceOk = $freeGB -ge 4
    [void]$checks.Add([pscustomobject]@{
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
    [void]$lines.Add("$state $($c.Name)")
    [void]$lines.Add("    $($c.Detail)")
    [void]$lines.Add("")
  }

  [void]$lines.Add($T.HelpHeader)
  [void]$lines.Add("Git:           " + $Urls.Git)
  [void]$lines.Add("CMake:         " + $Urls.CMake)
  [void]$lines.Add("Visual Studio: " + $Urls.VisualStudio)
  [void]$lines.Add("Ninja:         " + $Urls.Ninja)
  [void]$lines.Add("Skia m124:     " + $Urls.Skia)
  [void]$lines.Add("Aseprite:      " + $Urls.Aseprite)
  [void]$lines.Add("EULA:          " + $Urls.Eula)
  [void]$lines.Add("")
  [void]$lines.Add($T.SkiaHint)
  [void]$lines.Add("C:\deps\skia\out\Release-x64\skia.lib")
  [void]$lines.Add("")
  $summaryLine = if($missing.Count -eq 0) { $T.Ready } else { $T.NoBinary }
  [void]$lines.Add($summaryLine)

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

###BEGIN:portable_prereqs.ps1###
param(
  [Parameter(Mandatory=$true)][string]$ToolsRoot,
  [string]$SystemSkiaRoot = 'C:\deps\skia',
  [string]$ExpectedSkia = 'm124-08a5439a6b',
  [string]$Language = 'en'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($Language -ne 'de') { $Language = 'en' }

$gitDir   = Join-Path $ToolsRoot 'git'
$cmakeDir = Join-Path $ToolsRoot 'cmake'
$ninjaDir = Join-Path $ToolsRoot 'ninja'
$skiaDir  = Join-Path $ToolsRoot 'skia'
$stateDir = Join-Path (Split-Path $ToolsRoot -Parent) 'state'
$manifest = Join-Path $stateDir 'portable-tools.txt'
New-Item -ItemType Directory -Force -Path $ToolsRoot,$stateDir | Out-Null

function Say([string]$en,[string]$de) {
  if ($Language -eq 'de') { Write-Host $de -ForegroundColor Cyan }
  else { Write-Host $en -ForegroundColor Cyan }
}
function Warn([string]$en,[string]$de) {
  if ($Language -eq 'de') { Write-Host $de -ForegroundColor Yellow }
  else { Write-Host $en -ForegroundColor Yellow }
}
function Get-LatestRelease([string]$repo) {
  $headers = @{ 'User-Agent'='Aseprite-Build-Helper'; 'Accept'='application/vnd.github+json' }
  Invoke-RestMethod -Headers $headers -Uri ("https://api.github.com/repos/{0}/releases/latest" -f $repo)
}
function Get-Asset([string]$repo,[string]$pattern) {
  $release = Get-LatestRelease $repo
  $asset = @($release.assets | Where-Object { $_.name -match $pattern -and $_.name -notmatch 'busybox' }) | Select-Object -First 1
  if (-not $asset) { throw "No matching release asset found for $repo ($pattern)" }
  return $asset
}
function Download([string]$url,[string]$dest) {
  Invoke-WebRequest -UseBasicParsing -Headers @{ 'User-Agent'='Aseprite-Build-Helper' } -Uri $url -OutFile $dest
}
function Reset-Dir([string]$path) {
  if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $path | Out-Null
}
function Expand-ToRoot([string]$zip,[string]$target,[string]$needle) {
  $temp = Join-Path $env:TEMP ('abh-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $temp | Out-Null
  try {
    Expand-Archive -LiteralPath $zip -DestinationPath $temp -Force
    $hit = Get-ChildItem -LiteralPath $temp -Recurse -File -ErrorAction Stop | Where-Object { $_.FullName -like "*$needle" } | Select-Object -First 1
    if (-not $hit) { throw "Expected file not found after extraction: $needle" }
    $root = $hit.Directory.FullName
    $parts = ($needle -split '[\\/]') | Where-Object { $_ }
    for ($i=1; $i -lt $parts.Count; $i++) { $root = Split-Path $root -Parent }
    Reset-Dir $target
    Get-ChildItem -LiteralPath $root -Force | Copy-Item -Destination $target -Recurse -Force
  }
  finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

$records = New-Object System.Collections.Generic.List[string]

# Git: prefer a system installation. Otherwise install official MinGit x64.
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($git) {
  [void]$records.Add('Git=system|' + $git.Source)
} elseif (Test-Path (Join-Path $gitDir 'cmd\git.exe')) {
  [void]$records.Add('Git=portable|' + (Join-Path $gitDir 'cmd\git.exe'))
} else {
  Say 'Downloading portable Git from the official Git for Windows GitHub release...' 'Portable Git wird aus dem offiziellen Git-for-Windows-GitHub-Release geladen...'
  $asset = Get-Asset 'git-for-windows/git' '^MinGit-.*-64-bit\.zip$'
  $zip = Join-Path $env:TEMP ('abh-git-' + [guid]::NewGuid().ToString('N') + '.zip')
  try {
    Download $asset.browser_download_url $zip
    Reset-Dir $gitDir
    Expand-Archive -LiteralPath $zip -DestinationPath $gitDir -Force
    if (-not (Test-Path (Join-Path $gitDir 'cmd\git.exe'))) { throw 'Portable Git extraction did not produce cmd\git.exe' }
    [void]$records.Add('Git=portable|' + $asset.name)
  } finally { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
}

# CMake: prefer system CMake. Otherwise install official x64 ZIP from Kitware/CMake.
$cmake = Get-Command cmake.exe -ErrorAction SilentlyContinue
if ($cmake) {
  [void]$records.Add('CMake=system|' + $cmake.Source)
} elseif (Test-Path (Join-Path $cmakeDir 'bin\cmake.exe')) {
  [void]$records.Add('CMake=portable|' + (Join-Path $cmakeDir 'bin\cmake.exe'))
} else {
  Say 'Downloading portable CMake from the official Kitware GitHub release...' 'Portables CMake wird aus dem offiziellen Kitware-GitHub-Release geladen...'
  $asset = Get-Asset 'Kitware/CMake' '^cmake-.*-windows-x86_64\.zip$'
  $zip = Join-Path $env:TEMP ('abh-cmake-' + [guid]::NewGuid().ToString('N') + '.zip')
  try {
    Download $asset.browser_download_url $zip
    Expand-ToRoot $zip $cmakeDir 'bin\cmake.exe'
    if (-not (Test-Path (Join-Path $cmakeDir 'bin\cmake.exe'))) { throw 'Portable CMake extraction did not produce bin\cmake.exe' }
    [void]$records.Add('CMake=portable|' + $asset.name)
  } finally { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
}

# Ninja: prefer system Ninja. Otherwise install official ninja-win.zip.
$ninja = Get-Command ninja.exe -ErrorAction SilentlyContinue
if ($ninja) {
  [void]$records.Add('Ninja=system|' + $ninja.Source)
} elseif (Test-Path (Join-Path $ninjaDir 'ninja.exe')) {
  [void]$records.Add('Ninja=portable|' + (Join-Path $ninjaDir 'ninja.exe'))
} else {
  Say 'Downloading Ninja from the official GitHub release...' 'Ninja wird aus dem offiziellen GitHub-Release geladen...'
  $asset = Get-Asset 'ninja-build/ninja' '^ninja-win\.zip$'
  $zip = Join-Path $env:TEMP ('abh-ninja-' + [guid]::NewGuid().ToString('N') + '.zip')
  try {
    Download $asset.browser_download_url $zip
    Reset-Dir $ninjaDir
    Expand-Archive -LiteralPath $zip -DestinationPath $ninjaDir -Force
    if (-not (Test-Path (Join-Path $ninjaDir 'ninja.exe'))) { throw 'Ninja extraction did not produce ninja.exe' }
    [void]$records.Add('Ninja=portable|' + $asset.name)
  } finally { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
}

# Skia: prefer the user's existing manual location; otherwise keep ABH's managed copy locally.
$systemSkiaOk = (Test-Path (Join-Path $SystemSkiaRoot 'out\Release-x64\skia.lib')) -and (Test-Path (Join-Path $SystemSkiaRoot 'include'))
$portableSkiaOk = (Test-Path (Join-Path $skiaDir 'out\Release-x64\skia.lib')) -and (Test-Path (Join-Path $skiaDir 'include'))
if ($systemSkiaOk) {
  [void]$records.Add('Skia=system|' + $SystemSkiaRoot)
} elseif ($portableSkiaOk) {
  [void]$records.Add('Skia=portable|' + $skiaDir)
} else {
  Say 'Downloading the Aseprite-compatible Skia x64 package...' 'Das zu Aseprite passende Skia-x64-Paket wird geladen...'
  $url = "https://github.com/aseprite/skia/releases/download/$ExpectedSkia/Skia-Windows-Release-x64.zip"
  $zip = Join-Path $env:TEMP ('abh-skia-' + [guid]::NewGuid().ToString('N') + '.zip')
  try {
    Download $url $zip
    Expand-ToRoot $zip $skiaDir 'out\Release-x64\skia.lib'
    if (-not ((Test-Path (Join-Path $skiaDir 'out\Release-x64\skia.lib')) -and (Test-Path (Join-Path $skiaDir 'include')))) {
      throw 'Skia extraction did not produce the expected x64 layout.'
    }
    [void]$records.Add('Skia=portable|' + $ExpectedSkia)
  } finally { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
}

[void]$records.Add('Updated=' + (Get-Date).ToString('o'))
[IO.File]::WriteAllLines($manifest, $records, (New-Object Text.UTF8Encoding($false)))
Say 'Portable build dependencies are ready.' 'Portable Build-Abhängigkeiten sind bereit.'
exit 0
###END:portable_prereqs.ps1###

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
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
###END:uninstall.ico.b64###

###BEGIN:aseprite-launcher.vbs.b64###
T3B0aW9uIEV4cGxpY2l0DQonIEFCSF9SVU5USU1FX1ZFUlNJT049MS4zLjEwDQpEaW0gc2hlbGws
IGZzbywgc2NyaXB0RGlyLCBhYmhEaXIsIHByb2plY3REaXIsIHVwZGF0ZXIsIGJ1aWxkZXIsIGNt
ZCwgcSwgdWlMYW5nLCBtc2cNClNldCBzaGVsbCA9IENyZWF0ZU9iamVjdCgiV1NjcmlwdC5TaGVs
bCIpDQpTZXQgZnNvID0gQ3JlYXRlT2JqZWN0KCJTY3JpcHRpbmcuRmlsZVN5c3RlbU9iamVjdCIp
DQpxID0gQ2hyKDM0KQ0Kc2NyaXB0RGlyID0gZnNvLkdldFBhcmVudEZvbGRlck5hbWUoV1Njcmlw
dC5TY3JpcHRGdWxsTmFtZSkNCmFiaERpciA9IGZzby5HZXRQYXJlbnRGb2xkZXJOYW1lKHNjcmlw
dERpcikNCnByb2plY3REaXIgPSBmc28uR2V0UGFyZW50Rm9sZGVyTmFtZShhYmhEaXIpDQp1cGRh
dGVyID0gZnNvLkJ1aWxkUGF0aChmc28uQnVpbGRQYXRoKGFiaERpciwgInVwZGF0ZXIiKSwgImFz
ZXByaXRlLWJ1aWxkLXVwZGF0ZXIuYmF0IikNCmJ1aWxkZXIgPSBmc28uQnVpbGRQYXRoKHByb2pl
Y3REaXIsICJhc2Vwcml0ZS1idWlsZC1oZWxwZXIuYmF0IikNCg0KSWYgTm90IGZzby5GaWxlRXhp
c3RzKHVwZGF0ZXIpIFRoZW4NCiAgSWYgZnNvLkZpbGVFeGlzdHMoYnVpbGRlcikgVGhlbg0KICAg
IGNtZCA9ICJjbWQuZXhlIC9kIC9jICIgJiBxICYgcSAmIGJ1aWxkZXIgJiBxICYgIiAtLXJlZnJl
c2gtcnVudGltZSIgJiBxDQogICAgc2hlbGwuUnVuIGNtZCwgMCwgVHJ1ZQ0KICBFbmQgSWYNCkVu
ZCBJZg0KDQpJZiBOb3QgZnNvLkZpbGVFeGlzdHModXBkYXRlcikgVGhlbg0KICB1aUxhbmcgPSAi
ZW4iDQogIE9uIEVycm9yIFJlc3VtZSBOZXh0DQogIHVpTGFuZyA9IExDYXNlKHNoZWxsLlJlZ1Jl
YWQoIkhLRVlfQ1VSUkVOVF9VU0VSXENvbnRyb2wgUGFuZWxcSW50ZXJuYXRpb25hbFxMb2NhbGVO
YW1lIikpDQogIE9uIEVycm9yIEdvVG8gMA0KICBJZiBMZWZ0KHVpTGFuZywgMikgPSAiZGUiIFRo
ZW4NCiAgICBtc2cgPSAiQXNlcHJpdGUgQnVpbGQgVXBkYXRlciBrb25udGUgbmljaHQgZ2VmdW5k
ZW4gd2VyZGVuLiBCaXR0ZSBzdGFydGUgYXNlcHJpdGUtYnVpbGQtaGVscGVyLmJhdCB6dXIgUmVw
YXJhdHVyLiINCiAgRWxzZQ0KICAgIG1zZyA9ICJBc2Vwcml0ZSBCdWlsZCBVcGRhdGVyIGNvdWxk
IG5vdCBiZSBmb3VuZC4gUGxlYXNlIHJ1biBhc2Vwcml0ZS1idWlsZC1oZWxwZXIuYmF0IHRvIHJl
cGFpciBpdC4iDQogIEVuZCBJZg0KICBNc2dCb3ggbXNnLCB2YkNyaXRpY2FsLCAiQXNlcHJpdGUg
QnVpbGQgSGVscGVyIg0KICBXU2NyaXB0LlF1aXQgMg0KRW5kIElmDQoNCmNtZCA9ICJjbWQuZXhl
IC9kIC9jICIgJiBxICYgcSAmIHVwZGF0ZXIgJiBxICYgIiAtLXNjaGVkdWxlZCAtLWxhdW5jaCIg
JiBxDQpzaGVsbC5SdW4gY21kLCAwLCBGYWxzZQ0K
###END:aseprite-launcher.vbs.b64###

###BEGIN:uninstall-abh.bat.b64###
QGVjaG8gb2ZmDQpjaGNwIDY1MDAxID5udWwNCnNldGxvY2FsIEVuYWJsZUV4dGVuc2lvbnMgRW5h
YmxlRGVsYXllZEV4cGFuc2lvbg0Kc2V0ICJVTklOU1RBTExFUl9WRVJTSU9OPTEuMy4xMCINCmZv
ciAlJUkgaW4gKCIlfmRwMC4uIikgZG8gc2V0ICJBQkhfRElSPSUlfmZJIg0KZm9yICUlSSBpbiAo
IiVBQkhfRElSJVwuLiIpIGRvIHNldCAiUFJPSkVDVF9ESVI9JSV+ZkkiDQpzZXQgIlJPT1Q9Qzpc
YXNlcHJpdGUiDQpzZXQgIkNPTkZJRz0lQUJIX0RJUiVcY29uZmlnIg0Kc2V0ICJTT1VSQ0VTPSVD
T05GSUclXHNvdXJjZXMiDQpzZXQgIkJBQ0tVUFM9JUFCSF9ESVIlXGJhY2t1cHMiDQpzZXQgIk1B
TklGRVNUPSVBQkhfRElSJVxtYW5pZmVzdCINCnNldCAiQVBQX0FTRT0lQVBQREFUQSVcQXNlcHJp
dGUiDQpzZXQgIkFERE9OX1NDUklQVFM9JUFQUF9BU0UlXHNjcmlwdHNcYXV0by1tYW5hZ2VkIg0K
c2V0ICJMT0NBTF9TQ1JJUFRTPSVBUFBfQVNFJVxzY3JpcHRzXGF1dG8tbWFuYWdlZC1sb2NhbCIN
CnNldCAiTEFOR1VBR0U9ZW4iDQpmb3IgL2YgInVzZWJhY2txIGRlbGltcz0iICUlTCBpbiAoYHBv
d2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtQ29tbWFuZCAiJGM9KEdldC1VSUN1bHR1
cmUpLk5hbWU7IGlmKCRjIC1saWtlICdkZS0qJyl7J2RlJ31lbHNleydlbid9ImApIGRvIHNldCAi
TEFOR1VBR0U9JSVMIg0KZm9yICUlQSBpbiAoJSopIGRvICgNCiAgaWYgL0kgIiUlfkEiPT0iLS1s
YW5nPWRlIiBzZXQgIkxBTkdVQUdFPWRlIg0KICBpZiAvSSAiJSV+QSI9PSItLWxhbmc9ZW4iIHNl
dCAiTEFOR1VBR0U9ZW4iDQopDQpmb3IgL2YgInVzZWJhY2txIGRlbGltcz0iICUlRCBpbiAoYHBv
d2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtQ29tbWFuZCAiW0Vudmlyb25tZW50XTo6
R2V0Rm9sZGVyUGF0aCgnRGVza3RvcCcpImApIGRvIHNldCAiREVTS1RPUD0lJUQiDQoNCjptZW51
DQpjbHMNCmlmIC9JICIlTEFOR1VBR0UlIj09ImRlIiAoDQogZWNobyA9PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiBlY2hvICAgQXNl
cHJpdGUgQnVpbGQgSGVscGVyIC0gRGVpbnN0YWxsYXRpb24NCiBlY2hvID09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KIGVjaG8uDQog
ZWNobyBbMV0gTnVyIEhlbHBlci1MYXVmemVpdGRhdGVpZW4gZW50ZmVybmVuDQogZWNobyBbMl0g
SGVscGVyLUxhdWZ6ZWl0ZGF0ZWllbiArIGVyemV1Z3RlIFZlcmtuw7xwZnVuZ2VuIGVudGZlcm5l
bg0KIGVjaG8gWzNdIEhlbHBlci1MYXVmemVpdGRhdGVpZW4sIFZlcmtuw7xwZnVuZ2VuIHVuZCBB
QkgtQmFja3VwcyBlbnRmZXJuZW4NCiBlY2hvIFs0XSBMb2thbGUgQXNlcHJpdGUtUXVlbGwtL0J1
aWxkLU9yZG5lciBlbnRmZXJuZW4NCiBlY2hvIFs1XSBBTExFIHZvbiBBQkggdmVyd2FsdGV0ZW4g
SW5oYWx0ZSBlbnRmZXJuZW4NCiBlY2hvIFs2XSBBTExFUyBlbnRmZXJuZW4gKyBRdWVsbGVuLUtv
bmZpZ3VyYXRpb25lbiBhbHMgWklQIGV4cG9ydGllcmVuDQogZWNobyBbMF0gQWJicmVjaGVuDQog
ZWNoby4NCiBzZXQgL3AgIlNFTD1BdXN3YWhsOiAiDQopIGVsc2UgKA0KIGVjaG8gPT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogZWNo
byAgIEFzZXByaXRlIEJ1aWxkIEhlbHBlciAtIFVuaW5zdGFsbGVyDQogZWNobyA9PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiBlY2hv
Lg0KIGVjaG8gWzFdIFJlbW92ZSBoZWxwZXIgcnVudGltZSBmaWxlcyBvbmx5DQogZWNobyBbMl0g
UmVtb3ZlIGhlbHBlciBydW50aW1lIGZpbGVzICsgZ2VuZXJhdGVkIHNob3J0Y3V0cw0KIGVjaG8g
WzNdIFJlbW92ZSBoZWxwZXIgcnVudGltZSwgc2hvcnRjdXRzIGFuZCBBQkggYmFja3Vwcw0KIGVj
aG8gWzRdIFJlbW92ZSBsb2NhbCBBc2Vwcml0ZSBzb3VyY2UvYnVpbGQgZm9sZGVycw0KIGVjaG8g
WzVdIFJFTU9WRSBBTEwgQUJILW1hbmFnZWQgY29udGVudA0KIGVjaG8gWzZdIFJFTU9WRSBBTEwg
KyBleHBvcnQgc291cmNlIGNvbmZpZ3VyYXRpb25zIHRvIFpJUA0KIGVjaG8gWzBdIENhbmNlbA0K
IGVjaG8uDQogc2V0IC9wICJTRUw9U2VsZWN0aW9uOiAiDQopDQppZiAiJVNFTCUiPT0iMCIgZXhp
dCAvYiAwDQppZiAiJVNFTCUiPT0iMSIgZ290byBvcHQxDQppZiAiJVNFTCUiPT0iMiIgZ290byBv
cHQyDQppZiAiJVNFTCUiPT0iMyIgZ290byBvcHQzDQppZiAiJVNFTCUiPT0iNCIgZ290byBvcHQ0
DQppZiAiJVNFTCUiPT0iNSIgZ290byBvcHQ1DQppZiAiJVNFTCUiPT0iNiIgZ290byBvcHQ2DQpn
b3RvIG1lbnUNCg0KOndhcm5fcnVudGltZQ0KaWYgL0kgIiVMQU5HVUFHRSUiPT0iZGUiICgNCiBl
Y2hvLg0KIGVjaG8gRGllIEFCSC1MYXVmemVpdGRhdGVuIHdlcmRlbiBlbnRmZXJudC4NCiBlY2hv
IEVpZ2VuZSBEYXRlaWVuIGlubmVyaGFsYiB2b24gQUJILU9yZG5lcm4ga8O2bm5lbiBlYmVuZmFs
bHMgZ2Vsw7ZzY2h0IHdlcmRlbi4NCiBlY2hvLg0KIHNldCAvcCAiQU5TPUZvcnRmYWhyZW4/IFtZ
L05dOiAiDQogaWYgL0kgbm90ICIhQU5TISI9PSJZIiBleGl0IC9iIDENCikgZWxzZSAoDQogZWNo
by4NCiBlY2hvIEFCSCBydW50aW1lIGRhdGEgd2lsbCBiZSByZW1vdmVkLg0KIGVjaG8gRmlsZXMg
eW91IG1hbnVhbGx5IHBsYWNlZCBpbnNpZGUgQUJIIGZvbGRlcnMgbWF5IGFsc28gYmUgZGVsZXRl
ZC4NCiBlY2hvLg0KIHNldCAvcCAiQU5TPUNvbnRpbnVlPyBbWS9OXTogIg0KIGlmIC9JIG5vdCAi
IUFOUyEiPT0iWSIgZXhpdCAvYiAxDQopDQpleGl0IC9iIDANCg0KOndhcm5fc291cmNlDQpjbHMN
CmlmIC9JICIlTEFOR1VBR0UlIj09ImRlIiAoDQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiBlY2hvICAgV0FSTlVORyAt
IEFTRVBSSVRFIFNPVVJDRS9CVUlMRCBMw5ZTQ0hFTg0KIGVjaG8gPT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogZWNoby4NCiBlY2hv
IERlciBrb21wbGV0dGUgT3JkbmVyICIlUk9PVCUiIHdpcmQgZ2Vsw7ZzY2h0Lg0KIGVjaG8uDQog
ZWNobyBXSUNIVElHOg0KIGVjaG8gRWlnZW5lIERhdGVpZW4sIFRoZW1lcywgU2tyaXB0ZSwgUGF0
Y2hlcywgUXVlbGxjb2RlLcOEbmRlcnVuZ2VuIG9kZXINCiBlY2hvIHNvbnN0aWdlIERhdGVpZW4g
aW5uZXJoYWxiIGRpZXNlcyBPcmRuZXJzIHdlcmRlbiBlYmVuZmFsbHMgZ2Vsw7ZzY2h0Lg0KIGVj
aG8gUHLDvGZlbiBvZGVyIHNpY2hlcm4gU2llIGRlbiBPcmRuZXIgdm9yIGRlbSBGb3J0ZmFocmVu
Lg0KIGVjaG8uDQogZWNobyBbT10gQmV0cm9mZmVuZW4gT3JkbmVyIMO2ZmZuZW4NCiBlY2hvIFtK
XSBJY2ggdmVyc3RlaGUgZGFzIHVuZCBtw7ZjaHRlIGZvcnRmYWhyZW4NCiBlY2hvIFtOXSBBYmJy
ZWNoZW4NCiBzZXQgL3AgIkFOUz1BdXN3YWhsOiAiDQogaWYgL0kgIiFBTlMhIj09Ik8iIHN0YXJ0
ICIiIGV4cGxvcmVyLmV4ZSAiJVJPT1QlIiAmIHBhdXNlICYgZ290byB3YXJuX3NvdXJjZQ0KIGlm
IC9JIG5vdCAiIUFOUyEiPT0iWSIgZXhpdCAvYiAxDQopIGVsc2UgKA0KIGVjaG8gPT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogZWNo
byAgIFdBUk5JTkcgLSBSRU1PVkUgQVNFUFJJVEUgU09VUkNFL0JVSUxEDQogZWNobyA9PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiBl
Y2hvLg0KIGVjaG8gVGhlIGNvbXBsZXRlIGZvbGRlciAiJVJPT1QlIiB3aWxsIGJlIGRlbGV0ZWQu
DQogZWNoby4NCiBlY2hvIElNUE9SVEFOVDoNCiBlY2hvIFlvdXIgb3duIGZpbGVzLCB0aGVtZXMs
IHNjcmlwdHMsIHBhdGNoZXMsIHNvdXJjZSBtb2RpZmljYXRpb25zIG9yIG90aGVyDQogZWNobyBm
aWxlcyBpbnNpZGUgdGhpcyBmb2xkZXIgd2lsbCBiZSBkZWxldGVkIGFzIHdlbGwuDQogZWNobyBS
ZXZpZXcgb3IgYmFjayB1cCB0aGlzIGZvbGRlciBiZWZvcmUgY29udGludWluZy4NCiBlY2hvLg0K
IGVjaG8gW09dIE9wZW4gYWZmZWN0ZWQgZm9sZGVyDQogZWNobyBbWV0gSSB1bmRlcnN0YW5kIGFu
ZCB3YW50IHRvIGNvbnRpbnVlDQogZWNobyBbTl0gQ2FuY2VsDQogc2V0IC9wICJBTlM9U2VsZWN0
aW9uOiAiDQogaWYgL0kgIiFBTlMhIj09Ik8iIHN0YXJ0ICIiIGV4cGxvcmVyLmV4ZSAiJVJPT1Ql
IiAmIHBhdXNlICYgZ290byB3YXJuX3NvdXJjZQ0KIGlmIC9JIG5vdCAiIUFOUyEiPT0iWSIgZXhp
dCAvYiAxDQopDQpleGl0IC9iIDANCg0KOndhcm5fYWxsDQpjbHMNCmlmIC9JICIlTEFOR1VBR0Ul
Ij09ImRlIiAoDQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT0NCiBlY2hvICAgV0FSTlVORyAtIEFMTEVTIEVOVEZFUk5FTg0K
IGVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09DQogZWNoby4NCiBlY2hvIEVudGZlcm50IHdlcmRlbiB1bnRlciBhbmRlcmVtOg0K
IGVjaG8gLSBBQkgtTGF1ZnplaXQtL1N1cHBvcnQtRGF0ZWllbiwgTG9ncyB1bmQgRGlhZ25vc2Vi
ZXJpY2h0ZQ0KIGVjaG8gLSBCYWNrdXBzLCBTdGF0dXMtL1VwZGF0ZS1EYXRlaWVuIHVuZCBRdWVs
bGVuLUtvbmZpZ3VyYXRpb25lbg0KIGVjaG8gLSBlcnpldWd0ZXIgTGF1bmNoZXIgdW5kIGVyemV1
Z3RlIFZlcmtuw7xwZnVuZ2VuDQogZWNobyAtIGxva2FsIGdla2xvbnRlciBBc2Vwcml0ZSBTb3Vy
Y2UtL0J1aWxkLU9yZG5lcjogJVJPT1QlDQogZWNobyAtIHZvbiBBQkggdmVyd2FsdGV0ZSBUaGVt
ZXMsIEFkZC1vbnMgdW5kIFNrcmlwdGUNCiBlY2hvLg0KIGVjaG8gQUNIVFVORzoNCiBlY2hvIFZl
cndhbHRldGUgT3JkbmVyIHdlcmRlbiB2b2xsc3TDpG5kaWcgZ2Vsw7ZzY2h0LiBFaWdlbmUgRGF0
ZWllbiBvZGVyDQogZWNobyDDhG5kZXJ1bmdlbiBpbm5lcmhhbGIgZGllc2VyIE9yZG5lciB3ZXJk
ZW4gZWJlbmZhbGxzIGdlbMO2c2NodC4NCiBlY2hvIFNraWEgd2lyZCBuaWNodCBnZWzDtnNjaHQs
IGRhIEFCSCBlcyBuaWNodCBhdXRvbWF0aXNjaCBpbnN0YWxsaWVydCBoYXQuDQogZWNoby4NCiBl
Y2hvIFtPXSBCZXRyb2ZmZW5lIE9yZG5lciDDtmZmbmVuDQogZWNobyBbQ10gV2VpdGVyIHp1ciBm
aW5hbGVuIEJlc3TDpHRpZ3VuZw0KIGVjaG8gW05dIEFiYnJlY2hlbg0KIHNldCAvcCAiQU5TPUF1
c3dhaGw6ICINCiBpZiAvSSAiIUFOUyEiPT0iTyIgY2FsbCA6b3Blbl9hZmZlY3RlZCAmIHBhdXNl
ICYgZ290byB3YXJuX2FsbA0KIGlmIC9JIG5vdCAiIUFOUyEiPT0iQyIgZXhpdCAvYiAxDQogZWNo
by4NCiBzZXQgL3AgIkNPTkY9WnVtIEJlc3TDpHRpZ2VuIGV4YWt0IEFMTEVTIEVOVEZFUk5FTiBl
aW5nZWJlbjogIg0KIGlmIC9JIG5vdCAiIUNPTkYhIj09IkFMTEVTIEVOVEZFUk5FTiIgZXhpdCAv
YiAxDQopIGVsc2UgKA0KIGVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09DQogZWNobyAgIFdBUk5JTkcgLSBSRU1PVkUgQUxMDQog
ZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT0NCiBlY2hvLg0KIGVjaG8gVGhpcyByZW1vdmVzLCBhbW9uZyBvdGhlciB0aGluZ3M6
DQogZWNobyAtIEFCSCBydW50aW1lL3N1cHBvcnQgZmlsZXMsIGxvZ3MgYW5kIGRpYWdub3N0aWNz
DQogZWNobyAtIGJhY2t1cHMsIHN0YXRlL3VwZGF0ZSBmaWxlcyBhbmQgc291cmNlIGNvbmZpZ3Vy
YXRpb25zDQogZWNobyAtIGdlbmVyYXRlZCBsYXVuY2hlciBhbmQgc2hvcnRjdXRzDQogZWNobyAt
IGxvY2FsIEFzZXByaXRlIHNvdXJjZS9idWlsZCBmb2xkZXI6ICVST09UJQ0KIGVjaG8gLSBBQkgt
bWFuYWdlZCB0aGVtZXMsIGFkZC1vbnMgYW5kIHNjcmlwdHMNCiBlY2hvLg0KIGVjaG8gSU1QT1JU
QU5UOg0KIGVjaG8gTWFuYWdlZCBmb2xkZXJzIGFyZSByZW1vdmVkIGNvbXBsZXRlbHkuIFlvdXIg
b3duIGZpbGVzIG9yIGNoYW5nZXMgaW5zaWRlDQogZWNobyB0aG9zZSBmb2xkZXJzIHdpbGwgYWxz
byBiZSBkZWxldGVkLg0KIGVjaG8gU2tpYSBpcyBub3QgcmVtb3ZlZCBiZWNhdXNlIEFCSCBkaWQg
bm90IGluc3RhbGwgaXQgYXV0b21hdGljYWxseS4NCiBlY2hvLg0KIGVjaG8gW09dIE9wZW4gYWZm
ZWN0ZWQgZm9sZGVycw0KIGVjaG8gW0NdIENvbnRpbnVlIHRvIGZpbmFsIGNvbmZpcm1hdGlvbg0K
IGVjaG8gW05dIENhbmNlbA0KIHNldCAvcCAiQU5TPVNlbGVjdGlvbjogIg0KIGlmIC9JICIhQU5T
ISI9PSJPIiBjYWxsIDpvcGVuX2FmZmVjdGVkICYgcGF1c2UgJiBnb3RvIHdhcm5fYWxsDQogaWYg
L0kgbm90ICIhQU5TISI9PSJDIiBleGl0IC9iIDENCiBlY2hvLg0KIHNldCAvcCAiQ09ORj1UeXBl
IFJFTU9WRSBBTEwgZXhhY3RseSB0byBjb25maXJtOiAiDQogaWYgL0kgbm90ICIhQ09ORiEiPT0i
UkVNT1ZFIEFMTCIgZXhpdCAvYiAxDQopDQpleGl0IC9iIDANCg0KOndhcm5fZXhwb3J0X2FsbA0K
Y2xzDQppZiAvSSAiJUxBTkdVQUdFJSI9PSJkZSIgKA0KIGVjaG8gPT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogZWNobyAgIEFMTEVT
IEVOVEZFUk5FTiArIFFVRUxMRU4tS09ORklHVVJBVElPTkVOIEVYUE9SVElFUkVODQogZWNobyA9
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT0NCiBlY2hvLg0KIGVjaG8gVm9yIGRlciB2b2xsc3TDpG5kaWdlbiBFbnRmZXJudW5nIHdlcmRl
biBhbGxlIElOSS1EYXRlaWVuIGF1cw0KIGVjaG8gIiVTT1VSQ0VTJSIgYWxzIFpJUCBuZWJlbiBk
ZW4gdXJzcHLDvG5nbGljaGVuIFBha2V0ZGF0ZWllbiBnZXNwZWljaGVydC4NCiBlY2hvIEVudGhh
bHRlbiBzaW5kIFRoZW1lLSwgQWRkLW9uLSB1bmQgTWl4ZWQtS29uZmlndXJhdGlvbmVuIHNvd2ll
IElocmUNCiBlY2hvIGVpZ2VuZW4gUmVwb3NpdG9yeS1FaW50csOkZ2UgdW5kIEF1dG8tVXBkYXRl
LUVpbnN0ZWxsdW5nZW4uDQogZWNoby4NCiBlY2hvIERhbmFjaCB3aXJkIGRlcnNlbGJlIEluaGFs
dCB3aWUgYmVpIE9wdGlvbiBbNV0gZW50ZmVybnQuDQogZWNobyBFaWdlbmUgRGF0ZWllbiBpbm5l
cmhhbGIgdmVyd2FsdGV0ZXIgT3JkbmVyIHdlcmRlbiBlYmVuZmFsbHMgZ2Vsw7ZzY2h0Lg0KIGVj
aG8uDQogZWNobyBbT10gQmV0cm9mZmVuZSBPcmRuZXIgw7ZmZm5lbg0KIGVjaG8gW0NdIEV4cG9y
dGllcmVuIHVuZCB3ZWl0ZXIgenVyIGZpbmFsZW4gQmVzdMOkdGlndW5nDQogZWNobyBbTl0gQWJi
cmVjaGVuDQogc2V0IC9wICJBTlM9QXVzd2FobDogIg0KIGlmIC9JICIhQU5TISI9PSJPIiBjYWxs
IDpvcGVuX2FmZmVjdGVkICYgcGF1c2UgJiBnb3RvIHdhcm5fZXhwb3J0X2FsbA0KIGlmIC9JIG5v
dCAiIUFOUyEiPT0iQyIgZXhpdCAvYiAxDQogZWNoby4NCiBzZXQgL3AgIkNPTkY9WnVtIEJlc3TD
pHRpZ2VuIGV4YWt0IEtPTkZJRyBFWFBPUlRJRVJFTiBlaW5nZWJlbjogIg0KIGlmIC9JIG5vdCAi
IUNPTkYhIj09IktPTkZJRyBFWFBPUlRJRVJFTiIgZXhpdCAvYiAxDQopIGVsc2UgKA0KIGVjaG8g
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09DQogZWNobyAgIFJFTU9WRSBBTEwgKyBFWFBPUlQgU09VUkNFIENPTkZJR1VSQVRJT05TDQog
ZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT0NCiBlY2hvLg0KIGVjaG8gQmVmb3JlIHJlbW92YWwsIGFsbCBJTkkgZmlsZXMgdW5k
ZXINCiBlY2hvICIlU09VUkNFUyUiIHdpbGwgYmUgc2F2ZWQgYXMgYSBaSVAgbmV4dCB0byB0aGUg
b3JpZ2luYWwgcGFja2FnZSBmaWxlcy4NCiBlY2hvIEl0IGNvbnRhaW5zIHRoZW1lLCBhZGQtb24g
YW5kIG1peGVkIGNvbmZpZ3VyYXRpb25zLCBpbmNsdWRpbmcgeW91ciBvd24NCiBlY2hvIHJlcG9z
aXRvcnkgZW50cmllcyBhbmQgYXV0by11cGRhdGUgc2V0dGluZ3MuDQogZWNoby4NCiBlY2hvIFRo
ZSBzYW1lIGNvbnRlbnQgYXMgb3B0aW9uIFs1XSBpcyB0aGVuIHJlbW92ZWQuDQogZWNobyBZb3Vy
IG93biBmaWxlcyBpbnNpZGUgbWFuYWdlZCBmb2xkZXJzIHdpbGwgYWxzbyBiZSBkZWxldGVkLg0K
IGVjaG8uDQogZWNobyBbT10gT3BlbiBhZmZlY3RlZCBmb2xkZXJzDQogZWNobyBbQ10gRXhwb3J0
IGFuZCBjb250aW51ZSB0byBmaW5hbCBjb25maXJtYXRpb24NCiBlY2hvIFtOXSBDYW5jZWwNCiBz
ZXQgL3AgIkFOUz1TZWxlY3Rpb246ICINCiBpZiAvSSAiIUFOUyEiPT0iTyIgY2FsbCA6b3Blbl9h
ZmZlY3RlZCAmIHBhdXNlICYgZ290byB3YXJuX2V4cG9ydF9hbGwNCiBpZiAvSSBub3QgIiFBTlMh
Ij09IkMiIGV4aXQgL2IgMQ0KIGVjaG8uDQogc2V0IC9wICJDT05GPVR5cGUgRVhQT1JUIENPTkZJ
R1MgZXhhY3RseSB0byBjb25maXJtOiAiDQogaWYgL0kgbm90ICIhQ09ORiEiPT0iRVhQT1JUIENP
TkZJR1MiIGV4aXQgL2IgMQ0KKQ0KZXhpdCAvYiAwDQoNCjpleHBvcnRfc291cmNlcw0KaWYgbm90
IGV4aXN0ICIlU09VUkNFUyUiIGV4aXQgL2IgMQ0KZm9yIC9mICJ1c2ViYWNrcSBkZWxpbXM9IiAl
JVQgaW4gKGBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLUNvbW1hbmQgIkdldC1E
YXRlIC1Gb3JtYXQgJ3l5eXlNTWRkLUhIbW1zcyciYCkgZG8gc2V0ICJUUz0lJVQiDQpzZXQgIk9V
VFpJUD0lUFJPSkVDVF9ESVIlXEFCSC1zb3VyY2UtY29uZmlnLWJhY2t1cC0lVFMlLnppcCINCnNl
dCAiQUJIX0VYUE9SVF9TUkM9JVNPVVJDRVMlIg0Kc2V0ICJBQkhfRVhQT1JUX1pJUD0lT1VUWklQ
JSINCnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5
cGFzcyAtQ29tbWFuZCAiJHRtcD1Kb2luLVBhdGggJGVudjpURU1QICgnYWJoLXNvdXJjZS1leHBv
cnQtJytbZ3VpZF06Ok5ld0d1aWQoKSk7TmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtRm9y
Y2UgLVBhdGggKEpvaW4tUGF0aCAkdG1wICdzb3VyY2VzJyl8T3V0LU51bGw7Q29weS1JdGVtIC1Q
YXRoICgkZW52OkFCSF9FWFBPUlRfU1JDKydcKicpIC1EZXN0aW5hdGlvbiAoSm9pbi1QYXRoICR0
bXAgJ3NvdXJjZXMnKSAtUmVjdXJzZSAtRm9yY2U7QCgnQXNlcHJpdGUgQnVpbGQgSGVscGVyIFNv
dXJjZSBDb25maWd1cmF0aW9uIEJhY2t1cCcsJ0NyZWF0ZWQ6ICcrKEdldC1EYXRlIC1Gb3JtYXQg
J3l5eXktTU0tZGQgSEg6bW06c3MnKSwnQ29udGFpbnMgc291cmNlIElOSSBmaWxlcyBvbmx5LiBO
byByZXBvc2l0b3JpZXMgb3IgYmluYXJpZXMgYXJlIGluY2x1ZGVkLicpfFNldC1Db250ZW50IC1M
aXRlcmFsUGF0aCAoSm9pbi1QYXRoICR0bXAgJ2JhY2t1cC1pbmZvLnR4dCcpIC1FbmNvZGluZyBV
VEY4O0NvbXByZXNzLUFyY2hpdmUgLVBhdGggKCR0bXArJ1wqJykgLURlc3RpbmF0aW9uUGF0aCAk
ZW52OkFCSF9FWFBPUlRfWklQIC1Gb3JjZTtSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJHRtcCAt
UmVjdXJzZSAtRm9yY2UiID5udWwgMj4mMQ0KaWYgbm90IGV4aXN0ICIlT1VUWklQJSIgZXhpdCAv
YiAxDQppZiAvSSAiJUxBTkdVQUdFJSI9PSJkZSIgKGVjaG8gUXVlbGxlbi1Lb25maWd1cmF0aW9u
ZW4gZ2VzaWNoZXJ0OiAlT1VUWklQJSkgZWxzZSAoZWNobyBTb3VyY2UgY29uZmlndXJhdGlvbnMg
ZXhwb3J0ZWQ6ICVPVVRaSVAlKQ0KZXhpdCAvYiAwDQoNCjpvcGVuX2FmZmVjdGVkDQppZiBleGlz
dCAiJVJPT1QlIiBzdGFydCAiIiBleHBsb3Jlci5leGUgIiVST09UJSINCmlmIGV4aXN0ICIlQVBQ
X0FTRSVcZXh0ZW5zaW9ucyIgc3RhcnQgIiIgZXhwbG9yZXIuZXhlICIlQVBQX0FTRSVcZXh0ZW5z
aW9ucyINCmlmIGV4aXN0ICIlQVBQX0FTRSVcc2NyaXB0cyIgc3RhcnQgIiIgZXhwbG9yZXIuZXhl
ICIlQVBQX0FTRSVcc2NyaXB0cyINCmlmIGV4aXN0ICIlQUJIX0RJUiUiIHN0YXJ0ICIiIGV4cGxv
cmVyLmV4ZSAiJUFCSF9ESVIlIg0KZXhpdCAvYiAwDQoNCjpyZW1vdmVfc2hvcnRjdXRzDQpkZWwg
L3EgIiVERVNLVE9QJVxBc2Vwcml0ZS5sbmsiID5udWwgMj4mMQ0KZGVsIC9xICIlREVTS1RPUCVc
QXNlcHJpdGUgQnVpbGQgVXBkYXRlci5sbmsiID5udWwgMj4mMQ0KcmVtIExlZ2FjeSBzaG9ydGN1
dHMgZnJvbSBBQkggdjEuMSBhbmQgZWFybGllci4NCmRlbCAvcSAiJURFU0tUT1AlXEFzZXByaXRl
IC0gRm9yY2UgVXBkYXRlIENoZWNrLmxuayIgPm51bCAyPiYxDQpkZWwgL3EgIiVERVNLVE9QJVxB
c2Vwcml0ZSBCdWlsZCBIZWxwZXIgLSBVbmluc3RhbGwubG5rIiA+bnVsIDI+JjENCmV4aXQgL2Ig
MA0KDQo6cmVtb3ZlX21hbmFnZWRfY29udGVudA0KcG93ZXJzaGVsbC5leGUgLU5vTG9nbyAtTm9Q
cm9maWxlIC1FeGVjdXRpb25Qb2xpY3kgQnlwYXNzIC1Db21tYW5kICIkZmlsZXM9QCgnJU1BTklG
RVNUJVxtYW5hZ2VkLXRoZW1lLWV4dGVuc2lvbnMudHh0JywnJU1BTklGRVNUJVxtYW5hZ2VkLWFk
ZG9uLWV4dGVuc2lvbnMudHh0Jyk7Zm9yZWFjaCgkZiBpbiAkZmlsZXMpe2lmKFRlc3QtUGF0aCAt
TGl0ZXJhbFBhdGggJGYpe0dldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkZnxGb3JFYWNoLU9iamVj
dHtpZigkXyAtYW5kIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRfKSl7UmVtb3ZlLUl0ZW0gLUxp
dGVyYWxQYXRoICRfIC1SZWN1cnNlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51
ZX19fX0iID5udWwgMj4mMQ0KaWYgZXhpc3QgIiVBRERPTl9TQ1JJUFRTJSIgcm1kaXIgL3MgL3Eg
IiVBRERPTl9TQ1JJUFRTJSINCmlmIGV4aXN0ICIlTE9DQUxfU0NSSVBUUyUiIHJtZGlyIC9zIC9x
ICIlTE9DQUxfU0NSSVBUUyUiDQpleGl0IC9iIDANCg0KOnNlbGZfcmVtb3ZlX2FiaGRpcmVjdG9y
eQ0Kc2V0ICJUQVJHRVQ9JUFCSF9ESVIlIg0Kc3RhcnQgIiIgL2IgY21kLmV4ZSAvZCAvYyAicGlu
ZyAxMjcuMC4wLjEgLW4gMyBePm51bCBeJiBybWRpciAvcyAvcSBcIiVUQVJHRVQlXCIiDQpleGl0
IC9iIDANCg0KOnByZXNlcnZlX2NvbmZpZ3NfYW5kX2JhY2t1cHMNCnNldCAiVE1QS0VFUD0lVEVN
UCVcQUJILWtlZXAtJVJBTkRPTSUlUkFORE9NJSINCm1rZGlyICIhVE1QS0VFUCEiID5udWwgMj4m
MQ0KaWYgZXhpc3QgIiVCQUNLVVBTJSIgbW92ZSAiJUJBQ0tVUFMlIiAiIVRNUEtFRVAhXGJhY2t1
cHMiID5udWwgMj4mMQ0KaWYgZXhpc3QgIiVDT05GSUclIiBtb3ZlICIlQ09ORklHJSIgIiFUTVBL
RUVQIVxjb25maWciID5udWwgMj4mMQ0KZXhpdCAvYiAwDQoNCjpyZXN0b3JlX3ByZXNlcnZlZA0K
aWYgbm90IGRlZmluZWQgVE1QS0VFUCBleGl0IC9iIDANCnN0YXJ0ICIiIC9iIGNtZC5leGUgL2Qg
L2MgInBpbmcgMTI3LjAuMC4xIC1uIDQgXj5udWwgXiYgbWtkaXIgXCIlQUJIX0RJUiVcIiAyXj5u
dWwgXiYgaWYgZXhpc3QgXCIhVE1QS0VFUCFcYmFja3Vwc1wiIG1vdmUgXCIhVE1QS0VFUCFcYmFj
a3Vwc1wiIFwiJUFCSF9ESVIlXGJhY2t1cHNcIiBePm51bCAyXj5eJjEgXiYgaWYgZXhpc3QgXCIh
VE1QS0VFUCFcY29uZmlnXCIgbW92ZSBcIiFUTVBLRUVQIVxjb25maWdcIiBcIiVBQkhfRElSJVxj
b25maWdcIiBePm51bCAyXj5eJjEgXiYgcm1kaXIgL3MgL3EgXCIhVE1QS0VFUCFcIiINCmV4aXQg
L2IgMA0KDQo6b3B0MQ0KY2FsbCA6d2Fybl9ydW50aW1lDQppZiBlcnJvcmxldmVsIDEgZ290byBt
ZW51DQpjYWxsIDpwcmVzZXJ2ZV9jb25maWdzX2FuZF9iYWNrdXBzDQpjYWxsIDpzZWxmX3JlbW92
ZV9hYmhkaXJlY3RvcnkNCmNhbGwgOnJlc3RvcmVfcHJlc2VydmVkDQpleGl0IC9iIDANCg0KOm9w
dDINCmNhbGwgOndhcm5fcnVudGltZQ0KaWYgZXJyb3JsZXZlbCAxIGdvdG8gbWVudQ0KY2FsbCA6
cmVtb3ZlX3Nob3J0Y3V0cw0KY2FsbCA6cHJlc2VydmVfY29uZmlnc19hbmRfYmFja3Vwcw0KY2Fs
bCA6c2VsZl9yZW1vdmVfYWJoZGlyZWN0b3J5DQpjYWxsIDpyZXN0b3JlX3ByZXNlcnZlZA0KZXhp
dCAvYiAwDQoNCjpvcHQzDQpjYWxsIDp3YXJuX3J1bnRpbWUNCmlmIGVycm9ybGV2ZWwgMSBnb3Rv
IG1lbnUNCmNhbGwgOnJlbW92ZV9zaG9ydGN1dHMNCmNhbGwgOnNlbGZfcmVtb3ZlX2FiaGRpcmVj
dG9yeQ0KZXhpdCAvYiAwDQoNCjpvcHQ0DQpjYWxsIDp3YXJuX3NvdXJjZQ0KaWYgZXJyb3JsZXZl
bCAxIGdvdG8gbWVudQ0KaWYgZXhpc3QgIiVST09UJSIgcm1kaXIgL3MgL3EgIiVST09UJSINCmlm
IC9JICIlTEFOR1VBR0UlIj09ImRlIiAoZWNobyBBc2Vwcml0ZSBTb3VyY2UvQnVpbGQgd3VyZGUg
ZW50ZmVybnQuKSBlbHNlIChlY2hvIEFzZXByaXRlIHNvdXJjZS9idWlsZCB3YXMgcmVtb3ZlZC4p
DQpwYXVzZQ0KZ290byBtZW51DQoNCjpvcHQ1DQpjYWxsIDp3YXJuX2FsbA0KaWYgZXJyb3JsZXZl
bCAxIGdvdG8gbWVudQ0KY2FsbCA6cmVtb3ZlX3Nob3J0Y3V0cw0KY2FsbCA6cmVtb3ZlX21hbmFn
ZWRfY29udGVudA0KaWYgZXhpc3QgIiVST09UJSIgcm1kaXIgL3MgL3EgIiVST09UJSINCmNhbGwg
OnNlbGZfcmVtb3ZlX2FiaGRpcmVjdG9yeQ0KZXhpdCAvYiAwDQoNCjpvcHQ2DQpjYWxsIDp3YXJu
X2V4cG9ydF9hbGwNCmlmIGVycm9ybGV2ZWwgMSBnb3RvIG1lbnUNCmNhbGwgOmV4cG9ydF9zb3Vy
Y2VzDQppZiBlcnJvcmxldmVsIDEgKA0KIGlmIC9JICIlTEFOR1VBR0UlIj09ImRlIiAoZWNobyBG
RUhMRVI6IERpZSBRdWVsbGVuLUtvbmZpZ3VyYXRpb25lbiBrb25udGVuIG5pY2h0IGV4cG9ydGll
cnQgd2VyZGVuLikgZWxzZSAoZWNobyBFUlJPUjogU291cmNlIGNvbmZpZ3VyYXRpb25zIGNvdWxk
IG5vdCBiZSBleHBvcnRlZC4pDQogcGF1c2UNCiBnb3RvIG1lbnUNCikNCmNhbGwgOnJlbW92ZV9z
aG9ydGN1dHMNCmNhbGwgOnJlbW92ZV9tYW5hZ2VkX2NvbnRlbnQNCmlmIGV4aXN0ICIlUk9PVCUi
IHJtZGlyIC9zIC9xICIlUk9PVCUiDQpjYWxsIDpzZWxmX3JlbW92ZV9hYmhkaXJlY3RvcnkNCmV4
aXQgL2IgMA0K
###END:uninstall-abh.bat.b64###

###BEGIN:aseprite-build-updater.bat.b64###
QGVjaG8gb2ZmDQpjaGNwIDY1MDAxID5udWwNCnNldGxvY2FsIEVuYWJsZUV4dGVuc2lvbnMgRW5h
YmxlRGVsYXllZEV4cGFuc2lvbg0KDQpyZW0gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KcmVtIEFzZXBy
aXRlIEJ1aWxkIFVwZGF0ZXIgLSBnZW5lcmF0ZWQgYnkgQXNlcHJpdGUgQnVpbGQgSGVscGVyDQpy
ZW0gUHJvamVjdDogaHR0cHM6Ly9naXRodWIuY29tL3R2ZXR6aW8vYXNlcHJpdGUtYnVpbGQtaGVs
cGVyDQpyZW0gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KDQpzZXQgIlVQREFURVJfVkVSU0lPTj0xLjMu
MTAiDQpzZXQgIlBST0pFQ1RfVVJMPWh0dHBzOi8vZ2l0aHViLmNvbS90dmV0emlvL2FzZXByaXRl
LWJ1aWxkLWhlbHBlciINCnNldCAiQVBJX0xBVEVTVD1odHRwczovL2FwaS5naXRodWIuY29tL3Jl
cG9zL3R2ZXR6aW8vYXNlcHJpdGUtYnVpbGQtaGVscGVyL3JlbGVhc2VzL2xhdGVzdCINCmZvciAl
JUkgaW4gKCIlfmRwMC4uIikgZG8gc2V0ICJBQkhfRElSPSUlfmZJIg0KZm9yICUlSSBpbiAoIiVB
QkhfRElSJVwuLiIpIGRvIHNldCAiUFJPSkVDVF9ESVI9JSV+ZkkiDQpzZXQgIkJVSUxERVI9JVBS
T0pFQ1RfRElSJVxhc2Vwcml0ZS1idWlsZC1oZWxwZXIuYmF0Ig0Kc2V0ICJST09UPUM6XGFzZXBy
aXRlIg0Kc2V0ICJFWEU9JVJPT1QlXGJ1aWxkXGJpblxhc2Vwcml0ZS5leGUiDQpzZXQgIlNVUFBP
UlRfRElSPSVBQkhfRElSJVxzdXBwb3J0Ig0Kc2V0ICJVTklOU1RBTExFUj0lQUJIX0RJUiVcdW5p
bnN0YWxsZXJcdW5pbnN0YWxsLWFiaC5iYXQiDQpzZXQgIkNPTkZJR19ESVI9JUFCSF9ESVIlXGNv
bmZpZyINCnNldCAiU09VUkNFX0NPTkZJR19ESVI9JUNPTkZJR19ESVIlXHNvdXJjZXMiDQpzZXQg
IlNFVFRJTkdTX0ZJTEU9JUNPTkZJR19ESVIlXHNldHRpbmdzLmluaSINCnNldCAiU1RBVEVfRElS
PSVBQkhfRElSJVxzdGF0ZSINCnNldCAiVVNFUl9MT0dfRElSPSVBQkhfRElSJVxsb2dzXHVzZXIi
DQpzZXQgIkRFVl9MT0dfRElSPSVBQkhfRElSJVxsb2dzXGRldiINCnNldCAiUkVQT1JUX0RJUj0l
QUJIX0RJUiVccmVwb3J0cyINCnNldCAiQkFDS1VQX0RJUj0lQUJIX0RJUiVcYmFja3VwcyINCnNl
dCAiTUFOSUZFU1RfRElSPSVBQkhfRElSJVxtYW5pZmVzdCINCnNldCAiUFJPR1JFU1NfU0NSSVBU
PSVTVVBQT1JUX0RJUiVccHJvZ3Jlc3NfdWkucHMxIg0Kc2V0ICJQUk9HUkVTU19TVEFURT0lU1RB
VEVfRElSJVxwcm9ncmVzcy5zdGF0ZSINCnNldCAiVEhFTUVfU0NSSVBUPSVTVVBQT1JUX0RJUiVc
YXNlcHJpdGVfdGhlbWVzLnBzMSINCnNldCAiQURET05fU0NSSVBUPSVTVVBQT1JUX0RJUiVcYXNl
cHJpdGVfYWRkb25zLnBzMSINCnNldCAiTE9DQUxfVE9PTFNfU0NSSVBUPSVTVVBQT1JUX0RJUiVc
YXNlcHJpdGVfbG9jYWxfdG9vbHMucHMxIg0Kc2V0ICJTT1VSQ0VfQ09ORklHX1NDUklQVD0lU1VQ
UE9SVF9ESVIlXHNvdXJjZV9jb25maWcucHMxIg0Kc2V0ICJVUERBVEVfU1RBTVA9JVNUQVRFX0RJ
UiVcbGFzdF9hc2Vwcml0ZV9jaGVjay50eHQiDQpzZXQgIlRIRU1FX1NUQU1QPSVTVEFURV9ESVIl
XGxhc3RfdGhlbWVfY2hlY2sudHh0Ig0Kc2V0ICJBRERPTl9TVEFNUD0lU1RBVEVfRElSJVxsYXN0
X2FkZG9uX2NoZWNrLnR4dCINCnNldCAiU0VMRl9TVEFNUD0lU1RBVEVfRElSJVxsYXN0X2FiaF9j
aGVjay50eHQiDQpzZXQgIlNFTEZfQVZBSUxBQkxFPSVTVEFURV9ESVIlXGFiaC11cGRhdGUtYXZh
aWxhYmxlLnR4dCINCnNldCAiTE9HPSVVU0VSX0xPR19ESVIlXGFiaC11cGRhdGVyLmxvZyINCnNl
dCAiQUJIX0RBVEFfUk9PVD0lQUJIX0RJUiUiDQpzZXQgIlVQREFURVJfVkVSU0lPTl9FTlY9JVVQ
REFURVJfVkVSU0lPTiUiDQoNCm1rZGlyICIlU1RBVEVfRElSJSIgIiVVU0VSX0xPR19ESVIlIiAi
JURFVl9MT0dfRElSJSIgIiVSRVBPUlRfRElSJSIgIiVCQUNLVVBfRElSJSIgIiVDT05GSUdfRElS
JSIgIiVTT1VSQ0VfQ09ORklHX0RJUiUiID5udWwgMj4mMQ0KDQpzZXQgIlVJX0xBTkc9Ig0Kc2V0
ICJNT0RFX1NDSEVEVUxFRD0wIg0Kc2V0ICJNT0RFX0xBVU5DSD0wIg0Kc2V0ICJNT0RFX0ZPUkNF
PTAiDQpmb3IgJSVBIGluICglKikgZG8gKA0KICBpZiAvSSAiJSV+QSI9PSItLXNjaGVkdWxlZCIg
c2V0ICJNT0RFX1NDSEVEVUxFRD0xIg0KICBpZiAvSSAiJSV+QSI9PSItLWxhdW5jaCIgc2V0ICJN
T0RFX0xBVU5DSD0xIg0KICBpZiAvSSAiJSV+QSI9PSItLWZvcmNlIiBzZXQgIk1PREVfRk9SQ0U9
MSINCiAgaWYgL0kgIiUlfkEiPT0iLS1sYW5nPWRlIiBzZXQgIlVJX0xBTkc9ZGUiDQogIGlmIC9J
ICIlJX5BIj09Ii0tbGFuZz1lbiIgc2V0ICJVSV9MQU5HPWVuIg0KKQ0KaWYgbm90IGRlZmluZWQg
VUlfTEFORyBmb3IgL2YgInVzZWJhY2txIGRlbGltcz0iICUlTCBpbiAoYHBvd2Vyc2hlbGwuZXhl
IC1Ob0xvZ28gLU5vUHJvZmlsZSAtQ29tbWFuZCAiJGM9KEdldC1VSUN1bHR1cmUpLk5hbWU7IGlm
KCRjIC1saWtlICdkZS0qJyl7J2RlJ31lbHNleydlbid9ImApIGRvIHNldCAiVUlfTEFORz0lJUwi
DQppZiBub3QgZGVmaW5lZCBVSV9MQU5HIHNldCAiVUlfTEFORz1lbiINCg0KY2FsbCA6bG9hZF9z
ZXR0aW5ncw0KY2FsbCA6bG9nICJTVEFSVCB1cGRhdGVyPSVVUERBVEVSX1ZFUlNJT04lIGFyZ3M9
JSoiDQoNCmlmICIlTU9ERV9TQ0hFRFVMRUQlIj09IjEiIGdvdG8gc2NoZWR1bGVkDQppZiAiJU1P
REVfRk9SQ0UlIj09IjEiIGdvdG8gZm9yY2VfYWxsDQoNCmdvdG8gbWVudQ0KDQo6c2NoZWR1bGVk
DQpzZXQgIkFOWV9EVUU9MCINCmNhbGwgOmlzX2R1ZSAiJVNFTEZfU1RBTVAlIiAlVVBEQVRFX0lO
VEVSVkFMX0hPVVJTJQ0KaWYgZXJyb3JsZXZlbCAxIHNldCAiQU5ZX0RVRT0xIg0KY2FsbCA6aXNf
ZHVlICIlVVBEQVRFX1NUQU1QJSIgJVVQREFURV9JTlRFUlZBTF9IT1VSUyUNCmlmIGVycm9ybGV2
ZWwgMSBzZXQgIkFOWV9EVUU9MSINCmNhbGwgOmlzX2R1ZSAiJVRIRU1FX1NUQU1QJSIgJVVQREFU
RV9JTlRFUlZBTF9IT1VSUyUNCmlmIGVycm9ybGV2ZWwgMSBzZXQgIkFOWV9EVUU9MSINCmNhbGwg
OmlzX2R1ZSAiJUFERE9OX1NUQU1QJSIgJVVQREFURV9JTlRFUlZBTF9IT1VSUyUNCmlmIGVycm9y
bGV2ZWwgMSBzZXQgIkFOWV9EVUU9MSINCmlmICIlQU5ZX0RVRSUiPT0iMSIgKA0KICBjYWxsIDpw
cm9ncmVzc19zdGFydA0KICBjYWxsIDpwcm9ncmVzc191cGRhdGUgOCBjaGVjayAiMS80IiAiQ2hl
Y2tpbmcgQUJIIHVwZGF0ZXMuLi4iDQogIGNhbGwgOmNoZWNrX3NlbGZfdXBkYXRlIDANCiAgY2Fs
bCA6cHJvZ3Jlc3NfdXBkYXRlIDI4IGFzZXByaXRlICIyLzQiICJDaGVja2luZyBBc2Vwcml0ZSB1
cGRhdGVzLi4uIg0KICBjYWxsIDpjaGVja19hc2Vwcml0ZV9pZl9kdWUNCiAgY2FsbCA6cHJvZ3Jl
c3NfdXBkYXRlIDU4IHRoZW1lICIzLzQiICJDaGVja2luZyB0aGVtZXMuLi4iDQogIGNhbGwgOnN5
bmNfdGhlbWVzX2lmX2R1ZQ0KICBjYWxsIDpwcm9ncmVzc191cGRhdGUgODAgYWRkb24gIjQvNCIg
IkNoZWNraW5nIGFkZC1vbnMgYW5kIHNjcmlwdHMuLi4iDQogIGNhbGwgOnN5bmNfYWRkb25zX2lm
X2R1ZQ0KICBjYWxsIDpwcm9ncmVzc191cGRhdGUgMTAwIHN1Y2Nlc3MgIjQvNCIgIlVwZGF0ZSBj
aGVjayBjb21wbGV0ZWQuIg0KICBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLUNv
bW1hbmQgIlN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgNDUwIiA+bnVsIDI+JjENCiAgY2FsbCA6
cHJvZ3Jlc3Nfc3RvcA0KKQ0KaWYgIiVNT0RFX0xBVU5DSCUiPT0iMSIgY2FsbCA6bGF1bmNoX2Fz
ZXByaXRlDQpleGl0IC9iIDANCg0KOmZvcmNlX2FsbA0KY2FsbCA6cnVuX2FsbF91cGRhdGVzIDEN
CmV4aXQgL2IgJWVycm9ybGV2ZWwlDQoNCjptZW51DQpjbHMNCmlmIC9JICIlVUlfTEFORyUiPT0i
ZGUiICgNCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PQ0KIGVjaG8gICBBc2Vwcml0ZSBCdWlsZCBVcGRhdGVyIHYlVVBEQVRF
Ul9WRVJTSU9OJQ0KIGVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09DQogZWNoby4NCiBlY2hvIFsxXSBBbGxlIFVwZGF0ZXMgamV0
enQgcHLDvGZlbg0KIGVjaG8gWzJdIE51ciBBQkgtU2VsZi1VcGRhdGUgcHLDvGZlbg0KIGVjaG8g
WzNdIE51ciBBc2Vwcml0ZS1VcGRhdGUgcHLDvGZlbg0KIGVjaG8gWzRdIFRoZW1lcyAvIEFkZC1v
bnMgLyBTa3JpcHRlIHN5bmNocm9uaXNpZXJlbg0KIGVjaG8gWzVdIFN0YXR1cyBhbnplaWdlbg0K
IGVjaG8gWzZdIFJlcGFyYXR1ciAvIG5ldSBzeW5jaHJvbmlzaWVyZW4NCiBlY2hvIFs3XSBVcGRh
dGUtSW50ZXJ2YWxsIMOkbmRlcm4NCiBlY2hvIFs4XSBRdWVsbGVuLUtvbmZpZ3VyYXRpb25lbiDD
tmZmbmVuDQogZWNobyBbOV0gQXNlcHJpdGUtS29uZmlndXJhdGlvbiBzaWNoZXJuDQogZWNobyBb
QV0gTmV1ZXN0ZXMgS29uZmlndXJhdGlvbnMtQmFja3VwIHdpZWRlcmhlcnN0ZWxsZW4NCiBlY2hv
IFtMXSBMb2dzIMO2ZmZuZW4NCiBlY2hvIFtNXSBWb24gQUJIIHZlcndhbHRldGUgRGF0ZWllbiB1
bmQgT3JkbmVyIGFuemVpZ2VuDQogZWNobyBbRF0gRGlhZ25vc2VwYWtldCBmw7xyIEJ1Z3JlcG9y
dCBlcnN0ZWxsZW4NCiBlY2hvIFtSXSBCdWcgbWVsZGVuDQogZWNobyBbVV0gRGVpbnN0YWxsaWVy
ZW4NCiBlY2hvIFswXSBCZWVuZGVuDQogZWNoby4NCiBzZXQgL3AgIlNFTD1BdXN3YWhsOiAiDQop
IGVsc2UgKA0KIGVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09DQogZWNobyAgIEFzZXByaXRlIEJ1aWxkIFVwZGF0ZXIgdiVVUERB
VEVSX1ZFUlNJT04lDQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT0NCiBlY2hvLg0KIGVjaG8gWzFdIENoZWNrIGFsbCB1cGRh
dGVzIG5vdw0KIGVjaG8gWzJdIENoZWNrIEFCSCBzZWxmLXVwZGF0ZSBvbmx5DQogZWNobyBbM10g
Q2hlY2sgQXNlcHJpdGUgdXBkYXRlIG9ubHkNCiBlY2hvIFs0XSBTeW5jIHRoZW1lcyAvIGFkZC1v
bnMgLyBzY3JpcHRzDQogZWNobyBbNV0gU2hvdyBzdGF0dXMNCiBlY2hvIFs2XSBSZXBhaXIgLyBy
ZXN5bmMNCiBlY2hvIFs3XSBDaGFuZ2UgdXBkYXRlIGludGVydmFsDQogZWNobyBbOF0gT3BlbiBz
b3VyY2UgY29uZmlndXJhdGlvbnMNCiBlY2hvIFs5XSBCYWNrIHVwIEFzZXByaXRlIGNvbmZpZ3Vy
YXRpb24NCiBlY2hvIFtBXSBSZXN0b3JlIG5ld2VzdCBjb25maWd1cmF0aW9uIGJhY2t1cA0KIGVj
aG8gW0xdIE9wZW4gbG9ncw0KIGVjaG8gW01dIFNob3cgZmlsZXMgYW5kIGZvbGRlcnMgbWFuYWdl
ZCBieSBBQkgNCiBlY2hvIFtEXSBFeHBvcnQgZGlhZ25vc3RpYyBwYWNrYWdlIGZvciBhIGJ1ZyBy
ZXBvcnQNCiBlY2hvIFtSXSBSZXBvcnQgYSBidWcNCiBlY2hvIFtVXSBVbmluc3RhbGwNCiBlY2hv
IFswXSBFeGl0DQogZWNoby4NCiBzZXQgL3AgIlNFTD1TZWxlY3Rpb246ICINCikNCmlmICIlU0VM
JSI9PSIwIiBleGl0IC9iIDANCmlmICIlU0VMJSI9PSIxIiAoDQogIGNhbGwgOnJ1bl9hbGxfdXBk
YXRlcyAxDQogIGlmICIhU0VMRl9VUERBVEVfU1RBUlRFRCEiPT0iMSIgZXhpdCAvYiAwDQogIHBh
dXNlDQogIGdvdG8gbWVudQ0KKQ0KaWYgIiVTRUwlIj09IjIiICgNCiAgY2FsbCA6Y2hlY2tfc2Vs
Zl91cGRhdGUgMQ0KICBpZiAiIVNFTEZfVVBEQVRFX1NUQVJURUQhIj09IjEiIGV4aXQgL2IgMA0K
ICBwYXVzZQ0KICBnb3RvIG1lbnUNCikNCmlmICIlU0VMJSI9PSIzIiAoDQogIGNhbGwgOnByb2dy
ZXNzX3N0YXJ0DQogIGNhbGwgOnByb2dyZXNzX3VwZGF0ZSAyMCBhc2Vwcml0ZSAiQXNlcHJpdGUi
ICJDaGVja2luZyBBc2Vwcml0ZSB1cGRhdGVzLi4uIg0KICBjYWxsIDpjaGVja19hc2Vwcml0ZV9m
b3JjZQ0KICBjYWxsIDpwcm9ncmVzc191cGRhdGUgMTAwIHN1Y2Nlc3MgIkFzZXByaXRlIiAiVXBk
YXRlIGNoZWNrIGNvbXBsZXRlZC4iDQogIGNhbGwgOnByb2dyZXNzX3N0b3ANCiAgcGF1c2UNCiAg
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
bmRzIDQ1MCIgPm51bCAyPiYxDQpjYWxsIDpwcm9ncmVzc19zdG9wDQpleGl0IC9iIDANCg0KOmNo
ZWNrX3NlbGZfdXBkYXRlDQpzZXQgIklOVEVSQUNUSVZFPSV+MSINCnNldCAiU0VMRl9VUERBVEVf
U1RBUlRFRD0wIg0Kc2V0ICJMQVRFU1RfQUJIPSINCnNldCAiTEFURVNUX0FTU0VUPSINCnNldCAi
QUJIX0NVUlJFTlRfVkVSU0lPTj0lVVBEQVRFUl9WRVJTSU9OJSINCnNldCAiQUJIX0FQST0lQVBJ
X0xBVEVTVCUiDQpmb3IgL2YgInVzZWJhY2txIHRva2Vucz0xLCogZGVsaW1zPXwiICUlQSBpbiAo
YHBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5cGFz
cyAtQ29tbWFuZCAiJEVycm9yQWN0aW9uUHJlZmVyZW5jZT0nU3RvcCc7dHJ5eyRoPUB7J1VzZXIt
QWdlbnQnPSdBc2Vwcml0ZS1CdWlsZC1IZWxwZXInfTskcj1JbnZva2UtUmVzdE1ldGhvZCAtVXJp
ICRlbnY6QUJIX0FQSSAtSGVhZGVycyAkaCAtVGltZW91dFNlYyAxNTskdGFnPVtzdHJpbmddJHIu
dGFnX25hbWU7JHY9JHRhZy5UcmltU3RhcnQoJ3YnKTskYT0kci5hc3NldHN8V2hlcmUtT2JqZWN0
eyRfLm5hbWUgLW1hdGNoICdeYWJoLXdpbjY0LXYuKlwuemlwJCd9fFNlbGVjdC1PYmplY3QgLUZp
cnN0IDE7aWYoLW5vdCAkYSl7ZXhpdCA0fTtXcml0ZS1PdXRwdXQgKCR2Kyd8JyskYS5icm93c2Vy
X2Rvd25sb2FkX3VybCl9Y2F0Y2h7ZXhpdCAzfSJgKSBkbyAoDQogIHNldCAiTEFURVNUX0FCSD0l
JUEiDQogIHNldCAiTEFURVNUX0FTU0VUPSUlQiINCikNCj4iJVNFTEZfU1RBTVAlIiBlY2hvICVk
YXRlJSAldGltZSUNCmlmIG5vdCBkZWZpbmVkIExBVEVTVF9BQkggKA0KICBjYWxsIDpsb2cgIkFC
SCBzZWxmLXVwZGF0ZSBjaGVjayB1bmF2YWlsYWJsZS4iDQogIGlmICIlSU5URVJBQ1RJVkUlIj09
IjEiICgNCiAgICBpZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBBQkgtU2VsZi1VcGRhdGUg
a29ubnRlIGRlcnplaXQgbmljaHQgZ2VwcsO8ZnQgd2VyZGVuLikgZWxzZSAoZWNobyBBQkggc2Vs
Zi11cGRhdGUgY291bGQgbm90IGJlIGNoZWNrZWQgcmlnaHQgbm93LikNCiAgKQ0KICBleGl0IC9i
IDINCikNCnNldCAiQUJIX0xBVEVTVF9WRVJTSU9OPSVMQVRFU1RfQUJIJSINCnBvd2Vyc2hlbGwu
ZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtQ29tbWFuZCAidHJ5e2lmKFt2ZXJzaW9uXSRlbnY6QUJI
X0xBVEVTVF9WRVJTSU9OIC1ndCBbdmVyc2lvbl0kZW52OkFCSF9DVVJSRU5UX1ZFUlNJT04pe2V4
aXQgMX1lbHNle2V4aXQgMH19Y2F0Y2h7ZXhpdCAyfSIgPm51bCAyPiYxDQpzZXQgIkNNUD0lZXJy
b3JsZXZlbCUiDQppZiAiJUNNUCUiPT0iMCIgKA0KICBkZWwgL3EgIiVTRUxGX0FWQUlMQUJMRSUi
ID5udWwgMj4mMQ0KICBjYWxsIDpsb2cgIkFCSCBpcyB1cCB0byBkYXRlOiAlVVBEQVRFUl9WRVJT
SU9OJS4iDQogIGlmICIlSU5URVJBQ1RJVkUlIj09IjEiIGlmIC9JICIlVUlfTEFORyUiPT0iZGUi
IChlY2hvIEFCSCBpc3QgYWt0dWVsbDogdiVVUERBVEVSX1ZFUlNJT04lLikgZWxzZSAoZWNobyBB
QkggaXMgdXAgdG8gZGF0ZTogdiVVUERBVEVSX1ZFUlNJT04lLikNCiAgZXhpdCAvYiAwDQopDQpp
ZiBub3QgIiVDTVAlIj09IjEiIGV4aXQgL2IgMg0KPiIlU0VMRl9BVkFJTEFCTEUlIiBlY2hvICVM
QVRFU1RfQUJIJQ0KY2FsbCA6bG9nICJBQkggdXBkYXRlIGF2YWlsYWJsZTogJUxBVEVTVF9BQkgl
LiINCmlmICIlSU5URVJBQ1RJVkUlIj09IjAiIGV4aXQgL2IgMQ0KDQppZiAvSSAiJVVJX0xBTkcl
Ij09ImRlIiAoDQogIGVjaG8uDQogIGVjaG8gTmV1ZSBBQkgtVmVyc2lvbiBnZWZ1bmRlbjogdiVM
QVRFU1RfQUJIJSBeKGluc3RhbGxpZXJ0OiB2JVVQREFURVJfVkVSU0lPTiVeKQ0KICBlY2hvIERh
cyBVcGRhdGUgd2lyZCBhdXNzY2hsaWXDn2xpY2ggYXVzIGRlbSBvZmZpemllbGxlbiBHaXRIdWIt
UmVsZWFzZSBnZWxhZGVuLg0KICBlY2hvIElocmUgQUJILUtvbmZpZ3VyYXRpb25lbiwgUXVlbGxl
bi1JTklzLCBMb2dzIHVuZCBCYWNrdXBzIGJsZWliZW4gZXJoYWx0ZW4uDQogIGVjaG8gVm9yIGRl
bSBBdXN0YXVzY2ggd2VyZGVuIGRpZSBha3R1ZWxsZW4gUGFrZXRkYXRlaWVuIGdlc2ljaGVydC4N
CiAgZWNoby4NCiAgc2V0IC9wICJTRUxGQU5TPUpldHp0IGFrdHVhbGlzaWVyZW4/IFtZL05dOiAi
DQogIGlmIC9JIG5vdCAiIVNFTEZBTlMhIj09IlkiIGV4aXQgL2IgMQ0KKSBlbHNlICgNCiAgZWNo
by4NCiAgZWNobyBOZXcgQUJIIHZlcnNpb24gZm91bmQ6IHYlTEFURVNUX0FCSCUgXihpbnN0YWxs
ZWQ6IHYlVVBEQVRFUl9WRVJTSU9OJV4pDQogIGVjaG8gVGhlIHVwZGF0ZSBpcyBkb3dubG9hZGVk
IG9ubHkgZnJvbSB0aGUgb2ZmaWNpYWwgR2l0SHViIHJlbGVhc2UuDQogIGVjaG8gWW91ciBBQkgg
Y29uZmlndXJhdGlvbiwgc291cmNlIElOSXMsIGxvZ3MgYW5kIGJhY2t1cHMgYXJlIHByZXNlcnZl
ZC4NCiAgZWNobyBDdXJyZW50IHBhY2thZ2UgZmlsZXMgYXJlIGJhY2tlZCB1cCBiZWZvcmUgcmVw
bGFjZW1lbnQuDQogIGVjaG8uDQogIHNldCAvcCAiU0VMRkFOUz1VcGRhdGUgbm93PyBbWS9OXTog
Ig0KICBpZiAvSSBub3QgIiFTRUxGQU5TISI9PSJZIiBleGl0IC9iIDENCikNCmNhbGwgOnBlcmZv
cm1fc2VsZl91cGRhdGUNCmV4aXQgL2IgJWVycm9ybGV2ZWwlDQoNCjpwZXJmb3JtX3NlbGZfdXBk
YXRlDQpzZXQgIlNFTEZfVVBEQVRFX1NUQVJURUQ9MCINCmZvciAvZiAidXNlYmFja3EgZGVsaW1z
PSIgJSVUIGluIChgcG93ZXJzaGVsbC5leGUgLU5vTG9nbyAtTm9Qcm9maWxlIC1Db21tYW5kICJH
ZXQtRGF0ZSAtRm9ybWF0ICd5eXl5TU1kZC1ISG1tc3MnImApIGRvIHNldCAiVFM9JSVUIg0Kc2V0
ICJTRUxGX1RNUD0lVEVNUCVcYWJoLXNlbGYtdXBkYXRlLSVSQU5ET00lLSVSQU5ET00lIg0Kc2V0
ICJTRUxGX1pJUD0lU0VMRl9UTVAlXHVwZGF0ZS56aXAiDQpzZXQgIlNFTEZfRVhUUkFDVD0lU0VM
Rl9UTVAlXHBhY2thZ2UiDQpzZXQgIlNFTEZfQkFDS1VQPSVVUERBVEVSX0RJUiVcYmFja3VwXHYl
VVBEQVRFUl9WRVJTSU9OJS0lVFMlIg0KbWtkaXIgIiVTRUxGX1RNUCUiICIlU0VMRl9FWFRSQUNU
JSIgIiVTRUxGX0JBQ0tVUCUiID5udWwgMj4mMQ0Kc2V0ICJBQkhfREw9JUxBVEVTVF9BU1NFVCUi
DQpzZXQgIkFCSF9aSVA9JVNFTEZfWklQJSINCnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJv
ZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtQ29tbWFuZCAiJEVycm9yQWN0aW9uUHJlZmVy
ZW5jZT0nU3RvcCc7JGg9QHsnVXNlci1BZ2VudCc9J0FzZXByaXRlLUJ1aWxkLUhlbHBlcid9O0lu
dm9rZS1XZWJSZXF1ZXN0IC1VcmkgJGVudjpBQkhfREwgLUhlYWRlcnMgJGggLU91dEZpbGUgJGVu
djpBQkhfWklQIC1Vc2VCYXNpY1BhcnNpbmc7RXhwYW5kLUFyY2hpdmUgLUxpdGVyYWxQYXRoICRl
bnY6QUJIX1pJUCAtRGVzdGluYXRpb25QYXRoICclU0VMRl9FWFRSQUNUJScgLUZvcmNlOyRyZXE9
QCgnYXNlcHJpdGUtYnVpbGQtaGVscGVyLmJhdCcsJ1JFQURNRS5tZCcsJ0xJQ0VOU0UnLCdUSElS
RF9QQVJUWV9OT1RJQ0VTLm1kJyk7Zm9yZWFjaCgkbiBpbiAkcmVxKXtpZigtbm90KFRlc3QtUGF0
aCAtTGl0ZXJhbFBhdGggKEpvaW4tUGF0aCAnJVNFTEZfRVhUUkFDVCUnICRuKSkpe3Rocm93ICgn
TWlzc2luZyBwYWNrYWdlIGZpbGU6ICcrJG4pfX0iID4+IiVMT0clIiAyPiYxDQppZiBlcnJvcmxl
dmVsIDEgKA0KICBpZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBGRUhMRVI6IEFCSC1VcGRh
dGUga29ubnRlIG5pY2h0IGhlcnVudGVyZ2VsYWRlbiBvZGVyIGdlcHLDvGZ0IHdlcmRlbi4pIGVs
c2UgKGVjaG8gRVJST1I6IEFCSCB1cGRhdGUgY291bGQgbm90IGJlIGRvd25sb2FkZWQgb3IgdmFs
aWRhdGVkLikNCiAgcm1kaXIgL3MgL3EgIiVTRUxGX1RNUCUiID5udWwgMj4mMQ0KICBleGl0IC9i
IDENCikNCmZvciAlJUYgaW4gKGFzZXByaXRlLWJ1aWxkLWhlbHBlci5iYXQgUkVBRE1FLm1kIExJ
Q0VOU0UgVEhJUkRfUEFSVFlfTk9USUNFUy5tZCkgZG8gaWYgZXhpc3QgIiVQUk9KRUNUX0RJUiVc
JSVGIiBjb3B5IC95ICIlUFJPSkVDVF9ESVIlXCUlRiIgIiVTRUxGX0JBQ0tVUCVcJSVGIiA+bnVs
DQpzZXQgIkFQUExZX1BTPSVTRUxGX1RNUCVcYXBwbHktdXBkYXRlLnBzMSINCmlmIG5vdCBleGlz
dCAiJVNVUFBPUlRfRElSJVxzZWxmX3VwZGF0ZV9hcHBseS5wczEiICgNCiAgaWYgL0kgIiVVSV9M
QU5HJSI9PSJkZSIgKGVjaG8gRkVITEVSOiBJbnRlcm5lIFNlbGYtVXBkYXRlLUtvbXBvbmVudGUg
ZmVobHQuKSBlbHNlIChlY2hvIEVSUk9SOiBJbnRlcm5hbCBzZWxmLXVwZGF0ZSBjb21wb25lbnQg
aXMgbWlzc2luZy4pDQogIGV4aXQgL2IgMQ0KKQ0KY29weSAveSAiJVNVUFBPUlRfRElSJVxzZWxm
X3VwZGF0ZV9hcHBseS5wczEiICIlQVBQTFlfUFMlIiA+bnVsDQppZiBlcnJvcmxldmVsIDEgZXhp
dCAvYiAxDQpzdGFydCAiIiBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLVdpbmRv
d1N0eWxlIEhpZGRlbiAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtRmlsZSAiJUFQUExZX1BTJSIg
LVByb2plY3QgIiVQUk9KRUNUX0RJUiUiIC1OZXcgIiVTRUxGX0VYVFJBQ1QlIiAtQmFja3VwICIl
U0VMRl9CQUNLVVAlIiAtTGFuZyAiJVVJX0xBTkclIg0Kc2V0ICJTRUxGX1VQREFURV9TVEFSVEVE
PTEiDQppZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBBQkgtVXBkYXRlIHdpcmQgYW5nZXdl
bmRldC4gRGVyIFVwZGF0ZXIgc3RhcnRldCBhbnNjaGxpZcOfZW5kIG5ldS4pIGVsc2UgKGVjaG8g
QUJIIHVwZGF0ZSBpcyBiZWluZyBhcHBsaWVkLiBUaGUgdXBkYXRlciB3aWxsIHJlc3RhcnQgYWZ0
ZXJ3YXJkcy4pDQpleGl0IC9iIDANCg0KOmNoZWNrX2FzZXByaXRlX2lmX2R1ZQ0KY2FsbCA6aXNf
ZHVlICIlVVBEQVRFX1NUQU1QJSIgJVVQREFURV9JTlRFUlZBTF9IT1VSUyUNCmlmIG5vdCBlcnJv
cmxldmVsIDEgZXhpdCAvYiAwDQpjYWxsIDpjaGVja19hc2Vwcml0ZV9mb3JjZQ0KZXhpdCAvYiAl
ZXJyb3JsZXZlbCUNCg0KOmNoZWNrX2FzZXByaXRlX2ZvcmNlDQppZiBub3QgZXhpc3QgIiVCVUlM
REVSJSIgZXhpdCAvYiAyDQpkZWwgL3EgIiVVUERBVEVfU1RBTVAlIiA+bnVsIDI+JjENCmNhbGwg
IiVCVUlMREVSJSIgLS1hc2Vwcml0ZS11cGRhdGUgLS1sYW5nPSVVSV9MQU5HJQ0KZXhpdCAvYiAl
ZXJyb3JsZXZlbCUNCg0KOnN5bmNfdGhlbWVzX2lmX2R1ZQ0KY2FsbCA6aXNfZHVlICIlVEhFTUVf
U1RBTVAlIiAlVVBEQVRFX0lOVEVSVkFMX0hPVVJTJQ0KaWYgbm90IGVycm9ybGV2ZWwgMSBleGl0
IC9iIDANCmNhbGwgOnN5bmNfdGhlbWVzX2ZvcmNlDQpleGl0IC9iIDANCg0KOnN5bmNfYWRkb25z
X2lmX2R1ZQ0KY2FsbCA6aXNfZHVlICIlQURET05fU1RBTVAlIiAlVVBEQVRFX0lOVEVSVkFMX0hP
VVJTJQ0KaWYgbm90IGVycm9ybGV2ZWwgMSBleGl0IC9iIDANCmNhbGwgOnN5bmNfYWRkb25zX2Zv
cmNlDQpleGl0IC9iIDANCg0KOnN5bmNfdGhlbWVzX2ZvcmNlDQppZiBub3QgZXhpc3QgIiVUSEVN
RV9TQ1JJUFQlIiBleGl0IC9iIDANCnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAt
RXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtRmlsZSAiJVRIRU1FX1NDUklQVCUiID4+IiVMT0clIiAy
PiYxDQppZiBub3QgZXJyb3JsZXZlbCAxID4iJVRIRU1FX1NUQU1QJSIgZWNobyAlZGF0ZSUgJXRp
bWUlDQpleGl0IC9iIDANCg0KOnN5bmNfYWRkb25zX2ZvcmNlDQppZiBub3QgZXhpc3QgIiVBRERP
Tl9TQ1JJUFQlIiBleGl0IC9iIDANCnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAt
RXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtRmlsZSAiJUFERE9OX1NDUklQVCUiID4+IiVMT0clIiAy
PiYxDQppZiBub3QgZXJyb3JsZXZlbCAxID4iJUFERE9OX1NUQU1QJSIgZWNobyAlZGF0ZSUgJXRp
bWUlDQpleGl0IC9iIDANCg0KOnN5bmNfYWxsX3NvdXJjZXNfZm9yY2UNCmNhbGwgOnByb2dyZXNz
X3N0YXJ0DQpjYWxsIDpwcm9ncmVzc191cGRhdGUgMjAgdGhlbWUgIjEvMiIgIkNoZWNraW5nIHRo
ZW1lcy4uLiINCmNhbGwgOnN5bmNfdGhlbWVzX2ZvcmNlDQpjYWxsIDpwcm9ncmVzc191cGRhdGUg
NjUgYWRkb24gIjIvMiIgIkNoZWNraW5nIGFkZC1vbnMgYW5kIHNjcmlwdHMuLi4iDQpjYWxsIDpz
eW5jX2FkZG9uc19mb3JjZQ0KaWYgZXhpc3QgIiVMT0NBTF9UT09MU19TQ1JJUFQlIiBwb3dlcnNo
ZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLVdpbmRvd1N0eWxlIEhpZGRlbiAtRXhlY3V0aW9u
UG9saWN5IEJ5cGFzcyAtRmlsZSAiJUxPQ0FMX1RPT0xTX1NDUklQVCUiID4+IiVMT0clIiAyPiYx
DQpjYWxsIDpwcm9ncmVzc191cGRhdGUgMTAwIHN1Y2Nlc3MgIjIvMiIgIlVwZGF0ZSBjaGVjayBj
b21wbGV0ZWQuIg0KY2FsbCA6cHJvZ3Jlc3Nfc3RvcA0KZXhpdCAvYiAwDQoNCjpyZXBhaXINCmlm
IGV4aXN0ICIlU09VUkNFX0NPTkZJR19TQ1JJUFQlIiBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1O
b1Byb2ZpbGUgLUV4ZWN1dGlvblBvbGljeSBCeXBhc3MgLUZpbGUgIiVTT1VSQ0VfQ09ORklHX1ND
UklQVCUiIC1Sb290ICIlU09VUkNFX0NPTkZJR19ESVIlIiA+PiIlTE9HJSIgMj4mMQ0KaWYgZXhp
c3QgIiVMT0NBTF9UT09MU19TQ1JJUFQlIiBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2Zp
bGUgLVdpbmRvd1N0eWxlIEhpZGRlbiAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtRmlsZSAiJUxP
Q0FMX1RPT0xTX1NDUklQVCUiID4+IiVMT0clIiAyPiYxDQpjYWxsIDpzeW5jX3RoZW1lc19mb3Jj
ZQ0KY2FsbCA6c3luY19hZGRvbnNfZm9yY2UNCmlmIGV4aXN0ICIlQlVJTERFUiUiIGNhbGwgIiVC
VUlMREVSJSIgLS1yZWZyZXNoLXJ1bnRpbWUgLS1sYW5nPSVVSV9MQU5HJQ0KaWYgL0kgIiVVSV9M
QU5HJSI9PSJkZSIgKGVjaG8gUmVwYXJhdHVyIGFiZ2VzY2hsb3NzZW4uKSBlbHNlIChlY2hvIFJl
cGFpciBjb21wbGV0ZWQuKQ0KZXhpdCAvYiAwDQoNCjpzaG93X3N0YXR1cw0KY2FsbCA6bG9hZF9z
ZXR0aW5ncw0KZWNoby4NCmVjaG8gQUJIIC8gVXBkYXRlciB2ZXJzaW9uOiAlVVBEQVRFUl9WRVJT
SU9OJQ0KZWNobyBQcm9qZWN0IGZvbGRlcjogJVBST0pFQ1RfRElSJQ0KZWNobyBBQkggZGF0YTog
JUFCSF9ESVIlDQplY2hvIFVwZGF0ZSBpbnRlcnZhbDogJVVQREFURV9JTlRFUlZBTF9IT1VSUyUg
aG91cnMNCmlmIGV4aXN0ICIlRVhFJSIgKGVjaG8gQXNlcHJpdGU6IE9LKSBlbHNlIChlY2hvIEFz
ZXByaXRlOiBNSVNTSU5HKQ0Kc2V0ICJDVVJUQUc9dW5rbm93biINCmlmIGV4aXN0ICIlUk9PVCVc
LmdpdCIgZm9yIC9mICJkZWxpbXM9IiAlJVQgaW4gKCdnaXQgLUMgIiVST09UJSIgZGVzY3JpYmUg
LS10YWdzIC0tZXhhY3QtbWF0Y2ggSEVBRCAyXj5udWwnKSBkbyBzZXQgIkNVUlRBRz0lJVQiDQpl
Y2hvIEFzZXByaXRlIHRhZzogIUNVUlRBRyENCmlmIGV4aXN0ICIlU0VMRl9BVkFJTEFCTEUlIiAo
c2V0IC9wIEFWQUlMPTwiJVNFTEZfQVZBSUxBQkxFJSIgJiBlY2hvIEFCSCB1cGRhdGUgYXZhaWxh
YmxlOiB2IUFWQUlMISkgZWxzZSAoZWNobyBBQkggc2VsZi11cGRhdGU6IG5vIGtub3duIHBlbmRp
bmcgdXBkYXRlKQ0KZWNobyBMb2dzOiAlQUJIX0RJUiVcbG9ncw0KZXhpdCAvYiAwDQoNCjpzaG93
X21hbmFnZWQNCmlmIC9JICIlVUlfTEFORyUiPT0iZGUiICgNCiBlY2hvLg0KIGVjaG8gQUJILWVp
Z2VuZSBCZXJlaWNoZToNCikgZWxzZSAoDQogZWNoby4NCiBlY2hvIEFCSC1vd25lZCBsb2NhdGlv
bnM6DQopDQplY2hvICAgJUFCSF9ESVIlDQplY2hvICAgTGF1bmNoZXI6ICVBQkhfRElSJVxsYXVu
Y2hlcg0KZWNobyAgIFVwZGF0ZXI6ICVBQkhfRElSJVx1cGRhdGVyDQplY2hvICAgVW5pbnN0YWxs
ZXI6ICVBQkhfRElSJVx1bmluc3RhbGxlcg0KZWNobyAgIFNvdXJjZSBjb25maWd1cmF0aW9uczog
JVNPVVJDRV9DT05GSUdfRElSJQ0KZWNobyAgIEFzZXByaXRlIHNvdXJjZS9idWlsZDogJVJPT1Ql
DQplY2hvICAgTWFuYWdlZCB0aGVtZXM6ICVBQkhfRElSJVxtYW5hZ2VkXHRoZW1lcw0KZWNobyAg
IE1hbmFnZWQgYWRkLW9uczogJUFCSF9ESVIlXG1hbmFnZWRcYWRkb25zDQplY2hvICAgTWFuYWdl
ZCBzY3JpcHRzOiAlQVBQREFUQSVcQXNlcHJpdGVcc2NyaXB0c1xhdXRvLW1hbmFnZWQNCmV4aXQg
L2IgMA0KDQo6bG9hZF9zZXR0aW5ncw0Kc2V0ICJVUERBVEVfSU5URVJWQUxfSE9VUlM9MTIiDQpp
ZiBub3QgZXhpc3QgIiVTRVRUSU5HU19GSUxFJSIgKA0KID4iJVNFVFRJTkdTX0ZJTEUlIiBlY2hv
IDsgQXNlcHJpdGUgQnVpbGQgSGVscGVyIHNldHRpbmdzDQogPj4iJVNFVFRJTkdTX0ZJTEUlIiBl
Y2hvIFtHZW5lcmFsXQ0KID4+IiVTRVRUSU5HU19GSUxFJSIgZWNobyB1cGRhdGVfaW50ZXJ2YWxf
aG91cnM9MTINCikNCmZvciAvZiAidXNlYmFja3EgdG9rZW5zPTEsKiBkZWxpbXM9PSIgJSVBIGlu
ICgiJVNFVFRJTkdTX0ZJTEUlIikgZG8gaWYgL0kgIiUlfkEiPT0idXBkYXRlX2ludGVydmFsX2hv
dXJzIiBzZXQgIlVQREFURV9JTlRFUlZBTF9IT1VSUz0lJX5CIg0KZm9yIC9mICJkZWxpbXM9MDEy
MzQ1Njc4OSIgJSVYIGluICgiJVVQREFURV9JTlRFUlZBTF9IT1VSUyUiKSBkbyBzZXQgIlVQREFU
RV9JTlRFUlZBTF9IT1VSUz0xMiINCmlmIG5vdCBkZWZpbmVkIFVQREFURV9JTlRFUlZBTF9IT1VS
UyBzZXQgIlVQREFURV9JTlRFUlZBTF9IT1VSUz0xMiINCmlmICVVUERBVEVfSU5URVJWQUxfSE9V
UlMlIExTUyAxIHNldCAiVVBEQVRFX0lOVEVSVkFMX0hPVVJTPTEiDQpleGl0IC9iIDANCg0KOmNv
bmZpZ3VyZV91cGRhdGVfaW50ZXJ2YWwNCmNhbGwgOmxvYWRfc2V0dGluZ3MNCnNldCAiTkVXSU5U
PSINCmNscw0KaWYgL0kgIiVVSV9MQU5HJSI9PSJkZSIgKA0KIGVjaG8gPT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogZWNobyAgIFVQ
REFURS1JTlRFUlZBTEwNCiBlY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PQ0KIGVjaG8gQWt0dWVsbDogJVVQREFURV9JTlRFUlZB
TF9IT1VSUyUgU3R1bmRlbg0KIGVjaG8uDQogZWNobyBbMV0gMSBTdHVuZGUNCiBlY2hvIFsyXSAz
IFN0dW5kZW4NCiBlY2hvIFszXSA2IFN0dW5kZW4NCiBlY2hvIFs0XSAxMiBTdHVuZGVuIF4oU3Rh
bmRhcmReKQ0KIGVjaG8gWzVdIDI0IFN0dW5kZW4NCiBlY2hvIFs2XSBCZW51dHplcmRlZmluaWVy
dA0KIGVjaG8gWzBdIEFiYnJlY2hlbg0KIHNldCAvcCAiSU5UU0VMPUF1c3dhaGw6ICINCikgZWxz
ZSAoDQogZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT0NCiBlY2hvICAgVVBEQVRFIElOVEVSVkFMDQogZWNobyA9PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiBlY2hv
IEN1cnJlbnQ6ICVVUERBVEVfSU5URVJWQUxfSE9VUlMlIGhvdXJzDQogZWNoby4NCiBlY2hvIFsx
XSAxIGhvdXINCiBlY2hvIFsyXSAzIGhvdXJzDQogZWNobyBbM10gNiBob3Vycw0KIGVjaG8gWzRd
IDEyIGhvdXJzIF4oZGVmYXVsdF4pDQogZWNobyBbNV0gMjQgaG91cnMNCiBlY2hvIFs2XSBDdXN0
b20NCiBlY2hvIFswXSBDYW5jZWwNCiBzZXQgL3AgIklOVFNFTD1TZWxlY3Rpb246ICINCikNCmlm
ICIlSU5UU0VMJSI9PSIwIiBleGl0IC9iIDANCmlmICIlSU5UU0VMJSI9PSIxIiBzZXQgIk5FV0lO
VD0xIg0KaWYgIiVJTlRTRUwlIj09IjIiIHNldCAiTkVXSU5UPTMiDQppZiAiJUlOVFNFTCUiPT0i
MyIgc2V0ICJORVdJTlQ9NiINCmlmICIlSU5UU0VMJSI9PSI0IiBzZXQgIk5FV0lOVD0xMiINCmlm
ICIlSU5UU0VMJSI9PSI1IiBzZXQgIk5FV0lOVD0yNCINCmlmICIlSU5UU0VMJSI9PSI2IiBpZiAv
SSAiJVVJX0xBTkclIj09ImRlIiAoc2V0IC9wICJORVdJTlQ9SW50ZXJ2YWxsIGluIFN0dW5kZW4g
XihtaW5kZXN0ZW5zIDFeKTogIikgZWxzZSAoc2V0IC9wICJORVdJTlQ9SW50ZXJ2YWwgaW4gaG91
cnMgXihtaW5pbXVtIDFeKTogIikNCmlmIG5vdCBkZWZpbmVkIE5FV0lOVCBleGl0IC9iIDENCmZv
ciAvZiAiZGVsaW1zPTAxMjM0NTY3ODkiICUlWCBpbiAoIiVORVdJTlQlIikgZG8gc2V0ICJORVdJ
TlQ9Ig0KaWYgbm90IGRlZmluZWQgTkVXSU5UIGV4aXQgL2IgMQ0KaWYgJU5FV0lOVCUgTFNTIDEg
c2V0ICJORVdJTlQ9MSINCj4iJVNFVFRJTkdTX0ZJTEUlIiBlY2hvIDsgQXNlcHJpdGUgQnVpbGQg
SGVscGVyIHNldHRpbmdzDQo+PiIlU0VUVElOR1NfRklMRSUiIGVjaG8gW0dlbmVyYWxdDQo+PiIl
U0VUVElOR1NfRklMRSUiIGVjaG8gdXBkYXRlX2ludGVydmFsX2hvdXJzPSVORVdJTlQlDQpjYWxs
IDpsb2FkX3NldHRpbmdzDQppZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBVcGRhdGUtSW50
ZXJ2YWxsIGF1ZiAlVVBEQVRFX0lOVEVSVkFMX0hPVVJTJSBTdHVuZGVuIGdlc2V0enQuKSBlbHNl
IChlY2hvIFVwZGF0ZSBpbnRlcnZhbCBzZXQgdG8gJVVQREFURV9JTlRFUlZBTF9IT1VSUyUgaG91
cnMuKQ0KZXhpdCAvYiAwDQoNCjppc19kdWUNCmlmIG5vdCBleGlzdCAiJX4xIiBleGl0IC9iIDEN
CnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5cGFz
cyAtQ29tbWFuZCAiJGFnZT0oR2V0LURhdGUpLShHZXQtSXRlbSAtTGl0ZXJhbFBhdGggJyV+MScp
Lkxhc3RXcml0ZVRpbWU7IGlmKCRhZ2UuVG90YWxIb3VycyAtbHQgJX4yKXtleGl0IDB9ZWxzZXtl
eGl0IDF9IiA+bnVsIDI+JjENCmV4aXQgL2IgJWVycm9ybGV2ZWwlDQoNCjpiYWNrdXANCmlmIG5v
dCBleGlzdCAiJUFQUERBVEElXEFzZXByaXRlIiAoDQogaWYgL0kgIiVVSV9MQU5HJSI9PSJkZSIg
KGVjaG8gS2VpbmUgQXNlcHJpdGUtS29uZmlndXJhdGlvbiBnZWZ1bmRlbi4pIGVsc2UgKGVjaG8g
Tm8gQXNlcHJpdGUgY29uZmlndXJhdGlvbiB3YXMgZm91bmQuKQ0KIGV4aXQgL2IgMQ0KKQ0KZm9y
IC9mICJ1c2ViYWNrcSBkZWxpbXM9IiAlJVQgaW4gKGBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1O
b1Byb2ZpbGUgLUNvbW1hbmQgIkdldC1EYXRlIC1Gb3JtYXQgJ3l5eXlNTWRkLUhIbW1zcyciYCkg
ZG8gc2V0ICJUUz0lJVQiDQpzZXQgIkRFU1Q9JUJBQ0tVUF9ESVIlXCVUUyVcQXNlcHJpdGUiDQpt
a2RpciAiJURFU1QlIiA+bnVsIDI+JjENCnJvYm9jb3B5ICIlQVBQREFUQSVcQXNlcHJpdGUiICIl
REVTVCUiIC9NSVIgL1I6MSAvVzoxID5udWwNCmlmIC9JICIlVUlfTEFORyUiPT0iZGUiIChlY2hv
IEJhY2t1cCBlcnN0ZWxsdDogJURFU1QlKSBlbHNlIChlY2hvIEJhY2t1cCBjcmVhdGVkOiAlREVT
VCUpDQpleGl0IC9iIDANCg0KOnJlc3RvcmUNCnNldCAiTEFURVNUX0JBQ0tVUD0iDQpmb3IgL2Yg
ImRlbGltcz0iICUlRCBpbiAoJ2RpciAvYiAvYWQgL28tbiAiJUJBQ0tVUF9ESVIlIiAyXj5udWwn
KSBkbyBpZiBub3QgZGVmaW5lZCBMQVRFU1RfQkFDS1VQIHNldCAiTEFURVNUX0JBQ0tVUD0lQkFD
S1VQX0RJUiVcJSVEXEFzZXByaXRlIg0KaWYgbm90IGRlZmluZWQgTEFURVNUX0JBQ0tVUCAoDQog
aWYgL0kgIiVVSV9MQU5HJSI9PSJkZSIgKGVjaG8gS2VpbiBCYWNrdXAgZ2VmdW5kZW4uKSBlbHNl
IChlY2hvIE5vIGJhY2t1cCBmb3VuZC4pDQogZXhpdCAvYiAxDQopDQpjYWxsIDpiYWNrdXAgPm51
bCAyPiYxDQpta2RpciAiJUFQUERBVEElXEFzZXByaXRlIiA+bnVsIDI+JjENCnJvYm9jb3B5ICIl
TEFURVNUX0JBQ0tVUCUiICIlQVBQREFUQSVcQXNlcHJpdGUiIC9NSVIgL1I6MSAvVzoxID5udWwN
CmlmIC9JICIlVUlfTEFORyUiPT0iZGUiIChlY2hvIFdpZWRlcmhlcmdlc3RlbGx0OiAlTEFURVNU
X0JBQ0tVUCUpIGVsc2UgKGVjaG8gUmVzdG9yZWQ6ICVMQVRFU1RfQkFDS1VQJSkNCmV4aXQgL2Ig
MA0KDQo6ZXhwb3J0X2RpYWdub3N0aWNzDQpmb3IgL2YgInVzZWJhY2txIGRlbGltcz0iICUlVCBp
biAoYHBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtQ29tbWFuZCAiR2V0LURhdGUg
LUZvcm1hdCAneXl5eU1NZGQtSEhtbXNzJyJgKSBkbyBzZXQgIlRTPSUlVCINCnNldCAiT1VUPSVS
RVBPUlRfRElSJVxhYmgtZGlhZ25vc3RpY3MtJVRTJS56aXAiDQpzZXQgIkFCSF9ESUFHX09VVD0l
T1VUJSINCnNldCAiQUJIX0RJQUdfUk9PVD0lQUJIX0RJUiUiDQpzZXQgIkFCSF9ESUFHX1BST0pF
Q1Q9JVBST0pFQ1RfRElSJSINCnBvd2Vyc2hlbGwuZXhlIC1Ob0xvZ28gLU5vUHJvZmlsZSAtRXhl
Y3V0aW9uUG9saWN5IEJ5cGFzcyAtQ29tbWFuZCAiJHRtcD1Kb2luLVBhdGggJGVudjpURU1QICgn
YWJoLWRpYWctJytbZ3VpZF06Ok5ld0d1aWQoKSk7TmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9y
eSAtRm9yY2UgLVBhdGggJHRtcHxPdXQtTnVsbDskaG9tZT0kZW52OlVTRVJQUk9GSUxFO2ZvcmVh
Y2goJHN1YiBpbiBAKCdsb2dzXFx1c2VyJywnbG9nc1xcZGV2Jywnc3RhdGUnKSl7JHNyYz1Kb2lu
LVBhdGggJGVudjpBQkhfRElBR19ST09UICRzdWI7aWYoVGVzdC1QYXRoICRzcmMpeyRkc3Q9Sm9p
bi1QYXRoICR0bXAgKCRzdWIgLXJlcGxhY2UgJ1xcJywnLScpO05ldy1JdGVtIC1JdGVtVHlwZSBE
aXJlY3RvcnkgLUZvcmNlIC1QYXRoICRkc3R8T3V0LU51bGw7R2V0LUNoaWxkSXRlbSAkc3JjIC1G
aWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlfEZvckVhY2gtT2JqZWN0eyR0eHQ9R2V0
LUNvbnRlbnQgJF8uRnVsbE5hbWUgLVJhdyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTsk
dHh0PSR0eHQgLXJlcGxhY2UgW3JlZ2V4XTo6RXNjYXBlKCRob21lKSwnQzpcXFVzZXJzXFw8VVNF
Uj4nOyR0eHQ9JHR4dCAtcmVwbGFjZSAnKD9pKShhdXRob3JpemF0aW9ufGJlYXJlcnx0b2tlbnxw
YXNzd29yZHxzZWNyZXQpXHMqWzo9XVxzKlxTKycsJyQxPTxSRURBQ1RFRD4nO1NldC1Db250ZW50
IC1MaXRlcmFsUGF0aCAoSm9pbi1QYXRoICRkc3QgJF8uTmFtZSkgLVZhbHVlICR0eHQgLUVuY29k
aW5nIFVURjh9fX07QCgnQUJIIHZlcnNpb246ICcrJGVudjpVUERBVEVSX1ZFUlNJT05fRU5WLCdX
aW5kb3dzOiAnK1tFbnZpcm9ubWVudF06Ok9TVmVyc2lvbi5WZXJzaW9uU3RyaW5nLCdBcmNoaXRl
Y3R1cmU6ICcrJGVudjpQUk9DRVNTT1JfQVJDSElURUNUVVJFLCdVSSBjdWx0dXJlOiAnKyhHZXQt
VUlDdWx0dXJlKS5OYW1lKXxTZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggKEpvaW4tUGF0aCAkdG1w
ICdlbnZpcm9ubWVudC50eHQnKSAtRW5jb2RpbmcgVVRGODtDb21wcmVzcy1BcmNoaXZlIC1QYXRo
ICgkdG1wKydcXConKSAtRGVzdGluYXRpb25QYXRoICRlbnY6QUJIX0RJQUdfT1VUIC1Gb3JjZTtS
ZW1vdmUtSXRlbSAkdG1wIC1SZWN1cnNlIC1Gb3JjZSIgPm51bCAyPiYxDQppZiBleGlzdCAiJU9V
VCUiICgNCiBpZiAvSSAiJVVJX0xBTkclIj09ImRlIiAoZWNobyBEaWFnbm9zZXBha2V0IGVyc3Rl
bGx0OiAlT1VUJSkgZWxzZSAoZWNobyBEaWFnbm9zdGljIHBhY2thZ2UgY3JlYXRlZDogJU9VVCUp
DQogc3RhcnQgIiIgZXhwbG9yZXIuZXhlIC9zZWxlY3QsIiVPVVQlIg0KIGV4aXQgL2IgMA0KKQ0K
ZXhpdCAvYiAxDQoNCjpyZXBvcnRfYnVnDQpjYWxsIDpleHBvcnRfZGlhZ25vc3RpY3MgPm51bCAy
PiYxDQpzdGFydCAiIiAiJVBST0pFQ1RfVVJMJS9pc3N1ZXMvbmV3Ig0KZXhpdCAvYiAwDQoNCjpy
dW5fdW5pbnN0YWxsDQppZiBub3QgZXhpc3QgIiVVTklOU1RBTExFUiUiICgNCiBpZiAvSSAiJVVJ
X0xBTkclIj09ImRlIiAoZWNobyBVbmluc3RhbGxlciBmZWhsdC4gQml0dGUgenVlcnN0IFJlcGFy
YXR1ciBhdXNmw7xocmVuLikgZWxzZSAoZWNobyBVbmluc3RhbGxlciBpcyBtaXNzaW5nLiBSdW4g
UmVwYWlyIGZpcnN0LikNCiBleGl0IC9iIDENCikNCnNldCAiVEVNUF9VTklOU1RBTExFUj0lVEVN
UCVcQUJILXVuaW5zdGFsbC0lUkFORE9NJS0lUkFORE9NJS5iYXQiDQpjb3B5IC95ICIlVU5JTlNU
QUxMRVIlIiAiJVRFTVBfVU5JTlNUQUxMRVIlIiA+bnVsIDI+JjENCmlmIG5vdCBleGlzdCAiJVRF
TVBfVU5JTlNUQUxMRVIlIiBleGl0IC9iIDENCnN0YXJ0ICJBc2Vwcml0ZSBCdWlsZCBIZWxwZXIg
VW5pbnN0YWxsZXIiIGNtZC5leGUgL2QgL2MgIiIlVEVNUF9VTklOU1RBTExFUiUiIC0tbGFuZz0l
VUlfTEFORyUiDQpleGl0IC9iIDANCg0KOnByb2dyZXNzX3N0YXJ0DQpyZW0gdjEuMi44OiBpbnRl
cmFjdGl2ZSBwcm9ncmVzcyBzdGF5cyBpbiB0aGlzIENNRCB3aW5kb3cuDQpleGl0IC9iIDANCg0K
OnByb2dyZXNzX3VwZGF0ZQ0Kc2V0ICJBQkhfUENUPSV+MSINCnNldCAiQUJIX1BIQVNFPSV+MiIN
CnNldCAiQUJIX1NURVA9JX4zIg0Kc2V0ICJBQkhfTVNHPSV+NCINCnNldCAiQUJIX0NPTE9SPUN5
YW4iDQppZiAvSSAiJUFCSF9QSEFTRSUiPT0idGhlbWUiIHNldCAiQUJIX0NPTE9SPU1hZ2VudGEi
DQppZiAvSSAiJUFCSF9QSEFTRSUiPT0iYWRkb24iIHNldCAiQUJIX0NPTE9SPUdyZWVuIg0KaWYg
L0kgIiVBQkhfUEhBU0UlIj09InN1Y2Nlc3MiIHNldCAiQUJIX0NPTE9SPUdyZWVuIg0KaWYgL0kg
IiVBQkhfUEhBU0UlIj09ImJ1aWxkIiBzZXQgIkFCSF9DT0xPUj1ZZWxsb3ciDQppZiAvSSAiJUFC
SF9QSEFTRSUiPT0id2FybmluZyIgc2V0ICJBQkhfQ09MT1I9WWVsbG93Ig0KaWYgL0kgIiVBQkhf
UEhBU0UlIj09ImVycm9yIiBzZXQgIkFCSF9DT0xPUj1SZWQiDQppZiAiJU1PREVfU0NIRURVTEVE
JSI9PSIwIiBwb3dlcnNoZWxsLmV4ZSAtTm9Mb2dvIC1Ob1Byb2ZpbGUgLUNvbW1hbmQgIldyaXRl
LUhvc3QgKCdbJyskZW52OkFCSF9TVEVQKyddICcrJGVudjpBQkhfTVNHKSAtRm9yZWdyb3VuZENv
bG9yICRlbnY6QUJIX0NPTE9SIiAyPm51bA0KZXhpdCAvYiAwDQoNCjpwcm9ncmVzc19zdG9wDQpl
eGl0IC9iIDANCg0KOmxhdW5jaF9hc2Vwcml0ZQ0KaWYgZXhpc3QgIiVFWEUlIiBzdGFydCAiIiAi
JUVYRSUiDQpleGl0IC9iIDANCg0KOmxvZw0KPj4iJUxPRyUiIGVjaG8gWyVkYXRlJSAldGltZSVd
ICV+MQ0KZXhpdCAvYiAwDQo=
###END:aseprite-build-updater.bat.b64###
