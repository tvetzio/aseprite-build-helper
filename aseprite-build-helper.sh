#!/usr/bin/env bash
set -uo pipefail

ABH_VERSION="1.2.0"
PROJECT_NAME="Aseprite Build Helper"
PROJECT_URL="https://github.com/tvetzio/aseprite-build-helper"
ASEPRITE_REPO="https://github.com/aseprite/aseprite.git"
SKIA_RELEASE_BASE="https://github.com/aseprite/skia/releases/download"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
ABH_DIR="$SCRIPT_DIR/ABH"
TOOLS_DIR="$ABH_DIR/tools"
MANAGED_DIR="$ABH_DIR/managed"
ASEPRITE_DIR="$MANAGED_DIR/aseprite"
BUILD_DIR="$ASEPRITE_DIR/build-abh"
SKIA_ROOT="$TOOLS_DIR/skia"
RUNTIME_DIR="$ABH_DIR/runtime"
LAUNCHER_DIR="$ABH_DIR/launcher"
UPDATER_DIR="$ABH_DIR/updater"
UNINSTALLER_DIR="$ABH_DIR/uninstaller"
LOG_DIR="$ABH_DIR/logs"
USER_LOG_DIR="$LOG_DIR/user"
DEV_LOG_DIR="$LOG_DIR/dev"
STATE_DIR="$ABH_DIR/state"
CONFIG_DIR="$ABH_DIR/config"
REPORT_DIR="$ABH_DIR/reports"
BACKUP_DIR="$ABH_DIR/backups"
MAIN_LOG="$USER_LOG_DIR/abh-linux.log"
DEV_LOG="$DEV_LOG_DIR/abh-linux-dev.log"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"
SOURCES_DIR="$CONFIG_DIR/sources"
THEME_SOURCE_DIR="$SOURCES_DIR/themes"
ADDON_SOURCE_DIR="$SOURCES_DIR/addons"
MIXED_SOURCE_DIR="$SOURCES_DIR/mixed"
REPO_CACHE_DIR="$MANAGED_DIR/repos"
ASEPRITE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/aseprite"
ASEPRITE_EXT_DIR="$ASEPRITE_CONFIG_DIR/extensions"
ASEPRITE_SCRIPT_DIR="$ASEPRITE_CONFIG_DIR/scripts/auto-managed"
LAST_ABH_CHECK="$STATE_DIR/last_abh_check.txt"
LAST_CONTENT_CHECK="$STATE_DIR/last_content_check.txt"
DEFAULT_UPDATE_HOURS=12

mkdir -p "$TOOLS_DIR" "$MANAGED_DIR" "$RUNTIME_DIR" "$LAUNCHER_DIR" "$UPDATER_DIR" \
  "$UNINSTALLER_DIR" "$USER_LOG_DIR" "$DEV_LOG_DIR" "$STATE_DIR" "$CONFIG_DIR" \
  "$REPORT_DIR" "$BACKUP_DIR" "$THEME_SOURCE_DIR" "$ADDON_SOURCE_DIR" "$MIXED_SOURCE_DIR" "$REPO_CACHE_DIR" "$ASEPRITE_EXT_DIR" "$ASEPRITE_SCRIPT_DIR"

UI_LANG="en"
case "${LANG:-}" in
  de_*|de-*) UI_LANG="de" ;;
esac

if [[ "${1:-}" == "--lang=de" ]]; then UI_LANG="de"; shift; fi
if [[ "${1:-}" == "--lang=en" ]]; then UI_LANG="en"; shift; fi

ensure_visible_terminal() {
  case "${1:-}" in
    --scheduled|--launch) return 0 ;;
  esac

  if [[ -t 0 && -t 1 ]]; then
    return 0
  fi

  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    return 0
  fi

  local quoted="" arg
  printf -v quoted '%q %q ' "$SCRIPT_DIR/aseprite-build-helper.sh" "--lang=$UI_LANG"
  for arg in "$@"; do
    local q
    printf -v q '%q' "$arg"
    quoted+="$q "
  done
  quoted+='; rc=$?; printf "\\n"; if [ $rc -ne 0 ]; then printf "ABH exited with code %s\\n" "$rc"; fi; printf "Press Enter to close..."; read -r _; exit $rc'

  if command -v x-terminal-emulator >/dev/null 2>&1; then
    exec x-terminal-emulator -e bash -lc "$quoted"
  elif command -v gnome-terminal >/dev/null 2>&1; then
    exec gnome-terminal -- bash -lc "$quoted"
  elif command -v konsole >/dev/null 2>&1; then
    exec konsole -e bash -lc "$quoted"
  elif command -v xfce4-terminal >/dev/null 2>&1; then
    exec xfce4-terminal --command="bash -lc $(printf '%q' "$quoted")"
  elif command -v mate-terminal >/dev/null 2>&1; then
    exec mate-terminal -- bash -lc "$quoted"
  elif command -v xterm >/dev/null 2>&1; then
    exec xterm -e bash -lc "$quoted"
  fi
}

ensure_visible_terminal "$@"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$MAIN_LOG" >/dev/null
}

devlog() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$DEV_LOG"
}

say() {
  local de="$1" en="$2"
  if [[ "$UI_LANG" == "de" ]]; then printf '%s\n' "$de"; else printf '%s\n' "$en"; fi
}

pause_if_tty() {
  if [[ -t 0 ]]; then
    say "Drücke Enter zum Fortfahren..." "Press Enter to continue..."
    read -r _
  fi
}

show_popup() {
  local de_title="$1" en_title="$2" de_msg="$3" en_msg="$4" kind="${5:-info}"
  local title msg
  if [[ "$UI_LANG" == "de" ]]; then
    title="$de_title"
    msg="$de_msg"
  else
    title="$en_title"
    msg="$en_msg"
  fi

  if command -v zenity >/dev/null 2>&1; then
    if [[ "$kind" == "error" ]]; then
      zenity --error --title="$title" --text="$msg" >/dev/null 2>&1 || true
    else
      zenity --info --title="$title" --text="$msg" >/dev/null 2>&1 || true
    fi
  elif command -v kdialog >/dev/null 2>&1; then
    if [[ "$kind" == "error" ]]; then
      kdialog --error "$msg" --title "$title" >/dev/null 2>&1 || true
    else
      kdialog --msgbox "$msg" --title "$title" >/dev/null 2>&1 || true
    fi
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$msg" >/dev/null 2>&1 || true
  fi
}

show_success_popup() {
  show_popup     "Aseprite Build Helper"     "Aseprite Build Helper"     "$1"     "$2"     "info"
}

show_stage_failure() {
  local de_stage="$1" en_stage="$2" logfile="$3" rc="$4"
  printf '\n'
  say "FEHLER: $de_stage ist fehlgeschlagen (Code $rc)."       "ERROR: $en_stage failed (code $rc)."
  if [[ -f "$logfile" ]]; then
    say "Letzte Logzeilen:" "Last log lines:"
    printf '%s\n' '------------------------------------------------------------'
    tail -n 20 "$logfile" 2>/dev/null || true
    printf '%s\n' '------------------------------------------------------------'
    say "Vollständiger Log: $logfile" "Full log: $logfile"
  fi
  show_popup     "Aseprite Build Helper - Fehler"     "Aseprite Build Helper - Error"     "$de_stage ist fehlgeschlagen.\n\nDetails: $logfile"     "$en_stage failed.\n\nDetails: $logfile"     "error"
}

