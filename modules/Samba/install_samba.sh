#!/usr/bin/env bash

# NAME: install_Samba
# DESC: Script d'installation et configuration de Samba pour Arch Linux
# =============================================================================

set -euo pipefail

###############################################################################
# Script d'installation et configuration de Samba — Arch Linux / EndeavourOS
#
# Utilisation :
#   1. Rendez-le exécutable : chmod +x installation_samba_arch.sh
#   2. Exécutez-le          : sudo ./installation_samba_arch.sh [--dry-run]
#
# Options :
#   --help    : Affiche l'aide et quitte.
#   --dry-run : Simule les opérations sans effectuer de modifications.
###############################################################################

# ── Couleurs ──────────────────────────────────────────────────────────────────
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# ── Fonctions d'affichage ─────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET} $*"; exit 1; }

# ── Variables globales ────────────────────────────────────────────────────────
DRY_RUN=false
SMB_CONF="/etc/samba/smb.conf"
USER_HOME=$(getent passwd "${SUDO_USER:-}" | cut -d: -f6)
SHARE_DIR="${USER_HOME}/Share"

# ── Gestion des signaux ──────────────────────────────────────────────────────
cleanup_on_exit() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo -e "\n${RED}Installation interrompue (code $exit_code).${RESET}"
  fi
}
trap 'cleanup_on_exit; exit 130' INT TERM
trap 'cleanup_on_exit' EXIT

# ── Fonctions utilitaires ─────────────────────────────────────────────────────

show_help() {
  echo -e "${BOLD}=== Installation et configuration de Samba ===${RESET}"
  echo ""
  echo "Ce script installe Samba, crée une configuration de base, active les"
  echo "services, configure le pare-feu et ajoute un utilisateur Samba."
  echo ""
  echo "UTILISATION :"
  echo "  sudo ./installation_samba_arch.sh [options]"
  echo ""
  echo "OPTIONS :"
  echo "  --help      Affiche cette aide"
  echo "  --dry-run   Simule les opérations sans modifier le système"
  echo ""
  echo "CE QUE FAIT LE SCRIPT :"
  echo "  1. Met à jour la base de données pacman"
  echo "  2. Installe le paquet samba"
  echo "  3. Crée /etc/samba/smb.conf (si absent)"
  echo "  4. Valide la configuration avec testparm"
  echo "  5. Crée le répertoire de partage ~/Share"
  echo "  6. Active les services smb et nmb"
  echo "  7. Configure le pare-feu (firewalld ou ufw)"
  echo "  8. Crée un utilisateur Samba avec smbpasswd"
}

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
          warn "Nouvelle tentative dans 5 secondes… (tentative $attempt/$max_attempts)"
          sleep 5
        fi
      fi
    else
      echo "DRY-RUN : pacman -S --noconfirm --needed $package"
      return 0
    fi
  done

  return 1
}

# ── 1. Mise à jour pacman ─────────────────────────────────────────────────────
update_pacman() {
  info "Mise à jour de la base de données pacman…"
  if [ "$DRY_RUN" = false ]; then
    pacman -Sy --noconfirm
  else
    echo "DRY-RUN : pacman -Sy --noconfirm"
  fi
  success "Base de données pacman à jour."
}

# ── 2. Installation de Samba ──────────────────────────────────────────────────
install_samba() {
  info "Installation de Samba…"

  if pacman -Qi samba &>/dev/null; then
    warn "Samba est déjà installé — on continue."
  else
    if ! install_package_with_retry samba; then
      error "Impossible d'installer le paquet samba après plusieurs tentatives."
    fi
    success "Samba installé."
  fi
}

