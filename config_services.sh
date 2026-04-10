#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# NAME: config_services.sh
# DESC: Script autonome (Chaotic-AUR + Pacman + Paru + Systemd services + ZRAM)
# =============================================================================

# ─── Mode & résumé ───────────────────────────────────────────────────────────
DRY_RUN=false
CONTINUE_ON_ERROR=""
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
  [[ "$arg" == "--continue-on-error" ]] && CONTINUE_ON_ERROR="true"
  [[ "$arg" == "--no-continue-on-error" ]] && CONTINUE_ON_ERROR="false"
done

SUCCESSES=()
WARNINGS=()
FAILURES=()
CURRENT_STEP=""

record_success() { SUCCESSES+=( "$1" ); }
record_warning() { WARNINGS+=( "$1" ); }
record_failure() { FAILURES+=( "$1" ); }

print_summary() {
  log_title "Résumé"
  if ((${#SUCCESSES[@]})); then
    log_ok "Succès:"
    for s in "${SUCCESSES[@]}"; do
      printf "%b\n" "  - ${s}"
    done
  else
    log_warn "Aucun succès enregistré."
  fi

  if ((${#WARNINGS[@]})); then
    log_warn "Avertissements / étapes ignorées:"
    for w in "${WARNINGS[@]}"; do
      printf "%b\n" "  - ${w}"
    done
  fi

  if ((${#FAILURES[@]})); then
    log_error "Problèmes:"
    for f in "${FAILURES[@]}"; do
      printf "%b\n" "  - ${f}"
    done
  fi
}

trap print_summary EXIT

# ─── Couleurs / logs ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREY='\033[0;90m'
NC='\033[0m'

log_info()    { printf "%b\n" "${BLUE}[INFO]${NC} $*"; }
log_ok()      { printf "%b\n" "${GREEN}[OK]${NC} $*"; }
log_warn()    { printf "%b\n" "${YELLOW}[WARN]${NC} $*"; }
log_error()   { printf "%b\n" "${RED}[ERREUR]${NC} $*"; }
log_title()   { printf "\n%b\n" "${CYAN}── $* ──────────────────────────────────────────${NC}"; }
log_dry()     { printf "%b\n" "${GREY}[~]${NC} $*"; }

show_help() {
  cat <<'EOF'
Usage: ./config_services.sh [OPTIONS]

Options:
  --dry-run                    Dry-run global (aucune modification)
  --continue-on-error          Continue même si une étape échoue
  --no-continue-on-error       Stop au premier échec (défaut)
  --help, -h                   Affiche cette aide

Notes:
  - Le script doit être lancé en utilisateur normal (pas root).
  - Il utilisera sudo uniquement quand nécessaire.
EOF
}

ask_continue_mode_if_needed() {
  if [[ -n "${CONTINUE_ON_ERROR}" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    CONTINUE_ON_ERROR="false"
    return 0
  fi
  echo
  read -r -p "Continuer si une étape échoue ? (y/N): " -n 1 reply
  echo
  if [[ "${reply:-}" =~ ^[Yy]$ ]]; then
    CONTINUE_ON_ERROR="true"
  else
    CONTINUE_ON_ERROR="false"
  fi
}

run_step() {
  local name="$1"
  shift

  CURRENT_STEP="$name"

  # Désactive -e pour capturer l'échec sans quitter.
  set +e
  "$@"
  local ec=$?
  set -e

  if [[ $ec -ne 0 ]]; then
    log_error "Étape '${name}' — échec (code ${ec})"
    record_failure "Étape '${name}' — échec (code ${ec})"
    if [[ "${CONTINUE_ON_ERROR}" == "true" ]]; then
      log_warn "Continuation demandée — on passe à l'étape suivante."
      record_warning "Continuation malgré l'échec de '${name}'"
      return 0
    fi
    exit "$ec"
  fi
  return 0
}

prime_sudo() {
  log_info "Vérification de sudo..."
  sudo -v
  log_ok "sudo OK"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Commande manquante: $cmd"
    exit 1
  fi
}

# =============================================================================
# 1) Chaotic-AUR (intégré depuis modules/Choatic/install_Chaotic.sh)
# =============================================================================

chaotic_check_root_not_root() {
  if [[ ${EUID:-0} -eq 0 ]]; then
    log_error "Ce script ne doit pas être exécuté en tant que root"
    log_info "Exécutez-le en utilisateur normal (il utilisera sudo si nécessaire)."
    exit 1
  fi
}

chaotic_check_pacman() {
  if ! command -v pacman &>/dev/null; then
    log_error "pacman n'est pas disponible. Ce script est destiné à Arch Linux."
    exit 1
  fi
}

chaotic_check_requirements() {
  local missing=0
  for cmd in sudo grep sed tee mktemp rm wc curl wget date cp; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Commande manquante: $cmd"
      missing=1
    fi
  done
  if ((missing)); then
    exit 1
  fi
}

chaotic_check_internet() {
  log_info "Vérification de la connexion internet..."
  if ! curl -fsS --max-time 10 https://archlinux.org/ &>/dev/null; then
    log_error "Connexion internet indisponible (test HTTPS échoué)."
    exit 1
  fi
  log_ok "Connexion internet OK"
}

chaotic_update_system() {
  log_info "Mise à jour du système..."
  sudo pacman -Syu --noconfirm
  log_ok "Système mis à jour"
}

chaotic_install_dependencies() {
  log_info "Installation des dépendances requises..."
  sudo pacman -S --needed --noconfirm base-devel curl wget
  log_ok "Dépendances installées"
}

chaotic_add_primary_key() {
  log_info "Ajout de la clé GPG principale de Chaotic-AUR..."
  sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  sudo pacman-key --lsign-key 3056513887B78AEB
  log_ok "Clé GPG principale ajoutée et signée"
}

chaotic_install_chaotic_packages() {
  log_info "Installation de chaotic-keyring et chaotic-mirrorlist..."

  if pacman -Q chaotic-keyring &>/dev/null && pacman -Q chaotic-mirrorlist &>/dev/null; then
    log_ok "chaotic-keyring et chaotic-mirrorlist sont déjà installés"
    return 0
  fi

  local KEYRING_URL='https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
  local MIRRORLIST_URL='https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    trap 'rm -rf "$tmpdir"' EXIT
    cd "$tmpdir"
    log_info "Téléchargement de chaotic-keyring..."
    wget -q --show-progress "$KEYRING_URL" -O chaotic-keyring.pkg.tar.zst
    log_info "Téléchargement de chaotic-mirrorlist..."
    wget -q --show-progress "$MIRRORLIST_URL" -O chaotic-mirrorlist.pkg.tar.zst
    log_info "Installation des paquets..."
    sudo pacman -U --noconfirm chaotic-keyring.pkg.tar.zst chaotic-mirrorlist.pkg.tar.zst
  )
  log_ok "chaotic-keyring et chaotic-mirrorlist installés"
}

chaotic_add_chaotic_repo() {
  log_info "Ajout du dépôt Chaotic-AUR à pacman.conf..."
  local PACMAN_CONF="/etc/pacman.conf"
  local ts backup_path
  ts="$(date +%Y%m%d_%H%M%S)"
  backup_path="$PACMAN_CONF.backup.$ts"

  if grep -q "\[chaotic-aur\]" "$PACMAN_CONF"; then
    log_warn "Le dépôt Chaotic-AUR existe déjà dans pacman.conf"
    log_info "Suppression de l'ancienne entrée..."
    sudo sed -i '/\[chaotic-aur\]/,/^$/d' "$PACMAN_CONF"
  fi

  sudo cp "$PACMAN_CONF" "$backup_path"
  log_info "Sauvegarde créée: $backup_path"

  sudo tee -a "$PACMAN_CONF" >/dev/null << 'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

  log_ok "Dépôt Chaotic-AUR ajouté à pacman.conf"
}

chaotic_update_pacman_db() {
  log_info "Synchronisation des dépôts et mise à jour..."
  sudo pacman -Syu --noconfirm
  log_ok "Dépôts synchronisés et système à jour"
}

chaotic_verify_installation() {
  log_info "Vérification de l'installation..."
  if pacman -Sl chaotic-aur &>/dev/null; then
    log_ok "Le dépôt Chaotic-AUR est correctement installé et accessible"
    local package_count
    package_count="$(pacman -Sl chaotic-aur | wc -l)"
    log_info "Nombre de paquets disponibles dans Chaotic-AUR: $package_count"
  else
    log_error "L'installation a échoué - le dépôt n'est pas accessible"
    exit 1
  fi
}

chaotic_main() {
  log_title "Chaotic-AUR"
  CURRENT_STEP="Chaotic-AUR"
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "Dry-run: Chaotic-AUR serait installé/configuré (clés + dépôts + pacman.conf)."
    record_warning "Chaotic-AUR ignoré (dry-run)"
    return 0
  fi
  chaotic_check_root_not_root
  chaotic_check_pacman
  chaotic_check_requirements
  prime_sudo
  chaotic_check_internet

  log_warn "Ce script va modifier votre système (pacman.conf + clés + paquets)."
  read -r -p "Voulez-vous continuer? (y/N): " -n 1 reply
  printf "\n\n"
  if [[ ! "${reply:-}" =~ ^[Yy]$ ]]; then
    log_info "Installation annulée par l'utilisateur"
    return 0
  fi

  chaotic_update_system
  chaotic_install_dependencies
  chaotic_add_primary_key
  chaotic_install_chaotic_packages
  chaotic_add_chaotic_repo
  chaotic_update_pacman_db
  chaotic_verify_installation
  log_ok "Chaotic-AUR terminé."
  record_success "Chaotic-AUR"
}

# =============================================================================
# 2) Pacman ParallelDownloads (intégré depuis modules/Pacman/mod_pacman.sh)
# =============================================================================

pacman_parallel_main() {
  log_title "Pacman (ParallelDownloads)"
  CURRENT_STEP="Pacman (ParallelDownloads)"
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "Dry-run: la modification de /etc/pacman.conf serait appliquée (ParallelDownloads)."
    record_warning "Pacman ParallelDownloads ignoré (dry-run)"
    return 0
  fi
  local PACMAN_CONF="/etc/pacman.conf"
  local BACKUP_DIR="/etc/pacman.conf.backups"
  local LOG_FILE="/var/log/pacman_parallel_downloads.log"
  local AUTO_VALUE=""
  local SILENT_MODE=false
  local RESTORE_MODE=false

  pacman_log_message() {
    local message
    message="$(date '+%Y-%m-%d %H:%M:%S'): $1"
    if [[ "$SILENT_MODE" == false ]]; then
      echo "$message" | sudo tee -a "$LOG_FILE" >/dev/null
    else
      echo "$message" | sudo tee -a "$LOG_FILE" >/dev/null
    fi
  }

  pacman_create_backup_dir() {
    if ! sudo test -d "$BACKUP_DIR"; then
      sudo mkdir -p "$BACKUP_DIR"
      pacman_log_message "Répertoire de sauvegarde créé : $BACKUP_DIR"
    fi
  }

  pacman_create_timestamped_backup() {
    local timestamp backup_file
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    backup_file="$BACKUP_DIR/pacman.conf.bak.$timestamp"
    sudo cp "$PACMAN_CONF" "$backup_file"
    pacman_log_message "Sauvegarde créée : $backup_file"
    echo "$backup_file"
  }

  pacman_validate_syntax() {
    if ! pacman-conf --config "$PACMAN_CONF" >/dev/null 2>&1; then
      pacman_log_message "ERREUR: Syntaxe Pacman invalide détectée"
      return 1
    fi
    return 0
  }

  pacman_detect_optimal_value() {
    local cpu_count optimal_value mem_gb
    cpu_count="$(nproc)"

    if [[ "$cpu_count" -ge 8 ]]; then
      optimal_value=8
    elif [[ "$cpu_count" -ge 4 ]]; then
      optimal_value=6
    elif [[ "$cpu_count" -ge 2 ]]; then
      optimal_value=4
    else
      optimal_value=2
    fi

    mem_gb="$(free -g | awk '/^Mem:/{print $2}')"
    if [[ "$mem_gb" -lt 4 ]]; then
      optimal_value=$((optimal_value < 3 ? optimal_value : 3))
    fi

    pacman_log_message "Détection automatique : $optimal_value téléchargements parallèles (CPU: $cpu_count, RAM: ${mem_gb}GB)"
    echo "$optimal_value"
  }

  pacman_restore_config() {
    local latest_backup=""
    if [[ -d "$BACKUP_DIR" ]]; then
      latest_backup="$(sudo ls -t "$BACKUP_DIR"/pacman.conf.bak.* 2>/dev/null | head -1 || true)"
    fi

    if [[ -z "$latest_backup" || ! -f "$latest_backup" ]]; then
      pacman_log_message "ERREUR: Aucune sauvegarde trouvée dans $BACKUP_DIR"
      [[ "$SILENT_MODE" == false ]] && echo "Erreur : Aucune sauvegarde trouvée."
      exit 1
    fi

    sudo cp "$latest_backup" "$PACMAN_CONF"
    pacman_log_message "Configuration restaurée depuis $latest_backup"
    [[ "$SILENT_MODE" == false ]] && echo "Configuration restaurée avec succès depuis $latest_backup"
  }

  pacman_get_current_value() {
    if grep -q "^ParallelDownloads" "$PACMAN_CONF"; then
      grep "^ParallelDownloads" "$PACMAN_CONF" | sed 's/.*= *//'
    elif grep -q "^#ParallelDownloads" "$PACMAN_CONF"; then
      echo "désactivé (commenté)"
    else
      echo "non configuré"
    fi
  }

  # Traitement des arguments (mêmes options que le script original)
  while [[ $# -gt 0 ]]; do
    case $1 in
      --restore) RESTORE_MODE=true; shift ;;
      --auto) AUTO_VALUE="auto"; shift ;;
      --silent) SILENT_MODE=true; shift ;;
      --value) AUTO_VALUE="${2:-}"; shift 2 ;;
      --help|-h)
        cat <<'EOF'
Usage: sudo ./config_services.sh [OPTIONS]

Options Pacman (ParallelDownloads):
  --restore           : Restaure la configuration originale
  --auto              : Détection automatique du nombre optimal
  --silent            : Mode silencieux (pas d'interaction utilisateur)
  --value N           : Définit directement la valeur N (0-20)
EOF
        exit 0
        ;;
      --dry-run|--zram-*) # options d'autres sections, ignorées ici
        shift
        ;;
      *) # on ignore les options inconnues ici pour ne pas bloquer l'orchestrateur
        break
        ;;
    esac
  done

  if [[ ! -f "$PACMAN_CONF" ]]; then
    pacman_log_message "ERREUR: Le fichier $PACMAN_CONF n'existe pas"
    [[ "$SILENT_MODE" == false ]] && echo "Erreur : Le fichier $PACMAN_CONF n'existe pas."
    exit 1
  fi

  if [[ "$RESTORE_MODE" == true ]]; then
    pacman_restore_config
    return 0
  fi

  local current_value
  current_value="$(pacman_get_current_value)"
  [[ "$SILENT_MODE" == false ]] && echo "Valeur actuelle de ParallelDownloads : $current_value"

  local PARALLEL_DOWNLOADS
  if [[ -n "$AUTO_VALUE" ]]; then
    if [[ "$AUTO_VALUE" == "auto" ]]; then
      PARALLEL_DOWNLOADS="$(pacman_detect_optimal_value)"
      [[ "$SILENT_MODE" == false ]] && echo "Valeur détectée automatiquement : $PARALLEL_DOWNLOADS"
    else
      PARALLEL_DOWNLOADS="$AUTO_VALUE"
      [[ "$SILENT_MODE" == false ]] && echo "Valeur spécifiée : $PARALLEL_DOWNLOADS"
    fi
  else
    if [[ "$SILENT_MODE" == false ]]; then
      read -r -p "Entrez le nombre de téléchargements parallèles (entre 1 et 20, ou 0 pour désactiver) : " PARALLEL_DOWNLOADS
    else
      pacman_log_message "ERREUR: Mode silencieux activé mais aucune valeur spécifiée"
      exit 1
    fi
  fi

  if ! [[ "$PARALLEL_DOWNLOADS" =~ ^[0-9]+$ ]]; then
    pacman_log_message "ERREUR: La valeur doit être un entier positif"
    [[ "$SILENT_MODE" == false ]] && echo "Erreur : La valeur doit être un entier positif."
    exit 1
  fi
  if ((PARALLEL_DOWNLOADS < 0 || PARALLEL_DOWNLOADS > 20)); then
    pacman_log_message "ERREUR: Valeur hors limites (0-20)"
    [[ "$SILENT_MODE" == false ]] && echo "Erreur : Veuillez entrer un nombre entre 0 et 20."
    exit 1
  fi

  pacman_create_backup_dir
  pacman_create_timestamped_backup >/dev/null

  if ((PARALLEL_DOWNLOADS == 0)); then
    sudo sed -i 's/^ParallelDownloads/#ParallelDownloads/' "$PACMAN_CONF"
    pacman_log_message "ParallelDownloads désactivé (commenté)"
    [[ "$SILENT_MODE" == false ]] && echo "ParallelDownloads désactivé dans $PACMAN_CONF"
  else
    if grep -q "^#*ParallelDownloads" "$PACMAN_CONF"; then
      sudo sed -i "s/^#*ParallelDownloads = .*/ParallelDownloads = ${PARALLEL_DOWNLOADS}/" "$PACMAN_CONF"
    else
      echo "ParallelDownloads = ${PARALLEL_DOWNLOADS}" | sudo tee -a "$PACMAN_CONF" >/dev/null
    fi
    pacman_log_message "ParallelDownloads défini à ${PARALLEL_DOWNLOADS}"
    [[ "$SILENT_MODE" == false ]] && echo "ParallelDownloads mis à jour à ${PARALLEL_DOWNLOADS} dans $PACMAN_CONF"
  fi

  if ! pacman_validate_syntax; then
    pacman_log_message "ERREUR: La modification a créé une syntaxe Pacman invalide"
    [[ "$SILENT_MODE" == false ]] && echo "ERREUR: La modification a créé une syntaxe Pacman invalide. Restauration..."
    pacman_restore_config
    exit 1
  fi

  local new_value
  new_value="$(pacman_get_current_value)"
  [[ "$SILENT_MODE" == false ]] && echo "Nouvelle valeur : $new_value"
  pacman_log_message "Modification terminée avec succès. Nouvelle valeur : $new_value"
  record_success "Pacman ParallelDownloads = ${new_value}"
}

# =============================================================================
# 3) Paru BottomUp (intégré depuis modules/Paru/mod_paru.sh)
# =============================================================================

has_paru() { command -v paru >/dev/null 2>&1; }

paru_enable_bottomup() {
  CURRENT_STEP="Paru (BottomUp)"
  local CONF_DIR CONF_FILE
  CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/paru"
  CONF_FILE="$CONF_DIR/paru.conf"

  mkdir -p "$CONF_DIR"

  if [[ ! -f "$CONF_FILE" ]]; then
    cat >"$CONF_FILE" <<'EOF'
[options]
BottomUp
EOF
    echo "Créé: $CONF_FILE (BottomUp activé)"
    return 0
  fi

  cp -a "$CONF_FILE" "$CONF_FILE.bak"

  python3 - "$CONF_FILE" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="surrogateescape")
lines = text.splitlines(True)  # keepends

def is_section_header(s: str) -> bool:
    return bool(re.match(r"^\s*\[[^\]]+\]\s*$", s))

def section_name(s: str):
    m = re.match(r"^\s*\[([^\]]+)\]\s*$", s)
    return m.group(1).strip() if m else None

out = []
in_options = False
seen_options_section = False
bottomup_set = False

for line in lines:
    if is_section_header(line.rstrip("\n")):
        if in_options and not bottomup_set:
            out.append("BottomUp\n")
            bottomup_set = True
        in_options = (section_name(line.rstrip("\n")) or "").lower() == "options"
        if in_options:
            seen_options_section = True
        out.append(line)
        continue

    if in_options:
        if re.match(r"^\s*BottomUp\s*(?:[=].*)?$", line):
            out.append("BottomUp\n" if line.endswith("\n") else "BottomUp")
            bottomup_set = True
            continue
        if re.match(r"^\s*[#;]\s*BottomUp\s*(?:[=].*)?$", line):
            out.append("BottomUp\n" if line.endswith("\n") else "BottomUp")
            bottomup_set = True
            continue

    out.append(line)

if not seen_options_section:
    if out and not out[-1].endswith("\n"):
        out[-1] = out[-1] + "\n"
    if out and out[-1].strip() != "":
        out.append("\n")
    out.append("[options]\n")
    out.append("BottomUp\n")
else:
    if in_options and not bottomup_set:
        out.append("BottomUp\n")
        bottomup_set = True

path.write_text("".join(out), encoding="utf-8", errors="surrogateescape")
PY

  echo "OK: BottomUp activé dans $CONF_FILE (backup: $CONF_FILE.bak)"
  record_success "Paru BottomUp activé"
}

# =============================================================================
# 4) Services systemd (intégré depuis modules/Systemd/activation_services.sh)
# =============================================================================

services_main() {
  local DRY_RUN=false
  if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    log_warn "Mode dry-run activé — aucune modification ne sera appliquée."
  fi

  local SERVICES=( bluetooth.service )
  local TIMERS=( fstrim.timer paccache.timer )

  declare -A DEPS=(
    [paccache.timer]="pacman-contrib|paccache"
    [fstrim.timer]="util-linux|fstrim"
    [bluetooth.service]="bluez|bluetoothctl"
    [ufw.service]="ufw|ufw"
    [firewalld.service]="firewalld|firewall-cmd"
  )

  services_check_deps() {
    local missing=false
    log_title "Vérification des dépendances"
    for unit in "${SERVICES[@]}" "${TIMERS[@]}"; do
      if [[ -n "${DEPS[$unit]:-}" ]]; then
        local pkg="${DEPS[$unit]%%|*}"
        local cmd="${DEPS[$unit]##*|}"
        if ! command -v "$cmd" &>/dev/null; then
          log_error "${unit} — dépendance manquante : '${pkg}' (installez-le avec: pacman -S ${pkg})"
          missing=true
        else
          log_ok "${unit} — dépendance '${pkg}' OK"
        fi
      fi
    done

    for fw in ufw firewalld; do
      if [[ -n "${DEPS[${fw}.service]:-}" ]]; then
        local pkg="${DEPS[${fw}.service]%%|*}"
        local cmd="${DEPS[${fw}.service]##*|}"
        if command -v "$cmd" &>/dev/null; then
          log_ok "${fw}.service — dépendance '${pkg}' OK"
        fi
      fi
    done

    if [[ "$missing" == true ]]; then
      log_error "Des dépendances sont manquantes. Installez-les avant de relancer le script."
      exit 1
    fi
  }

  services_enable_unit() {
    local unit="$1"
    if ! systemctl list-unit-files --all --no-legend --no-pager "${unit}" 2>/dev/null | grep -Fq -- "${unit}"; then
      log_warn "${unit} — introuvable, ignoré."
      return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
      if systemctl is-enabled --quiet "${unit}" 2>/dev/null; then
        log_dry "${unit} — déjà activé (aucune action)."
      else
        log_dry "${unit} — serait activé et démarré."
      fi
      return 0
    fi

    if systemctl is-enabled --quiet "${unit}" 2>/dev/null; then
      log_ok "${unit} — déjà activé."
    else
      sudo systemctl enable --now "${unit}" \
        && log_ok "${unit} — activé et démarré." \
        || log_error "${unit} — échec de l'activation."
    fi
  }

  services_detect_firewall() {
    local has_ufw=false has_firewalld=false
    command -v ufw &>/dev/null && has_ufw=true
    command -v firewall-cmd &>/dev/null && has_firewalld=true

    if $has_ufw && $has_firewalld; then
      log_warn "ufw et firewalld sont tous les deux installés."
      log_warn "Vérification du service déjà actif..."
      if systemctl is-enabled --quiet ufw.service 2>/dev/null; then
        echo "ufw"
      elif systemctl is-enabled --quiet firewalld.service 2>/dev/null; then
        echo "firewalld"
      else
        log_warn "Aucun des deux n'est activé. ufw sera utilisé par défaut."
        echo "ufw"
      fi
    elif $has_ufw; then
      echo "ufw"
    elif $has_firewalld; then
      echo "firewalld"
    else
      echo "none"
    fi
  }

  services_check_deps

  log_title "Firewall"
  local FIREWALL
  FIREWALL="$(services_detect_firewall)"
  case "$FIREWALL" in
    ufw) log_ok "Firewall détecté : ufw"; services_enable_unit "ufw.service" ;;
    firewalld) log_ok "Firewall détecté : firewalld"; services_enable_unit "firewalld.service" ;;
    none) log_warn "Aucun firewall détecté (ni ufw ni firewalld). Ignoré." ;;
  esac

  log_title "Services"
  for svc in "${SERVICES[@]}"; do
    services_enable_unit "$svc"
  done

  log_title "Timers"
  for tmr in "${TIMERS[@]}"; do
    services_enable_unit "$tmr"
  done

  if [[ "$DRY_RUN" == false ]]; then
    log_title "Statut final"
    local ALL_SERVICES=( "${SERVICES[@]}" )
    [[ "$FIREWALL" != "none" ]] && ALL_SERVICES+=( "${FIREWALL}.service" )

    local grep_services=()
    for u in "${ALL_SERVICES[@]}"; do
      grep_services+=( -e "$u" )
    done
    systemctl list-units --type=service --state=active --no-legend --no-pager | grep -F "${grep_services[@]}" || true

    local grep_timers=()
    for t in "${TIMERS[@]}"; do
      grep_timers+=( -e "$t" )
    done
    systemctl list-timers --all --no-legend --no-pager | grep -F "${grep_timers[@]}" || true
  fi

  printf "\n"
  [[ "$DRY_RUN" == true ]] && log_warn "Dry-run terminé — aucune modification effectuée." || log_ok "Terminé."
}

# =============================================================================
# 5) ZRAM (intégré depuis modules/Zram/activation_zram.sh)
# =============================================================================

zram_main() {
  CURRENT_STEP="ZRAM"
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "Dry-run: zram-generator serait installé/configuré et le service ZRAM démarré."
    record_warning "ZRAM ignoré (dry-run)"
    return 0
  fi
  # Paramètres par défaut (mêmes valeurs que le script original)
  local ZRAM_COMP_ALGO="zstd"
  local ZRAM_SIZE="ram / 2"
  local ZRAM_PRIORITY=100
  local ZRAM_FS_TYPE="swap"

  local PERFORM_TEST=false
  local VERBOSE=false
  local AUTO_CONFIG=true
  local PURGE=false

  local CONFIG_FILE="/etc/systemd/zram-generator.conf.d/99-zram.conf"
  local BACKUP_DIR="/etc/systemd/zram-generator.conf.d/backups"

  zram_print_message() {
    local type="$1" message="$2" timestamp
    timestamp="$(date '+%H:%M:%S')"
    case "$type" in
      INFO) printf "%b\n" "${BLUE}[$timestamp] [INFO]${NC} ${message}" ;;
      SUCCESS) printf "%b\n" "${GREEN}[$timestamp] [SUCCESS]${NC} ${message}" ;;
      WARN) printf "%b\n" "${YELLOW}[$timestamp] [WARN]${NC} ${message}" ;;
      ERROR) printf "%b\n" "${RED}[$timestamp] [ERROR]${NC} ${message}" >&2 ;;
      DEBUG) [[ "$VERBOSE" == true ]] && printf "%b\n" "${CYAN}[$timestamp] [DEBUG]${NC} ${message}" ;;
      *) printf "%b\n" "[$timestamp] ${message}" ;;
    esac
  }

  zram_validate_input() {
    local input="$1" pattern="$2" description="$3"
    if [[ ! "$input" =~ $pattern ]]; then
      zram_print_message "ERROR" "$description invalide: $input"
      exit 1
    fi
  }

  zram_cleanup_on_error() {
    trap - ERR
    zram_print_message "ERROR" "Une erreur s'est produite. Nettoyage en cours..."
    if systemctl is-active --quiet systemd-zram-setup@zram0.service 2>/dev/null; then
      zram_print_message "INFO" "Arrêt du service ZRAM..."
      sudo systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
    fi
    sudo systemctl daemon-reload 2>/dev/null || true
    zram_print_message "ERROR" "Nettoyage terminé."
    exit 1
  }

  zram_detect_optimal_config() {
    [[ "$AUTO_CONFIG" == false ]] && return 0
    zram_print_message "INFO" "Détection de la configuration optimale..."
    local ram_gb ram_mb
    ram_gb="$(free -g | awk '/^Mem:/{print $2}')"
    ram_mb="$(free -m | awk '/^Mem:/{print $2}')"
    if [[ ! "$ram_gb" =~ ^[0-9]+$ ]]; then
      zram_print_message "WARN" "Impossible de détecter la RAM (valeur: '$ram_gb'). Utilisation des valeurs par défaut."
      ram_gb=0
    fi
    zram_print_message "INFO" "Mémoire totale détectée: ${ram_gb}GB (${ram_mb}MB)"

    if [[ "$ram_gb" -le 2 ]]; then
      ZRAM_SIZE="ram / 4"
      ZRAM_PRIORITY=50
      zram_print_message "INFO" "RAM faible détectée. Configuration conservatrice: ram/4, priorité 50"
    elif [[ "$ram_gb" -le 4 ]]; then
      ZRAM_SIZE="ram / 2"
      ZRAM_PRIORITY=100
      zram_print_message "INFO" "RAM modérée détectée. Configuration équilibrée: ram/2, priorité 100"
    elif [[ "$ram_gb" -le 8 ]]; then
      ZRAM_SIZE="ram / 2"
      ZRAM_PRIORITY=150
      zram_print_message "INFO" "RAM suffisante détectée. Configuration standard: ram/2, priorité 150"
    else
      ZRAM_SIZE="min(ram / 2, 8G)"
      ZRAM_PRIORITY=200
      zram_print_message "INFO" "RAM importante détectée. Configuration optimisée: min(ram/2, 8G), priorité 200"
    fi

    local existing_swap_priority
    existing_swap_priority="$(swapon --show=PRIO --noheadings 2>/dev/null | awk 'NF{print $1}' | sort -n | head -n 1 || true)"
    existing_swap_priority="${existing_swap_priority//[^0-9]/}"
    if [[ -n "$existing_swap_priority" ]] && [[ "$existing_swap_priority" =~ ^[0-9]+$ ]] && [[ "$existing_swap_priority" -ge "$ZRAM_PRIORITY" ]]; then
      ZRAM_PRIORITY=$((existing_swap_priority + 10))
      zram_print_message "INFO" "Ajustement de la priorité du swap à $ZRAM_PRIORITY pour être plus élevé que les swap existants"
    fi
  }

  zram_validate_config() {
    zram_print_message "DEBUG" "Validation de la configuration..."
    zram_validate_input "$ZRAM_COMP_ALGO" "^(zstd|lz4|lzo-rle|lzo)$" "Algorithme de compression"
    zram_validate_input "$ZRAM_SIZE" "^(ram\\s*/\\s*[2-4])$|^([0-9]+[GMK])$|^min\\(ram\\s*/\\s*[2-4],\\s*[0-9]+[GMK]\\)$" "Taille ZRAM"
    zram_validate_input "$ZRAM_PRIORITY" "^[0-9]+$" "Priorité"
    if [[ "$ZRAM_PRIORITY" -lt 0 || "$ZRAM_PRIORITY" -gt 32767 ]]; then
      zram_print_message "ERROR" "Priorité invalide (0-32767): $ZRAM_PRIORITY"
      exit 1
    fi
    zram_print_message "SUCCESS" "Configuration validée avec succès"
  }

  zram_check_system_requirements() {
    zram_print_message "INFO" "Vérification des prérequis système..."
    local required_commands=(systemctl pacman free awk grep sed zramctl swapon df uname cut sort head mktemp mv rm)
    for cmd in "${required_commands[@]}"; do
      if ! command -v "$cmd" &>/dev/null; then
        zram_print_message "ERROR" "Commande requise manquante: $cmd"
        exit 3
      fi
    done
    zram_print_message "SUCCESS" "Tous les prérequis sont satisfaits"
  }

  zram_backup_existing_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
      sudo mkdir -p "$BACKUP_DIR"
      sudo chmod 700 "$BACKUP_DIR"
      local backup_file temp_backup
      backup_file="${BACKUP_DIR}/99-zram.conf.backup.$(date +%Y%m%d_%H%M%S)"
      temp_backup="$(mktemp "${BACKUP_DIR}/temp_backup.XXXXXX")"
      if sudo cp "$config_file" "$temp_backup" && sudo mv "$temp_backup" "$backup_file"; then
        sudo chmod 640 "$backup_file"
        zram_print_message "SUCCESS" "Configuration existante sauvegardée: $backup_file"
      else
        sudo rm -f "$temp_backup" 2>/dev/null || true
        zram_print_message "WARN" "Impossible de sauvegarder la configuration existante"
      fi
    fi
  }

  zram_install_package() {
    zram_print_message "INFO" "Vérification de l'installation de 'zram-generator'..."
    if pacman -Q zram-generator &>/dev/null; then
      zram_print_message "SUCCESS" "'zram-generator' est déjà installé."
    else
      zram_print_message "INFO" "Installation de 'zram-generator'..."
      sudo pacman -Syu --noconfirm || zram_print_message "WARN" "Échec de la mise à jour des paquets. Tentative d'installation directe..."
      sudo pacman -S --noconfirm zram-generator
      zram_print_message "SUCCESS" "'zram-generator' a été installé avec succès."
    fi
  }

  zram_configure_zram() {
    zram_print_message "INFO" "Application de la configuration ZRAM..."
    zram_print_message "INFO" "  - Algorithme : ${ZRAM_COMP_ALGO}"
    zram_print_message "INFO" "  - Taille       : ${ZRAM_SIZE}"
    zram_print_message "INFO" "  - Priorité     : ${ZRAM_PRIORITY}"
    zram_print_message "INFO" "  - Type FS      : ${ZRAM_FS_TYPE}"

    zram_backup_existing_config "$CONFIG_FILE"

    sudo mkdir -p "$(dirname "$CONFIG_FILE")"
    sudo chmod 755 "$(dirname "$CONFIG_FILE")"

    local temp_config
    temp_config="$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")"
    cat <<EOF > "$temp_config"