require_x64() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) return 0 ;;
    *)
      say "Diese Ausgabe unterstützt derzeit nur Linux x86_64. Erkannt: $arch" \
          "This build currently supports Linux x86_64 only. Detected: $arch"
      return 1
      ;;
  esac
}

detect_distro() {
  DISTRO_ID="unknown"
  DISTRO_LIKE=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
  fi
}

pkg_family() {
  case "$DISTRO_ID $DISTRO_LIKE" in
    *debian*|*ubuntu*) echo debian ;;
    *fedora*|*rhel*|*centos*) echo fedora ;;
    *arch*) echo arch ;;
    *suse*|*opensuse*) echo suse ;;
    *void*) echo void ;;
    *) echo unknown ;;
  esac
}

install_packages() {
  detect_distro
  local family
  family="$(pkg_family)"

  case "$family" in
    debian)
      sudo apt-get update && sudo apt-get install -y \
        g++ clang cmake ninja-build unzip zip curl git \
        libx11-dev libxcursor-dev libxi-dev libxrandr-dev \
        libgl1-mesa-dev libfontconfig1-dev
      ;;
    fedora)
      sudo dnf install -y \
        gcc-c++ clang libcxx-devel cmake ninja-build unzip zip curl git \
        libX11-devel libXcursor-devel libXi-devel libXrandr-devel \
        mesa-libGL-devel fontconfig-devel
      ;;
    arch)
      sudo pacman -S --needed --noconfirm \
        base-devel clang cmake ninja unzip zip curl git \
        libx11 libxcursor libxi libxrandr mesa fontconfig libwebp
      ;;
    suse)
      sudo zypper install -y \
        gcc-c++ clang cmake ninja unzip zip curl git \
        libX11-devel libXcursor-devel libXi-devel libXrandr-devel \
        Mesa-libGL-devel fontconfig-devel
      ;;
    void)
      sudo xbps-install -Sy \
        gcc clang cmake ninja unzip zip curl git \
        libX11-devel libXcursor-devel libXi-devel libXrandr-devel \
        MesaLib-devel fontconfig-devel libwebp-devel
      ;;
    *)
      say "Die Distribution wird für die automatische Paketinstallation noch nicht unterstützt." \
          "This distribution is not yet supported for automatic package installation."
      return 1
      ;;
  esac
}

check_commands() {
  local missing=0 cmd
  for cmd in git curl unzip zip cmake ninja clang clang++; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf '  [MISSING] %s\n' "$cmd"
      missing=1
    else
      printf '  [OK]      %s -> %s\n' "$cmd" "$(command -v "$cmd")"
    fi
  done
  return "$missing"
}

ensure_prerequisites() {
  say "Systemvoraussetzungen werden geprüft..." "Checking system prerequisites..."
  if check_commands; then
    return 0
  fi

  say "Es fehlen benötigte Pakete." "Required packages are missing."
  detect_distro
  say "Erkannte Distribution: $DISTRO_ID" "Detected distribution: $DISTRO_ID"

  if [[ ! -t 0 ]]; then
    return 1
  fi

  local answer
  say "ABH kann die benötigten Pakete über den System-Paketmanager installieren." \
      "ABH can install the required packages using the system package manager."
  say "Dafür wird sudo verwendet. Fortfahren? [J/n]" "This uses sudo. Continue? [Y/n]"
  read -r answer
  case "${answer:-}" in
    n|N|nein|Nein|no|NO) return 1 ;;
  esac

  install_packages || return 1
  check_commands
}

latest_stable_tag() {
  git -C "$ASEPRITE_DIR" tag -l 'v*' 2>/dev/null \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+([.][0-9]+)?$' \
    | sort -V \
    | tail -n1
}

ensure_source() {
  local source_log="$DEV_LOG_DIR/source-last.log"
  : > "$source_log"

  if [[ ! -d "$ASEPRITE_DIR/.git" ]]; then
    say "Aseprite-Quellcode wird geklont ..." "Cloning Aseprite source ..."
    rm -rf "$ASEPRITE_DIR"
    if git clone --recursive "$ASEPRITE_REPO" "$ASEPRITE_DIR" >"$source_log" 2>&1; then
      say "Aseprite-Quellcode wird geklont ... OK" "Cloning Aseprite source ... OK"
    else
      local rc=$?
      show_stage_failure "Aseprite-Quellcode" "Aseprite source clone" "$source_log" "$rc"
      return "$rc"
    fi
  else
    say "Aseprite-Repository wird aktualisiert ..." "Updating Aseprite repository ..."
    if git -C "$ASEPRITE_DIR" fetch --tags --prune origin >"$source_log" 2>&1; then
      say "Aseprite-Repository wird aktualisiert ... OK" "Updating Aseprite repository ... OK"
    else
      local rc=$?
      show_stage_failure "Aseprite-Repository" "Aseprite repository update" "$source_log" "$rc"
      return "$rc"
    fi
  fi

  local tag
  tag="$(latest_stable_tag)"
  if [[ -z "$tag" ]]; then
    say "Es konnte kein stabiler Aseprite-Tag ermittelt werden." \
        "Could not determine a stable Aseprite tag."
    return 1
  fi

  log "Selected Aseprite tag: $tag"
  say "Aseprite-Version $tag wird vorbereitet ..." "Preparing Aseprite $tag ..."
  if ! git -C "$ASEPRITE_DIR" checkout --force "$tag" >>"$source_log" 2>&1; then
    local rc=$?
    show_stage_failure "Aseprite-Version" "Aseprite version checkout" "$source_log" "$rc"
    return "$rc"
  fi
  if ! git -C "$ASEPRITE_DIR" submodule update --init --recursive >>"$source_log" 2>&1; then
    local rc=$?
    show_stage_failure "Aseprite-Submodule" "Aseprite submodules" "$source_log" "$rc"
    return "$rc"
  fi
  say "Aseprite-Version $tag wird vorbereitet ... OK" "Preparing Aseprite $tag ... OK"
  printf '%s\n' "$tag" > "$STATE_DIR/aseprite_tag.txt"
}

required_skia_tag() {
  local tag_file="$ASEPRITE_DIR/laf/misc/skia-tag.txt"
  [[ -f "$tag_file" ]] || return 1
  tr -d '\r\n' < "$tag_file"
}

ensure_skia() {
  local skia_tag skia_dir archive url
  skia_tag="$(required_skia_tag)" || {
    say "Die von Aseprite erwartete Skia-Version konnte nicht gelesen werden." \
        "Could not read the Skia version required by Aseprite."
    return 1
  }

  skia_dir="$SKIA_ROOT/$skia_tag"
  archive="$TOOLS_DIR/Skia-Linux-Release-x64-$skia_tag.zip"
  url="$SKIA_RELEASE_BASE/$skia_tag/Skia-Linux-Release-x64.zip"

  if [[ -f "$skia_dir/out/Release-x64/libskia.a" ]]; then
    log "Skia ready: $skia_tag"
    printf '%s\n' "$skia_dir"
    return 0
  fi

  local download_log="$DEV_LOG_DIR/skia-download-last.log"
  : > "$download_log"
  say "Skia $skia_tag herunterladen ..." "Downloading Skia $skia_tag ..." >&2
  mkdir -p "$skia_dir"
  rm -f "$archive"
  if curl --silent --show-error --fail --location --retry 3 --connect-timeout 20 -o "$archive" "$url" >>"$download_log" 2>&1; then
    say "Skia $skia_tag herunterladen ... OK" "Downloading Skia $skia_tag ... OK" >&2
  else
    local rc=$?
    show_stage_failure "Skia-Download" "Skia download" "$download_log" "$rc"
    return "$rc"
  fi
  say "Skia entpacken ..." "Extracting Skia ..." >&2
  if unzip -q -o "$archive" -d "$skia_dir" >>"$download_log" 2>&1; then
    say "Skia entpacken ... OK" "Extracting Skia ... OK" >&2
  else
    local rc=$?
    show_stage_failure "Skia entpacken" "Skia extraction" "$download_log" "$rc"
    return "$rc"
  fi

  if [[ ! -f "$skia_dir/out/Release-x64/libskia.a" ]]; then
    say "Skia wurde entpackt, aber libskia.a wurde nicht am erwarteten Ort gefunden." \
        "Skia was extracted, but libskia.a was not found in the expected location." >&2
    return 1
  fi

  printf '%s\n' "$skia_dir"
}

