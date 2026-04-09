#!/usr/bin/env bash

# NAME: mod_pacman
# DESC: Script de modification de la configuration de Pacman pour les téléchargements parallèles
# =============================================================================

set -euo pipefail

PACMAN_CONF="/etc/pacman.conf"
BACKUP_DIR="/etc/pacman.conf.backups"
LOG_FILE="/var/log/pacman_parallel_downloads.log"
AUTO_VALUE=""
SILENT_MODE=false
RESTORE_MODE=false

# Fonction d'affichage d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --restore           : Restaure la configuration originale"
    echo "  --auto              : Détection automatique du nombre optimal"
    echo "  --silent            : Mode silencieux (pas d'interaction utilisateur)"
    echo "  --value N           : Définit directement la valeur N (0-20)"
    echo "  --help, -h          : Affiche cette aide"
    echo ""
    echo "Exemples:"
    echo "  sudo $0                    # Mode interactif"
    echo "  sudo $0 --auto             # Détection automatique"
    echo "  sudo $0 --value 5          # Définir à 5 téléchargements"
    echo "  sudo $0 --silent --value 3 # Mode silencieux avec valeur 3"
    echo "  sudo $0 --restore          # Restaurer la configuration"
}

# Fonction de journalisation
log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S'): $1"
    if [ "$SILENT_MODE" = false ]; then
        echo "$message" | tee -a "$LOG_FILE"
    else
        echo "$message" >> "$LOG_FILE"
    fi
}

# Fonction pour créer le répertoire de sauvegarde
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log_message "Répertoire de sauvegarde créé : $BACKUP_DIR"
    fi
}

# Fonction pour créer une sauvegarde avec horodatage
create_timestamped_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/pacman.conf.bak.$timestamp"
    cp "$PACMAN_CONF" "$backup_file"
    log_message "Sauvegarde créée : $backup_file"
    echo "$backup_file"
}

# Fonction de validation de syntaxe Pacman
validate_pacman_syntax() {
    if ! pacman-conf --config "$PACMAN_CONF" >/dev/null 2>&1; then
        log_message "ERREUR: Syntaxe Pacman invalide détectée"
        return 1
    fi
    return 0
}

# Fonction de détection automatique du nombre optimal
detect_optimal_value() {
    local cpu_count=$(nproc)
    local optimal_value
    
    # Calcul basé sur le nombre de CPU et la mémoire disponible
    if [ "$cpu_count" -ge 8 ]; then
        optimal_value=8
    elif [ "$cpu_count" -ge 4 ]; then
        optimal_value=6
    elif [ "$cpu_count" -ge 2 ]; then
        optimal_value=4
    else
        optimal_value=2
    fi
    
    # Ajustement basé sur la mémoire disponible (en GB)
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$mem_gb" -lt 4 ]; then
        optimal_value=$((optimal_value < 3 ? optimal_value : 3))
    fi
    
    log_message "Détection automatique : $optimal_value téléchargements parallèles (CPU: $cpu_count, RAM: ${mem_gb}GB)"
    echo "$optimal_value"
}

# Fonction de restauration
restore_config() {
    local latest_backup=""
    
    # Chercher la sauvegarde la plus récente
    if [ -d "$BACKUP_DIR" ]; then
        latest_backup=$(ls -t "$BACKUP_DIR"/pacman.conf.bak.* 2>/dev/null | head -1)
    fi
    
    if [ -z "$latest_backup" ] || [ ! -f "$latest_backup" ]; then
        log_message "ERREUR: Aucune sauvegarde trouvée dans $BACKUP_DIR"
        if [ "$SILENT_MODE" = false ]; then
            echo "Erreur : Aucune sauvegarde trouvée."
        fi
        exit 1
    fi

    cp "$latest_backup" "$PACMAN_CONF"
    log_message "Configuration restaurée depuis $latest_backup"
    if [ "$SILENT_MODE" = false ]; then
        echo "Configuration restaurée avec succès depuis $latest_backup"
    fi
}

# Fonction pour obtenir la valeur actuelle
get_current_value() {
    if grep -q "^ParallelDownloads" "$PACMAN_CONF"; then
        grep "^ParallelDownloads" "$PACMAN_CONF" | sed 's/.*= *//'
    elif grep -q "^#ParallelDownloads" "$PACMAN_CONF"; then
        echo "désactivé (commenté)"
    else
        echo "non configuré"
    fi
}

# Traitement des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --restore)
            RESTORE_MODE=true
            shift
            ;;
        --auto)
            AUTO_VALUE="auto"
            shift
            ;;
        --silent)
            SILENT_MODE=true
            shift
            ;;
        --value)
            AUTO_VALUE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            if [ "$SILENT_MODE" = false ]; then
                echo "Erreur : Option inconnue $1"
            fi
            show_help
            exit 1
            ;;
        *)
            if [ "$SILENT_MODE" = false ]; then
                echo "Erreur : Argument inattendu $1"
            fi
            show_help
            exit 1
            ;;
    esac