# ── 3. Configuration smb.conf ────────────────────────────────────────────────
configure_samba() {
  if [[ -f "$SMB_CONF" ]]; then
    warn "smb.conf déjà présent ($SMB_CONF) — non modifié."
    return
  fi

  info "Création d'un smb.conf…"
  if [ "$DRY_RUN" = false ]; then
    mkdir -p /etc/samba
    cat > "$SMB_CONF" <<EOF
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   server role = standalone server
   log file = /var/log/samba/%m.log
   max log size = 50
   dns proxy = no

# ── Partage Share ─────────────────────────────────────────────────────────────
# Visible par tout le monde sur le réseau, accessible uniquement
# par les membres du groupe « samba » avec mot de passe.
[Share]
   path = ${SHARE_DIR}
   comment = Dossier partagé
   browsable = yes
   writable = yes
   guest ok = no
   valid users = @samba
   create mask = 0660
   directory mask = 2770
   force group = samba
EOF
    success "smb.conf créé : $SMB_CONF"
  else
    echo "DRY-RUN : création de $SMB_CONF"
  fi
}

# ── 4. Validation de la configuration ────────────────────────────────────────
validate_config() {
  info "Validation de la configuration Samba (testparm)…"
  if [ "$DRY_RUN" = false ]; then
    if testparm -s "$SMB_CONF" &>/dev/null; then
      success "La configuration Samba est valide."
    else
      warn "testparm a détecté des problèmes dans la configuration."
      warn "Exécutez « testparm » manuellement pour plus de détails."
    fi
  else
    echo "DRY-RUN : testparm -s $SMB_CONF"
  fi
}

# ── 5. Création du répertoire de partage ─────────────────────────────────────
create_share_directory() {
  if [[ -d "$SHARE_DIR" ]]; then
    warn "Le répertoire de partage existe déjà : $SHARE_DIR"
    return
  fi

  info "Création du répertoire de partage : $SHARE_DIR"
  if [ "$DRY_RUN" = false ]; then
    # Créer le groupe samba s'il n'existe pas déjà
    if ! getent group samba &>/dev/null; then
      groupadd samba
      success "Groupe « samba » créé."
    fi
    mkdir -p "$SHARE_DIR"
    chown "$SUDO_USER":samba "$SHARE_DIR"
    chmod 2770 "$SHARE_DIR"
    success "Répertoire de partage créé avec les bonnes permissions."
  else
    echo "DRY-RUN : mkdir -p $SHARE_DIR && chown/chmod"
  fi
}

# ── 6. Activation des services ───────────────────────────────────────────────
enable_services() {
  info "Activation et démarrage des services smb et nmb…"
  if [ "$DRY_RUN" = false ]; then
    systemctl enable --now smb.service nmb.service
    success "Services smb et nmb actifs."
  else
    echo "DRY-RUN : systemctl enable --now smb.service nmb.service"
  fi
}

# ── 7. Configuration du pare-feu ─────────────────────────────────────────────
configure_firewall() {
  info "Détection du pare-feu…"

  if command -v firewall-cmd &>/dev/null; then
    info "firewalld détecté."
    if [ "$DRY_RUN" = false ]; then
      systemctl enable --now firewalld
      firewall-cmd --permanent --add-service=samba
      firewall-cmd --reload
      success "Règles Samba ajoutées dans firewalld."
    else
      echo "DRY-RUN : firewall-cmd --permanent --add-service=samba"
    fi

  elif command -v ufw &>/dev/null; then
    info "ufw détecté."
    if [ "$DRY_RUN" = false ]; then
      ufw allow Samba
      success "Règles Samba ajoutées dans ufw."
    else
      echo "DRY-RUN : ufw allow Samba"
    fi

  else
    warn "Aucun pare-feu reconnu (ufw / firewalld)."
    warn "Ports à ouvrir manuellement : TCP 139, TCP 445, UDP 137, UDP 138"
  fi
}

