#!/bin/bash
set -euo pipefail

###############################################################################
# Script d'installation des paquets de base pour Arch/EndeavourOS
#
# Utilisation:
# 1. Rendez-le exécutable: chmod +x install_base.sh
# 2. Exécutez-le: sudo ./install_base.sh [--dry-run]
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

# Configuration du dossier utilisateur
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# Options
DRY_RUN=false

# Fonction de confirmation
confirm_installation() {
  if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}Continuer avec l'installation ? (y/N)${RESET}"
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

# Sauvegarde des paquets installés
backup_installed_packages() {
  local backup_file="$USER_HOME/packages_backup_$(date +%Y%m%d_%H%M%S).txt"
  echo -e "${GREEN}Sauvegarde de la liste des paquets installés...${RESET}"
  pacman -Qqe > "$backup_file"
  chown "$SUDO_USER:$SUDO_USER" "$backup_file"
  echo -e "${GREEN}Sauvegarde créée: $backup_file${RESET}"
}

# Création d'un script de récupération
create_recovery_script() {
  local recovery_script="$USER_HOME/recovery_$(date +%Y%m%d_%H%M%S).sh"
  cat > "$recovery_script" << 'EOF'
#!/bin/bash
# Script de récupération généré automatiquement

echo "=== Script de récupération ==="
echo "Nettoyage des caches..."
sudo pacman -Sc --noconfirm

echo "Récupération terminée"
EOF
  chmod +x "$recovery_script"
  chown "$SUDO_USER:$SUDO_USER" "$recovery_script"
}

# Fonction d'aide détaillée
show_help() {
  echo -e "${GREEN}=== Aide du script d'installation des paquets de base ===${RESET}"
  echo ""
  echo "Ce script permet d'installer automatiquement les paquets de base sur Arch/EndeavourOS."
  echo ""
  echo "UTILISATION:"
  echo "  sudo ./install_base.sh [options]"
  echo ""
  echo "OPTIONS:"
  echo "  --help      Affiche cette aide"
  echo "  --dry-run   Simule sans installer"
  echo ""
  echo "PAQUETS INSTALLÉS:"
  echo "  - Spécifique EndeavourOS: akm, eos-update-notifier"
  echo "  - Utilitaires: catfish, flatpak, flameshot, gparted, gufw, openrgb, qbittorrent, transmission-qt, distrobox, lshw, fwupd, timeshift, p7zip"
  echo "  - Terminal: btop, fastfetch, yazi, neovim, kitty"
  echo "  - Sécurité: keepassxc"
  echo "  - Navigateurs: thunderbird, vivaldi"
  echo "  - Multimédia: strawberry, vlc"
  echo "  - Communication: discord"
  echo "  - Office et notes: libreoffice-fresh, libreoffice-fresh-fr, obsidian"
  echo "  - Développement: code, meld, zed"
  echo "  - Virtualisation: qemu-full, virt-manager"
}

# Mise à jour système
update_system() {
  echo -e "${GREEN}Mise à jour du système...${RESET}"
  if [ "$DRY_RUN" = false ]; then
    pacman -Syu --noconfirm
  else
    echo "DRY-RUN: pacman -Syu --noconfirm"
  fi
}

# Détection du système (EndeavourOS ou Arch)
is_endeavouros() {
  if [ -f /etc/os-release ]; then
    grep -q "ID=endeavouros" /etc/os-release && return 0 || return 1
  fi
  return 1
}

# Fonction installation de paquets
install_packages() {
  
  local packages=()
  
  # Paquets spécifiques à EndeavourOS (conditionnels)
  if is_endeavouros; then
    packages+=(
      akm
      eos-update-notifier
    )
    echo -e "${GREEN}Système EndeavourOS détecté - inclusion des paquets spécifiques${RESET}"
  else
    echo -e "${YELLOW}Système Arch détecté - paquets EndeavourOS-spécifiques ignorés${RESET}"
  fi

  # Paquets communs
  packages+=(
      # Utilitaires
      catfish
      flatpak
      flameshot
      gnome-disk-utility
      gparted
      gufw
      openrgb
      qbittorrent
      transmission-qt
      distrobox
      lshw
      fwupd
      timeshift
      p7zip

      # Utilitaires terminal
      btop
      fastfetch
      yazi
      neovim

      # Sécurité
      keepassxc

      # Navigateur internet et email
      thunderbird
      vivaldi
      vivaldi-ffmpeg-codecs

      # Multimédia
      strawberry
      vlc

      # Communication
      discord

      # Office et notes
      libreoffice-fresh
      libreoffice-fresh-fr
      obsidian

      # Virtualisation
      qemu-full
      virt-manager

      # Shell et terminal
      kitty

      # Développement
      code
      meld
      zed
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
  echo -e "${GREEN}=== Résumé de l'installation ===${RESET}"
  echo -e "Utilisateur: $SUDO_USER"
  echo -e "Date: $(date)"
  echo -e "Paquets installés: $(pacman -Q | wc -l)"
  echo -e "${GREEN}Installation terminée avec succès !${RESET}"
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
echo -e "${GREEN}=== Configuration ===${RESET}"
echo -e "Utilisateur: $SUDO_USER"
echo -e "Dossier home: $USER_HOME"
echo -e "Mode dry-run: $DRY_RUN"
echo ""

# Demander confirmation avant de continuer
confirm_installation

# Fonction principale
main() {
  # Sauvegarde et préparation
  backup_installed_packages
  create_recovery_script
  
  # Mise à jour système
  update_system

  # Installation des paquets de base
  install_packages
  
  # Nettoyage
  cleanup

  # Résumé final
  show_installation_summary
}

# Exécution
main
