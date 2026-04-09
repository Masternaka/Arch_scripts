# 🐟 Installation et configuration de Fish Shell (À vérifier s'il fonctionne)

Script d'installation automatisée du shell **Fish** sur **EndeavourOS / Arch Linux**, avec des outils CLI modernes, des plugins utiles et une configuration complète prête à l'emploi.

---

## 📁 Structure des fichiers

```
Installation et configuration Fish/
├── install_fish.sh     # Script principal d'installation
├── fish_alias.fish     # Fichier d'alias/abbreviations (indépendant)
└── README.md           # Ce fichier
```

---

## 🚀 Utilisation

### Prérequis

- EndeavourOS ou toute distribution basée sur Arch Linux
- Accès `sudo`

### Lancer le script

```bash
# Rendre le script exécutable
chmod +x install_fish.sh

# Simuler l'installation (aucune modification)
./install_fish.sh --dry-run

# Lancer l'installation
./install_fish.sh
```

> **💡 Conseil** : Utilise d'abord `--dry-run` (ou `-n`) pour voir exactement ce que le script va faire avant de l'exécuter.

### Après l'installation

```bash
# Démarrer Fish immédiatement
exec fish

# Ou simplement se reconnecter
```

---

## 📦 Ce que le script installe

### Étape 1 — Paquets système (via pacman)

| Paquet | Description |
|--------|-------------|
| `fish` | Le shell Fish |
| `bat` | Remplacement de `cat` avec coloration syntaxique |
| `eza` | Remplacement de `ls` avec icônes et intégration git |
| `fzf` | Recherche floue interactive |
| `zoxide` | Remplacement de `cd` intelligent (mémorise les dossiers) |
| `ripgrep` | Remplacement de `grep` ultra-rapide (`rg`) |
| `fd` | Remplacement de `find` moderne et rapide |
| `tldr` | Pages man simplifiées et pratiques |
| `micro` | Éditeur de texte terminal moderne et simple |
| `starship` | Prompt cross-shell personnalisable |
| `ttf-jetbrains-mono-nerd` | Police Nerd Font pour le terminal |
| `curl`, `wget`, `git`, `unzip` | Dépendances utilitaires |

### Étape 2 — Fisher

