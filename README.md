# Arch_scripts


Exactement. La fonction discover_modules utilise find avec la recherche récursive :
bashfind "${MODULES_DIR}" -type f -name "*.sh" | sort
Donc peu importe la profondeur ou le nom des sous-dossiers, tout fichier .sh sera détecté et affiché automatiquement dans le menu. Par exemple :
modules/
├── arch/
├── debian/
├── serveur/
├── gaming/
├── travail/
│   ├── vpn.sh
│   └── outils_bureau.sh
└── perso/
    ├── musique.sh
    └── photos.sh
Tout ça fonctionnerait sans toucher à install.sh. La seule convention à respecter pour que le menu soit bien affiché, c'est les deux lignes d'en-tête dans chaque .sh :
bash# NAME: Mon Module
# DESC: description courte
Sans elles, le script utilise quand même le nom du fichier comme fallback, donc même ça c'est optionnel.