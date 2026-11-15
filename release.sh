#!/usr/bin/env bash
# Sortir une version : ./release.sh 1.3.2
set -euo pipefail
cd "$(dirname "$0")"

v="${1:-}"
[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage : ./release.sh 1.3.2"; exit 1; }
git rev-parse -q --verify "refs/tags/v$v" >/dev/null && { echo "le tag v$v existe déjà"; exit 1; }

first=$(grep -m1 '^## ' CHANGELOG.md || true)
[[ "$first" == "## $v"* ]] || { echo "CHANGELOG.md doit commencer par une section '## $v' (trouvé : '$first')"; exit 1; }

sed -i "s/^## Version: .*/## Version: $v/" XbiGold.toc
git add -A
git commit -m "XbiGold $v" || true
git tag -a "v$v" -m "XbiGold $v"
git push origin HEAD
git push origin "v$v"
echo "v$v envoyée : GitHub crée le zip et l'envoie sur CurseForge."
