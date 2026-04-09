# Scripts disponibles pour l'activation de ZRAM avec configuration adaptative et sécurité renforcée (FONCTIONNE)

# Utilisation:
# 1. Rendez le script exécutable: chmod +x activation_zram.sh
# 2. Exécutez-le avec sudo: sudo ./activation_zram.sh

---

## Scripts disponibles

### 📁 **activation_zram.sh**
**Version améliorée avec sécurité renforcée et configuration automatique adaptative**

**Nouveautés v2.1:**
- 🔒 **Sécurité renforcée**: Validation des entrées, opérations atomiques, permissions sécurisées
- 🧠 **Configuration adaptative**: Détection automatique de la taille et priorité optimales selon la RAM
- ⚡ **Robustesse accrue**: Vérification espace disque, gestion erreurs améliorée, logging sécurisé
- 🎯 **Flexibilité**: Options avancées en ligne de commande

### 📁 **activation_zram.sh**
**Version complète avec options avancées**
Script robuste avec logging complet, tests de performance et gestion d'erreurs avancée.

### 📁 **activation_zram_test.sh**
**Version simplifiée pour installation rapide**
Script minimaliste pour une installation rapide et basique.

---

## Installation recommandée

### Installation avec configuration automatique
```bash
sudo ./activation_zram.sh install
```

### Installation avec paramètres personnalisés
```bash
sudo ./activation_zram.sh install --size '4G' --algorithm lz4
```

### Installation sans configuration automatique
```bash
sudo ./activation_zram.sh install --no-auto-config --size '8G'
```

---

## Options disponibles

### Commandes
- `install` (défaut) - Installe et configure ZRAM
- `uninstall` - Désactive ZRAM et supprime la configuration
- `uninstall --purge` - Désinstalle complètement (paquet inclus)
- `verify` - Vérifie le statut de ZRAM
- `test` - Teste les performances de ZRAM
- `rollback` - Annule l'installation

### Options
- `--size SIZE` - Taille ZRAM (ex: '4G', 'ram / 2')
- `--algorithm ALGO` - Algorithme de compression (zstd, lz4, lzo-rle, lzo)
- `--priority PRIO` - Priorité du swap (0-32767)
- `--test` - Effectue des tests de performance après installation
- `--verbose, -v` - Mode verbeux
- `--no-auto-config` - Désactive la configuration automatique adaptative
- `--help, -h` - Affiche l'aide

---

## Exemples d'utilisation

```bash
# Installation standard avec configuration automatique
sudo ./activation_zram.sh

# Installation avec algorithme lz4 et taille fixe de 4GB
sudo ./activation_zram.sh install --algorithm lz4 --size '4G'

# Installation avec priorité élevée et tests de performance
sudo ./activation_zram.sh install --priority 200 --test --verbose

# Vérification du statut ZRAM
sudo ./activation_zram.sh verify

# Désinstallation complète
sudo ./activation_zram.sh uninstall --purge
```

---

## Configuration automatique adaptative

Le script ajuste automatiquement les paramètres selon votre système :

| RAM disponible | Taille ZRAM | Priorité | Recommandation |
|---------------|-------------|----------|----------------|
| ≤ 2GB | ram/4 | 50 | Configuration conservatrice |
| 3-4GB | ram/2 | 100 | Configuration équilibrée |
| 5-8GB | ram/2 | 150 | Configuration standard |
| > 8GB | min(ram/2, 8G) | 200 | Configuration optimisée |

---

## Algorithmes de compression

- **zstd** (recommandé) - Excellent ratio compression/vitesse
- **lz4** - Très rapide, bon ratio
- **lzo-rle** - Rapide, léger en CPU
- **lzo** - Compatible, plus ancien