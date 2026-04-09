#!/usr/bin/env bash

# NAME: activation_services
# DESC: Script d'activation des services Systemd pour Arch Linux
# =============================================================================

set -euo pipefail

# ─── Couleurs ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GREY='\033[0;90m'
RESET='\033[0m'

info()    { echo -e "${GREEN}[✔]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✘]${RESET} $*"; }
dry()     { echo -e "${GREY}[~]${RESET} $*"; }
title()   { echo -e "\n${CYAN}── $* ──────────────────────────────────────────${RESET}"; }

# ─── Dry-run ─────────────────────────────────────────────────────────────────
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  warn "Mode dry-run activé — aucune modification ne sera appliquée."
fi

# ─── Vérification root ───────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]] && ! $DRY_RUN; then
  error "Ce script doit être exécuté en tant que root (sudo)."
  exit 1
fi

# ─── Listes ──────────────────────────────────────────────────────────────────
SERVICES=(
  # firewall géré automatiquement (ufw ou firewalld — voir detect_firewall)
  bluetooth.service
)

TIMERS=(
  fstrim.timer
  paccache.timer
)

# ─── Dépendances requises ────────────────────────────────────────────────────
# Format : "unit|paquet_requis|commande_à_vérifier"
declare -A DEPS=(
  [paccache.timer]="pacman-contrib|paccache"
  [fstrim.timer]="util-linux|fstrim"
  [bluetooth.service]="bluez|bluetoothctl"
  [ufw.service]="ufw|ufw"
  [firewalld.service]="firewalld|firewall-cmd"
)

# ─── Vérification des dépendances ────────────────────────────────────────────
check_deps() {
  local missing=false

  title "Vérification des dépendances"

  for unit in "${SERVICES[@]}" "${TIMERS[@]}"; do
    if [[ -n "${DEPS[$unit]:-}" ]]; then
      local pkg="${DEPS[$unit]%%|*}"
      local cmd="${DEPS[$unit]##*|}"

      if ! command -v "$cmd" &>/dev/null; then
        error "${unit} — dépendance manquante : '${pkg}' (installez-le avec: pacman -S ${pkg})"
        missing=true
      else
        info "${unit} — dépendance '${pkg}' OK"
      fi
    fi
  done

  # Vérifier aussi le firewall détecté
  for fw in ufw firewalld; do
    if [[ -n "${DEPS[${fw}.service]:-}" ]]; then
      local pkg="${DEPS[${fw}.service]%%|*}"
      local cmd="${DEPS[${fw}.service]##*|}"
      if command -v "$cmd" &>/dev/null; then
        info "${fw}.service — dépendance '${pkg}' OK"
      fi
    fi
  done

  if $missing; then
    error "Des dépendances sont manquantes. Installez-les avant de relancer le script."
    exit 1
  fi
}

# ─── Fonction d'activation ───────────────────────────────────────────────────
enable_unit() {
  local unit="$1"

  # Utiliser une recherche "fixed string" (pas regex) pour éviter les faux matchs
  # (ex: '.' dans "bluetooth.service" en regex).
  if ! systemctl list-unit-files --all --no-legend --no-pager "${unit}" 2>/dev/null | grep -Fq -- "${unit}"; then
    warn "${unit} — introuvable, ignoré."
    return
  fi

  if $DRY_RUN; then
    if systemctl is-enabled --quiet "${unit}" 2>/dev/null; then
      dry "${unit} — déjà activé (aucune action)."
    else
      dry "${unit} — serait activé et démarré."
    fi
    return
  fi

  if systemctl is-enabled --quiet "${unit}" 2>/dev/null; then
    info "${unit} — déjà activé."
  else
    systemctl enable --now "${unit}" \
      && info "${unit} — activé et démarré." \
      || error "${unit} — échec de l'activation."
  fi
}

# ─── Détection du firewall ───────────────────────────────────────────────────
detect_firewall() {
  local has_ufw=false
  local has_firewalld=false

  command -v ufw          &>/dev/null && has_ufw=true
  command -v firewall-cmd &>/dev/null && has_firewalld=true

  if $has_ufw && $has_firewalld; then
    warn "ufw et firewalld sont tous les deux installés."
    warn "Vérification du service déjà actif..."

    if systemctl is-enabled --quiet ufw.service 2>/dev/null; then
      echo "ufw"
    elif systemctl is-enabled --quiet firewalld.service 2>/dev/null; then
      echo "firewalld"
    else
      warn "Aucun des deux n'est activé. ufw sera utilisé par défaut."
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

# ─── Vérification des dépendances ────────────────────────────────────────────
check_deps

# ─── Activation du firewall ──────────────────────────────────────────────────
title "Firewall"

FIREWALL=$(detect_firewall)

case "$FIREWALL" in
  ufw)
    info "Firewall détecté : ufw"
    enable_unit "ufw.service"
    ;;
  firewalld)
    info "Firewall détecté : firewalld"
    enable_unit "firewalld.service"
    ;;
  none)
    warn "Aucun firewall détecté (ni ufw ni firewalld). Ignoré."
    ;;
esac

# ─── Activation des services ─────────────────────────────────────────────────
title "Services"
for svc in "${SERVICES[@]}"; do
  enable_unit "${svc}"
done

# ─── Activation des timers ───────────────────────────────────────────────────
title "Timers"
for tmr in "${TIMERS[@]}"; do
  enable_unit "${tmr}"
done

# ─── Résumé ──────────────────────────────────────────────────────────────────
if ! $DRY_RUN; then
  title "Statut final"

  ALL_SERVICES=( "${SERVICES[@]}" )
  [[ "$FIREWALL" != "none" ]] && ALL_SERVICES+=( "${FIREWALL}.service" )

  grep_services=()
  for u in "${ALL_SERVICES[@]}"; do
    grep_services+=( -e "$u" )
  done

  systemctl list-units --type=service --state=active --no-legend --no-pager \
    | grep -F "${grep_services[@]}" || true

  grep_timers=()
  for t in "${TIMERS[@]}"; do
    grep_timers+=( -e "$t" )
  done

  systemctl list-timers --all --no-legend --no-pager \
    | grep -F "${grep_timers[@]}" || true
fi

echo ""
$DRY_RUN && warn "Dry-run terminé — aucune modification effectuée." || info "Terminé."