#!/usr/bin/env bash

# NAME: mod_paru.sh
# DESC: Modifie le fichier de configuration de paru pour activer BottomUp.
# =============================================================================

set -euo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/paru"
CONF_FILE="$CONF_DIR/paru.conf"

mkdir -p "$CONF_DIR"

# Active BottomUp dans la section [options].
# - Si le fichier n'existe pas, on le crée avec [options] + BottomUp.
# - Si BottomUp est commenté, on le dé-commente.
# - Si BottomUp est absent, on l'ajoute dans [options] (ou on crée la section).
if [[ ! -f "$CONF_FILE" ]]; then
  cat >"$CONF_FILE" <<'EOF'
[options]
BottomUp
EOF
  echo "Créé: $CONF_FILE (BottomUp activé)"
  exit 0
fi

cp -a "$CONF_FILE" "$CONF_FILE.bak"

python3 - "$CONF_FILE" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="surrogateescape")
lines = text.splitlines(True)  # keepends

def is_section_header(s: str) -> bool:
    return bool(re.match(r"^\s*\[[^\]]+\]\s*$", s))

def section_name(s: str) -> str | None:
    m = re.match(r"^\s*\[([^\]]+)\]\s*$", s)
    return m.group(1).strip() if m else None

def normalize_option_line(s: str) -> str:
    # Convertit '# BottomUp' ou ';BottomUp' ou 'BottomUp = true' vers 'BottomUp\n' si présent
    # Sans toucher aux commentaires non liés.
    return s

out = []
in_options = False
seen_options_section = False
bottomup_set = False

for i, line in enumerate(lines):
    if is_section_header(line.rstrip("\n")):
        # Si on quitte [options] sans avoir mis BottomUp, on l'ajoute juste avant la nouvelle section
        if in_options and not bottomup_set:
            out.append("BottomUp\n")
            bottomup_set = True
        in_options = (section_name(line.rstrip("\n")) or "").lower() == "options"
        if in_options:
            seen_options_section = True
        out.append(line)
        continue

    if in_options:
        # Cas déjà présent (actif)
        if re.match(r"^\s*BottomUp\s*(?:[=].*)?$", line):
            out.append("BottomUp\n" if line.endswith("\n") else "BottomUp")
            bottomup_set = True
            continue
        # Cas commenté
        if re.match(r"^\s*[#;]\s*BottomUp\s*(?:[=].*)?$", line):
            out.append("BottomUp\n" if line.endswith("\n") else "BottomUp")
            bottomup_set = True
            continue

    out.append(line)

if not seen_options_section:
    # Ajoute une section [options] à la fin
    if out and not out[-1].endswith("\n"):
        out[-1] = out[-1] + "\n"
    if out and out[-1].strip() != "":
        out.append("\n")
    out.append("[options]\n")
    out.append("BottomUp\n")
else:
    # On était dans [options] jusqu'à la fin du fichier
    if in_options and not bottomup_set:
        out.append("BottomUp\n")
        bottomup_set = True

new_text = "".join(out)
path.write_text(new_text, encoding="utf-8", errors="surrogateescape")
PY

echo "OK: BottomUp activé dans $CONF_FILE (backup: $CONF_FILE.bak)"
