@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Aseprite Personal Build Helper
rem Helper author/maintainer: Etzio
rem Project URL: https://github.com/tvetzio/aseprite-build-helper
rem
rem This file is a build helper, updater and launcher.
rem It does NOT contain or distribute a compiled copy of Aseprite.
rem Aseprite is cloned from the official repository and compiled locally.
rem ============================================================================

set "HELPER_VERSION=1.0"

set "ROOT=C:\aseprite"
set "BUILD=%ROOT%\build"
set "EXE=%BUILD%\bin\aseprite.exe"
set "SKIA=C:\deps\skia"
set "REPO=https://github.com/aseprite/aseprite.git"
set "INITIAL_TAG=v1.3.18.6"
set "EXPECTED_SKIA=m124-08a5439a6b"

set "STARTER_DIR=%~dp0"
set "README_FILE=%STARTER_DIR%README.md"

set "SUPPORT_DIR=%LOCALAPPDATA%\AsepritePersonalBuildHelper\support"
set "SUPPORT_VERSION_FILE=%SUPPORT_DIR%\version.txt"
set "PREFLIGHT_SCRIPT=%SUPPORT_DIR%\aseprite_preflight.ps1"
set "THEME_SCRIPT=%SUPPORT_DIR%\aseprite_themes.ps1"
set "ADDON_SCRIPT=%SUPPORT_DIR%\aseprite_addons.ps1"
set "LOCAL_TOOLS_SCRIPT=%SUPPORT_DIR%\aseprite_local_tools.ps1"
set "ICON_B64_FILE=%SUPPORT_DIR%\helper_icon.ico.b64"
set "ICON_FILE=%SUPPORT_DIR%\helper_icon.ico"

set "LOGDIR=%LOCALAPPDATA%\AsepriteBuild"
set "LOG=%LOGDIR%\aseprite_boot.log"
set "UPDATE_STAMP=%LOGDIR%\last_update_check.txt"
set "THEME_STAMP=%LOGDIR%\last_theme_check.txt"
set "ADDON_STAMP=%LOGDIR%\last_addon_check.txt"

set "UPDATE_INTERVAL_HOURS=6"
set "THEME_INTERVAL_HOURS=24"
set "ADDON_INTERVAL_HOURS=24"

set "THEME_BG_DUE=0"
set "ADDON_BG_DUE=0"
set "SUPPORT_REFRESHED=0"
set "UI_LANG="
set "MODE_REPAIR=0"
set "MODE_FORCE_UPDATE=0"
set "MODE_BACKUP=0"
set "MODE_RESTORE=0"
set "MODE_STATUS=0"
set "MODE_MAINTENANCE=0"
set "BACKUP_ROOT=%USERPROFILE%\Documents\AsepritePersonalBuildHelper\Backups"

rem Optional manual UI override:
rem   aseprite_personal_build_helper.bat --lang=de
rem   aseprite_personal_build_helper.bat --lang=en
for %%A in (%*) do (
  if /I "%%~A"=="--lang=de" set "UI_LANG=de"
  if /I "%%~A"=="--lang=en" set "UI_LANG=en"
  if /I "%%~A"=="--repair" set "MODE_REPAIR=1"
  if /I "%%~A"=="--force-update" set "MODE_FORCE_UPDATE=1"
  if /I "%%~A"=="--backup" set "MODE_BACKUP=1"
  if /I "%%~A"=="--restore" set "MODE_RESTORE=1"
  if /I "%%~A"=="--status" set "MODE_STATUS=1"
  if /I "%%~A"=="--maintenance" set "MODE_MAINTENANCE=1"
)

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%SUPPORT_DIR%" mkdir "%SUPPORT_DIR%" >nul 2>&1

rem --------------------------------------------------------------------------
rem Extract embedded support files only when this helper version changes.
rem This keeps normal starts fast while still allowing a single BAT to carry
rem all helper scripts.
rem --------------------------------------------------------------------------
set "INSTALLED_HELPER_VERSION="
if exist "%SUPPORT_VERSION_FILE%" set /p INSTALLED_HELPER_VERSION=<"%SUPPORT_VERSION_FILE%"

