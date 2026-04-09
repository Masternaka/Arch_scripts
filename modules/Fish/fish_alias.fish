# =============================================================================
# ~/.config/fish/fish_alias.fish — Abbreviations Fish Shell
# Les abbreviations se développent quand on appuie sur Espace/Entrée
# =============================================================================

# --- Fichiers (eza + bat) ----------------------------------------------------
abbr -a ls   'eza --icons'
abbr -a ll   'eza -lh --icons --git'
abbr -a la   'eza -lah --icons --git'
abbr -a lt   'eza --tree --icons --level=2'
abbr -a l    'eza -1 --icons'
abbr -a lS   'eza -lah --icons --git --sort=size'
abbr -a lm   'eza -lah --icons --git --sort=modified'
abbr -a cat  'bat --paging=never'
abbr -a less 'bat'

# --- Navigation --------------------------------------------------------------
abbr -a ..    'cd ..'
abbr -a ...   'cd ../..'
abbr -a ....  'cd ../../..'
abbr -a mkdir 'mkdir -pv'
abbr -a md    'mkdir -pv'
abbr -a rd    'rmdir'
abbr -a cp    'cp -iv'
abbr -a mv    'mv -iv'
abbr -a rm    'rm -Iv'
abbr -a du    'du -sh'
abbr -a df    'df -h'

# --- Recherche ---------------------------------------------------------------
abbr -a rg    'rg --smart-case'
abbr -a ff    'fd --type f'
abbr -a fdir  'fd --type d'
abbr -a grep  'grep --color=auto'

# --- Git ---------------------------------------------------------------------
abbr -a g     'git'
abbr -a gs    'git status -sb'
abbr -a ga    'git add'
abbr -a gaa   'git add --all'
abbr -a gc    'git commit -m'
abbr -a gca   'git commit --amend --no-edit'
abbr -a gp    'git push'
abbr -a gpl   'git pull'
abbr -a gf    'git fetch --prune'
abbr -a gd    'git diff'
abbr -a gds   'git diff --staged'
abbr -a gl    'git log --oneline --graph --decorate --all'
abbr -a gco   'git checkout'
abbr -a gsw   'git switch'
abbr -a gb    'git branch -vv'
abbr -a gbd   'git branch -d'
abbr -a grb   'git rebase'
abbr -a gst   'git stash'
abbr -a gstp  'git stash pop'
abbr -a gcl   'git clone --depth 1'

# --- Pacman (base) -----------------------------------------------------------
abbr -a update   'sudo pacman -Syu'
abbr -a install  'sudo pacman -S'
abbr -a remove   'sudo pacman -Rns'
abbr -a search   'pacman -Ss'
abbr -a pkginfo  'pacman -Qi'
abbr -a pkgfiles 'pacman -Ql'

# --- AUR / yay ---------------------------------------------------------------
abbr -a yinstall 'yay -S'
abbr -a ysearch  'yay -Ss'
abbr -a yremove  'yay -Rns'
abbr -a yupdate  'yay -Syu'

# --- Mise à jour complète ----------------------------------------------------
abbr -a upall    'sudo pacman -Syu && yay -Sua && flatpak update'

# --- Nettoyage et maintenance ------------------------------------------------
abbr -a orphans  'pacman -Qtdq'
abbr -a clean    'sudo pacman -Rns (pacman -Qtdq)'
abbr -a cleanpkg 'sudo pacman -Sc'
abbr -a cleanall 'sudo pacman -Scc'
abbr -a pacdiff  'sudo pacdiff'

# --- Listes de paquets -------------------------------------------------------
abbr -a pkglist    'pacman -Qqe'
abbr -a pkgexpl    'pacman -Qqet'
abbr -a pkgaur     'pacman -Qqem'
abbr -a pkgforeign 'pacman -Qqm'

# --- Logs et historique pacman -----------------------------------------------
abbr -a lpacman  'bat /var/log/pacman.log'

# Historique des paquets
abbr -a rip "expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
abbr -a riplong "expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -3000 | nl"

# --- Mirrors -----------------------------------------------------------------
abbr -a mirrors      'sudo reflector --latest 30 --number 10 --sort score --save /etc/pacman.d/mirrorlist'
abbr -a mirrors-fast 'sudo reflector --latest 20 --number 5 --sort rate --save /etc/pacman.d/mirrorlist'

