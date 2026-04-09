# Installation Samba — Arch Linux / EndeavourOS (À vérifier s'il fonctionne)

Ce dossier contient un script d'installation et de configuration de **Samba** pour Arch Linux / EndeavourOS.

## 📌 Ce que fait le script

Le script `installation_samba_arch.sh` effectue automatiquement les étapes suivantes :

1. **Mise à jour** de la base de données pacman (`pacman -Sy`)
2. **Installation** du paquet **samba** (avec retry automatique)
3. **Création** d'un fichier `/etc/samba/smb.conf` avec un partage `[Share]` actif (si absent)
4. **Validation** de la configuration avec `testparm`
5. **Création** du répertoire de partage `~/Share` dans le dossier home de l'utilisateur
6. **Activation** et démarrage des services **smb** et **nmb**
7. **Configuration** du pare-feu (si **firewalld** ou **ufw** est présent)
8. **Création** d'un utilisateur Samba avec `smbpasswd` (interactif)

## ▶️ Utilisation

Ouvrez un terminal et exécutez :

```bash
sudo bash EndeavourOS/samba/installation_samba_arch.sh
```

### Options disponibles

| Option      | Description                                    |
|-------------|------------------------------------------------|
| `--help`    | Affiche l'aide détaillée et quitte             |
| `--dry-run` | Simule les opérations sans modifier le système |

```bash
# Voir l'aide
sudo bash EndeavourOS/samba/installation_samba_arch.sh --help

# Simuler l'installation sans rien modifier
sudo bash EndeavourOS/samba/installation_samba_arch.sh --dry-run
```

## 🔐 Gestion des utilisateurs Samba

Le script propose automatiquement de créer un utilisateur Samba à la fin de l'installation :

- Il demande un nom d'utilisateur Linux existant
- Si l'utilisateur n'existe pas, il propose de le créer
- Il définit le mot de passe système (via `passwd`)
- Il définit le mot de passe Samba (via `smbpasswd -a`)
- Il ajoute l'utilisateur au groupe `samba`

### 👇 Ajouter un utilisateur Samba manuellement

```bash
# Ajouter un utilisateur existant
sudo smbpasswd -a <utilisateur>

# Activer un utilisateur Samba
sudo smbpasswd -e <utilisateur>

# Désactiver un utilisateur Samba
sudo smbpasswd -d <utilisateur>

# Supprimer un utilisateur Samba
sudo smbpasswd -x <utilisateur>
```

## 📂 Partage configuré

Le script crée automatiquement un partage `[Share]` avec les règles suivantes :

| Paramètre       | Valeur                        |
|-----------------|-------------------------------|
| Chemin          | `~/Share`                     |
| Visible (browse)| ✅ Oui — par tout le monde     |
| Accès écriture  | 🔒 Membres du groupe `samba` uniquement |
| Authentification| 🔑 Mot de passe Samba requis   |
| Propriétaire    | `<utilisateur>:samba`         |
| Permissions     | `2770` (setgid)               |

### Ajouter un autre partage

1. Éditez `/etc/samba/smb.conf` et ajoutez une nouvelle section :
   ```ini
   [MonPartage]
      path = /home/utilisateur/MonPartage
      browsable = yes
      writable = yes
      guest ok = no
      valid users = @samba
      create mask = 0660
      directory mask = 2770
      force group = samba
   ```
2. Créez le dossier et ajustez les permissions :
   ```bash
   mkdir -p ~/MonPartage
   sudo chown $USER:samba ~/MonPartage
   sudo chmod 2770 ~/MonPartage
   ```
3. Redémarrez Samba :
   ```bash
   sudo systemctl restart smb nmb
   ```

## 🔍 Commandes utiles

```bash
# Vérifier la configuration Samba
testparm

# Vérifier le statut des services
systemctl status smb nmb

# Lister les utilisateurs Samba
sudo pdbedit -L

# Lister les partages actifs
smbclient -L localhost -U <utilisateur>
```

---

> **Note :** Ce script est conçu pour Arch Linux / EndeavourOS. Sur d'autres distributions, adaptez les commandes d'installation et de gestion de pare-feu.