done

# Vérifier les permissions
if [[ $EUID -ne 0 ]]; then
    if [ "$SILENT_MODE" = false ]; then
        echo "Erreur : Veuillez exécuter ce script en tant qu'administrateur (sudo)."
    fi
    exit 1
fi

# Vérifier l'existence du fichier de configuration
if [ ! -f "$PACMAN_CONF" ]; then
    log_message "ERREUR: Le fichier $PACMAN_CONF n'existe pas"
    if [ "$SILENT_MODE" = false ]; then
        echo "Erreur : Le fichier $PACMAN_CONF n'existe pas."
    fi
    exit 1
fi

# Mode restauration
if [ "$RESTORE_MODE" = true ]; then
    restore_config
    exit 0
fi

# Afficher la valeur actuelle
current_value=$(get_current_value)
if [ "$SILENT_MODE" = false ]; then
    echo "Valeur actuelle de ParallelDownloads : $current_value"
fi

# Déterminer la valeur à utiliser
if [ -n "$AUTO_VALUE" ]; then
    if [ "$AUTO_VALUE" = "auto" ]; then
        PARALLEL_DOWNLOADS=$(detect_optimal_value)
        if [ "$SILENT_MODE" = false ]; then
            echo "Valeur détectée automatiquement : $PARALLEL_DOWNLOADS"
        fi
    else
        PARALLEL_DOWNLOADS="$AUTO_VALUE"
        if [ "$SILENT_MODE" = false ]; then
            echo "Valeur spécifiée : $PARALLEL_DOWNLOADS"
        fi
    fi
else
    # Mode interactif
    if [ "$SILENT_MODE" = false ]; then
        read -p "Entrez le nombre de téléchargements parallèles (entre 1 et 20, ou 0 pour désactiver) : " PARALLEL_DOWNLOADS
    else
        log_message "ERREUR: Mode silencieux activé mais aucune valeur spécifiée"
        exit 1
    fi
fi

# Validation de la saisie
if ! [[ "$PARALLEL_DOWNLOADS" =~ ^[0-9]+$ ]]; then
    log_message "ERREUR: La valeur doit être un entier positif"
    if [ "$SILENT_MODE" = false ]; then
        echo "Erreur : La valeur doit être un entier positif."
    fi
    exit 1
fi

if ((PARALLEL_DOWNLOADS < 0 || PARALLEL_DOWNLOADS > 20)); then
    log_message "ERREUR: Valeur hors limites (0-20)"
    if [ "$SILENT_MODE" = false ]; then
        echo "Erreur : Veuillez entrer un nombre entre 0 et 20."
    fi
    exit 1
fi

# Créer le répertoire de sauvegarde et sauvegarder
create_backup_dir
create_timestamped_backup >/dev/null

# Modification de la configuration
if ((PARALLEL_DOWNLOADS == 0)); then
    # Désactiver en commentant la ligne
    sed -i 's/^ParallelDownloads/#ParallelDownloads/' "$PACMAN_CONF"
    log_message "ParallelDownloads désactivé (commenté)"
    if [ "$SILENT_MODE" = false ]; then
        echo "ParallelDownloads désactivé dans $PACMAN_CONF"
    fi
else
    # Activer avec la valeur spécifiée
    if grep -q "^#*ParallelDownloads" "$PACMAN_CONF"; then
        sed -i "s/^#*ParallelDownloads = .*/ParallelDownloads = ${PARALLEL_DOWNLOADS}/" "$PACMAN_CONF"
    else
        # Ajouter la ligne si elle n'existe pas
        echo "ParallelDownloads = ${PARALLEL_DOWNLOADS}" >> "$PACMAN_CONF"
    fi
    log_message "ParallelDownloads défini à ${PARALLEL_DOWNLOADS}"
    if [ "$SILENT_MODE" = false ]; then
        echo "ParallelDownloads mis à jour à ${PARALLEL_DOWNLOADS} dans $PACMAN_CONF"
    fi
fi

# Validation de la syntaxe Pacman
if ! validate_pacman_syntax; then
    log_message "ERREUR: La modification a créé une syntaxe Pacman invalide"
    if [ "$SILENT_MODE" = false ]; then
        echo "ERREUR: La modification a créé une syntaxe Pacman invalide. Restauration..."
    fi
    restore_config
    exit 1
fi

# Vérifier que la modification a fonctionné
new_value=$(get_current_value)
if [ "$SILENT_MODE" = false ]; then
    echo "Nouvelle valeur : $new_value"
    echo "Modifications enregistrées dans $LOG_FILE"
    echo "Pour restaurer la configuration originale, utilisez : sudo $0 --restore"
fi

log_message "Modification terminée avec succès. Nouvelle valeur : $new_value"