Installe [Fisher](https://github.com/jorgebucaran/fisher), le gestionnaire de plugins pour Fish.

### Étape 3 — Plugins Fish

| Plugin | Description |
|--------|-------------|
| `autopair.fish` | Fermeture automatique des `()`, `""`, `[]`, etc. |
| `done` | Notification quand une commande longue se termine |
| `fzf.fish` | Intégration fzf dans Fish (`Ctrl+R`, `Ctrl+F`, `Alt+C`) |
| `z` | Navigation rapide par mémoire (`z projets`) |
| `puffer-fish` | Expansion de `!!` et `!$` comme en bash/zsh |
| `sponge` | Supprime automatiquement les commandes échouées de l'historique |
| `fish-colored-man` | Pages man en couleur |
| `fish-abbreviation-tips` | Rappelle les abbreviations disponibles quand on tape la commande complète |

### Étape 4 — Thème Starship

Applique le preset **Catppuccin Powerline** pour un prompt élégant et informatif.

### Étape 5 — Configuration Fish

Génère `~/.config/fish/config.fish` avec :

- **Éditeur par défaut** : `micro`
- **Pager** : `bat`
- **FZF** configuré avec le thème Catppuccin
- **Alias** sourcés depuis un fichier séparé (`fish_alias.fish`)
- **Fonctions utilitaires** intégrées (voir ci-dessous)
- **Intégrations** : zoxide et Starship

### Étape 5b — Copie des alias

Copie le fichier `fish_alias.fish` dans `~/.config/fish/`. Ce fichier est indépendant et peut être modifié sans toucher à la configuration principale.

### Étape 6 — Shell par défaut

Change le shell par défaut de l'utilisateur vers Fish.

---

## ⌨️ Raccourcis clavier

| Raccourci | Action |
|-----------|--------|
| `Ctrl+R` | Recherche dans l'historique (fzf) |
| `Ctrl+F` | Recherche de fichiers (fzf) |
| `Alt+C` | Navigation dans les dossiers (fzf) |
| `!!` | Dernière commande (puffer-fish) |
| `!$` | Dernier argument (puffer-fish) |

---

## 📝 Alias disponibles

Les alias sont des **abbreviations Fish** : ils se développent automatiquement quand on appuie sur `Espace` ou `Entrée`, ce qui permet de voir la commande réelle avant exécution.

### Fichiers

| Alias | Commande |
|-------|----------|
| `ls` | `eza --icons` |
| `ll` | `eza -lh --icons --git` |
| `la` | `eza -lah --icons --git` |
| `lt` | `eza --tree --icons --level=2` |
| `l` | `eza -1 --icons` |
| `lS` | `eza -lah --icons --git --sort=size` |
| `lm` | `eza -lah --icons --git --sort=modified` |
| `cat` | `bat --paging=never` |
| `less` | `bat` |

### Navigation

| Alias | Commande |
|-------|----------|
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `....` | `cd ../../..` |
| `mkdir` | `mkdir -pv` |
| `cp` | `cp -iv` |
| `mv` | `mv -iv` |
| `rm` | `rm -Iv` |

### Recherche

| Alias | Commande |
|-------|----------|
| `rg` | `rg --smart-case` |
| `ff` | `fd --type f` |
| `fdir` | `fd --type d` |
| `grep` | `grep --color=auto` |

### Git

| Alias | Commande |
|-------|----------|
| `gs` | `git status -sb` |
| `ga` | `git add` |
| `gaa` | `git add --all` |
| `gc` | `git commit -m` |
| `gp` | `git push` |
| `gpl` | `git pull` |
| `gd` | `git diff` |
| `gl` | `git log --oneline --graph --decorate --all` |
| `gco` | `git checkout` |
| `gsw` | `git switch` |
| `gb` | `git branch -vv` |
| `gst` | `git stash` |
| `gstp` | `git stash pop` |
| `gcl` | `git clone --depth 1` |

### Système (Arch / EndeavourOS)

| Alias | Commande |
|-------|----------|
| `update` | `sudo pacman -Syu` |
| `install` | `sudo pacman -S` |
| `remove` | `sudo pacman -Rns` |
| `search` | `pacman -Ss` |
| `orphans` | `pacman -Qtdq` |
| `clean` | `sudo pacman -Rns (pacman -Qtdq)` |
| `services` | `systemctl list-units --type=service --state=running` |
| `logs` | `journalctl -xe` |
| `jf` | `journalctl -f` |

### Réseau

| Alias | Commande |
|-------|----------|
| `ipa` | `ip -c addr` |
| `ping` | `ping -c 5` |
| `ports` | `ss -tulnp` |
| `myip` | `curl -s ifconfig.me` |

---

## 🔧 Fonctions utilitaires

Ces fonctions sont intégrées dans `config.fish` :

| Fonction | Description |
|----------|-------------|
| `mkcd <dossier>` | Crée un dossier et s'y déplace directement |
| `extract <archive>` | Extraire n'importe quelle archive (zip, tar, gz, bz2, xz, 7z, rar, zst) |
| `backup <fichier>` | Crée une copie de sauvegarde avec timestamp |
| `dush` | Affiche la taille des sous-dossiers triée par taille |
| `fopen` | Recherche un fichier avec fzf et l'ouvre dans micro |
| `fhistory` | Recherche interactive dans l'historique avec fzf |
| `sysupdate` | Met à jour tout le système (pacman + yay + plugins Fish) |
| `sysinfo` | Affiche un résumé rapide du système (hôte, noyau, mémoire, disque, réseau) |

---

## 🛡️ Sécurité et sauvegardes

Le script crée automatiquement des **sauvegardes** (`.bak`) de tous les fichiers existants avant de les remplacer :

- `~/.config/fish/config.fish` → `config.fish.bak`
- `~/.config/fish/fish_alias.fish` → `fish_alias.fish.bak`
- `~/.config/starship.toml` → `starship.toml.bak`

---

## ✏️ Personnalisation

### Modifier les alias

Édite directement le fichier `fish_alias.fish` dans ce dépôt, puis relance le script ou copie-le manuellement :

```bash
cp fish_alias.fish ~/.config/fish/fish_alias.fish
```

Les changements sont pris en compte au prochain démarrage de Fish ou avec :

```bash
source ~/.config/fish/fish_alias.fish
```

### Modifier la configuration

La configuration principale est générée par le script dans `~/.config/fish/config.fish`. Pour des modifications permanentes, édite ce fichier directement sur ton système.

---

## 📌 Notes

- Le script est **idempotent** : il peut être relancé sans risque, les paquets et plugins déjà installés sont ignorés
- Le mode `--dry-run` permet de prévisualiser toutes les actions sans rien modifier
- Le fichier `fish_alias.fish` doit être **dans le même dossier** que `install_fish.sh`
