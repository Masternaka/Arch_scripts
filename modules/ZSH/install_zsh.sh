#!/usr/bin/env bash

# NAME: install_zsh
# DESC: Script d'installation de ZSH pour Arch Linux
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
DIM='\033[2m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}==> ${RESET}${BOLD}$*${RESET}"; }
success() { echo -e "${GREEN}${BOLD}✔  $*${RESET}"; }
warn()    { echo -e "${YELLOW}${BOLD}!  $*${RESET}"; }
skip()    { echo -e "  ${DIM}↳ déjà installé, ignoré.${RESET}"; }
drylog()  { echo -e "  ${BLUE}${BOLD}[dry-run]${RESET}${BLUE} $*${RESET}"; }

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
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       setup-zsh.sh — Arch Linux          ║${RESET}"
if $DRY_RUN; then
echo -e "${BOLD}║  ${YELLOW}MODE DRY-RUN — aucune modification${RESET}${BOLD}      ║${RESET}"
fi
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""

# =============================================================================
# 1. Paquets système
# =============================================================================
info "Vérification des paquets système..."

PKGS=(zsh bat fzf zoxide eza ripgrep starship curl git unzip)
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
# 2. Police JetBrainsMono Nerd Font
# =============================================================================
info "Vérification de JetBrainsMonoNerdFont..."

FONT_DIR="${HOME}/.local/share/fonts/JetBrainsMono"

if fc-list | grep -qi "JetBrainsMono"; then
    skip
else
    echo -e "  ${YELLOW}JetBrainsMonoNerdFont${RESET} → à installer"
    ensure_dir "$FONT_DIR"

    if $DRY_RUN; then
        drylog "Récupération du dernier tag Nerd Fonts via l'API GitHub"
        drylog "Téléchargement de JetBrainsMono.zip"
        drylog "Extraction des .ttf dans $FONT_DIR"
        drylog "fc-cache -fv $FONT_DIR"
    else
        LATEST_TAG=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
            | grep '"tag_name"' | cut -d'"' -f4)
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${LATEST_TAG}/JetBrainsMono.zip"
        TMP_ZIP=$(mktemp /tmp/JetBrainsMono_XXXXXX.zip)
        curl -fsSL "$FONT_URL" -o "$TMP_ZIP"
        unzip -o "$TMP_ZIP" -d "$FONT_DIR" '*.ttf' 2>/dev/null
        rm -f "$TMP_ZIP"
        fc-cache -fv "$FONT_DIR" &>/dev/null
        success "JetBrainsMonoNerdFont installée dans $FONT_DIR."
    fi
fi

# =============================================================================
# 3. Zinit
# =============================================================================
info "Vérification de Zinit..."

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ -d "$ZINIT_HOME" ]]; then
    warn "Zinit déjà présent → mise à jour du dépôt"
    run "git -C '$ZINIT_HOME' pull --ff-only"
else
    echo -e "  ${YELLOW}zinit${RESET} → à installer"
    run "git clone https://github.com/zdharma-continuum/zinit.git '$ZINIT_HOME'"
    $DRY_RUN || success "Zinit installé dans $ZINIT_HOME."
fi

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
# 5. Fichier .zshrc
# =============================================================================
info "Génération de ~/.zshrc..."

ZSHRC="${HOME}/.zshrc"

if [[ -f "$ZSHRC" ]]; then
    if $DRY_RUN; then
        drylog "Sauvegarde $ZSHRC → $ZSHRC.bak"
    else
        warn "~/.zshrc existant sauvegardé dans ~/.zshrc.bak"
        cp "$ZSHRC" "${ZSHRC}.bak"
    fi
fi

if $DRY_RUN; then
    drylog "Écriture de ~/.zshrc avec les sections :"
    echo -e "  ${DIM}· Zinit bootstrap${RESET}"
    echo -e "  ${DIM}· Plugins : zsh-completions, zsh-autosuggestions, zsh-syntax-highlighting${RESET}"
    echo -e "  ${DIM}·           zsh-bat, fzf-zsh-plugin, zsh-zoxide${RESET}"
    echo -e "  ${DIM}· Options zsh (history, auto_cd)${RESET}"
    echo -e "  ${DIM}· Aliases : eza, navigation, git, système, réseau${RESET}"
    echo -e "  ${DIM}· Init Starship${RESET}"
