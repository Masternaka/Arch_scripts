#!/usr/bin/env bash

# NAME: install_Fish
# DESC: Script d'installation de Fish pour Arch Linux
# =============================================================================

set -euo pipefail

# =============================================================================
# Flags
# =============================================================================
DRY_RUN=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" || "$arg" == "-n" ]] && DRY_RUN=true
done

# =============================================================================
# Couleurs & helpers
# =============================================================================
BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}==> ${RESET}${BOLD}$*${RESET}"; }
success() { echo -e "${GREEN}${BOLD}✔  $*${RESET}"; }
warn()    { echo -e "${YELLOW}${BOLD}!  $*${RESET}"; }
skip()    { echo -e "  ${DIM}↳ déjà installé, ignoré.${RESET}"; }
drylog()  { echo -e "  ${BLUE}${BOLD}[dry-run]${RESET}${BLUE} $*${RESET}"; }
err()     { echo -e "${RED}${BOLD}✖  $*${RESET}" >&2; }

# Exécute ou simule une commande selon le mode
run() {
    if $DRY_RUN; then
        drylog "$*"
    else
        eval "$*"
    fi
}

# Crée un dossier (simulé en dry-run)
ensure_dir() {
    if $DRY_RUN; then
        drylog "mkdir -p $1"
    else
        mkdir -p "$1"
    fi
}

# =============================================================================
# Helpers de détection
# =============================================================================
is_installed()     { command -v "$1" &>/dev/null; }
pacman_installed() { pacman -Qi "$1" &>/dev/null 2>&1; }

# =============================================================================
# Bannière
# =============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   🐟 install-fish.sh — EndeavourOS / Arch   ║${RESET}"
if $DRY_RUN; then
echo -e "${BOLD}║  ${YELLOW}MODE DRY-RUN — aucune modification${RESET}${BOLD}         ║${RESET}"
fi
echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""

# =============================================================================
# 1. Paquets système
# =============================================================================
info "Installation de Fish et des outils CLI..."

PKGS=(
    # ── Shell ──────────────────────────────────────────────────────────────
    fish

    # ── Outils CLI modernes ────────────────────────────────────────────────
    bat                      # cat amélioré avec coloration syntaxique
    eza                      # ls moderne avec icônes et git
    fzf                      # recherche floue interactive
    zoxide                   # cd intelligent (mémorise les dossiers)
    ripgrep                  # grep ultra-rapide (rg)
    fd                       # find moderne et rapide
    tldr                     # man pages simplifiées
    micro                    # éditeur de texte moderne et simple
    starship                 # prompt cross-shell personnalisable

    # ── Police ───────────────────────────────────────────────────────
    ttf-jetbrains-mono-nerd  # police Nerd Font pour le terminal

    # ── Dépendances ───────────────────────────────────────────────
    curl
    wget
    git
    unzip
)

TO_INSTALL=()

for pkg in "${PKGS[@]}"; do
    if pacman_installed "$pkg"; then
        echo -e "  ${DIM}$pkg${RESET}"
        skip
    else
        echo -e "  ${YELLOW}$pkg${RESET} → à installer"
        TO_INSTALL+=("$pkg")
    fi
done

if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
    run "sudo pacman -Syu --noconfirm ${TO_INSTALL[*]}"
    $DRY_RUN || success "Paquets installés : ${TO_INSTALL[*]}"
else
    success "Tous les paquets système sont déjà présents."
fi

# =============================================================================
# 2. Fisher (gestionnaire de plugins Fish)
# =============================================================================
info "Vérification de Fisher..."

FISHER_FUNC="${HOME}/.config/fish/functions/fisher.fish"

if [[ -f "$FISHER_FUNC" ]]; then
    skip
else
    echo -e "  ${YELLOW}fisher${RESET} → à installer"
    if $DRY_RUN; then
        drylog "Installation de Fisher via curl | fish"
    else
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish \
            | fish -c 'source - && fisher install jorgebucaran/fisher'
        success "Fisher installé."
    fi
fi

# =============================================================================
# 3. Plugins Fish (via Fisher)
# =============================================================================
info "Installation des plugins Fish..."

