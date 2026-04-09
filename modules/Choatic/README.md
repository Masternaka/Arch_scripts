# Installation du dépôt Chaotic-AUR (FONCTIONNE)

Ce script Bash configure votre système Arch/EndeavourOS pour utiliser le dépôt Chaotic-AUR.

## Ce que fait le script

1. Vérifie que vous n'êtes pas root (exécution en tant qu'utilisateur normal requise).
2. Vérifie que `pacman` est disponible et que la connexion Internet fonctionne.
3. Met à jour le système (`sudo pacman -Syu`).
4. Installe les dépendances nécessaires : `base-devel`, `curl`, `wget`.
5. Ajoute et signe la clé GPG principale de Chaotic-AUR.
6. Télécharge et installe `chaotic-keyring` et `chaotic-mirrorlist`.
7. Ajoute le dépôt Chaotic-AUR dans `/etc/pacman.conf` (avec `Include = /etc/pacman.d/chaotic-mirrorlist`).
8. Met à jour la base de données de `pacman`.
9. Vérifie que le dépôt Chaotic-AUR est accessible et affiche quelques informations.

## Comment l'utiliser

1. Ouvrez un terminal dans ce dossier : `cd ~/Desktop/Github/EndeavourOS/Choatic`
2. Rendez le script exécutable (si nécessaire) :

```bash
chmod +x install_Chaotic.sh
```

3. Lancez le script (en tant qu'utilisateur normal, pas root) :

```bash
./install_Chaotic.sh
```

4. Répondez `y` lorsque le script demande confirmation.

## Notes

- Le script crée une sauvegarde de `/etc/pacman.conf` avant de modifier le fichier.
- Si le dépôt Chaotic-AUR existe déjà, l’ancien bloc sera supprimé et remplacé.
- En cas de problème, vérifiez la sortie du script pour identifier l’étape qui échoue.