build_aseprite() {
  local skia_dir
  skia_dir="$(ensure_skia)" || return 1

  say "Aseprite wird konfiguriert..." "Configuring Aseprite..."
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"

  export CC=clang
  export CXX=clang++

  say "CMake konfigurieren ..." "Configuring CMake ..."
  if cmake \
    -S "$ASEPRITE_DIR" \
    -B "$BUILD_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CXX_FLAGS:STRING=-stdlib=libstdc++ \
    -DCMAKE_EXE_LINKER_FLAGS:STRING=-stdlib=libstdc++ \
    -DLAF_BACKEND=skia \
    -DSKIA_DIR="$skia_dir" \
    -DSKIA_LIBRARY_DIR="$skia_dir/out/Release-x64" \
    -DSKIA_LIBRARY="$skia_dir/out/Release-x64/libskia.a" \
    >"$DEV_LOG_DIR/cmake-last.log" 2>&1; then
    say "CMake konfigurieren ... OK" "Configuring CMake ... OK"
  else
    local rc=$?
    show_stage_failure "CMake-Konfiguration" "CMake configuration" "$DEV_LOG_DIR/cmake-last.log" "$rc"
    return "$rc"
  fi

  say "Aseprite kompilieren ..." "Building Aseprite ..."
  if cmake --build "$BUILD_DIR" -- aseprite >"$DEV_LOG_DIR/build-last.log" 2>&1; then
    say "Aseprite kompilieren ... OK" "Building Aseprite ... OK"
  else
    local rc=$?
    show_stage_failure "Aseprite-Kompilierung" "Aseprite build" "$DEV_LOG_DIR/build-last.log" "$rc"
    return "$rc"
  fi

  [[ -x "$BUILD_DIR/bin/aseprite" ]] || return 1
  return 0
}

create_runtime() {
  cat > "$LAUNCHER_DIR/aseprite-launcher.sh" <<EOF_LAUNCHER
#!/usr/bin/env bash
"$SCRIPT_DIR/aseprite-build-helper.sh" --scheduled >/dev/null 2>&1 &
exec "$BUILD_DIR/bin/aseprite" "\$@"
EOF_LAUNCHER
  chmod +x "$LAUNCHER_DIR/aseprite-launcher.sh"

  cat > "$UPDATER_DIR/aseprite-build-updater.sh" <<EOF_UPDATER
#!/usr/bin/env bash
exec "$SCRIPT_DIR/aseprite-build-helper.sh" --manager "\$@"
EOF_UPDATER
  chmod +x "$UPDATER_DIR/aseprite-build-updater.sh"

  cat > "$UNINSTALLER_DIR/uninstall-abh.sh" <<EOF_UNINSTALL
#!/usr/bin/env bash
exec "$SCRIPT_DIR/aseprite-build-helper.sh" --uninstall "\$@"
EOF_UNINSTALL
  chmod +x "$UNINSTALLER_DIR/uninstall-abh.sh"

  local apps_dir="$HOME/.local/share/applications"
  local desktop_dir=""
  mkdir -p "$apps_dir"

  if command -v xdg-user-dir >/dev/null 2>&1; then
    desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
  fi
  if [[ -z "$desktop_dir" || "$desktop_dir" == "$HOME" ]]; then
    if [[ -d "$HOME/Schreibtisch" ]]; then
      desktop_dir="$HOME/Schreibtisch"
    else
      desktop_dir="$HOME/Desktop"
    fi
  fi
  mkdir -p "$desktop_dir"

  cat > "$apps_dir/aseprite-abh.desktop" <<EOF_DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Aseprite
Comment=Aseprite built locally with Aseprite Build Helper
Exec="$LAUNCHER_DIR/aseprite-launcher.sh"
Terminal=false
Icon=applications-graphics
Categories=Graphics;2DGraphics;RasterGraphics;
StartupNotify=true
EOF_DESKTOP

  cat > "$apps_dir/aseprite-build-updater.desktop" <<EOF_DESKTOP2
[Desktop Entry]
Version=1.0
Type=Application
Name=Aseprite Build Updater
Comment=Update and maintain the local Aseprite build
Exec="$UPDATER_DIR/aseprite-build-updater.sh"
Terminal=true
Icon=system-software-update
Categories=Utility;
StartupNotify=true
EOF_DESKTOP2

  chmod +x "$apps_dir/aseprite-abh.desktop" "$apps_dir/aseprite-build-updater.desktop"

  cp -f "$apps_dir/aseprite-abh.desktop" "$desktop_dir/Aseprite.desktop"
  cp -f "$apps_dir/aseprite-build-updater.desktop" "$desktop_dir/Aseprite Build Updater.desktop"
  chmod +x "$desktop_dir/Aseprite.desktop" "$desktop_dir/Aseprite Build Updater.desktop"

  if command -v gio >/dev/null 2>&1; then
    gio set "$desktop_dir/Aseprite.desktop" metadata::trusted true >/dev/null 2>&1 || true
    gio set "$desktop_dir/Aseprite Build Updater.desktop" metadata::trusted true >/dev/null 2>&1 || true
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
  fi

  say "Anwendungs- und Desktop-Verknüpfungen wurden erstellt." \
      "Application and desktop shortcuts were created."
  say "Desktop: $desktop_dir" "Desktop: $desktop_dir"
}


version_gt() {
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]
}

hours_since_file() {
  local f="$1" now then
  [[ -f "$f" ]] || { echo 999999; return; }
  now="$(date +%s)"
  then="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
  echo $(( (now-then)/3600 ))
}

ensure_settings() {
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    cat > "$SETTINGS_FILE" <<EOF_SETTINGS
# Aseprite Build Helper settings
update_interval_hours=12
recommended_content_pack=ask
EOF_SETTINGS
    return
  fi
  grep -q '^update_interval_hours=' "$SETTINGS_FILE" || printf 'update_interval_hours=12\n' >> "$SETTINGS_FILE"
  grep -q '^recommended_content_pack=' "$SETTINGS_FILE" || printf 'recommended_content_pack=ask\n' >> "$SETTINGS_FILE"
}

set_setting() {
  local key="$1" value="$2" tmp
  ensure_settings
  tmp="$(mktemp)"
  awk -F= -v k="$key" -v v="$value" 'BEGIN{done=0} $1==k {print k "=" v; done=1; next} {print} END{if(!done) print k "=" v}' "$SETTINGS_FILE" > "$tmp"
  mv "$tmp" "$SETTINGS_FILE"
}