FISH_PLUGINS=(
    jorgebucaran/autopair.fish      # fermeture auto des parenthèses/guillemets
    franciscolourenco/done          # notification quand une commande longue se termine
    PatrickF1/fzf.fish              # intégration fzf dans Fish (Ctrl+R, Ctrl+F, etc.)
    jethrokuan/z                    # navigation rapide (z <dossier>)
    nickeb96/puffer-fish            # expansion de !! et !$ comme en bash/zsh
    meaningful-ooo/sponge           # supprime les commandes échouées de l'historique
    decors/fish-colored-man         # pages man en couleur
    gazorby/fish-abbreviation-tips  # rappel des abbréviations disponibles
)

for plugin in "${FISH_PLUGINS[@]}"; do
    plugin_name="${plugin##*/}"
    if $DRY_RUN; then
        drylog "fisher install $plugin"
    else
        # Vérifie si le plugin est déjà installé
        if fish -c "fisher list" 2>/dev/null | grep -q "$plugin"; then
            echo -e "  ${DIM}$plugin_name${RESET}"
            skip
        else
            echo -e "  ${CYAN}$plugin_name${RESET} → installation..."
            fish -c "fisher install $plugin"
            success "$plugin_name installé."
        fi
    fi
done

# =============================================================================
# 4. Thème Catppuccin Powerline pour Starship
# =============================================================================
info "Application du preset Catppuccin Powerline..."

STARSHIP_CFG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"
STARSHIP_TOML="${STARSHIP_CFG_DIR}/starship.toml"

ensure_dir "$STARSHIP_CFG_DIR"

if [[ -f "$STARSHIP_TOML" ]]; then
    if $DRY_RUN; then
        drylog "Sauvegarde $STARSHIP_TOML → starship.toml.bak"
    else
        warn "starship.toml existant sauvegardé dans starship.toml.bak"
        cp "$STARSHIP_TOML" "${STARSHIP_TOML}.bak"
    fi
fi

run "starship preset catppuccin-powerline -o '$STARSHIP_TOML'"
$DRY_RUN || success "Preset appliqué dans $STARSHIP_TOML."

# =============================================================================
# 5. Configuration Fish (config.fish)
# =============================================================================
info "Génération de ~/.config/fish/config.fish..."

FISH_CONFIG_DIR="${HOME}/.config/fish"
FISH_CONFIG="${FISH_CONFIG_DIR}/config.fish"

ensure_dir "$FISH_CONFIG_DIR"

if [[ -f "$FISH_CONFIG" ]]; then
    if $DRY_RUN; then
        drylog "Sauvegarde $FISH_CONFIG → config.fish.bak"
    else
        warn "config.fish existant sauvegardé dans config.fish.bak"
        cp "$FISH_CONFIG" "${FISH_CONFIG}.bak"
    fi
fi

if $DRY_RUN; then
    drylog "Écriture de ~/.config/fish/config.fish avec les sections :"
    echo -e "  ${DIM}· Désactivation du message de bienvenue${RESET}"
    echo -e "  ${DIM}· Variables d'environnement (EDITOR=micro, PATH)${RESET}"
    echo -e "  ${DIM}· Source du fichier d'alias (fish_alias.fish)${RESET}"
    echo -e "  ${DIM}· Fonctions utilitaires (mkcd, extract, backup)${RESET}"
    echo -e "  ${DIM}· Intégration zoxide et fzf${RESET}"
    echo -e "  ${DIM}· Init Starship${RESET}"
else
    cat > "$FISH_CONFIG" <<'FISHCONFIG'
# =============================================================================
# ~/.config/fish/config.fish — Configuration Fish Shell
# =============================================================================

# --- Désactiver le message de bienvenue --------------------------------------
set -g fish_greeting ""

# --- Variables d'environnement -----------------------------------------------
set -gx EDITOR micro
set -gx VISUAL micro
set -gx PAGER "bat --paging=always"
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Ajouter ~/.local/bin au PATH
fish_add_path ~/.local/bin

