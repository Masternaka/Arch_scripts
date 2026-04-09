#!/bin/bash

## Fonctionne pas

# Script d'installation d'outils de productivité sur Arch Linux
# zoxide: outil de navigation de répertoires intelligent
# fzf: outil de recherche floue en ligne de commande
# fd: alternative moderne à 'find' avec recherche floue
# eza: alternative moderne à 'ls' avec couleurs et informations détaillées
# ripgrep: outil de recherche ultra-rapide dans les fichiers
# bat: alternative moderne à 'cat' avec coloration syntaxique

set -e

echo "=== Installation d'outils de productivité sur Arch Linux ==="
echo

# Vérifier si pacman est disponible
if ! command -v pacman &> /dev/null; then
    echo "❌ Erreur: pacman n'est pas installé. Ce script est destiné à Arch Linux."
    exit 1
fi

# Installation de zoxide
echo "📦 Installation de zoxide..."
sudo pacman -S --noconfirm zoxide
echo "✅ zoxide installé avec succès"
echo

# Installation de fzf
echo "📦 Installation de fzf..."
sudo pacman -S --noconfirm fzf
echo "✅ fzf installé avec succès"
echo

# Installation de fd
echo "📦 Installation de fd..."
sudo pacman -S --noconfirm fd
echo "✅ fd installé avec succès"
echo

# Installation de eza
echo "📦 Installation de eza..."
sudo pacman -S --noconfirm eza
echo "✅ eza installé avec succès"
echo

# Installation de ripgrep
echo "📦 Installation de ripgrep..."
sudo pacman -S --noconfirm ripgrep
echo "✅ ripgrep installé avec succès"
echo

# Installation de bat
echo "📦 Installation de bat..."
sudo pacman -S --noconfirm bat
echo "✅ bat installé avec succès"
echo

# Configuration pour bash/zsh
echo "⚙️  Configuration des shells..."
echo

# Demander si l'utilisateur veut la configuration recommandée
read -p "Voulez-vous ajouter la configuration recommandée (alias, intégration fzf)? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    CONFIG_MODE="full"
else
    CONFIG_MODE="minimal"
fi

# Configuration pour bash
if [ -f ~/.bashrc ]; then
    if ! grep -q "zoxide init bash" ~/.bashrc; then
        echo "eval \"\$(zoxide init bash)\"" >> ~/.bashrc
        
        if [ "$CONFIG_MODE" = "full" ]; then
            cat >> ~/.bashrc << 'EOF'

# Configuration zoxide et fzf
alias cd='z'
alias cdi='zi'

# Options fzf recommandées
export FZF_DEFAULT_OPTS="--height 40% --reverse --border --multi"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"

# Alias pour les nouveaux outils
alias ls='eza --git --icons'
alias ll='eza -l --git --icons'
alias la='eza -la --git --icons'
alias tree='eza --tree --git --icons'
alias find='fd'
alias cat='bat'
alias grep='rg'
EOF
        fi
        echo "✅ zoxide ajouté à ~/.bashrc"
    else
        echo "ℹ️  zoxide déjà configuré dans ~/.bashrc"
    fi
fi

# Configuration pour zsh
if [ -f ~/.zshrc ]; then
    if ! grep -q "zoxide init zsh" ~/.zshrc; then
        echo "eval \"\$(zoxide init zsh)\"" >> ~/.zshrc
        
        if [ "$CONFIG_MODE" = "full" ]; then
            cat >> ~/.zshrc << 'EOF'

# Configuration zoxide et fzf
alias cd='z'
alias cdi='zi'

# Options fzf recommandées
export FZF_DEFAULT_OPTS="--height 40% --reverse --border --multi"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"

# Alias pour les nouveaux outils
alias ls='eza --git --icons'
alias ll='eza -l --git --icons'
alias la='eza -la --git --icons'
alias tree='eza --tree --git --icons'
alias find='fd'
alias cat='bat'
alias grep='rg'
EOF
        fi
        echo "✅ zoxide ajouté à ~/.zshrc"
    else
        echo "ℹ️  zoxide déjà configuré dans ~/.zshrc"
    fi
fi

echo
echo "🎉 Installation terminée!"
echo
echo "📋 Commandes disponibles:"
echo "   - zoxide: utiliser 'z' au lieu de 'cd' pour naviguer intelligemment"
echo "   - fzf: utiliser Ctrl+R pour chercher dans l'historique avec fzf"
echo "   - fd: alternative moderne à 'find' (ex: fd 'pattern')"
echo "   - eza: alternative moderne à 'ls' avec couleurs et icônes"
echo "   - ripgrep: recherche ultra-rapide dans les fichiers (ex: rg 'pattern')"
echo "   - bat: alternative moderne à 'cat' avec coloration syntaxique"
echo

if [ "$CONFIG_MODE" = "full" ]; then
    echo "⚙️  Configuration appliquée:"
    echo "   - Alias 'cd' remplacé par 'z' (navigation intelligente)"
    echo "   - Alias 'cdi' pour navigation interactive avec fzf"
    echo "   - Options fzf personnalisées (hauteur, thème, multi-select)"
    echo "   - Alias 'ls' remplacé par 'eza --git --icons'"
    echo "   - Alias 'll' pour liste détaillée avec eza"
    echo "   - Alias 'la' pour liste complète avec eza"
    echo "   - Alias 'tree' pour arborescence avec eza"
    echo "   - Alias 'find' remplacé par 'fd'"
    echo "   - Alias 'cat' remplacé par 'bat'"
    echo "   - Alias 'grep' remplacé par 'rg'"
else
    echo "ℹ️  Mode minimal: configuration de base uniquement"
    echo "   Vous pouvez personnaliser manuellement ~/.bashrc ou ~/.zshrc"
fi
echo
echo "💡 Conseil: Redémarrez votre terminal pour appliquer les modifications"