get_update_hours() {
  ensure_settings
  local v
  v="$(awk -F= '$1=="update_interval_hours" {gsub(/[[:space:]]/,"",$2); print $2}' "$SETTINGS_FILE" | tail -n1)"
  [[ "$v" =~ ^[0-9]+$ ]] && (( v >= 1 )) && echo "$v" || echo "$DEFAULT_UPDATE_HOURS"
}

get_recommended_content_pack() {
  ensure_settings
  local v
  v="$(awk -F= '$1=="recommended_content_pack" {gsub(/[[:space:]]/,"",$2); print tolower($2)}' "$SETTINGS_FILE" | tail -n1)"
  case "$v" in true|false|ask) echo "$v" ;; *) echo ask ;; esac
}

write_source_ini() {
  local dir="$1" file="$2" name="$3" type="$4" repo="$5" managed="$6" auto="$7" license="${8:-unverified}" recommended="${9:-false}"
  [[ -f "$dir/$file" ]] && return 0
  cat > "$dir/$file" <<EOF_SOURCE
[Source]
name=$name
type=$type
repository=$repo
enabled=true
auto_update=$auto
managed_by=$managed
license=$license
recommended=$recommended
EOF_SOURCE
}

is_recommended_repo() {
  case "$1" in
    https://github.com/catppuccin/aseprite.git|\
    https://github.com/marsn3/aseprite-nord.git|\
    https://github.com/dracula/aseprite.git|\
    https://github.com/Pixeltica/AsepriteExtensions.git|\
    https://github.com/Snepsid/aseprite-scripts.git|\
    https://github.com/christopherwk210/aseprite-scripts.git|\
    https://github.com/sandord/aseprite-scripts.git|\
    https://github.com/colinlienard/aseprite-scripts.git|\
    https://github.com/aseprite/Aseprite-Script-Examples.git|\
    https://github.com/Gabinou/tilemap_scripts_aseprite.git|\
    https://github.com/quantumsheep/aseprite-export-layers.git|\
    https://github.com/JRiggles/Lospec-Palette-Importer.git|\
    https://github.com/securas/EdgeNormals.git|\
    https://github.com/Beatso/UsefulAsepriteScripts.git) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_default_sources() {
  mkdir -p "$THEME_SOURCE_DIR" "$ADDON_SOURCE_DIR" "$MIXED_SOURCE_DIR"

  # Recommended pack: licenses verified and suitable for the default opt-in set.
  write_source_ini "$THEME_SOURCE_DIR" catppuccin.ini "Catppuccin" theme "https://github.com/catppuccin/aseprite.git" ABH true "MIT" true
  write_source_ini "$THEME_SOURCE_DIR" nord.ini "Nord" theme "https://github.com/marsn3/aseprite-nord.git" ABH true "MIT + Aseprite EULA-derived theme assets" true
  write_source_ini "$THEME_SOURCE_DIR" dracula.ini "Dracula" theme "https://github.com/dracula/aseprite.git" ABH true "MIT + Aseprite EULA-derived theme assets" true

  write_source_ini "$ADDON_SOURCE_DIR" pixeltica.ini "Pixeltica Extensions" addon "https://github.com/Pixeltica/AsepriteExtensions.git" ABH true "MIT" true
  write_source_ini "$ADDON_SOURCE_DIR" snepsid.ini "Snepsid scripts" addon "https://github.com/Snepsid/aseprite-scripts.git" ABH true "CC0-1.0" true
  write_source_ini "$ADDON_SOURCE_DIR" christopherwk210.ini "christopherwk210 scripts" addon "https://github.com/christopherwk210/aseprite-scripts.git" ABH true "MIT" true
  write_source_ini "$ADDON_SOURCE_DIR" sandord.ini "sandord scripts" addon "https://github.com/sandord/aseprite-scripts.git" ABH true "MIT" true
  write_source_ini "$ADDON_SOURCE_DIR" colinlienard.ini "colinlienard scripts" addon "https://github.com/colinlienard/aseprite-scripts.git" ABH true "MIT" true
  write_source_ini "$ADDON_SOURCE_DIR" examples.ini "Aseprite Script Examples" addon "https://github.com/aseprite/Aseprite-Script-Examples.git" ABH true "MIT" true
  write_source_ini "$ADDON_SOURCE_DIR" gabinou.ini "Gabinou tilemap scripts" addon "https://github.com/Gabinou/tilemap_scripts_aseprite.git" ABH true "MIT" true
  write_source_ini "$ADDON_SOURCE_DIR" export-layers.ini "Export Layers" addon "https://github.com/quantumsheep/aseprite-export-layers.git" ABH true "MIT" true
  write_source_ini "$ADDON_SOURCE_DIR" lospec.ini "Lospec Palette Importer" addon "https://github.com/JRiggles/Lospec-Palette-Importer.git" ABH true "MIT" true
  write_source_ini "$ADDON_SOURCE_DIR" edge-normals.ini "EdgeNormals" addon "https://github.com/securas/EdgeNormals.git" ABH true "MIT" true
  write_source_ini "$ADDON_SOURCE_DIR" useful.ini "Useful Aseprite Scripts" addon "https://github.com/Beatso/UsefulAsepriteScripts.git" ABH true "MIT" true

  # Optional sources remain available but are not part of the recommended automatic pack.
  # They are disabled by the built-in policy until the user explicitly manages them.
  write_source_ini "$THEME_SOURCE_DIR" studio.ini "Studio Theme" theme "https://github.com/Lyutria/aseprite-studio-theme.git" ABH false "unverified" false
  write_source_ini "$THEME_SOURCE_DIR" monaki.ini "Monaki" theme "https://github.com/el-falso/monaki-theme.git" ABH false "Aseprite EULA" false
  write_source_ini "$THEME_SOURCE_DIR" jmswrnr.ini "JMSWRNR Themes" theme "https://github.com/jmswrnr/aseprite-themes.git" ABH false "unverified" false
  write_source_ini "$THEME_SOURCE_DIR" dark-moon.ini "Dark Moon" theme "https://github.com/emhuo/dark-moon-theme.git" ABH false "CC BY 4.0 / OFL fonts" false
  write_source_ini "$THEME_SOURCE_DIR" aletheia.ini "Aletheia" theme "https://github.com/behreajj/Aletheia.git" ABH false "license file present; not included in recommended pack" false

  write_source_ini "$ADDON_SOURCE_DIR" thkwznk.ini "thkwznk scripts" addon "https://github.com/thkwznk/aseprite-scripts.git" ABH false "unverified" false
  write_source_ini "$ADDON_SOURCE_DIR" mrbrownjeremy.ini "mrbrownjeremy scripts" addon "https://github.com/mrbrownjeremy/aseprite-scripts.git" ABH false "license file present; not included in recommended pack" false
  write_source_ini "$ADDON_SOURCE_DIR" opsiskalopsis.ini "OpsisKalopsis scripts" addon "https://github.com/OpsisKalopsis/aseprite-scripts.git" ABH false "unverified" false
  write_source_ini "$ADDON_SOURCE_DIR" dominickjohn.ini "dominickjohn scripts" addon "https://github.com/dominickjohn/aseprite.git" ABH false "unverified" false
  write_source_ini "$ADDON_SOURCE_DIR" limeth.ini "Limeth iso scripts" addon "https://github.com/Limeth/aseprite-iso-scripts.git" ABH false "license file present; not included in recommended pack" false
  write_source_ini "$ADDON_SOURCE_DIR" dithering.ini "Dithering Brushes" addon "https://github.com/exokem/aseprite-dithering-brushes.git" ABH false "CC BY-NC-SA 4.0" false
  write_source_ini "$ADDON_SOURCE_DIR" normalmap.ini "Normalmap" addon "https://github.com/carlmartus/aseprite_normalmap.git" ABH false "unverified" false
  write_source_ini "$ADDON_SOURCE_DIR" ez-outline.ini "EZ Outline" addon "https://github.com/iNightfaller/aseprite-ez-outline.git" ABH false "license file present; not included in recommended pack" false
  write_source_ini "$ADDON_SOURCE_DIR" zachary.ini "Zachary Scripts" addon "https://github.com/ZachIsAGardner/ZacharyAsepriteScripts.git" ABH false "unverified" false
  write_source_ini "$ADDON_SOURCE_DIR" savu.ini "Normal map and tileset scripts" addon "https://github.com/SavuGeorge/Aseprite-scripts-for-normal-map-and-tileset-manipulation.git" ABH false "no clear license found" false
  write_source_ini "$ADDON_SOURCE_DIR" rikfuzz.ini "rikfuzz scripts" addon "https://github.com/rikfuzz/aseprite-scripts.git" ABH false "GPL-3.0" false
  write_source_ini "$ADDON_SOURCE_DIR" puzzlescript.ini "PuzzleScript Export" addon "https://github.com/pancelor/aseprite-puzzlescript-export.git" ABH false "unverified" false
  write_source_ini "$ADDON_SOURCE_DIR" davebarker.ini "Dave Barker scripts" addon "https://github.com/davebarkeruk/Aseprite_LUA_Scripts.git" ABH false "unverified" false
  write_source_ini "$ADDON_SOURCE_DIR" tekf.ini "TekF scripts" addon "https://github.com/TekF/Aseprite-Scripts.git" ABH false "unverified" false
  write_source_ini "$ADDON_SOURCE_DIR" lpc.ini "LPC2ASE" addon "https://github.com/IoriBranford/aseprite-import-lpc-character.git" ABH false "unverified" false

  if [[ ! -f "$THEME_SOURCE_DIR/_USER_THEME_TEMPLATE.ini" ]]; then
    cat > "$THEME_SOURCE_DIR/_USER_THEME_TEMPLATE.ini" <<'EOF_USER'
# Copy this file and rename it. Review the source license before enabling it.
[Source]
name=My Theme
type=theme
repository=https://github.com/example/theme.git
enabled=false
auto_update=false
managed_by=user
license=review-required
recommended=false
EOF_USER
  fi
  if [[ ! -f "$ADDON_SOURCE_DIR/_USER_ADDON_TEMPLATE.ini" ]]; then
    cat > "$ADDON_SOURCE_DIR/_USER_ADDON_TEMPLATE.ini" <<'EOF_USER'
# Copy this file and rename it. Review the source license before enabling it.
[Source]
name=My Add-on
type=addon
repository=https://github.com/example/addon.git
enabled=false
auto_update=false
managed_by=user
license=review-required
recommended=false
EOF_USER
  fi
  if [[ ! -f "$MIXED_SOURCE_DIR/_USER_MIXED_TEMPLATE.ini" ]]; then
    cat > "$MIXED_SOURCE_DIR/_USER_MIXED_TEMPLATE.ini" <<'EOF_USER'
# Mixed repositories can contain extensions and loose Lua scripts.
[Source]
name=My Mixed Source
type=mixed
repository=https://github.com/example/mixed.git
enabled=false
auto_update=false
managed_by=user
license=review-required
recommended=false
EOF_USER
  fi
}

