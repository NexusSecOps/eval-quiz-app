#!/usr/bin/env bash
# J3 : construction des images, tag avec le hash du commit, envoi dans ACR.
# Prérequis : Docker démarré, "az login" fait, registre créé par acr-create.sh.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/config.sh

# Traçabilité : avec des fichiers modifiés non commités, le tag ne correspondrait pas au contenu réel.
# On refuse donc de pousser dans ce cas.
if [ -n "$(git status --porcelain)" ]; then
  echo "Erreur : modifications non commitées. Commiter avant de pousser les images." >&2
  exit 1
fi

# Adresse du registre, de la forme nomduregistre.azurecr.io.
LOGIN_SERVER="$(az acr show --name "${ACR_NAME}" --query loginServer --output tsv)"

# Connexion de Docker au registre avec un jeton temporaire issu de la session az.
# Aucun mot de passe n'est saisi ni stocké dans le script.
az acr login --name "${ACR_NAME}"

# --platform linux/amd64 : Container Apps tourne sur du x86.
# Indispensable si l'image est construite sur un Mac ARM, sans effet sur un PC classique.
echo "Construction de ${FRONTEND_IMAGE}:${IMAGE_TAG}"
docker build --platform linux/amd64 \
  -t "${LOGIN_SERVER}/${FRONTEND_IMAGE}:${IMAGE_TAG}" \
  -f Dockerfile .

echo "Construction de ${BACKEND_IMAGE}:${IMAGE_TAG}"
docker build --platform linux/amd64 \
  -t "${LOGIN_SERVER}/${BACKEND_IMAGE}:${IMAGE_TAG}" \
  ./backend

# Envoi des deux images dans le registre.
docker push "${LOGIN_SERVER}/${FRONTEND_IMAGE}:${IMAGE_TAG}"
docker push "${LOGIN_SERVER}/${BACKEND_IMAGE}:${IMAGE_TAG}"

# Preuves J3 : dépôts présents et tags disponibles dans le registre.
echo "Dépôts présents dans ${ACR_NAME} :"
az acr repository list --name "${ACR_NAME}" --output table

echo "Tags de ${FRONTEND_IMAGE} :"
az acr repository show-tags --name "${ACR_NAME}" --repository "${FRONTEND_IMAGE}" --output table

echo "Tags de ${BACKEND_IMAGE} :"
az acr repository show-tags --name "${ACR_NAME}" --repository "${BACKEND_IMAGE}" --output table
