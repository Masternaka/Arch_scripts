#!/usr/bin/env bash

# Script d'installation et d'intégration d'AppImage pour Arch/EndeavourOS
#
# Fonctionnalités:
# - Installe les dépendances nécessaires (fuse2, desktop-file-utils, xdg-utils)
# - Installe une AppImage depuis une URL ou un fichier local
# - Intègre l'application au menu (fichier .desktop) et gère l'icône
# - Désinstalle proprement (binaire, .desktop, icône)
# - Mode utilisateur (par défaut) et mode système (requiert sudo)
#
# Utilisation rapide:
#   Installer (utilisateur):
#     ./install_appimage.sh install "https://exemple.com/App.appImage" --name MonApp
#     ./install_appimage.sh install /chemin/vers/AppImage --name MonApp
#
#   Installer (système, nécessite sudo):
#     sudo ./install_appimage.sh install URL|FICHIER --system --name MonApp
#
#   Désinstaller:
#     ./install_appimage.sh uninstall MonApp
#     sudo ./install_appimage.sh uninstall MonApp --system
#
#   Lister:
#     ./install_appimage.sh list
#     ./install_appimage.sh list --system
#
# Options d'installation:
#   --name NOM         Nom logique de l'application (si non fourni, dérivé du nom de fichier)
#   --icon /chemin     Icône personnalisée (png/svg)
#   --system           Installe pour tous les utilisateurs (/opt/AppImages et /usr/share/applications)
#
# Notes:
# - Beaucoup d'AppImage nécessitent fuse2 sur Arch. Ce script l'installe si absent.
# - L'extraction du .desktop et de l'icône est tentée via --appimage-extract; en cas d'échec, un .desktop générique est généré.

set -euo pipefail
IFS=$'\n\t'

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*" >&2; }
err()  { printf "[ERREUR] %s\n" "$*" >&2; }

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || { err "Commande requise introuvable: $cmd"; exit 1; }
}