ini_value() {
  local file="$1" key="$2"
  awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,""); gsub(/^ +| +$/,"",$0); print; exit}' "$file"
}

safe_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+|-+$//g'
}

sync_one_source() {
  local ini="$1" force="${2:-false}" name type repo enabled auto managed slug dest
  name="$(ini_value "$ini" name)"
  type="$(ini_value "$ini" type)"
  repo="$(ini_value "$ini" repository)"
  enabled="$(ini_value "$ini" enabled)"
  auto="$(ini_value "$ini" auto_update)"
  managed="$(ini_value "$ini" managed_by)"
  [[ "$enabled" == "true" ]] || return 0
  if [[ "$managed" == "ABH" ]] && is_recommended_repo "$repo" && [[ "$(get_recommended_content_pack)" != "true" ]]; then
    log "Skipping recommended ABH source (pack disabled): $name"
    return 0
  fi
  if [[ "$managed" == "ABH" ]] && ! is_recommended_repo "$repo"; then
    log "Skipping non-recommended built-in source: $name"
    return 0
  fi
  [[ -n "$repo" ]] || return 0
  if [[ "$force" != "true" && "$auto" != "true" ]]; then
    log "Skipping source (auto_update=false): $name"
    return 0
  fi
  slug="$(safe_slug "${name:-$(basename "$repo" .git)}")"
  [[ -n "$slug" ]] || slug="source"
  dest="$REPO_CACHE_DIR/$slug"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" fetch --all --prune >>"$DEV_LOG" 2>&1 || return 1
    git -C "$dest" pull --ff-only >>"$DEV_LOG" 2>&1 || true
  else
    rm -rf "$dest"
    git clone --depth 1 "$repo" "$dest" >>"$DEV_LOG" 2>&1 || return 1
  fi

  if [[ "$type" == "theme" || "$type" == "mixed" ]]; then
    local ext_target="$ASEPRITE_EXT_DIR/auto-$slug"
    rm -rf "$ext_target"
    mkdir -p "$ext_target"
    cp -a "$dest/." "$ext_target/"
  fi

  if [[ "$type" == "addon" || "$type" == "mixed" ]]; then
    local script_target="$ASEPRITE_SCRIPT_DIR/$slug"
    rm -rf "$script_target"
    mkdir -p "$script_target"
    find "$dest" -type f \( -iname '*.lua' -o -iname '*.aseprite-extension' \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
      local rel="${f#$dest/}"
      mkdir -p "$script_target/$(dirname "$rel")"
      cp -a "$f" "$script_target/$rel"
    done
    find "$dest" -maxdepth 1 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' -o -iname 'README*' \) -exec cp -a {} "$script_target/" \; 2>/dev/null || true
    if [[ -f "$dest/package.json" ]]; then
      local ext_target="$ASEPRITE_EXT_DIR/auto-$slug"
      rm -rf "$ext_target"
      mkdir -p "$ext_target"
      cp -a "$dest/." "$ext_target/"
    fi
  fi
  log "Synced source: $name ($type)"
}

sync_sources() {
  local force="${1:-false}" failures=0 ini
  ensure_default_sources
  mkdir -p "$ASEPRITE_EXT_DIR" "$ASEPRITE_SCRIPT_DIR" "$REPO_CACHE_DIR"
  if [[ "$(get_recommended_content_pack)" == "true" ]]; then
    say "Empfohlenes Theme-/Add-on-/Skript-Paket wird synchronisiert..." "Synchronizing recommended theme/add-on/script pack..."
  else
    say "Empfohlenes Content-Paket ist deaktiviert; nur aktivierte Benutzerquellen werden synchronisiert." "Recommended content pack is disabled; only enabled user sources will be synchronized."
  fi
  for ini in "$THEME_SOURCE_DIR"/*.ini "$ADDON_SOURCE_DIR"/*.ini "$MIXED_SOURCE_DIR"/*.ini; do
    [[ -f "$ini" ]] || continue
    [[ "$(basename "$ini")" == _USER_* ]] && continue
    sync_one_source "$ini" "$force" || { failures=$((failures+1)); devlog "Source sync failed: $ini"; }
  done
  touch "$LAST_CONTENT_CHECK"
  if (( failures == 0 )); then
    say "Theme-/Add-on-Synchronisierung abgeschlossen." "Theme/add-on synchronization completed."
    return 0
  fi
  say "Synchronisierung abgeschlossen, aber $failures Quelle(n) meldeten Fehler. Details: $DEV_LOG" \
      "Synchronization completed, but $failures source(s) reported errors. Details: $DEV_LOG"
  return 1
}

latest_abh_release_asset() {
  curl -fsSL --connect-timeout 15 --max-time 30 \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/tvetzio/aseprite-build-helper/releases?per_page=30" 2>>"$DEV_LOG" \
    | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | sed -E 's/^.*"(https:[^"]+)"$/\1/' \
    | grep -E '/abh-linux-x64-v[0-9][^/]*\.tar\.gz$' \
    | head -n1
}

check_self_update() {
  local interactive="${1:-false}" latest cur asset tmp unpack asset_name
  asset="$(latest_abh_release_asset || true)"
  touch "$LAST_ABH_CHECK"
  if [[ -z "$asset" ]]; then
    say "ABH-Self-Update ist derzeit nicht erreichbar." "ABH self-update is currently unavailable."
    devlog "Linux self-update asset lookup unavailable."
    return 0
  fi
  asset_name="${asset##*/}"
  latest="${asset_name#abh-linux-x64-v}"
  latest="${latest%.tar.gz}"
  cur="$ABH_VERSION"
  if ! version_gt "$latest" "$cur"; then
    say "ABH ist aktuell (v$cur)." "ABH is up to date (v$cur)."
    return 0
  fi
  say "Neue ABH-Linux-Version gefunden: v$latest (installiert: v$cur)" "New ABH Linux version found: v$latest (installed: v$cur)"
  [[ "$interactive" == "true" && -t 0 ]] || return 0
  say "Jetzt aktualisieren? [J/n]" "Update now? [Y/n]"
  read -r ans
  case "${ans:-}" in n|N|nein|Nein|no|NO) return 0 ;; esac

  tmp="$(mktemp -d)"
  mkdir -p "$UPDATER_DIR/backup"
  cp -f "$SCRIPT_DIR/aseprite-build-helper.sh" "$UPDATER_DIR/backup/aseprite-build-helper-$ABH_VERSION.sh" 2>/dev/null || true
  cp -f "$SCRIPT_DIR/README.md" "$UPDATER_DIR/backup/README-$ABH_VERSION.md" 2>/dev/null || true
  curl -fL --retry 3 -o "$tmp/abh.tar.gz" "$asset" >>"$DEV_LOG" 2>&1 || { rm -rf "$tmp"; return 1; }
  mkdir -p "$tmp/unpack"
  tar -xzf "$tmp/abh.tar.gz" -C "$tmp/unpack" || { rm -rf "$tmp"; return 1; }
  unpack="$(find "$tmp/unpack" -maxdepth 2 -type f -name aseprite-build-helper.sh -printf '%h\n' | head -n1)"
  [[ -n "$unpack" ]] || { rm -rf "$tmp"; return 1; }
  for f in aseprite-build-helper.sh README.md LICENSE THIRD_PARTY_NOTICES.md; do
    [[ -f "$unpack/$f" ]] && cp -f "$unpack/$f" "$SCRIPT_DIR/$f"
  done
  chmod +x "$SCRIPT_DIR/aseprite-build-helper.sh"
  rm -rf "$tmp"
  say "ABH wurde auf v$latest aktualisiert. Der Updater wird neu gestartet." "ABH was updated to v$latest. Restarting updater."
  exec "$SCRIPT_DIR/aseprite-build-helper.sh" --manager
}