# ── 8. Création de l'utilisateur Samba ────────────────────────────────────────
create_samba_user() {
  echo ""
  info "Configuration de l'utilisateur Samba…"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    echo "DRY-RUN : smbpasswd -a <utilisateur>"
    return
  fi

  # Demander le nom d'utilisateur
  echo -e "${BOLD}Entrez le nom d'utilisateur Linux à ajouter comme utilisateur Samba :${RESET}"
  read -r -p "> " samba_user

  # Valider que le champ n'est pas vide
  if [[ -z "$samba_user" ]]; then
    warn "Aucun utilisateur saisi — étape ignorée."
    warn "Vous pourrez ajouter un utilisateur plus tard avec : sudo smbpasswd -a <utilisateur>"
    return
  fi

  # Vérifier que l'utilisateur Linux existe
  if ! id "$samba_user" &>/dev/null; then
    warn "L'utilisateur « $samba_user » n'existe pas sur ce système."
    echo -e "${YELLOW}Voulez-vous créer l'utilisateur système « $samba_user » ? (y/N)${RESET}"
    read -r -s -n 1 -p "> " create_user
    echo

    if [[ "$create_user" =~ ^[Yy]$ ]]; then
      useradd -m -s /bin/bash "$samba_user"
      success "Utilisateur système « $samba_user » créé."

      info "Définition du mot de passe système pour « $samba_user »…"
      passwd "$samba_user"
    else
      warn "Création annulée — étape ignorée."
      return
    fi
  fi

  # Ajouter l'utilisateur au groupe samba
  if getent group samba &>/dev/null; then
    usermod -aG samba "$samba_user"
    success "Utilisateur « $samba_user » ajouté au groupe « samba »."
  fi

  # Créer le mot de passe Samba
  info "Définition du mot de passe Samba pour « $samba_user »…"
  echo -e "${BOLD}Entrez le mot de passe Samba pour « $samba_user » :${RESET}"
  smbpasswd -a "$samba_user"

  # Activer l'utilisateur Samba
  smbpasswd -e "$samba_user"
  success "Utilisateur Samba « $samba_user » créé et activé."
}

# ── Résumé final ──────────────────────────────────────────────────────────────
show_summary() {
  echo ""
  echo -e "${BOLD}=== Installation terminée ===${RESET}"
  echo -e "  • Fichier de config  : ${CYAN}$SMB_CONF${RESET}"
  echo -e "  • Répertoire partagé : ${CYAN}$SHARE_DIR${RESET}"
  echo -e "  • Partage [Share]    : ${GREEN}actif${RESET} (visible par tous, accès par mot de passe)"
  echo -e "  • Vérifier la config : ${CYAN}testparm${RESET}"
  echo -e "  • Statut services    : ${CYAN}systemctl status smb nmb${RESET}"
  echo -e "  • Ajouter un autre   : ${CYAN}sudo smbpasswd -a <utilisateur>${RESET}"
  echo -e "  • Redémarrer Samba   : ${CYAN}sudo systemctl restart smb nmb${RESET}"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

# Vérification root
if [ "$EUID" -ne 0 ]; then
  error "Ce script doit être exécuté en root (sudo)."
fi

# Vérification SUDO_USER
if [ -z "${SUDO_USER:-}" ]; then
  error "SUDO_USER n'est pas défini. Veuillez exécuter avec sudo."
fi

# Gestion des arguments
for arg in "$@"; do
  case $arg in
    --help)
      show_help
      exit 0
      ;;
    --dry-run) DRY_RUN=true ;;
    *)
      error "Option inconnue : $arg (utilisez --help pour voir les options)."
      ;;
  esac
done

# Affichage de la configuration
echo ""
echo -e "${BOLD}=== Installation et configuration de Samba — Arch Linux ===${RESET}"
echo ""
echo -e "  Utilisateur  : ${CYAN}$SUDO_USER${RESET}"
echo -e "  Mode dry-run : ${CYAN}$DRY_RUN${RESET}"
echo ""

# Confirmation
confirm_installation

# Exécution des étapes
main() {
  update_pacman          # 1. Mise à jour pacman
  install_samba          # 2. Installation du paquet samba
  configure_samba        # 3. Création de smb.conf
  validate_config        # 4. Validation avec testparm
  create_share_directory # 5. Création du répertoire de partage
  enable_services        # 6. Activation des services
  configure_firewall     # 7. Configuration pare-feu
  create_samba_user      # 8. Création utilisateur Samba
  show_summary           # Résumé final
}

main