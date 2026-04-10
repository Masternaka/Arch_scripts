#!/usr/bin/env bash
set -Eeuo pipefail

on_error() {
  local exit_code=$?
  printf "%b\n" "${RED}[ERREUR]${NC} Échec (code ${exit_code}) à la ligne ${BASH_LINENO[0]}: ${BASH_COMMAND}" >&2
  exit "$exit_code"
}
trap on_error ERR

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "%b\n" "${BLUE}[INFO]${NC} $*"; }
ok()   { printf "%b\n" "${GREEN}[OK]${NC} $*"; }
warn() { printf "%b\n" "${YELLOW}[WARN]${NC} $*"; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

chaotic_script="${script_dir}/modules/Choatic/install_Chaotic.sh"
pacman_script="${script_dir}/modules/Pacman/mod_pacman.sh"
paru_script="${script_dir}/modules/Paru/mod_paru.sh"
services_script="${script_dir}/modules/Systemd/activation_services.sh"
zram_script="${script_dir}/modules/Zram/activation_zram.sh"

require_file() {
  local p="$1"
  if [[ ! -f "$p" ]]; then
    printf "%b\n" "${RED}[ERREUR]${NC} Fichier introuvable: $p" >&2
    exit 1
  fi
}

prime_sudo() {
  info "Vérification de sudo..."
  sudo -v
  ok "sudo OK"
}

has_paru() {
  command -v paru >/dev/null 2>&1
}

main() {
  if [[ ${EUID:-0} -eq 0 ]]; then
    printf "%b\n" "${RED}[ERREUR]${NC} Ce script ne doit pas être exécuté en tant que root." >&2
    printf "%b\n" "${BLUE}[INFO]${NC} Lance-le en utilisateur normal; il utilisera sudo si nécessaire." >&2
    exit 1
  fi

  require_file "$chaotic_script"
  require_file "$pacman_script"
  require_file "$paru_script"
  require_file "$services_script"
  require_file "$zram_script"

  prime_sudo

  info "1/5 Installation du dépôt Chaotic-AUR."
  bash "$chaotic_script"
  ok "Chaotic-AUR terminé."

  info "2/5 Configuration de pacman (ParallelDownloads)."
  sudo bash "$pacman_script"
  ok "Configuration pacman terminée."

  info "3/5 Configuration de paru (BottomUp) — seulement si paru est installé."
  if has_paru; then
    bash "$paru_script"
    ok "Configuration paru terminée."
  else
    warn "paru n'est pas installé — étape ignorée."
  fi

  info "4/5 Activation des services systemd."
  sudo bash "$services_script"
  ok "Activation des services terminée."

  info "5/5 Activation de ZRAM."
  sudo bash "$zram_script"
  ok "ZRAM terminé."

  ok "Tout est terminé."
}

main "$@"