[zram0]
compression-algorithm = ${ZRAM_COMP_ALGO}
zram-size = ${ZRAM_SIZE}
swap-priority = ${ZRAM_PRIORITY}
fs-type = ${ZRAM_FS_TYPE}
EOF

    sudo mv "$temp_config" "$CONFIG_FILE"
    sudo chmod 644 "$CONFIG_FILE"
    zram_print_message "SUCCESS" "Fichier de configuration créé/mis à jour: $CONFIG_FILE"
  }

  zram_activate_zram() {
    zram_print_message "INFO" "Rechargement de systemd et activation de ZRAM..."
    sudo systemctl daemon-reload
    sudo systemctl start systemd-zram-setup@zram0.service
    zram_print_message "SUCCESS" "Service ZRAM démarré avec succès"

    local retries=0
    until systemctl is-active --quiet systemd-zram-setup@zram0.service 2>/dev/null || [[ "$retries" -ge 15 ]]; do
      sleep 1
      ((retries++))
      zram_print_message "DEBUG" "Attente... ($retries/15)"
    done
    systemctl is-active --quiet systemd-zram-setup@zram0.service
    zram_print_message "SUCCESS" "Service ZRAM actif et fonctionnel (après ${retries}s)"
  }

  zram_verify() {
    zram_print_message "INFO" "Vérification complète du statut ZRAM..."
    systemctl is-active --quiet systemd-zram-setup@zram0.service
    [[ -b "/dev/zram0" ]]
    zramctl
    swapon --show
    zram_print_message "SUCCESS" "Vérification ZRAM terminée"
  }

  zram_test() {
    zram_print_message "INFO" "Test de performance ZRAM..."
    if ! systemctl is-active --quiet systemd-zram-setup@zram0.service; then
      zram_print_message "WARN" "ZRAM non actif, impossible de tester les performances"
      return 0
    fi
    [[ -b "/dev/zram0" ]] || { zram_print_message "WARN" "Périphérique /dev/zram0 introuvable"; return 0; }
    zram_print_message "INFO" "Test d'écriture sur /dev/zram0 (50MB)..."
    dd if=/dev/urandom of=/dev/zram0 bs=1M count=50 2>&1 | grep -E "copied|MB/s|GB/s" || true
    zram_print_message "INFO" "Test de lecture depuis /dev/zram0..."
    dd if=/dev/zram0 of=/dev/null bs=1M 2>&1 | grep -E "copied|MB/s|GB/s" || true
    zram_print_message "SUCCESS" "Tests de performance terminés"
  }

  zram_uninstall() {
    zram_print_message "INFO" "Désinstallation de ZRAM..."
    sudo systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
    sudo rm -f "$CONFIG_FILE" 2>/dev/null || true
    sudo systemctl daemon-reload 2>/dev/null || true
    if [[ "$PURGE" == true ]]; then
      sudo pacman -Rns --noconfirm zram-generator || true
    fi
    zram_print_message "SUCCESS" "ZRAM a été désactivé"
  }

  zram_show_usage() {
    cat <<'EOF'
Usage: sudo ./config_services.sh [--dry-run] [zram-command] [zram-options]

Commandes ZRAM (optionnel):
  zram-install        Installe/configure/active ZRAM (défaut)
  zram-verify         Vérifie le statut ZRAM
  zram-test           Teste les performances
  zram-uninstall      Désactive ZRAM (option: --zram-purge)

Options ZRAM (préfixées):
  --zram-size SIZE
  --zram-algorithm ALGO
  --zram-priority PRIO
  --zram-test
  --zram-verbose
  --zram-no-auto-config
  --zram-purge
EOF
  }

  local COMMAND="install"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      zram-install) COMMAND="install"; shift ;;
      zram-uninstall) COMMAND="uninstall"; shift ;;
      zram-verify) COMMAND="verify"; shift ;;
      zram-test) COMMAND="test"; shift ;;
      --zram-size) ZRAM_SIZE="${2:-}"; shift 2 ;;
      --zram-algorithm) ZRAM_COMP_ALGO="${2:-}"; shift 2 ;;
      --zram-priority) ZRAM_PRIORITY="${2:-}"; shift 2 ;;
      --zram-test) PERFORM_TEST=true; shift ;;
      --zram-verbose) VERBOSE=true; shift ;;
      --zram-no-auto-config) AUTO_CONFIG=false; shift ;;
      --zram-purge) PURGE=true; shift ;;
      --help|-h) zram_show_usage; exit 0 ;;
      --dry-run) shift ;; # géré par services_main
      *) shift ;;
    esac
  done

  trap zram_cleanup_on_error ERR
  zram_detect_optimal_config
  zram_validate_config
  zram_check_system_requirements

  case "$COMMAND" in
    install)
      zram_install_package
      zram_configure_zram
      zram_activate_zram
      zram_verify
      [[ "$PERFORM_TEST" == true ]] && zram_test
      zram_print_message "SUCCESS" "Installation et configuration de ZRAM terminées !"
      record_success "ZRAM installé/configuré"
      ;;
    uninstall) zram_uninstall ;;
    verify) zram_verify ;;
    test) zram_test ;;
    *) zram_show_usage; exit 1 ;;
  esac
}