create_diagnostic_package() {
  local stamp work out
  stamp="$(date '+%Y%m%d-%H%M%S')"
  work="$(mktemp -d)"
  out="$REPORT_DIR/abh-linux-diagnostics-$stamp.zip"
  mkdir -p "$work/logs/user" "$work/logs/dev" "$work/state" "$work/config"
  {
    echo "Aseprite Build Helper Diagnostic Report"
    echo "Helper version: $ABH_VERSION"
    echo "Created: $(date -Is)"
    echo "Kernel: $(uname -a)"
    echo "Architecture: $(uname -m)"
    echo "UI language: $UI_LANG"
    echo "Distribution:"
    cat /etc/os-release 2>/dev/null || true
    echo
    echo "Tool versions:"
    git --version 2>&1 || true
    cmake --version 2>&1 | head -n1 || true
    ninja --version 2>&1 || true
    clang --version 2>&1 | head -n1 || true
    curl --version 2>&1 | head -n1 || true
    echo
    echo "Aseprite state:"
    echo "Executable: $BUILD_DIR/bin/aseprite"
    echo "Executable present: $([[ -x "$BUILD_DIR/bin/aseprite" ]] && echo yes || echo no)"
    echo "Recorded tag: $(cat "$STATE_DIR/aseprite_tag.txt" 2>/dev/null || echo unknown)"
    if [[ -d "$ASEPRITE_DIR/.git" ]]; then
      echo "Commit: $(git -C "$ASEPRITE_DIR" rev-parse HEAD 2>/dev/null || true)"
      echo "Describe: $(git -C "$ASEPRITE_DIR" describe --tags --always 2>/dev/null || true)"
      echo "Branch: $(git -C "$ASEPRITE_DIR" branch --show-current 2>/dev/null || true)"
      echo "Status:"
      git -C "$ASEPRITE_DIR" status --short 2>/dev/null || true
      echo "Submodules:"
      git -C "$ASEPRITE_DIR" submodule status --recursive 2>/dev/null || true
    fi
    echo
    echo "Skia:"
    echo "Required tag: $(required_skia_tag 2>/dev/null || echo unknown)"
    find "$SKIA_ROOT" -maxdepth 3 -type f -name libskia.a -print 2>/dev/null || true
    echo
    echo "Runtime files:"
    find "$LAUNCHER_DIR" "$UPDATER_DIR" "$UNINSTALLER_DIR" -maxdepth 2 -type f -print 2>/dev/null || true
    echo
    echo "Managed source configs:"
    find "$SOURCES_DIR" -type f -name '*.ini' -maxdepth 3 -print 2>/dev/null || true
    echo
    echo "Recent processes:"
    ps -eo pid,ppid,comm,args | grep -E 'aseprite|cmake|ninja|git|abh' | grep -v grep || true
  } > "$work/dev-diagnostic.txt"
  cp -a "$USER_LOG_DIR/." "$work/logs/user/" 2>/dev/null || true
  cp -a "$DEV_LOG_DIR/." "$work/logs/dev/" 2>/dev/null || true
  cp -a "$STATE_DIR/." "$work/state/" 2>/dev/null || true
  cp -a "$CONFIG_DIR/." "$work/config/" 2>/dev/null || true
  (cd "$work" && zip -qr "$out" .)
  rm -rf "$work"
  say "Diagnosepaket erstellt: $out" "Diagnostic package created: $out"
  printf '%s\n' "$out"
}

open_path() {
  local p="$1"
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$p" >/dev/null 2>&1 &
  elif command -v gio >/dev/null 2>&1; then gio open "$p" >/dev/null 2>&1 &
  fi
}

