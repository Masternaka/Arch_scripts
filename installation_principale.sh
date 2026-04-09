#!/usr/bin/env bash

# =============================================================================
#  install.sh — Script principal d'installation modulaire
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"

# -----------------------------------------------------------------------------
# Couleurs
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# -----------------------------------------------------------------------------
# Fonctions utilitaires (disponibles dans les modules via export)
# -----------------------------------------------------------------------------
log_info()    { echo -e "${BLUE}  →${RESET} $*"; }
log_success() { echo -e "${GREEN}  ✔${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}  ⚠${RESET} $*"; }
log_error()   { echo -e "${RED}  ✖${RESET} $*" >&2; }
log_skip()    { echo -e "${CYAN}  ↷${RESET} $* ${CYAN}(ignoré)${RESET}"; }

export -f log_info log_success log_warn log_error log_skip

# -----------------------------------------------------------------------------
# Découverte automatique des modules (récursive dans les sous-dossiers)
# -----------------------------------------------------------------------------
discover_modules() {
    find "${MODULES_DIR}" -type f -name "*.sh" | sort
}

# Lire la description d'un module (ligne # DESC: ...)
get_module_desc() {
    local file="$1"
    grep -m1 '^# DESC:' "$file" | sed 's/^# DESC: *//' || echo "Aucune description"
}

# Lire le nom d'un module (ligne # NAME: ...)
get_module_name() {
    local file="$1"
    grep -m1 '^# NAME:' "$file" | sed 's/^# NAME: *//' || basename "$file" .sh
}

# Obtenir le nom du sous-dossier relatif à MODULES_DIR
get_module_folder() {
    local file="$1"
    local relative
    relative="${file#${MODULES_DIR}/}"          # retire le préfixe MODULES_DIR/
    local folder
    folder="$(dirname "${relative}")"
    [[ "${folder}" == "." ]] && echo "" || echo "${folder}"
}

# -----------------------------------------------------------------------------
# Affichage du menu de sélection
# -----------------------------------------------------------------------------
print_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║       🐧  Installateur Modulaire         ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"
}

show_menu() {
    local -a module_files=("$@")
    local i=1
    local last_folder=""

    echo -e "${BOLD}  Modules disponibles :${RESET}\n"

    for f in "${module_files[@]}"; do
        local name desc folder
        name=$(get_module_name "$f")
        desc=$(get_module_desc "$f")
        folder=$(get_module_folder "$f")

        # Afficher un séparateur à chaque changement de sous-dossier
        if [[ "${folder}" != "${last_folder}" ]]; then
            local label="${folder:-racine}"
            echo -e "  ${BOLD}${YELLOW}── ${label} ──────────────────────────────────────${RESET}"
            last_folder="${folder}"
        fi

        printf "  ${CYAN}%2d)${RESET} ${BOLD}%-22s${RESET} %s\n" "$i" "$name" "$desc"
        ((i++))
    done

    echo
    echo -e "  ${CYAN} a)${RESET} ${BOLD}Tout sélectionner${RESET}"
    echo -e "  ${RED} q)${RESET} ${BOLD}Quitter${RESET}"
    echo
    echo -e "${YELLOW}  Entrez les numéros des modules à exécuter, séparés par des espaces.${RESET}"
    echo -e "${YELLOW}  Exemple : 1 3${RESET}"
    echo
}

# -----------------------------------------------------------------------------
# Sélection des modules par l'utilisateur
# -----------------------------------------------------------------------------
select_modules() {
    local -a module_files=("$@")
    local total="${#module_files[@]}"
    local -a selected=()

    while true; do
        print_header
        show_menu "${module_files[@]}"
        echo -ne "${BOLD}  Votre choix : ${RESET}"
        read -r input

        # Quitter
        [[ "${input,,}" == "q" ]] && echo -e "\n${YELLOW}  Annulé.${RESET}" && exit 0

        # Tout sélectionner
        if [[ "${input,,}" == "a" ]]; then
            selected=("${module_files[@]}")
            break
        fi

        # Sélection individuelle
        selected=()
        local valid=true
        for num in $input; do
            if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= total )); then
                selected+=("${module_files[$((num - 1))]}")
            else
                log_error "Numéro invalide : ${num}"
                valid=false
                break
            fi
        done

        [[ "${valid}" == "true" && "${#selected[@]}" -gt 0 ]] && break
        echo -e "${RED}  Sélection invalide, réessayez.${RESET}"
        sleep 1
    done

    # Retourner la sélection via stdout (un fichier par ligne)
    printf '%s\n' "${selected[@]}"
}

# -----------------------------------------------------------------------------
# Confirmation avant exécution
# -----------------------------------------------------------------------------
confirm_selection() {
    local -a selected=("$@")

    echo
    echo -e "${BOLD}${BLUE}  ── Modules sélectionnés ────────────────────${RESET}"
    for f in "${selected[@]}"; do
        local folder
        folder=$(get_module_folder "$f")
        local label="${folder:+[${folder}] }"
        echo -e "     ${GREEN}✔${RESET} ${label}$(get_module_name "$f")"
    done
    echo -e "${BOLD}${BLUE}  ─────────────────────────────────────────────${RESET}"
    echo
    echo -ne "${YELLOW}  Lancer l'installation ? [o/N] : ${RESET}"
    read -r confirm

    [[ "${confirm,,}" =~ ^(o|oui|y|yes)$ ]]
}

# -----------------------------------------------------------------------------
# Exécution des modules sélectionnés
# -----------------------------------------------------------------------------
run_modules() {
    local -a selected=("$@")
    local failed=0

    for f in "${selected[@]}"; do
        local name folder label
        name=$(get_module_name "$f")
        folder=$(get_module_folder "$f")
        label="${folder:+[${folder}] }${name}"

        echo
        echo -e "${BOLD}${BLUE}  ══ Module : ${label} ══${RESET}"

        if bash "$f"; then
            log_success "Module '${label}' terminé"
        else
            log_error "Module '${label}' a échoué (code : $?)"
            ((failed++))
        fi
    done

    echo
    echo -e "${BOLD}${BLUE}  ── Résumé ───────────────────────────────────${RESET}"
    echo -e "  Modules exécutés  : ${#selected[@]}"

    if (( failed > 0 )); then
        echo -e "  ${RED}Échecs            : ${failed}${RESET}"
    else
        echo -e "  ${GREEN}Tous réussis ✔${RESET}"
    fi

    echo -e "${BOLD}${BLUE}  ─────────────────────────────────────────────${RESET}"
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    # Vérifier que le dossier modules existe
    if [[ ! -d "${MODULES_DIR}" ]]; then
        log_error "Dossier modules introuvable : ${MODULES_DIR}"
        exit 1
    fi

    # Découvrir les modules disponibles
    mapfile -t module_files < <(discover_modules)

    if [[ "${#module_files[@]}" -eq 0 ]]; then
        log_error "Aucun module trouvé dans ${MODULES_DIR}"
        exit 1
    fi

    # Afficher le menu et récupérer la sélection
    mapfile -t selected < <(select_modules "${module_files[@]}")

    if [[ "${#selected[@]}" -eq 0 ]]; then
        log_warn "Aucun module sélectionné."
        exit 0
    fi

    # Confirmation
    if ! confirm_selection "${selected[@]}"; then
        echo -e "${YELLOW}  Installation annulée.${RESET}"
        exit 0
    fi

    # Exécution
    run_modules "${selected[@]}"
}

main "$@"