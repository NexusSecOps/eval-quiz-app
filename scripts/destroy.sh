#!/usr/bin/env bash
# Nettoyage : suppression du groupe de ressources et de tout son contenu.
# Cela inclut l'ACR et ses images, puis les Container Apps à partir de J4.
# Opération irréversible, d'où la confirmation demandée.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/config.sh

# Rien à faire si le groupe n'existe pas.
if [ "$(az group exists --name "${RESOURCE_GROUP}")" != "true" ]; then
  echo "Le groupe ${RESOURCE_GROUP} n'existe pas, rien à supprimer."
  exit 0
fi

# Confirmation : il faut retaper le nom exact du groupe, pour éviter une suppression par erreur.
read -r -p "Taper ${RESOURCE_GROUP} pour confirmer la suppression : " CONFIRMATION
if [ "${CONFIRMATION}" != "${RESOURCE_GROUP}" ]; then
  echo "Annulé."
  exit 1
fi

# --yes : pas de seconde question d'Azure, la confirmation a déjà été faite.
# --no-wait : rend la main tout de suite, la suppression continue côté Azure.
az group delete --name "${RESOURCE_GROUP}" --yes --no-wait
echo "Suppression lancée. Vérifier avec : az group exists --name ${RESOURCE_GROUP}"