is_url() {
  local s="$1"
  [[ "$s" =~ ^https?:// ]] && return 0 || return 1
}

ensure_dependencies() {
  # Dépendances système utiles pour AppImage et intégration
  local pkgs=(fuse2 desktop-file-utils xdg-utils)
  if command -v pacman >/dev/null 2>&1; then
    local to_install=()
    for p in "${pkgs[@]}"; do
      if ! pacman -Qi "$p" >/dev/null 2>&1; then
        to_install+=("$p")
      fi
    done
    if (( ${#to_install[@]} > 0 )); then
      bold "Installation des dépendances manquantes: ${to_install[*]}"
      sudo pacman -S --needed --noconfirm "${to_install[@]}"
    fi
  else
    warn "Gestionnaire pacman introuvable. Assurez-vous que fuse2/desktop-file-utils/xdg-utils sont installés."
  fi
}

install_scope_dirs() {
  # Définit les répertoires selon --system ou utilisateur
  local scope="$1" # user|system
  if [[ "$scope" == "system" ]]; then
    APP_DIR="/opt/AppImages"
    BIN_DIR="/usr/local/bin"
    DESKTOP_DIR="/usr/share/applications"
    ICONS_DIR="/usr/share/icons/hicolor/256x256/apps"
    mkdir -p "$APP_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICONS_DIR"
  else
    local home_dir
    home_dir="$HOME"
    APP_DIR="$home_dir/.local/bin/AppImages"
    BIN_DIR="$home_dir/.local/bin"
    DESKTOP_DIR="$home_dir/.local/share/applications"
    ICONS_DIR="$home_dir/.local/share/icons/hicolor/256x256/apps"
    mkdir -p "$APP_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICONS_DIR"
  fi
}

sanitize_name() {
  local n="$1"
  n="${n##*/}"
  n="${n%.AppImage}"
  n="${n%.appimage}"
  n="${n// /-}"
  n="${n//[^A-Za-z0-9._-]/}"
  printf "%s" "$n"
}

download_if_needed() {
  local src="$1"; local dest="$2"
  if is_url "$src"; then
    require_cmd curl
    info "Téléchargement: $src"
    curl -L --fail --progress-bar "$src" -o "$dest"
  else
    if [[ -f "$src" ]]; then
      cp -f "$src" "$dest"
    else
      err "Fichier introuvable: $src"
      exit 1
    fi
  fi
}

extract_resources() {
  # Extrait .desktop et icône depuis l'AppImage si possible
  local appimage_path="$1"; shift
  local extract_dir
  extract_dir="$(mktemp -d)"
  local desktop_out="$1"; shift
  local icon_out="$1"; shift

  # Tentative via --appimage-extract dans un sous-shell pour isoler le cwd
  (
    cd "$extract_dir" || return 1
    if "$appimage_path" --appimage-extract >/dev/null 2>&1; then
      return 0
    fi
  ) || {
    # Tentative via bsdtar (certaines AppImage sont juste squashfs)
    if command -v bsdtar >/dev/null 2>&1; then
      bsdtar -xf "$appimage_path" -C "$extract_dir" 2>/dev/null || true
    fi
  }

  local found_desktop=""
  if [[ -d "$extract_dir/squashfs-root" ]]; then
    # Chercher un .desktop
    found_desktop=$(find "$extract_dir/squashfs-root" -maxdepth 2 -type f -name "*.desktop" | head -n1 || true)
    if [[ -n "$found_desktop" ]]; then
      cp -f "$found_desktop" "$desktop_out"
    fi

    # Chercher icône: priorité .DirIcon, puis hicolor/png, puis usr/share/pixmaps
    if [[ -f "$extract_dir/squashfs-root/.DirIcon" ]]; then
      cp -f "$extract_dir/squashfs-root/.DirIcon" "$icon_out" 2>/dev/null || true
    else
      local icon_candidate
      icon_candidate=$(find "$extract_dir/squashfs-root" -type f \( -name "*.png" -o -name "*.svg" \) \
        | grep -E "/icons/|/pixmaps/|/usr/share/icons/|/hicolor/" | head -n1 || true)
      if [[ -n "$icon_candidate" ]]; then
        cp -f "$icon_candidate" "$icon_out" 2>/dev/null || true
      fi
    fi
  fi

  rm -rf "$extract_dir" 2>/dev/null || true
}

write_desktop_file() {
  local name="$1"; shift
  local exec_path="$1"; shift
  local icon_path="$1"; shift
  local desktop_path="$1"; shift
  local app_name_human="$name"
  cat > "$desktop_path" <<EOF
[Desktop Entry]
Type=Application
Name=$app_name_human
Exec="$exec_path" %U
Icon=$icon_path
Terminal=false
Categories=Utility;Application;
StartupWMClass=$app_name_human
EOF
}

normalize_desktop_exec_and_icon() {
  # Adapte un .desktop existant pour pointer vers l'AppImage et icône extraits
  local desktop_file="$1"; shift
  local exec_path="$1"; shift
  local icon_path="$1"; shift
  # Remplace Exec= et Icon=
  if grep -q '^Exec=' "$desktop_file"; then
    sed -i "s#^Exec=.*#Exec=\"$exec_path\" %U#" "$desktop_file"
  else
    echo "Exec=\"$exec_path\" %U" >> "$desktop_file"
  fi
  if [[ -n "$icon_path" ]]; then
    if grep -q '^Icon=' "$desktop_file"; then
      sed -i "s#^Icon=.*#Icon=$icon_path#" "$desktop_file"
    else
      echo "Icon=$icon_path" >> "$desktop_file"
    fi
  fi
  # S'assure des champs de base
  grep -q '^Type=' "$desktop_file" || echo "Type=Application" >> "$desktop_file"
  grep -q '^Terminal=' "$desktop_file" || echo "Terminal=false" >> "$desktop_file"
  grep -q '^Categories=' "$desktop_file" || echo "Categories=Utility;Application;" >> "$desktop_file"
}

install_appimage() {
  local source_path_or_url=""
  local name_override=""
  local icon_override=""
  local scope="user"

  # Parse args
  while (( "$#" )); do
    case "$1" in
      --name)
        name_override="$2"; shift 2;;
      --icon)
        icon_override="$2"; shift 2;;
      --system)
        scope="system"; shift;;
      --)
        shift; break;;
      *)
        if [[ -z "$source_path_or_url" ]]; then
          source_path_or_url="$1"; shift
        else
          shift
        fi
        ;;
    esac
  done

  if [[ -z "$source_path_or_url" ]]; then
    err "Argument manquant: URL ou chemin AppImage"
    exit 1
  fi

  if [[ "$scope" == "system" && $EUID -ne 0 ]]; then
    warn "Le mode système requiert les privilèges root. Relancez avec sudo."
    exit 1
  fi

  ensure_dependencies
  install_scope_dirs "$scope"

  # Détermination du nom
  local base_name="$(basename "$source_path_or_url")"
  local app_name
  if [[ -n "$name_override" ]]; then
    app_name="$(sanitize_name "$name_override")"
  else
    app_name="$(sanitize_name "$base_name")"
  fi

  local target_appimage="$APP_DIR/$app_name.AppImage"
  mkdir -p "$APP_DIR"

  # Téléchargement / copie
  download_if_needed "$source_path_or_url" "$target_appimage"
  chmod +x "$target_appimage"

  # Lien dans BIN_DIR pour accès direct (nom sans espace)
  mkdir -p "$BIN_DIR"
  ln -sf "$target_appimage" "$BIN_DIR/$app_name"

  # Intégration .desktop et icône
  mkdir -p "$DESKTOP_DIR" "$ICONS_DIR"
  local desktop_path="$DESKTOP_DIR/$app_name.desktop"
  local icon_path="$ICONS_DIR/$app_name.png"

  local tmp_desktop="$(mktemp)"
  local extracted_icon=""
  extract_resources "$target_appimage" "$tmp_desktop" "$icon_path" || true

  if [[ -s "$tmp_desktop" ]]; then
    normalize_desktop_exec_and_icon "$tmp_desktop" "$target_appimage" "$icon_path"
    mv -f "$tmp_desktop" "$desktop_path"
  else
    rm -f "$tmp_desktop" 2>/dev/null || true
    # Génère un .desktop minimaliste
    write_desktop_file "$app_name" "$target_appimage" "$icon_path" "$desktop_path"
  fi

  # Icône override si fournie
  if [[ -n "$icon_override" && -f "$icon_override" ]]; then
    cp -f "$icon_override" "$icon_path"
  fi

  # Base de données desktop
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" || true
  fi

  bold "Installation terminée"
  echo "Nom:        $app_name"
  echo "Binaire:    $target_appimage"
  echo "Lien:       $BIN_DIR/$app_name"
  echo "Desktop:    $desktop_path"
  echo "Icône:      $icon_path"
}