if /I not "%INSTALLED_HELPER_VERSION%"=="%HELPER_VERSION%" (
  set "ASE_HELPER_SELF=%~f0"
  set "ASE_HELPER_SUPPORT=%SUPPORT_DIR%"
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "$raw=[IO.File]::ReadAllText($env:ASE_HELPER_SELF); $out=$env:ASE_HELPER_SUPPORT; $enc=New-Object Text.UTF8Encoding($false); $names=@('aseprite_preflight.ps1','aseprite_themes.ps1','aseprite_addons.ps1','aseprite_local_tools.ps1','game_pixel_starter.lua','game_export_pack.lua','game_asset_template_generator.lua','autotile_template_generator.lua','game_collision_pivot_metadata.lua','pivot_origin_presets.lua','helper_icon.ico.b64'); foreach($n in $names){ $e=[regex]::Escape($n); $m=[regex]::Match($raw,'(?s)###BEGIN:'+ $e +'###\r?\n(.*?)\r?\n###END:'+ $e +'###'); if(-not $m.Success){exit 91}; [IO.File]::WriteAllText((Join-Path $out $n),$m.Groups[1].Value,$enc) }; $b64=Join-Path $out 'helper_icon.ico.b64'; $ico=Join-Path $out 'helper_icon.ico'; [IO.File]::WriteAllBytes($ico,[Convert]::FromBase64String(([IO.File]::ReadAllText($b64)).Trim()))" >nul 2>&1

  if errorlevel 1 (
    echo.
    echo ERROR: The helper could not unpack its internal support files.
    echo Please download a fresh copy of aseprite_personal_build_helper.bat.
    echo.
    pause
    exit /b 1
  )

  >"%SUPPORT_VERSION_FILE%" echo %HELPER_VERSION%
  set "SUPPORT_REFRESHED=1"
)

rem Make Ninja available when it is installed beside CMake but not in PATH.
where ninja.exe >nul 2>&1
if errorlevel 1 if exist "C:\Program Files\CMake\bin\ninja.exe" set "PATH=C:\Program Files\CMake\bin;%PATH%"

rem If the hidden launcher is used before Aseprite exists, reopen this helper
rem visibly. First-time setup should never fail silently.
if /I "%~1"=="--hidden" if not exist "%EXE%" (
  start "Aseprite Personal Build Helper" cmd.exe /c ""%~f0" --builder-visible"
  exit /b 0
)

call :log "------------------------------------------------------------"
call :log "START helper=%HELPER_VERSION%"

call :ensure_shortcuts

if "%MODE_MAINTENANCE%"=="1" (
  call :maintenance_menu
  exit /b %errorlevel%
)

if "%MODE_BACKUP%"=="1" (
  call :backup_config
  exit /b %errorlevel%
)

if "%MODE_RESTORE%"=="1" (
  call :restore_config
  exit /b %errorlevel%
)

if "%MODE_STATUS%"=="1" (
  call :status_report
  exit /b 0
)

if "%MODE_REPAIR%"=="1" (
  call :repair_all
  exit /b %errorlevel%
)

if "%MODE_FORCE_UPDATE%"=="1" (
  call :force_update_prepare
)

rem Install/refresh our local GameDev scripts when this helper was updated,
rem or when the local export script is missing.
if "%SUPPORT_REFRESHED%"=="1" (
  call :install_local_tools
) else (
  if not exist "%APPDATA%\Aseprite\scripts\auto-managed-local\Game Export Pack.lua" call :install_local_tools
)