report_bug() {
  create_diagnostic_package >/dev/null || true
  open_path "https://github.com/tvetzio/aseprite-build-helper/issues/new"
  say "GitHub Issues wurde geöffnet. Bitte das neueste Diagnosepaket aus ABH/reports anhängen." \
      "GitHub Issues was opened. Please attach the newest diagnostic package from ABH/reports."
}


check_aseprite_update_available() {
  [[ -d "$ASEPRITE_DIR/.git" ]] || return 0
  git -C "$ASEPRITE_DIR" fetch --tags --prune origin >>"$DEV_LOG" 2>&1 || return 0
  local current latest
  current="$(cat "$STATE_DIR/aseprite_tag.txt" 2>/dev/null || true)"
  latest="$(latest_stable_tag 2>/dev/null || true)"
  if [[ -n "$latest" && "$latest" != "$current" ]]; then
    printf '%s\n' "$latest" > "$STATE_DIR/aseprite_update_available.txt"
    log "Aseprite update available: current=$current latest=$latest"
  else
    rm -f "$STATE_DIR/aseprite_update_available.txt"
  fi
}

scheduled_maintenance() {
  local hours age_abh age_content
  hours="$(get_update_hours)"
  age_abh="$(hours_since_file "$LAST_ABH_CHECK")"
  age_content="$(hours_since_file "$LAST_CONTENT_CHECK")"
  if (( age_abh >= hours )); then
    check_self_update false >/dev/null 2>&1 || true
    check_aseprite_update_available >/dev/null 2>&1 || true
  fi
  if (( age_content >= hours )); then
    sync_sources false >/dev/null 2>&1 || true
  fi
}


change_update_interval() {
  ensure_settings
  local current new
  current="$(get_update_hours)"
  say "Aktuelles Update-Intervall: $current Stunden" "Current update interval: $current hours"
  say "Neue Stunden eingeben (mindestens 1) oder Enter zum Abbrechen:" "Enter new hours (minimum 1) or press Enter to cancel:"
  read -r new
  [[ -n "$new" ]] || return 0
  if [[ "$new" =~ ^[0-9]+$ ]] && (( new >= 1 )); then
    set_setting update_interval_hours "$new"
    say "Update-Intervall gespeichert: $new Stunden" "Update interval saved: $new hours"
  else
    say "Ungültiger Wert." "Invalid value."
  fi
}


ask_recommended_content_pack() {
  local state
  state="$(get_recommended_content_pack)"
  [[ "$state" == "ask" ]] || return 0
  printf '\n'
  say "Optionales Drittanbieter-Content-Paket" "Optional third-party content pack"
  say "ABH kann ein geprüftes Paket aus Themes, Add-ons und Skripten direkt aus den jeweiligen Original-Repositories installieren." \
      "ABH can install a reviewed pack of themes, add-ons and scripts directly from their original repositories."
  say "Diese Inhalte sind nicht Teil von ABH und unterliegen ihren eigenen Lizenzen." \
      "This content is not part of ABH and remains subject to its own licenses."
  printf '\n'
  say "[1] Empfohlenes Paket installieren" "[1] Install recommended pack"
  say "[2] Überspringen - nur Aseprite einrichten" "[2] Skip - install Aseprite only"
  printf '> '
  read -r choice
  case "$choice" in
    1) set_setting recommended_content_pack true ;;
    *) set_setting recommended_content_pack false ;;
  esac
}

manage_recommended_content_pack() {
  local state choice
  state="$(get_recommended_content_pack)"
  printf '\n'
  say "Empfohlenes Content-Paket: $state" "Recommended content pack: $state"
  say "[1] Aktivieren und jetzt synchronisieren" "[1] Enable and synchronize now"
  say "[2] Deaktivieren (installierte Inhalte behalten)" "[2] Disable (keep installed content)"
  say "[0] Abbrechen" "[0] Cancel"
  printf '> '
  read -r choice
  case "$choice" in
    1)
      set_setting recommended_content_pack true
      sync_sources true && show_success_popup "Empfohlenes Content-Paket wurde synchronisiert." "Recommended content pack synchronized."
      ;;
    2)
      set_setting recommended_content_pack false
      say "Automatische Synchronisierung des empfohlenen Pakets wurde deaktiviert." \
          "Automatic synchronization of the recommended pack was disabled."
      ;;
    *) return 0 ;;
  esac
}

manager_menu() {
  while true; do
    printf '\n%s v%s\n' "$PROJECT_NAME" "$ABH_VERSION"
    say "Aseprite Build Updater" "Aseprite Build Updater"
    printf '\n'
    say "[1] Alle Updates jetzt prüfen" "[1] Check all updates now"
    say "[2] Nur ABH-Self-Update prüfen" "[2] Check ABH self-update only"
    say "[3] Nur Aseprite aktualisieren / neu bauen" "[3] Update/rebuild Aseprite only"
    say "[4] Themes / Add-ons / Skripte synchronisieren" "[4] Synchronize themes/add-ons/scripts"
    say "[5] Status anzeigen" "[5] Show status"
    say "[6] Diagnosepaket erstellen" "[6] Create diagnostic package"
    say "[7] Quellen-Konfigurationen öffnen" "[7] Open source configurations"
    say "[8] Update-Intervall anzeigen/ändern" "[8] Show/change update interval"
    say "[9] Empfohlenes Content-Paket verwalten" "[9] Manage recommended content pack"
    say "[R] Bug melden" "[R] Report a bug"
    say "[U] Deinstallieren" "[U] Uninstall"
    say "[0] Beenden" "[0] Exit"
    printf '> '
    read -r c
    case "$c" in
      1) check_self_update true; update_all; pause_if_tty ;;
      2) check_self_update true; pause_if_tty ;;
      3) update_aseprite_only; pause_if_tty ;;
      4) sync_sources true && show_success_popup "Vorgang erfolgreich abgeschlossen." "Operation completed successfully."; pause_if_tty ;;
      5) status; pause_if_tty ;;
      6) create_diagnostic_package; pause_if_tty ;;
      7) ensure_default_sources; open_path "$SOURCES_DIR" ;;
      8) change_update_interval; pause_if_tty ;;
      9) manage_recommended_content_pack; pause_if_tty ;;
      r|R) report_bug; pause_if_tty ;;
      u|U) uninstall_menu; return ;;
      0) return ;;
    esac
  done
}

status() {
  printf '%s v%s\n' "$PROJECT_NAME" "$ABH_VERSION"
  printf 'Root:       %s\n' "$SCRIPT_DIR"
  printf 'Aseprite:   %s\n' "$([[ -x "$BUILD_DIR/bin/aseprite" ]] && echo READY || echo NOT_BUILT)"
  printf 'Tag:        %s\n' "$(cat "$STATE_DIR/aseprite_tag.txt" 2>/dev/null || echo unknown)"
  printf 'Source:     %s\n' "$ASEPRITE_DIR"
  printf 'Build:      %s\n' "$BUILD_DIR"
  printf 'Logs:       %s\n' "$LOG_DIR"
  printf 'Interval:   %sh\n' "$(get_update_hours)"
  printf 'Update:     %s\n' "$(cat "$STATE_DIR/aseprite_update_available.txt" 2>/dev/null || echo none)"
  printf 'Sources:    %s\n' "$SOURCES_DIR"
  printf 'Content:    %s\n' "$(get_recommended_content_pack)"
}

