Nouveau script activation_services.sh (FONCTIONNE) 

chmod +x ./enable-services.sh pour rendre le script exécutable
Utiliser la commande ./enable-services.sh --dry-run pour tester avant d'exécuter le script.
sudo ./enable-services.sh pour utiliser le script




# Script d'activation des services et timers systemd

Ce dossier contient le script `activation_services.sh` destiné à activer et vérifier des services et timers systemd essentiels sur un système Arch/EndeavourOS. Le script propose une interface claire avec couleurs, des contrôles de disponibilité, des options avancées et un récapitulatif de fin d'exécution.

## Nouveautés de la version améliorée
- **Mode dry-run** pour simulation sans modification
- **Options CLI flexibles** (`--dry-run`, `--verbose`, `--no-backup`)
- **Validation robuste** des noms de services systemd
- **Backup automatique** des configurations existantes
- **Logging amélioré** avec mode verbose
- **Informations utiles** et commandes de référence

## Fonctionnalités
- **Activation automatique de services essentiels** (`bluetooth.service`, `ufw.service`).
- **Gestion des timers** (`fstrim.timer`, `paccache.timer`).
- **Vérification de disponibilité** des unités avant traitement.
- **Affichage d'état** (status) et messages colorés.
- **Compteurs de succès/échecs** pour services et timers.
- **Résumé final** clair avec totaux et indicateurs.
- **Mode simulation** pour tester sans modifier.
- **Sauvegarde automatique** des configurations.
- **Validation robuste** des services systemd.

## Prérequis
- Distribution basée sur Arch Linux (EndeavourOS, Arch, etc.).
- Privilèges administrateur: exécuter via `sudo`.
- `systemd` et l'outil `systemctl` disponibles.

## Installation
1. Copier le script dans un répertoire (par exemple dans ce dépôt ou `~/bin`).
2. Rendre le script exécutable:
```bash
chmod +x activation_services.sh
```

## Utilisation

### Exécution standard
```bash
sudo ./activation_services.sh
```

### Options disponibles

#### 1. Simulation sans modifier
```bash
sudo ./activation_services.sh --dry-run
```
*Idéal pour tester avant d'appliquer réellement les modifications*

#### 2. Mode détaillé
```bash
sudo ./activation_services.sh --verbose
```
*Affiche des logs détaillés pendant l'exécution*

#### 3. Sans backup
```bash
sudo ./activation_services.sh --no-backup
```
*Désactive la sauvegarde automatique des configurations*

#### 4. Aide
```bash
sudo ./activation_services.sh --help
```
*Affiche l'aide complète et les options disponibles*

### Combinaison d'options
```bash
# Simulation détaillée sans backup
sudo ./activation_services.sh --dry-run --verbose --no-backup

# Exécution complète avec logs détaillés
sudo ./activation_services.sh --verbose
```

## Unités gérées par défaut
- **Services**:
  - `bluetooth.service` - Gestion du Bluetooth
  - `ufw.service` - Pare-feu simplifié
- **Timers**:
  - `fstrim.timer` - Optimisation SSD (hebdomadaire)
  - `paccache.timer` - Nettoyage cache pacman (mensuel)

Ces listes sont définies dans le script et peuvent être adaptées en éditant les tableaux `services=(...)` et `timers=(...)`.

## Détails de fonctionnement
   - Affiche le statut (`systemctl status --no-pager`).
   - Active le timer (`systemctl enable`).
   - Incrémente les compteurs.
5. **Vérification finale**:
   - Pour les services: contrôle `systemctl is-active` (actif/inactif).
   - Pour les timers: contrôle `systemctl is-enabled` (activé/non activé).
6. **Résumé final**:
   - Affiche totaux des succès/échecs pour services et timers.
   - Indique si tout est OK (🎉) ou s'il reste des avertissements (⚠️).

## Personnalisation
- Modifier les listes:
```bash
services=("bluetooth.service" "ufw.service" "mon.service")

# Timers
timers=("fstrim.timer" "paccache.timer" "mon.timer")
```
- Vous pouvez commenter/supprimer des unités non pertinentes pour votre système.

## Dépannage
- **"Ce script doit être exécuté en tant que root"**: relancer avec `sudo`.
- **Service/Timer n'existe pas**: le script continue mais compte un échec; vérifiez que le paquet fournissant l’unité est installé.
- **Service inactif après exécution**: consulter `systemctl status <service>` et les journaux `journalctl -u <service>`.
- **Timer non activé**: vérifier `systemctl list-timers` et l’unité correspondante.

## Bonnes pratiques
- Vérifier que les unités voulues existent avant de les ajouter aux listes.
- Lancer à nouveau le script après modification de la configuration des unités.
- Versionnez vos adaptations si vous personnalisez largement les listes.

## Avertissements
- Le script modifie l'état des services/timers (start/enable). Assurez-vous de comprendre l’impact sur votre système.
- Testé sur des systèmes de type Arch/EndeavourOS utilisant systemd.