rem ============================================================================
rem EXISTING INSTALLATION: fast launcher + occasional update checks
rem ============================================================================
if exist "%EXE%" (
  if "%SUPPORT_REFRESHED%"=="1" (
    set "THEME_BG_DUE=1"
    set "ADDON_BG_DUE=1"
  )
  if not exist "%THEME_STAMP%" (
    set "THEME_BG_DUE=1"
  ) else (
    call :mark_theme_sync_due
  )

  if not exist "%ADDON_STAMP%" (
    set "ADDON_BG_DUE=1"
  ) else (
    call :mark_addon_sync_due
  )

  if not exist "%ROOT%\.git" (
    call :log "WARNING: Existing Aseprite binary found, but C:\aseprite is not a Git repository."
    call :launch
    exit /b 0
  )

  call :aseprite_check_due
  if not errorlevel 1 (
    call :log "Aseprite update check skipped; cache is still fresh."
    call :launch
    exit /b 0
  )

  call :log "Checking GitHub for stable Aseprite release tags..."
  git -C "%ROOT%" fetch --tags --prune --quiet origin >>"%LOG%" 2>&1
  >"%UPDATE_STAMP%" echo %date% %time%

  if errorlevel 1 (
    call :log "Git fetch failed or network is unavailable. Launching installed Aseprite."
    call :launch
    exit /b 0
  )

  set "LATEST_TAG="
  for /f "usebackq delims=" %%V in (`powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$tags=@(& git -C '%ROOT%' tag --list 'v*'); $items=foreach($t in $tags){if($t -match '^v(\d+\.\d+\.\d+(?:\.\d+)?)$'){try{[pscustomobject]@{Tag=$t;Ver=[version]$Matches[1]}}catch{}}}; ($items|Sort-Object Ver -Descending|Select-Object -First 1).Tag"`) do set "LATEST_TAG=%%V"

  if not defined LATEST_TAG (
    call :log "Could not determine the newest stable tag. Launching installed Aseprite."
    call :launch
    exit /b 0
  )

  set "CURRENT_COMMIT="
  set "LATEST_COMMIT="
  for /f "delims=" %%H in ('git -C "%ROOT%" rev-parse HEAD 2^>nul') do set "CURRENT_COMMIT=%%H"
  for /f "delims=" %%H in ('git -C "%ROOT%" rev-list -n 1 "!LATEST_TAG!" 2^>nul') do set "LATEST_COMMIT=%%H"

  if /I "!CURRENT_COMMIT!"=="!LATEST_COMMIT!" (
    call :log "No Aseprite update. Current stable release: !LATEST_TAG!"
    call :launch
    exit /b 0
  )

  call :log "Aseprite update found: !LATEST_TAG!"
  set "OLD_COMMIT=!CURRENT_COMMIT!"

  git -C "%ROOT%" checkout --force "!LATEST_TAG!" >>"%LOG%" 2>&1
  if errorlevel 1 (
    call :log "Checkout failed. Launching the installed build."
    call :launch
    exit /b 0
  )

  git -C "%ROOT%" submodule sync --recursive >>"%LOG%" 2>&1
  git -C "%ROOT%" submodule update --init --recursive --force >>"%LOG%" 2>&1
  if errorlevel 1 (
    call :log "Submodule update failed. Rolling source checkout back."
    git -C "%ROOT%" checkout --force "!OLD_COMMIT!" >>"%LOG%" 2>&1
    git -C "%ROOT%" submodule update --init --recursive --force >>"%LOG%" 2>&1
    call :launch
    exit /b 0
  )

  call :validate_skia_for_source
  if errorlevel 1 (
    call :log "The new Aseprite release requests a different Skia revision. Keeping the existing build."
    git -C "%ROOT%" checkout --force "!OLD_COMMIT!" >>"%LOG%" 2>&1
    git -C "%ROOT%" submodule update --init --recursive --force >>"%LOG%" 2>&1
    call :launch
    exit /b 0
  )

  call :build
  if errorlevel 1 (
    call :log "Update build failed. Rolling source checkout back; existing executable is kept."
    git -C "%ROOT%" checkout --force "!OLD_COMMIT!" >>"%LOG%" 2>&1
    git -C "%ROOT%" submodule update --init --recursive --force >>"%LOG%" 2>&1
    call :launch
    exit /b 0
  )

  call :log "Aseprite update build completed successfully."
  call :launch
  exit /b 0
)

rem ============================================================================
rem FIRST INSTALLATION
rem ============================================================================
call :log "No Aseprite executable found. Starting first-time setup."

echo.
echo ============================================================
echo   ASEPRITE PERSONAL BUILD HELPER - FIRST-TIME SETUP
echo ============================================================
echo.
echo A setup window will check the required tools and show official links
echo for anything that is missing.
echo.

if defined UI_LANG (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PREFLIGHT_SCRIPT%" -ReadmePath "%README_FILE%" -SkiaRoot "%SKIA%" -AsepriteRoot "%ROOT%" -Language "%UI_LANG%"
) else (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PREFLIGHT_SCRIPT%" -ReadmePath "%README_FILE%" -SkiaRoot "%SKIA%" -AsepriteRoot "%ROOT%"
)

if errorlevel 1 (
  call :log "First-time setup was cancelled or prerequisites are still missing."
  exit /b 1
)

