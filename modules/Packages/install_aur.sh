#!/bin/bash
set -euo pipefail

###############################################################################
# Script d'installation des paquets AUR pour Arch/EndeavourOS
#
# Utilisation:
# 1. Rendez-le exécutable: chmod +x install_aur.sh
# 2. Exécutez-le: sudo ./install_aur.sh [--dry-run]
#
# Ce script installe les paquets AUR via yay.
# Note: Exécutez d'abord install_base.sh avant ce script
#
# Options
# --help : Affiche l'aide et quitte.
# --dry-run : Simule les installations sans effectuer de modifications.
###############################################################################

# Couleurs
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

# Options
DRY_RUN=false

# Fonction de confirmation
confirm_installation() {
  if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}Continuer avec l'installation des paquets AUR ? (y/N)${RESET}"
    read -r -s -n 1 -p "> " response
    echo
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Installation annulée.${RESET}"
      exit 0
    fi
  fi
}

# Fonction de nettoyage en cas d'interruption
cleanup_on_exit() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo -e "${RED}Installation interrompue.${RESET}"
  fi
}

# Installation AUR avec retry
install_aur_package_with_retry() {
  local package="$1"
  local max_attempts=3
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    
    if [ "$DRY_RUN" = false ]; then
      if sudo -u "$SUDO_USER" yay -S --noconfirm --needed "$package"; then
        return 0
      else
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
          echo -e "${YELLOW}Nouvelle tentative dans 5 secondes... (tentative $attempt/$max_attempts)${RESET}"
          sleep 5
        fi
        continue
      fi
    else
      echo "DRY-RUN: yay -S --noconfirm --needed $package"
      return 0
    fi
  done
  
  return 1
}

# Installer yay si manquant
install_yay() {
  if ! command -v yay &>/dev/null; then
    echo -e "${YELLOW}yay non détecté. Installation...${RESET}"
    if [ "$DRY_RUN" = false ]; then
      pacman -S --noconfirm --needed base-devel git
      sudo -u "$SUDO_USER" bash -c '
        cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm'
    else
      echo "DRY-RUN: Installation de yay"
    fi
  else
    echo -e "${GREEN}✓ yay est installé${RESET}"
  fi
}

# Fonction d'aide détaillée
show_help() {
  echo -e "${GREEN}=== Aide du script d'installation AUR ===${RESET}"
  echo ""
  echo "Ce script permet d'installer automatiquement les paquets AUR sur Arch/EndeavourOS."
  echo ""
  echo "UTILISATION:"
  echo "  sudo ./install_aur.sh [options]"
  echo ""
  echo "OPTIONS:"
  echo "  --help      Affiche cette aide"
  echo "  --dry-run   Simule sans installer"
  echo ""
  echo "PAQUETS AUR INSTALLÉS:"
  echo "  - Utilitaires: pacseek, ipscan"
  echo "  - Navigateur: brave-bin"
  echo "  - Développement: github-desktop, gitkraken, visual-studio-code-bin"
  echo "  - Multimédia: deadbeef, spotify"
}

# Installation de paquets AUR améliorée
install_aur_packages() {
  
  local aur_packages=(
      # Utilitaires
      pacseek
      ipscan

      # Navigateur internet
      brave-bin

      # Développement
      github-desktop
      gitkraken
      visual-studio-code-bin

      # Multimédia
      deadbeef
      spotify
  )

  local total_aur_packages=${#aur_packages[@]}
  local current_aur_package=0
  local failed_aur_packages=()

  for aur in "${aur_packages[@]}"; do
    current_aur_package=$((current_aur_package + 1))
    echo -e "${GREEN}[$current_aur_package/$total_aur_packages] Installation AUR de [$aur]...${RESET}"
    
    if ! install_aur_package_with_retry "$aur"; then
      failed_aur_packages+=("$aur")
      echo -e "${RED}Échec de l'installation AUR de [$aur]${RESET}"
    fi
  done

  # Rapport des échecs AUR
  if [ ${#failed_aur_packages[@]} -gt 0 ]; then
    echo -e "${RED}Packages AUR non installés: ${failed_aur_packages[*]}${RESET}"
  fi
}

# Fonction de nettoyage final
cleanup() {
  if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}Nettoyage du cache AUR...${RESET}"
    sudo -u "$SUDO_USER" yay -Sc --noconfirm
  else
    echo "DRY-RUN: Nettoyage du cache AUR"
  fi
}

# Résumé d'installation détaillé
show_installation_summary() {
  echo -e "${GREEN}=== Résumé de l'installation AUR ===${RESET}"
  echo -e "Utilisateur: $SUDO_USER"
  echo -e "Date: $(date)"
  
  if command -v yay &>/dev/null; then
    local aur_count=$(yay -Qm | wc -l)
    echo -e "Paquets AUR installés: $aur_count"
  fi
  
  echo -e "${GREEN}Installation AUR terminée avec succès !${RESET}"
}

# Vérification du mode superutilisateur
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Veuillez exécuter ce script avec sudo.${RESET}"
  exit 1
fi

# Vérification que SUDO_USER est défini
if [ -z "${SUDO_USER:-}" ]; then
  echo -e "${RED}SUDO_USER n'est pas défini. Veuillez exécuter avec sudo.${RESET}"
  exit 1
fi

# Gestion des signaux d'interruption
trap 'cleanup_on_exit; exit 130' INT TERM
trap 'cleanup_on_exit' EXIT

# Gestion des arguments
for arg in "$@"; do
  case $arg in
    --help)
      show_help
      exit 0
      ;;
    --dry-run) DRY_RUN=true ;;
    *)
      echo -e "${RED}Option inconnue: $arg${RESET}"
      echo "Utilisez --help pour voir les options disponibles."
      exit 1
      ;;
  esac
done

# Affichage des paramètres et confirmation
echo -e "${GREEN}=== Configuration AUR ===${RESET}"
echo -e "Utilisateur: $SUDO_USER"
echo -e "Mode dry-run: $DRY_RUN"
echo ""

# Demander confirmation avant de continuer
confirm_installation

# Fonction principale
main() {
  # Installation de yay si manquant
  install_yay
  
  # Installation des paquets AUR
  install_aur_packages
  
  # Nettoyage
  cleanup

  # Résumé final
  show_installation_summary
}

# Exécution
main
