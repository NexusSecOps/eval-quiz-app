#!/usr/bin/env bash
# J6-B : mise à jour des deux Container Apps vers les images du commit courant.
# Appelé par le CD après acr-push.sh, utilisable aussi en local.
# Seule l'image change : secrets et configuration restent ceux posés par deploy.sh.
# Le CD n'a donc besoin d'aucun secret applicatif, ils restent dans Azure.
# Un changement d'image crée une nouvelle révision.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/config.sh

LOGIN_SERVER="$(az acr show --name "${ACR_NAME}" --query loginServer -o tsv)"

# On vérifie que les images de ce commit sont bien dans l'ACR avant de toucher aux applications.
for IMAGE in "${FRONTEND_IMAGE}" "${BACKEND_IMAGE}"; do
  if ! az acr repository show --name "${ACR_NAME}" --image "${IMAGE}:${IMAGE_TAG}" --output none 2>/dev/null; then
    echo "Erreur : ${IMAGE}:${IMAGE_TAG} absente de l'ACR. Lancer d'abord ./scripts/acr-push.sh" >&2
    exit 1
  fi
done

# Backend d'abord, puis frontend : même ordre qu'au premier déploiement.
echo "Mise à jour de ${BACKEND_APP} vers ${BACKEND_IMAGE}:${IMAGE_TAG}"
az containerapp update -g "${RESOURCE_GROUP}" -n "${BACKEND_APP}" \
  --image "${LOGIN_SERVER}/${BACKEND_IMAGE}:${IMAGE_TAG}" --output none

echo "Mise à jour de ${FRONTEND_APP} vers ${FRONTEND_IMAGE}:${IMAGE_TAG}"
az containerapp update -g "${RESOURCE_GROUP}" -n "${FRONTEND_APP}" \
  --image "${LOGIN_SERVER}/${FRONTEND_IMAGE}:${IMAGE_TAG}" --output none

# Preuves : les 3 dernières révisions de chaque application.
# La plus récente doit être active, avec l'image du commit déployé.
for APP in "${BACKEND_APP}" "${FRONTEND_APP}"; do
  echo "Révisions de ${APP} :"
  az containerapp revision list -g "${RESOURCE_GROUP}" -n "${APP}" \
    --query "[-3:].{revision:name, active:properties.active, image:properties.template.containers[0].image, etat:properties.runningState, creation:properties.createdTime}" \
    --output table
done