echo.
echo [1/3] Prerequisites OK.

call :validate_skia_files
if errorlevel 1 (
  call :fatal "Skia is missing or incomplete. Expected: C:\deps\skia\out\Release-x64\skia.lib"
  exit /b 1
)

if not exist "%ROOT%\.git" (
  if exist "%ROOT%" (
    call :fatal "C:\aseprite already exists but is not a Git repository. Rename or remove that incomplete folder first."
    exit /b 1
  )

  echo [2/3] Cloning the official Aseprite source...
  call :log "Cloning Aseprite %INITIAL_TAG% recursively..."
  git clone --recursive --branch "%INITIAL_TAG%" "%REPO%" "%ROOT%" >>"%LOG%" 2>&1
  if errorlevel 1 (
    call :fatal "git clone failed. See the build log for details."
    exit /b 1
  )
)

if not exist "%EXE%" if exist "%BUILD%\CMakeCache.txt" (
  call :log "Removing a stale or failed CMake build directory."
  rmdir /s /q "%BUILD%" >>"%LOG%" 2>&1
)

call :validate_skia_for_source
if errorlevel 1 (
  call :fatal "The checked-out Aseprite source expects a different Skia revision."
  exit /b 1
)

echo [3/3] Compiling Aseprite. The first build can take several minutes...
call :build
if errorlevel 1 (
  call :fatal "The Aseprite build failed. See the build log for details."
  exit /b 1
)

call :log "First Aseprite build completed successfully."
set "THEME_BG_DUE=1"
set "ADDON_BG_DUE=1"
call :launch
exit /b 0

rem ============================================================================
rem FUNCTIONS
rem ============================================================================

:install_local_tools
if exist "%LOCAL_TOOLS_SCRIPT%" (
  powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%LOCAL_TOOLS_SCRIPT%" >nul 2>&1
)
exit /b 0

:aseprite_check_due
if not exist "%UPDATE_STAMP%" exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$age=(Get-Date)-(Get-Item -LiteralPath '%UPDATE_STAMP%').LastWriteTime; if($age.TotalHours -lt %UPDATE_INTERVAL_HOURS%){exit 0}else{exit 1}" >nul 2>&1
exit /b %errorlevel%