# --- Flatpak -----------------------------------------------------------------
abbr -a flatinstall 'flatpak install'
abbr -a flatsearch  'flatpak search'
abbr -a flatremove  'flatpak uninstall'
abbr -a flatupdate  'flatpak update'
abbr -a flatlist    'flatpak list'
abbr -a flatinfo    'flatpak info'
abbr -a flatrun     'flatpak run'
abbr -a flatclean   'flatpak uninstall --unused'
abbr -a flatrepair  'flatpak repair'

# --- Systemd -----------------------------------------------------------------
abbr -a reboot     'sudo systemctl reboot'
abbr -a poweroff   'sudo systemctl poweroff'
abbr -a suspend    'sudo systemctl suspend'

# Gestion des services
abbr -a sysstatus  'systemctl status'
abbr -a sysstart   'sudo systemctl start'
abbr -a sysstop    'sudo systemctl stop'
abbr -a sysrestart 'sudo systemctl restart'
abbr -a sysreload  'sudo systemctl reload'
abbr -a sysenable  'sudo systemctl enable'
abbr -a sysdisable 'sudo systemctl disable'
abbr -a sysmask    'sudo systemctl mask'
abbr -a sysunmask  'sudo systemctl unmask'
abbr -a sysdreload 'sudo systemctl daemon-reload'

# Gestions des polices
abbr -a update-font 'sudo fc-cache -fv'
abbr -a list-fonts 'fc-list'

# Listes et informations
abbr -a services   'systemctl list-units --type=service --state=running'
abbr -a sysfailed  'systemctl list-units --failed'
abbr -a systimers  'systemctl list-timers --all'
abbr -a sysunits   'systemctl list-unit-files'
abbr -a syscat     'systemctl cat'
abbr -a sysedit    'sudo systemctl edit'

# Systemd utilisateur (--user)
abbr -a sysustart   'systemctl --user start'
abbr -a sysustop    'systemctl --user stop'
abbr -a sysurestart 'systemctl --user restart'
abbr -a sysuenable  'systemctl --user enable'
abbr -a sysudisable 'systemctl --user disable'
abbr -a sysustatus  'systemctl --user status'
abbr -a sysulist    'systemctl --user list-units'

# Journalctl
abbr -a logs       'journalctl -xe'
abbr -a lsystem    'journalctl -f'
abbr -a jctl       'journalctl -p 3 -xb'
abbr -a jboot      'journalctl -b'
abbr -a jprev      'journalctl -b -1'
abbr -a jservice   'journalctl -u'

# --- Édition de fichiers de configuration ------------------------------------
abbr -a npacman     'sudo $EDITOR /etc/pacman.conf'
abbr -a nmakepkg    'sudo $EDITOR /etc/makepkg.conf'
abbr -a nmirrorlist 'sudo $EDITOR /etc/pacman.d/mirrorlist'
abbr -a nfstab      'sudo $EDITOR /etc/fstab'
abbr -a nhosts      'sudo $EDITOR /etc/hosts'
abbr -a nsamba      'sudo $EDITOR /etc/samba/smb.conf'
abbr -a nfish       '$EDITOR ~/.config/fish/config.fish'
abbr -a nalias      '$EDITOR ~/.config/fish/fish_alias.fish'

# --- Système et monitoring ---------------------------------------------------
abbr -a freemem  'free -mth'
abbr -a hw       'hwinfo --short'
abbr -a uptime   'uptime -p'
abbr -a update-font 'sudo fc-cache -fv'

# --- Permissions et sécurité -------------------------------------------------
abbr -a fix-permissions 'sudo chown -R $USER:$USER ~/.config ~/.local'
abbr -a fix-home        'sudo chown -R $USER:$USER $HOME'

# --- Réseau ------------------------------------------------------------------
abbr -a ipa       'ip -c addr'
abbr -a ipr       'ip -c route'
abbr -a ping      'ping -c 5'
abbr -a ports     'ss -tulnp'
abbr -a myip      'curl -s ifconfig.me; echo'
abbr -a myip6     'curl -s ifconfig.co; echo'
abbr -a dns       'resolvectl status'
abbr -a speedtest 'curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -'