setup() {
  log "START helper=$ABH_VERSION mode=setup"
  require_x64 || return 1
  ensure_prerequisites || return 1
  ensure_source || return 1
  build_aseprite || return 1
  ensure_default_sources
  ask_recommended_content_pack
  sync_sources true || true
  create_runtime || return 1
  say "Einrichtung abgeschlossen." "Setup completed."
  say "Aseprite: $BUILD_DIR/bin/aseprite" "Aseprite: $BUILD_DIR/bin/aseprite"
  show_success_popup "Aseprite-Build erfolgreich abgeschlossen." "Aseprite build completed successfully."
}

update_aseprite_only() {
  log "START helper=$ABH_VERSION mode=aseprite-update"
  require_x64 || return 1
  ensure_prerequisites || return 1
  ensure_source || return 1
  build_aseprite || return 1
  create_runtime || return 1
  say "Aseprite-Update abgeschlossen." "Aseprite update completed."
  show_success_popup "Aseprite-Build erfolgreich abgeschlossen." "Aseprite build completed successfully."
}

update_all() {
  log "START helper=$ABH_VERSION mode=update"
  require_x64 || return 1
  ensure_prerequisites || return 1
  ensure_source || return 1
  build_aseprite || return 1
  ensure_default_sources
  sync_sources true || true
  create_runtime || return 1
  say "Update abgeschlossen." "Update completed."
  show_success_popup "Aseprite-Build erfolgreich abgeschlossen." "Aseprite build completed successfully."
}

uninstall_menu() {
  say "Aseprite Build Helper - Deinstallation" "Aseprite Build Helper - Uninstall"
  printf '\n'
  say "[1] Nur ABH-Runtime und Desktop-Einträge entfernen" "[1] Remove ABH runtime and desktop entries only"
  say "[2] Zusätzlich lokalen Aseprite-Build entfernen" "[2] Also remove the local Aseprite build"
  say "[3] ALLES entfernen, was ABH in diesem Projektordner verwaltet" "[3] REMOVE ALL content managed by ABH in this project folder"
  say "[0] Abbrechen" "[0] Cancel"
  printf '> '
  read -r choice

  case "$choice" in
    1)
      rm -f "$HOME/.local/share/applications/aseprite-abh.desktop" \
            "$HOME/.local/share/applications/aseprite-build-updater.desktop" \
            "$HOME/Desktop/Aseprite.desktop" "$HOME/Desktop/Aseprite Build Updater.desktop" \
            "$HOME/Schreibtisch/Aseprite.desktop" "$HOME/Schreibtisch/Aseprite Build Updater.desktop"
      rm -rf "$LAUNCHER_DIR" "$UPDATER_DIR" "$UNINSTALLER_DIR" "$RUNTIME_DIR"
      ;;
    2)
      rm -f "$HOME/.local/share/applications/aseprite-abh.desktop" \
            "$HOME/.local/share/applications/aseprite-build-updater.desktop" \
            "$HOME/Desktop/Aseprite.desktop" "$HOME/Desktop/Aseprite Build Updater.desktop" \
            "$HOME/Schreibtisch/Aseprite.desktop" "$HOME/Schreibtisch/Aseprite Build Updater.desktop"
      rm -rf "$LAUNCHER_DIR" "$UPDATER_DIR" "$UNINSTALLER_DIR" "$RUNTIME_DIR" "$BUILD_DIR"
      ;;
    3)
      say "WARNUNG: Dadurch wird der komplette ABH-Ordner gelöscht. Eigene Dateien darin gehen ebenfalls verloren." \
          "WARNING: This deletes the complete ABH directory. Any personal files stored inside it will also be lost."
      say "Zum Bestätigen REMOVE ALL eingeben:" "Type REMOVE ALL to confirm:"
      read -r confirm
      [[ "$confirm" == "REMOVE ALL" ]] || return 0
      rm -f "$HOME/.local/share/applications/aseprite-abh.desktop" \
            "$HOME/.local/share/applications/aseprite-build-updater.desktop" \
            "$HOME/Desktop/Aseprite.desktop" "$HOME/Desktop/Aseprite Build Updater.desktop" \
            "$HOME/Schreibtisch/Aseprite.desktop" "$HOME/Schreibtisch/Aseprite Build Updater.desktop"
      rm -rf "$ABH_DIR"
      ;;
    *) return 0 ;;
  esac
  say "Deinstallation abgeschlossen." "Uninstall completed."
}

usage() {
  cat <<EOF_USAGE
$PROJECT_NAME v$ABH_VERSION

Usage:
  ./aseprite-build-helper.sh              Open first-start/main menu
  ./aseprite-build-helper.sh --update     Update Aseprite and rebuild
  ./aseprite-build-helper.sh --manager    Open updater/maintenance menu
  ./aseprite-build-helper.sh --sync       Synchronize themes/add-ons/scripts
  ./aseprite-build-helper.sh --diagnostic Create diagnostic ZIP
  ./aseprite-build-helper.sh --scheduled  Run silent scheduled maintenance
  ./aseprite-build-helper.sh --status     Show current status
  ./aseprite-build-helper.sh --launch     Start Aseprite
  ./aseprite-build-helper.sh --uninstall  Open uninstall menu
  ./aseprite-build-helper.sh --lang=de    Force German UI
  ./aseprite-build-helper.sh --lang=en    Force English UI
EOF_USAGE
}

case "${1:-}" in
  --update) update_all ;;
  --manager) manager_menu ;;
  --sync) sync_sources true ;;
  --diagnostic) create_diagnostic_package ;;
  --scheduled) scheduled_maintenance ;;
  --status) status ;;
  --launch)
    if [[ -x "$BUILD_DIR/bin/aseprite" ]]; then exec "$BUILD_DIR/bin/aseprite"; else setup; fi
    ;;
  --uninstall) uninstall_menu ;;
  --help|-h) usage ;;
  "")
    if [[ -x "$BUILD_DIR/bin/aseprite" ]]; then
      status
      printf '\n'
      say "[1] Aseprite starten" "[1] Launch Aseprite"
      say "[2] Aktualisieren / neu bauen" "[2] Update / rebuild"
      say "[3] Status anzeigen" "[3] Show status"
      say "[4] Deinstallieren" "[4] Uninstall"
      say "[0] Beenden" "[0] Exit"
      printf '> '
      read -r choice
      case "$choice" in
        1) exec "$BUILD_DIR/bin/aseprite" ;;
        2) manager_menu ;;
        3) status; pause_if_tty ;;
        4) uninstall_menu ;;
        *) exit 0 ;;
      esac
    else
      printf '%s v%s\n' "$PROJECT_NAME" "$ABH_VERSION"
      printf '\n'
      say "Aseprite wurde noch nicht eingerichtet." "Aseprite has not been set up yet."
      printf '\n'
      say "[1] Geführte Ersteinrichtung starten" "[1] Start guided first-time setup"
      say "[2] Voraussetzungen / Status anzeigen" "[2] Show requirements / status"
      say "[3] Erweiterte Wartung öffnen" "[3] Open advanced maintenance"
      say "[0] Beenden" "[0] Exit"
      printf '> '
      read -r choice
      case "$choice" in
        1) setup; pause_if_tty ;;
        2) status; printf '\n'; check_commands || true; pause_if_tty ;;
        3) manager_menu ;;
        *) exit 0 ;;
      esac
    fi
    ;;
  *) usage; exit 2 ;;
esac