uninstall_appimage() {
  local app_name=""
  local scope="user"
  while (( "$#" )); do
    case "$1" in
      --system) scope="system"; shift;;
      *) app_name="$1"; shift;;
    esac
  done
  if [[ -z "$app_name" ]]; then
    err "Veuillez fournir le nom utilisé à l'installation (ex: MonApp)"
    exit 1
  fi
  if [[ "$scope" == "system" && $EUID -ne 0 ]]; then
    warn "Le mode système requiert les privilèges root. Relancez avec sudo."
    exit 1
  fi

  install_scope_dirs "$scope"

  local app_path="$APP_DIR/$app_name.AppImage"
  local link_path="$BIN_DIR/$app_name"
  local desktop_path="$DESKTOP_DIR/$app_name.desktop"
  local icon_path="$ICONS_DIR/$app_name.png"

  rm -f "$app_path" "$link_path" "$desktop_path" "$icon_path" 2>/dev/null || true
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" || true
  fi
  bold "Désinstallation terminée pour: $app_name"
}

list_appimages() {
  local scope="user"
  while (( "$#" )); do
    case "$1" in
      --system) scope="system"; shift;;
      *) shift;;
    esac
  done
  install_scope_dirs "$scope"
  echo "Répertoire: $APP_DIR"
  if compgen -G "$APP_DIR/*.AppImage" >/dev/null; then
    ls -1 "$APP_DIR"/*.AppImage | sed 's#.*/##' | sed 's#.AppImage$##'
  else
    echo "(aucune AppImage installée dans ce scope)"
  fi
}

print_help() {
  cat <<'HLP'
Utilisation: install_appimage.sh <commande> [options]

Commandes:
  install <URL|FICHIER> [--name NOM] [--icon /chemin] [--system]
  uninstall <NOM> [--system]
  list [--system]
  help

Exemples:
  ./install_appimage.sh install "https://exemple.com/MonApp-latest-x86_64.AppImage" --name MonApp
  ./install_appimage.sh install ~/Téléchargements/MonApp.AppImage --name MonApp --icon ~/monapp.png
  sudo ./install_appimage.sh install URL --system --name MonApp
  ./install_appimage.sh uninstall MonApp
  ./install_appimage.sh list
HLP
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    install) install_appimage "$@" ;;
    uninstall) uninstall_appimage "$@" ;;
    list) list_appimages "$@" ;;
    help|--help|-h|"") print_help ;;
    *) err "Commande inconnue: $cmd"; print_help; exit 1 ;;
  esac
}

main "$@"