# =============================================================================
# Orchestration
# =============================================================================

main() {
  chaotic_check_root_not_root

  case "${1:-}" in
    --help|-h)
      show_help
      exit 0
      ;;
  esac

  require_cmd bash
  require_cmd sudo
  require_cmd python3
  require_cmd pacman
  require_cmd systemctl

  ask_continue_mode_if_needed

  if [[ "$DRY_RUN" == false ]]; then
    prime_sudo
  else
    log_warn "Mode dry-run global activé — seules les vérifications/affichages seront effectués."
  fi

  log_title "Orchestration"
  log_info "Enchaînement: Chaotic-AUR → Pacman → Paru(si installé) → Services → ZRAM"
  log_info "Mode erreurs: $([[ "${CONTINUE_ON_ERROR}" == "true" ]] && echo 'continuer' || echo 'stop')"

  run_step "Chaotic-AUR" chaotic_main

  log_title "Pacman (ParallelDownloads)"
  log_info "Application via sudo uniquement sur les commandes nécessaires."
  run_step "Pacman (ParallelDownloads)" pacman_parallel_main "$@"
  log_ok "Pacman terminé."

  log_title "Paru"
  if has_paru; then
    if [[ "$DRY_RUN" == true ]]; then
      log_dry "Dry-run: Paru serait configuré (BottomUp)."
      record_warning "Paru ignoré (dry-run)"
    else
      run_step "Paru (BottomUp)" paru_enable_bottomup
    fi
    log_ok "Paru terminé."
  else
    log_warn "paru n'est pas installé — étape ignorée."
    record_warning "Paru non installé — étape ignorée"
  fi

  log_title "Services systemd"
  CURRENT_STEP="Services systemd"
  if [[ "$DRY_RUN" == true ]]; then
    run_step "Services systemd (dry-run)" services_main --dry-run
  else
    run_step "Services systemd" services_main
  fi
  log_ok "Services terminés."
  record_success "Services systemd (activation demandée)"

  log_title "ZRAM"
  if [[ "$DRY_RUN" == true ]]; then
    run_step "ZRAM (dry-run)" zram_main "$@"
  else
    run_step "ZRAM" zram_main "$@"
  fi
  log_ok "ZRAM terminé."

  log_ok "Tout est terminé."
}

main "$@"
