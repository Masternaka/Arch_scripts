#!/bin/bash
set -euo pipefail

###############################################################################
# Script d'installation de GNOME pour Arch/EndeavourOS
#
# Utilisation:
# 1. Rendez-le exécutable: chmod +x install_gnome.sh
# 2. Exécutez-le: sudo ./install_gnome.sh [--dry-run]
#
# Ce script installe les paquets GNOME et ses extensions.
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
    echo -e "${YELLOW}Continuer avec l'installation de GNOME ? (y/N)${RESET}"
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

# Installation avec retry automatique
install_package_with_retry() {
  local package="$1"
  local max_attempts=3
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    
    if [ "$DRY_RUN" = false ]; then
      if pacman -S --noconfirm --needed "$package"; then
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
      echo "DRY-RUN: pacman -S --noconfirm --needed $package"
      return 0
    fi
  done
  
  return 1
}

# Fonction d'aide détaillée
show_help() {
  echo -e "${GREEN}=== Aide du script d'installation GNOME ===${RESET}"
  echo ""
  echo "Ce script permet d'installer GNOME et ses extensions sur Arch/EndeavourOS."
  echo ""
  echo "UTILISATION:"
  echo "  sudo ./install_gnome.sh [options]"
  echo ""
  echo "OPTIONS:"
  echo "  --help      Affiche cette aide"
  echo "  --dry-run   Simule sans installer"
  echo ""
  echo "PAQUETS GNOME INSTALLÉS:"
  echo "  - Tweaks: gnome-tweaks, gnome-shell-extensions"
  echo "  - Fichiers: gvfs, gvfs-afc, gvfs-gphoto2, gvfs-mtp, gvfs-nfs, gvfs-smb"
  echo "  - Intégration: xdg-user-dirs-gtk, adw-gtk3, qt6-wayland"
}

# Fonction installation de paquets GNOME
install_gnome_packages() {
  
  local packages=(
      gnome-tweaks
      gnome-shell-extensions
      gvfs
      gvfs-afc
      gvfs-gphoto2
      gvfs-mtp
      gvfs-nfs
      gvfs-smb
      xdg-user-dirs-gtk
      adw-gtk3
      qt6-wayland
  )

  local total_packages=${#packages[@]}
  local current_package=0
  local failed_packages=()

  for pkg in "${packages[@]}"; do
    current_package=$((current_package + 1))
    echo -e "${GREEN}[$current_package/$total_packages] Traitement de [$pkg]...${RESET}"
    
    if pacman -Qi "$pkg" &>/dev/null; then
      echo -e "${YELLOW}[$pkg] déjà installé.${RESET}"
    else
      echo -e "${GREEN}Installation de [$pkg]...${RESET}"
      if ! install_package_with_retry "$pkg"; then
        failed_packages+=("$pkg")
        echo -e "${RED}Échec de l'installation de [$pkg]${RESET}"
      fi
    fi
  done

  # Rapport des échecs
  if [ ${#failed_packages[@]} -gt 0 ]; then
    echo -e "${RED}Packages non installés: ${failed_packages[*]}${RESET}"
  fi
}

# Fonction de nettoyage final
cleanup() {
  if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}Nettoyage du cache...${RESET}"
    pacman -Sc --noconfirm
  else
    echo "DRY-RUN: Nettoyage du cache"
  fi
}

# Résumé d'installation détaillé
show_installation_summary() {
  echo -e "${GREEN}=== Résumé de l'installation GNOME ===${RESET}"
  echo -e "Date: $(date)"
  echo -e "Paquets installés: $(pacman -Q | wc -l)"
  echo -e "${GREEN}Installation GNOME terminée avec succès !${RESET}"
}

# Vérification du mode superutilisateur
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Veuillez exécuter ce script avec sudo.${RESET}"
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
echo -e "${GREEN}=== Configuration GNOME ===${RESET}"
echo -e "Mode dry-run: $DRY_RUN"
echo ""

# Demander confirmation avant de continuer
confirm_installation

# Fonction principale
main() {
  # Installation des paquets GNOME
  install_gnome_packages
  
  # Nettoyage
  cleanup

  # Résumé final
  show_installation_summary
}

# Exécution
main