# --- Options FZF -------------------------------------------------------------
set -gx FZF_DEFAULT_COMMAND "fd --type f --hidden --follow --exclude .git"
set -gx FZF_DEFAULT_OPTS "\
    --height 40% --layout=reverse --border \
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_ALT_C_COMMAND "fd --type d --hidden --follow --exclude .git"

# --- Charger les alias depuis un fichier séparé -----------------------------
set -l ALIAS_FILE ~/.config/fish/fish_alias.fish
if test -f $ALIAS_FILE
    source $ALIAS_FILE
end

# =============================================================================
# Fonctions utilitaires
# =============================================================================

# Crée un dossier et s'y déplace directement
function mkcd -d "Crée un dossier et s'y déplace"
    mkdir -pv $argv[1] && cd $argv[1]
end

# Extraire n'importe quelle archive
function extract -d "Extraire une archive (zip, tar, gz, bz2, xz, 7z...)"
    if test -f $argv[1]
        switch (string lower $argv[1])
            case '*.tar.bz2'
                tar xjf $argv[1]
            case '*.tar.gz' '*.tgz'
                tar xzf $argv[1]
            case '*.tar.xz' '*.txz'
                tar xJf $argv[1]
            case '*.tar.zst'
                tar --zstd -xf $argv[1]
            case '*.bz2'
                bunzip2 $argv[1]
            case '*.gz'
                gunzip $argv[1]
            case '*.xz'
                unxz $argv[1]
            case '*.zip'
                unzip $argv[1]
            case '*.rar'
                unrar x $argv[1]
            case '*.7z'
                7z x $argv[1]
            case '*'
                echo "Format non reconnu : $argv[1]"
                return 1
        end
    else
        echo "Fichier introuvable : $argv[1]"
        return 1
    end
end

# Sauvegarde rapide d'un fichier
function backup -d "Crée une copie de sauvegarde avec timestamp"
    cp $argv[1] "$argv[1].bak."(date +%Y%m%d_%H%M%S)
    echo "✔ Sauvegarde créée : $argv[1].bak."(date +%Y%m%d_%H%M%S)
end

# Taille des sous-dossiers, triée
function dush -d "Taille des sous-dossiers du répertoire courant"
    du -sh */ 2>/dev/null | sort -rh
end

# Rechercher un fichier et l'ouvrir avec fzf
function fopen -d "Recherche un fichier avec fzf et l'ouvre dans l'éditeur"
    set -l file (fd --type f --hidden | fzf --preview 'bat --color=always --line-range :50 {}')
    if test -n "$file"
        $EDITOR $file
    end
end

# Historique interactif avec fzf
function fhistory -d "Recherche dans l'historique avec fzf"
    history | fzf --no-sort | read -l cmd
    if test -n "$cmd"
        commandline $cmd
    end
end

# Mettre à jour le système complet
function sysupdate -d "Met à jour tout le système (pacman + yay + fisher)"
    echo "📦 Mise à jour pacman..."
    sudo pacman -Syu
    if command -q yay
        echo "📦 Mise à jour AUR (yay)..."
        yay -Sua --noconfirm
    end
    echo "🐟 Mise à jour des plugins Fish..."
    fisher update
    echo "✔ Système à jour !"
end

# Afficher un résumé rapide du système
function sysinfo -d "Résumé rapide du système"
    echo ""
    echo -e "\033[1m── Système ────────────────────────────\033[0m"
    echo "  Hôte     : "(hostname)
    echo "  Noyau    : "(uname -r)
    echo "  Uptime   : "(uptime -p)
    echo ""
    echo -e "\033[1m── Mémoire ────────────────────────────\033[0m"
    free -h | awk '/^Mem:/ {printf "  Utilisée : %s / %s\n", $3, $2}'
    echo ""
    echo -e "\033[1m── Disque ─────────────────────────────\033[0m"
    df -h / | awk 'NR==2 {printf "  Utilisé  : %s / %s (%s)\n", $3, $2, $5}'
    echo ""
    echo -e "\033[1m── Réseau ─────────────────────────────\033[0m"
    echo "  IP locale : "(ip -4 addr show scope global | awk '/inet/ {print $2}' | head -1)
    echo ""
end

# =============================================================================
# Intégrations
# =============================================================================