else
    cat > "$ZSHRC" <<'ZSHRC'
# =============================================================================
# ~/.zshrc — zsh + zinit
# =============================================================================

# --- Zinit bootstrap ---------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
source "${ZINIT_HOME}/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# --- Plugins -----------------------------------------------------------------
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light fdellwing/zsh-bat
zinit light unixorn/fzf-zsh-plugin
zinit light z-shell/zsh-zoxide

# --- Completions -------------------------------------------------------------
autoload -Uz compinit && compinit

# --- Options zsh -------------------------------------------------------------
setopt AUTO_CD
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="${HOME}/.zsh_history"

# --- Aliases : Fichiers (eza + bat) ------------------------------------------
alias ls='eza --icons'
alias ll='eza -lh --icons --git'
alias la='eza -lah --icons --git'
alias lt='eza --tree --icons'
alias l='eza -1 --icons'
alias cat='bat --paging=never'
alias less='bat'

# --- Aliases : Navigation ----------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias mkdir='mkdir -pv'          # crée les parents, verbose
alias md='mkdir -pv'
alias rd='rmdir'
alias cp='cp -iv'                # interactif + verbose
alias mv='mv -iv'
alias rm='rm -Iv'                # confirmation si >3 fichiers
alias du='du -sh'
alias df='df -h'

# --- Aliases : Git -----------------------------------------------------------
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -m'
alias gca='git commit --amend --no-edit'
alias gp='git push'
alias gpl='git pull'
alias gf='git fetch --prune'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate --all'
alias gco='git checkout'
alias gb='git branch -vv'
alias gbd='git branch -d'
alias grb='git rebase'
alias gst='git stash'
alias gstp='git stash pop'

# --- Aliases : Système (Arch) ------------------------------------------------
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rns'
alias search='pacman -Ss'
alias pkginfo='pacman -Qi'
alias pkgfiles='pacman -Ql'
alias orphans='pacman -Qtdq'
alias clean='sudo pacman -Rns $(pacman -Qtdq)'  # supprime les orphelins
alias reboot='sudo systemctl reboot'
alias poweroff='sudo systemctl poweroff'
alias suspend='sudo systemctl suspend'
alias services='systemctl list-units --type=service --state=running'
alias logs='journalctl -xe'
alias j='journalctl -f'         # suivi des logs en direct

# --- Aliases : Réseau --------------------------------------------------------
alias ip='ip -c'                 # sortie colorée
alias ipa='ip -c addr'
alias ipr='ip -c route'
alias ping='ping -c 5'
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me && echo'
alias myip6='curl -s ifconfig.co && echo'
alias dns='resolvectl status'
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -'

# --- Starship ----------------------------------------------------------------
eval "$(starship init zsh)"
ZSHRC
    success "~/.zshrc généré."
fi

# =============================================================================
# 6. Shell par défaut
# =============================================================================
info "Vérification du shell par défaut..."

ZSH_PATH="$(which zsh 2>/dev/null || echo '/usr/bin/zsh')"

if [[ "$SHELL" == "$ZSH_PATH" ]]; then
    success "zsh est déjà le shell par défaut."
else
    warn "Shell actuel : $SHELL → changement vers $ZSH_PATH"
    run "chsh -s '$ZSH_PATH'"
    $DRY_RUN || success "Shell par défaut changé. Reconnecte-toi pour appliquer."
fi

# =============================================================================
# Récapitulatif
# =============================================================================
echo ""
echo -e "${BOLD}══════════════════════════════════════════${RESET}"
if $DRY_RUN; then
    echo -e "${YELLOW}${BOLD}  DRY-RUN terminé — aucune modification effectuée.${RESET}"
    echo -e "  Lance ${CYAN}./setup-zsh.sh${RESET} sans flag pour appliquer."
else
    echo -e "${GREEN}${BOLD}  Installation terminée !${RESET}"
    echo -e "  Lance ${CYAN}exec zsh${RESET} pour démarrer."
fi
echo -e "${BOLD}══════════════════════════════════════════${RESET}"
echo ""