:mark_theme_sync_due
set "THEME_BG_DUE=0"
if not exist "%THEME_SCRIPT%" exit /b 0
if not exist "%THEME_STAMP%" (
  set "THEME_BG_DUE=1"
  exit /b 0
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$age=(Get-Date)-(Get-Item -LiteralPath '%THEME_STAMP%').LastWriteTime; if($age.TotalHours -ge %THEME_INTERVAL_HOURS%){exit 0}else{exit 1}" >nul 2>&1
if not errorlevel 1 set "THEME_BG_DUE=1"
exit /b 0

:mark_addon_sync_due
set "ADDON_BG_DUE=0"
if not exist "%ADDON_SCRIPT%" exit /b 0
if not exist "%ADDON_STAMP%" (
  set "ADDON_BG_DUE=1"
  exit /b 0
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$age=(Get-Date)-(Get-Item -LiteralPath '%ADDON_STAMP%').LastWriteTime; if($age.TotalHours -ge %ADDON_INTERVAL_HOURS%){exit 0}else{exit 1}" >nul 2>&1
if not errorlevel 1 set "ADDON_BG_DUE=1"
exit /b 0

:start_theme_sync_background
if not "%THEME_BG_DUE%"=="1" exit /b 0
if not exist "%THEME_SCRIPT%" exit /b 0
call :log "Starting background dark-theme sync."
start "" /b powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%THEME_SCRIPT%"
>"%THEME_STAMP%" echo %date% %time%
set "THEME_BG_DUE=0"
exit /b 0

:start_addon_sync_background
if not "%ADDON_BG_DUE%"=="1" exit /b 0
if not exist "%ADDON_SCRIPT%" exit /b 0
call :log "Starting background add-on sync."
start "" /b powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%ADDON_SCRIPT%"
>"%ADDON_STAMP%" echo %date% %time%
set "ADDON_BG_DUE=0"
exit /b 0

:build
call :load_msvc
if errorlevel 1 exit /b 1

if not exist "%BUILD%" mkdir "%BUILD%" >>"%LOG%" 2>&1

call :log "Configuring CMake..."
cmake.exe ^
  -S "%ROOT%" ^
  -B "%BUILD%" ^
  -G Ninja ^
  -DCMAKE_BUILD_TYPE=RelWithDebInfo ^
  -DLAF_BACKEND=skia ^
  -DSKIA_DIR="%SKIA%" ^
  -DSKIA_LIBRARY_DIR="%SKIA%\out\Release-x64" ^
  -DSKIA_LIBRARY="%SKIA%\out\Release-x64\skia.lib" >>"%LOG%" 2>&1

if errorlevel 1 (
  call :log "CMake configuration failed."
  exit /b 1
)

call :log "Building Aseprite with Ninja..."
ninja.exe -C "%BUILD%" aseprite >>"%LOG%" 2>&1
if errorlevel 1 (
  call :log "Ninja build failed."
  exit /b 1
)

if not exist "%EXE%" (
  call :log "Build command completed but aseprite.exe is missing."
  exit /b 1
)
exit /b 0

:load_msvc
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSROOT="

if exist "%VSWHERE%" (
  for /f "usebackq tokens=* delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSROOT=%%I"
)

if not defined VSROOT (
  if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
    set "VSROOT=C:\Program Files\Microsoft Visual Studio\2022\Community"
  )
)

if not defined VSROOT (
  call :log "Visual Studio C++ toolchain was not found."
  exit /b 1
)

set "VCVARS=%VSROOT%\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" (
  call :log "vcvars64.bat was not found: %VCVARS%"
  exit /b 1
)

call :log "Loading MSVC x64 environment from: %VCVARS%"
call "%VCVARS%" >nul 2>&1
if errorlevel 1 exit /b 1

where cl.exe >>"%LOG%" 2>&1
if errorlevel 1 (
  call :log "cl.exe is unavailable after loading vcvars64.bat."
  exit /b 1
)
exit /b 0

:validate_skia_files
if not exist "%SKIA%\out\Release-x64\skia.lib" exit /b 1
if not exist "%SKIA%\include" exit /b 1
exit /b 0

:validate_skia_for_source
call :validate_skia_files
if errorlevel 1 exit /b 1

set "SOURCE_SKIA="
if exist "%ROOT%\laf\misc\skia-tag.txt" set /p SOURCE_SKIA=<"%ROOT%\laf\misc\skia-tag.txt"

if defined SOURCE_SKIA (
  call :log "Source expects Skia: !SOURCE_SKIA!"
  if /I not "!SOURCE_SKIA!"=="%EXPECTED_SKIA%" (
    call :log "Helper is configured for Skia %EXPECTED_SKIA%; source requests !SOURCE_SKIA!."
    exit /b 1
  )
)
exit /b 0

:launch
if exist "%EXE%" (
  call :log "Launching Aseprite."
  start "" "%EXE%"
  call :start_theme_sync_background
  call :start_addon_sync_background
  exit /b 0
)
call :log "Cannot launch because %EXE% does not exist."
exit /b 1

:fatal
call :log "FATAL: %~1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('%~1`n`nBuild log:`n%LOG%','Aseprite Personal Build Helper','OK','Error') | Out-Null" >nul 2>&1
exit /b 1

:log
>>"%LOG%" echo [%date% %time%] %~1
exit /b 0

goto :eof

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
    Title="Aseprite Personal Build Helper - Ersteinrichtung"
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
    SourceGood="Ziel ist frei oder bereits ein gueltiges Git-Repository."
    SourceBadFmt="{0} existiert, ist aber kein Git-Repository. Den Ordner bitte umbenennen oder entfernen."
    SpaceFmt="{0} GB frei (empfohlen: mindestens 4 GB)"
    SpaceName="Freier Speicher auf C:"
    Ready="Alles sieht gut aus. Der lokale Build kann gestartet werden."
    NoBinary="Dieses Toolkit liefert keine fertige Aseprite-Binary mit. Aseprite wird lokal aus dem offiziellen Quellcode gebaut."
    Sources="Offizielle Seiten:"
    SkiaHint="Skia muss so entpackt sein, dass diese Datei existiert:"
    OpenReadme="README oeffnen"
    Exit="Beenden"
    Retry="Erneut pruefen"
    Build="Build starten"
    OpenFolder="Skia-Ordner oeffnen"
    Eula="Aseprite EULA"
    Ack="Ich verstehe, dass Aseprite lokal fuer meinen eigenen persoenlichen Gebrauch gebaut wird und dass dieses Toolkit keine fertige Aseprite-Version verteilt."
    NeedAck="Bitte den Hinweis zur persoenlichen Nutzung bestaetigen, bevor der Build gestartet wird."
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
    Title="Aseprite Personal Build Helper - First-time setup"
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
    Ready="Everything looks good. The local build can start."
    NoBinary="This toolkit does not ship a compiled Aseprite binary. Aseprite is built locally from the official source code."
    Sources="Official pages:"
    SkiaHint="Skia must be extracted so this file exists:"
    OpenReadme="Open README"
    Exit="Exit"
    Retry="Check again"
    Build="Start build"
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

$ManagerRoot = Join-Path $env:LOCALAPPDATA "AsepriteThemeManager"
$RepoRoot = Join-Path $ManagerRoot "repos"
$LogDir = Join-Path $env:LOCALAPPDATA "AsepriteBuild"
$LogFile = Join-Path $LogDir "aseprite_themes.log"
$ExtensionRoot = Join-Path $env:APPDATA "Aseprite\extensions"

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

# Curated dark/subdued Aseprite theme sources.
# The manager automatically discovers multiple theme packages inside one repository.
$Sources = @(
  @{ Id = "catppuccin"; Url = "https://github.com/catppuccin/aseprite.git" },
  @{ Id = "nord";       Url = "https://github.com/marsn3/aseprite-nord.git" },
  @{ Id = "dracula";    Url = "https://github.com/dracula/aseprite.git" },
  @{ Id = "studio";     Url = "https://github.com/Lyutria/aseprite-studio-theme.git" },
  @{ Id = "monaki";     Url = "https://github.com/el-falso/monaki-theme.git" },
  @{ Id = "jmswrnr";    Url = "https://github.com/jmswrnr/aseprite-themes.git" },
  @{ Id = "dark-moon";  Url = "https://github.com/emhuo/dark-moon-theme.git" },

  # Modern dark theme with clear visual state distinctions.
  @{ Id = "aletheia";   Url = "https://github.com/behreajj/Aletheia.git" }
)

foreach ($source in $Sources) {
  $repo = Sync-Repo -Id $source.Id -Url $source.Url
  if ($repo) {
    Install-ThemePackagesFromRepo -RepoId $source.Id -RepoPath $repo
  }
}

Write-Log "THEME SYNC END"
exit 0
###END:aseprite_themes.ps1###

###BEGIN:aseprite_addons.ps1###
$ErrorActionPreference = "Continue"

$ManagerRoot = Join-Path $env:LOCALAPPDATA "AsepriteAddonManager"
$RepoRoot = Join-Path $ManagerRoot "repos"
$LogDir = Join-Path $env:LOCALAPPDATA "AsepriteBuild"
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

# Curated for pixel art / game workflows.
# mode:
#   scripts    -> mirrored into Aseprite's Scripts folder
#   extensions -> installs package.json/.aseprite-extension packages
#   both       -> both mechanisms
$Sources = @(
  # Large productivity / animation suite:
  @{ Id="thkwznk"; Url="https://github.com/thkwznk/aseprite-scripts.git"; Mode="both" },

  # Tile index overlay extension:
  @{ Id="pixeltica"; Url="https://github.com/Pixeltica/AsepriteExtensions.git"; Mode="both" },

  # Sprite-sheet/layer import-export utilities:
  @{ Id="snepsid"; Url="https://github.com/Snepsid/aseprite-scripts.git"; Mode="scripts" },

  # Stroke, color overlay, animation background:
  @{ Id="christopherwk210"; Url="https://github.com/christopherwk210/aseprite-scripts.git"; Mode="scripts" },

  # Retro palette bit-depth reducer:
  @{ Id="sandord"; Url="https://github.com/sandord/aseprite-scripts.git"; Mode="scripts" },

  # Extra scripts and packaged plugins:
  @{ Id="mrbrownjeremy"; Url="https://github.com/mrbrownjeremy/aseprite-scripts.git"; Mode="both" },

  # Better game sprite-sheet export:
  @{ Id="colinlienard"; Url="https://github.com/colinlienard/aseprite-scripts.git"; Mode="scripts" },

  # Official Aseprite example/toolbox scripts:
  @{ Id="aseprite-examples"; Url="https://github.com/aseprite/Aseprite-Script-Examples.git"; Mode="scripts" },

  # Isometric tiles / tileset helpers:
  @{ Id="opsis-isometric"; Url="https://github.com/OpsisKalopsis/aseprite-scripts.git"; Mode="scripts" },

  # Tilemap + tileset exporters:
  @{ Id="gabinou-tilemap"; Url="https://github.com/Gabinou/tilemap_scripts_aseprite.git"; Mode="scripts" },

  # Dynamic color-shading/ramp helper:
  @{ Id="dominickjohn-shading"; Url="https://github.com/dominickjohn/aseprite.git"; Mode="scripts" },

  # Isometric cube-face texture helper:
  @{ Id="limeth-iso"; Url="https://github.com/Limeth/aseprite-iso-scripts.git"; Mode="scripts" },

  # Layer exporter:
  @{ Id="quantumsheep-export"; Url="https://github.com/quantumsheep/aseprite-export-layers.git"; Mode="scripts" },

  # Import palettes directly from Lospec.
  @{ Id="lospec-importer"; Url="https://github.com/JRiggles/Lospec-Palette-Importer.git"; Mode="both" },

  # Generate reusable dithering brushes from foreground/background colors.
  @{ Id="dithering-brushes"; Url="https://github.com/exokem/aseprite-dithering-brushes.git"; Mode="both" },

  # Fake edge normal maps for lit 2D sprites.
  @{ Id="edge-normals"; Url="https://github.com/securas/EdgeNormals.git"; Mode="scripts" },

  # Convert height maps to normal maps (useful with Godot/2D lighting).
  @{ Id="height-normalmap"; Url="https://github.com/carlmartus/aseprite_normalmap.git"; Mode="scripts" },

  # Resize canvas, stack animation frames, interpolate midpoint colors.
  @{ Id="beatso-tools"; Url="https://github.com/Beatso/UsefulAsepriteScripts.git"; Mode="scripts" },

  # Non-destructive outline workflow in dedicated locked layers.
  @{ Id="ez-outline"; Url="https://github.com/iNightfaller/aseprite-ez-outline.git"; Mode="scripts" },

  # Grid selection, sprite-sheet resize and workflow helpers.
  @{ Id="zachary-tools"; Url="https://github.com/ZachIsAGardner/ZacharyAsepriteScripts.git"; Mode="scripts" },

  # Additional normal-map and tileset manipulation tools.
  @{ Id="normal-tileset-tools"; Url="https://github.com/SavuGeorge/Aseprite-scripts-for-normal-map-and-tileset-manipulation.git"; Mode="scripts" },

  # Simple pixel-art anti-alias and outline scripts.
  @{ Id="rikfuzz-tools"; Url="https://github.com/rikfuzz/aseprite-scripts.git"; Mode="scripts" },

  # PuzzleScript tile/sprite exporter for grid-based games.
  @{ Id="puzzlescript-export"; Url="https://github.com/pancelor/aseprite-puzzlescript-export.git"; Mode="scripts" },

  # ANIMATION PACK ---------------------------------------------------------

  # Ghost/onion-like animation layers, layer transitions, normal + looped
  # particle animation generators.
  @{ Id="davebarker-animation"; Url="https://github.com/davebarkeruk/Aseprite_LUA_Scripts.git"; Mode="scripts" },

  # Parallax animation helper with per-layer speed and wrapping.
  @{ Id="tekf-parallax"; Url="https://github.com/TekF/Aseprite-Scripts.git"; Mode="scripts" },

  # LPC character generator importer: brings generated modular characters
  # and their directional animation sets into Aseprite.
  @{ Id="lpc2ase"; Url="https://github.com/IoriBranford/aseprite-import-lpc-character.git"; Mode="both" }
)

foreach ($source in $Sources) {
  $repo = Sync-Repo -Id $source.Id -Url $source.Url
  if (-not $repo) { continue }

  if ($source.Mode -in @("scripts", "both")) {
    Install-ScriptRepo -Id $source.Id -RepoPath $repo
  }

  if ($source.Mode -in @("extensions", "both")) {
    Install-ExtensionsFromRepo -RepoId $source.Id -RepoPath $repo
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

###BEGIN:helper_icon.ico.b64###
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
###END:helper_icon.ico.b64###