# --- Zoxide (cd intelligent) -------------------------------------------------
if command -q zoxide
    zoxide init fish | source
end

# --- Starship (prompt) -------------------------------------------------------
if command -q starship
    starship init fish | source
end
FISHCONFIG
    success "~/.config/fish/config.fish généré."
fi

# =============================================================================
# 5b. Copie du fichier d'alias (fish_alias.fish)
# =============================================================================
info "Installation de ~/.config/fish/fish_alias.fish..."

FISH_ALIAS_FILE="${FISH_CONFIG_DIR}/fish_alias.fish"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ALIAS="${SCRIPT_DIR}/fish_alias.fish"

# Vérifier que le fichier source existe
if [[ ! -f "$SOURCE_ALIAS" ]]; then
    err "Fichier fish_alias.fish introuvable dans $SCRIPT_DIR"
    err "Assure-toi que fish_alias.fish est dans le même dossier que ce script."
    exit 1
fi

if [[ -f "$FISH_ALIAS_FILE" ]]; then
    if $DRY_RUN; then
        drylog "Sauvegarde $FISH_ALIAS_FILE → fish_alias.fish.bak"
    else
        warn "fish_alias.fish existant sauvegardé dans fish_alias.fish.bak"
        cp "$FISH_ALIAS_FILE" "${FISH_ALIAS_FILE}.bak"
    fi
fi

run "cp '$SOURCE_ALIAS' '$FISH_ALIAS_FILE'"
$DRY_RUN || success "fish_alias.fish copié dans $FISH_CONFIG_DIR."

# =============================================================================
# 6. Shell par défaut
# =============================================================================
info "Vérification du shell par défaut..."

FISH_PATH="$(which fish 2>/dev/null || echo '/usr/bin/fish')"

if [[ "$SHELL" == "$FISH_PATH" ]]; then
    success "fish est déjà le shell par défaut."
else
    warn "Shell actuel : $SHELL → changement vers $FISH_PATH"

    # S'assurer que fish est dans /etc/shells
    if ! grep -q "$FISH_PATH" /etc/shells 2>/dev/null; then
        run "echo '$FISH_PATH' | sudo tee -a /etc/shells"
    fi

    run "chsh -s '$FISH_PATH'"
    $DRY_RUN || success "Shell par défaut changé. Reconnecte-toi pour appliquer."
fi

# =============================================================================
# Récapitulatif
# =============================================================================
echo ""
echo -e "${BOLD}══════════════════════════════════════════════${RESET}"
if $DRY_RUN; then
    echo -e "${YELLOW}${BOLD}  DRY-RUN terminé — aucune modification effectuée.${RESET}"
    echo -e "  Lance ${CYAN}./install_fish.sh${RESET} sans flag pour appliquer."
else
    echo -e "${GREEN}${BOLD}  🐟 Installation terminée !${RESET}"
    echo ""
    echo -e "  ${BOLD}Outils installés :${RESET}"
    echo -e "  ${DIM}  bat, eza, fzf, zoxide, ripgrep, fd, tldr, micro, starship${RESET}"
    echo ""
    echo -e "  ${BOLD}Plugins Fish :${RESET}"
    echo -e "  ${DIM}  autopair, done, fzf.fish, z, puffer-fish, sponge, colored-man${RESET}"
    echo ""
    echo -e "  ${BOLD}Raccourcis utiles :${RESET}"
    echo -e "  ${CYAN}Ctrl+R${RESET}  → recherche historique (fzf)"
    echo -e "  ${CYAN}Ctrl+F${RESET}  → recherche fichiers (fzf)"
    echo -e "  ${CYAN}Alt+C${RESET}   → navigation dossiers (fzf)"
    echo -e "  ${CYAN}z <nom>${RESET} → navigation rapide (zoxide)"
    echo -e "  ${CYAN}!!${RESET}      → dernière commande (puffer-fish)"
    echo ""
    echo -e "  Lance ${CYAN}exec fish${RESET} ou reconnecte-toi pour démarrer."
fi
echo -e "${BOLD}══════════════════════════════════════════════${RESET}"
echo ""
