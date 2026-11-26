#!/usr/bin/env bash
# Scan Trivy des images du docker-compose.yml.
# Usage : scripts/trivy-scan.sh avant|apres
# Sortie : rapports lisibles dans preuves/J2/, code de sortie 1 si une CRITICAL est trouvée.
set -euo pipefail

PHASE="${1:?Usage : $0 avant|apres}"

# Version de Trivy épinglée : même résultat pour tout le monde.
TRIVY_IMAGE="aquasec/trivy:0.76.2"
OUT="${OUT_DIR:-preuves/J2}"
mkdir -p "$OUT"

# Trivy tourne dans un conteneur : rien à installer sur la machine.
# Le socket Docker lui permet de lire les images locales.
# label=disable : évite le refus de SELinux (Fedora), sans effet ailleurs.
# Le volume trivy-cache garde la base de vulnérabilités entre deux scans.
trivy() {
  docker run --rm --security-opt label=disable \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy-cache:/root/.cache/ \
    "$TRIVY_IMAGE" "$@"
}

status=0

# Images du Compose : celles que nous construisons et celle de la base.
for img in $(docker compose config --images); do
  # Nom de fichier sûr : on remplace / et : par _.
  fichier="$OUT/$PHASE-${img//[\/:]/_}.txt"

  echo "Scan de $img : $fichier"
  {
    echo "Date : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Trivy : $TRIVY_IMAGE"
    echo "Image : $img"
    echo
    trivy image --quiet --severity HIGH,CRITICAL "$img"
  } > "$fichier"

  # Contrôle bloquant : code de sortie 1 s'il existe au moins une CRITICAL.
  if ! trivy image --quiet --severity CRITICAL --exit-code 1 "$img" > /dev/null; then
    echo "CRITICAL trouvée dans $img"
    status=1
  fi
done

exit "$status"
