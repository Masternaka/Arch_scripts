# Script de modification de Pacman: ParallelDownloads (FONCTIONNE)

###############################################################################
# Script de modification du nombre de téléchargements parallèles dans pacman.conf
# Version améliorée 2.0
#
# Utilisation:
# 1. Sauvegardez ce script sous un nom, par exemple: mod-pacman.sh
# 2. Rendez-le exécutable: chmod +x mod-pacman.sh
# 3. Exécutez-le: sudo ./mod-pacman.sh [OPTIONS]
#
# Options:
#   --restore    : Restaure la configuration originale
#   --auto       : Détection automatique du nombre optimal
#   --silent     : Mode silencieux (pas d'interaction utilisateur)
#   --value N    : Définit directement la valeur N
#   --help       : Affiche cette aide
#
# Exemples:
#   sudo ./mod-pacman.sh --auto
#   sudo ./mod-pacman.sh --value 5
#   sudo ./mod-pacman.sh --silent --value 3
#   sudo ./mod-pacman.sh --restore
###############################################################################

Ce dossier contient le script `mod_pacman.sh` (Version améliorée 2.0) permettant de consulter, modifier ou désactiver la valeur `ParallelDownloads` dans le fichier de configuration de Pacman (`/etc/pacman.conf`). Il gère automatiquement la sauvegarde, la restauration et la validation de la configuration.

## Fonctionnalités
- **Détection automatique** d'une valeur optimale en fonction du nombre de CPU et de la mémoire.
- **Mode interactif** ou **mode silencieux** (sans interaction).
- **Définition explicite d'une valeur** (entre 0 et 20).
  - `0` désactive la fonctionnalité en commentant la ligne.
- **Sauvegardes horodatées** du fichier `pacman.conf` dans `/etc/pacman.conf.backups`.
- **Restauration** simple vers la dernière sauvegarde.
- **Journalisation** des opérations dans `/var/log/pacman_parallel_downloads.log`.
- **Validation de syntaxe** via `pacman-conf` après modification, avec restauration automatique en cas d'erreur.

## Prérequis
- Système basé sur Arch Linux (EndeavourOS, Arch, etc.).
- Accès admin: exécuter les commandes avec `sudo`.
- Outils disponibles:
  - `pacman-conf` (fourni par `pacman`).
  - `nproc`, `free`, `awk`, `sed`, `tee`, etc. (généralement inclus).

## Installation
1. Copier le script dans un répertoire (ex: `~/bin` ou le dépôt actuel).
2. Le rendre exécutable:
```bash
chmod +x mod_pacman.sh
```

## Utilisation rapide
- Mode interactif:
```bash
sudo ./mod_pacman.sh
```
- Détection automatique:
```bash
sudo ./mod_pacman.sh --auto
```
- Valeur explicite (ex: 5 téléchargements):
```bash
sudo ./mod_pacman.sh --value 5
```
- Mode silencieux + valeur:
```bash
sudo ./mod_pacman.sh --silent --value 3
```
- Restauration de la dernière sauvegarde:
```bash
sudo ./mod_pacman.sh --restore
```

## Options disponibles
- `--restore` : restaure `pacman.conf` depuis la dernière sauvegarde.
- `--auto` : calcule une valeur optimale selon CPU et RAM.
- `--silent` : exécution sans interaction (utile pour scripts/automatisation).
- `--value N` : force la valeur à `N` (entier 0–20). `0` commente la ligne.
- `--help`, `-h` : affiche l'aide intégrée.

## Détails de fonctionnement
- Le script lit la valeur actuelle via la directive `ParallelDownloads` (ou détecte si elle est commentée/non présente).
- Avant toute modification, il crée le répertoire `/etc/pacman.conf.backups` s'il n'existe pas, puis sauvegarde `pacman.conf` avec un horodatage.
- Saisie et validations:
  - Refuse les valeurs non entières.
  - Refuse les valeurs hors plage `0–20`.
- Application de la modification:
  - `0` ➜ commente la directive (désactivation).
  - `1–20` ➜ met à jour la directive (décommente/écrit la ligne).
- Après modification, la syntaxe est vérifiée (`pacman-conf`). En cas d'échec, le script restaure automatiquement la sauvegarde la plus récente et s'arrête en erreur.
- Toutes les actions sont journalisées dans `/var/log/pacman_parallel_downloads.log`.

## Détection automatique: logique
- Nombre de CPU via `nproc`:
  - ≥ 8 ➜ 8
  - ≥ 4 ➜ 6
  - ≥ 2 ➜ 4
  - sinon ➜ 2
- Ajustement RAM via `free -g`:
  - si RAM < 4 Go ➜ valeur plafonnée à 3 (si supérieure).

## Restauration
Pour restaurer la configuration précédente:
```bash
sudo ./mod_pacman.sh --restore
```
Le script cherchera la sauvegarde la plus récente dans `/etc/pacman.conf.backups` et la restaurera sur `/etc/pacman.conf`.

## Journalisation
Les opérations sont consignées dans:
```
/var/log/pacman_parallel_downloads.log
```
En mode non silencieux, les messages sont affichés à l'écran et écrits dans le fichier. En mode silencieux, ils sont uniquement écrits dans le fichier de log.

## Dépannage
- "Erreur : Veuillez exécuter ce script en tant qu'administrateur" ➜ relancer avec `sudo`.
- "Le fichier /etc/pacman.conf n'existe pas" ➜ vérifier l'environnement Arch/EndeavourOS.
- "La valeur doit être un entier positif" ➜ vérifier `--value`.
- "Valeur hors limites (0-20)" ➜ utiliser une valeur comprise entre 0 et 20.
- "Syntaxe Pacman invalide" après modification ➜ le script restaure automatiquement; vérifier les permissions et l'intégrité de `pacman.conf`.

## Sécurité et bonnes pratiques
- Toujours créer une sauvegarde (le script le fait automatiquement).
- Éviter de modifier manuellement `pacman.conf` sans comprendre les implications.
- Conserver quelques sauvegardes récentes dans `/etc/pacman.conf.backups`.

## Avertissements
- Ce script modifie un fichier système (`/etc/pacman.conf`). Utilisez-le en connaissance de cause.
- Testé sur des systèmes de type Arch/EndeavourOS. D'autres distributions peuvent ne pas fournir les mêmes outils ou chemins.
