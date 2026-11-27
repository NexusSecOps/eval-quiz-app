#!/usr/bin/env bash
# J4 : déploiement du frontend et du backend sur Azure Container Apps.
# Prérequis :
#   - "az login" fait, extension containerapp installée (az extension add --name containerapp) ;
#   - fournisseurs Microsoft.App, Microsoft.OperationalInsights et Microsoft.ContainerRegistry enregistrés ;
#   - registre créé (acr-create.sh) et images du commit courant poussées (acr-push.sh).
# Secrets : lus dans l'environnement ou dans le fichier .env.azure (ignoré par Git, jamais versionné).
# Variables attendues : RESEND_API_KEY, ADMIN_PASSWORD, JWT_SECRET, et DATABASE_URL (voir J5).
# Script idempotent : le relancer met à jour les applications existantes avec le tag courant.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/config.sh

# Fichier local de secrets, facultatif. "set -a" exporte tout ce qu'il définit.
if [ -f .env.azure ]; then
  set -a
  source .env.azure
  set +a
fi

# Les secrets ne sont jamais écrits dans ce script : on refuse de démarrer s'il en manque.
for VAR in RESEND_API_KEY ADMIN_PASSWORD JWT_SECRET; do
  if [ -z "${!VAR:-}" ]; then
    echo "Erreur : ${VAR} n'est pas défini (environnement ou fichier .env.azure)." >&2
    exit 1
  fi
done

# J4 n'exige pas la connexion à PostgreSQL : sans DATABASE_URL, on met une adresse factice.
# Le backend démarre quand même (le pool ne se connecte qu'à la première requête) et /health répond.
# Pour J5, définir DATABASE_URL avec l'URL Neon (sslmode=require) et relancer.
if [ -z "${DATABASE_URL:-}" ]; then
  echo "Attention : DATABASE_URL absent, valeur factice utilisée (suffisant pour /health, pas pour J5)."
  DATABASE_URL="postgres://factice:factice@invalide.invalid:5432/factice?sslmode=require"
fi
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
FROM_EMAIL="${FROM_EMAIL:-Quiz App <noreply@example.com>}"

LOGIN_SERVER="$(az acr show --name "${ACR_NAME}" --query loginServer --output tsv)"
ACR_ID="$(az acr show --name "${ACR_NAME}" --query id --output tsv)"
IDENTITY_NAME="id-quiz-acr"

# On vérifie que le tag existe dans le registre : sinon Container Apps échouerait au démarrage de la révision.
for REPO in "${FRONTEND_IMAGE}" "${BACKEND_IMAGE}"; do
  if ! az acr repository show-tags --name "${ACR_NAME}" --repository "${REPO}" --output tsv 2>/dev/null | grep -qx "${IMAGE_TAG}"; then
    echo "Erreur : ${REPO}:${IMAGE_TAG} absent de ${ACR_NAME}. Lancer ./scripts/acr-push.sh d'abord." >&2
    exit 1
  fi
done

# Environnement Container Apps : réseau et domaine partagés par les deux applications.
# Il crée aussi un espace Log Analytics pour les logs des conteneurs.
if az containerapp env show --name "${CONTAINERAPPS_ENV}" --resource-group "${RESOURCE_GROUP}" --output none 2>/dev/null; then
  echo "L'environnement ${CONTAINERAPPS_ENV} existe déjà."
else
  echo "Création de l'environnement ${CONTAINERAPPS_ENV} (quelques minutes)"
  az containerapp env create \
    --name "${CONTAINERAPPS_ENV}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --tags projet=quiz-app \
    --output none
fi

# Identité managée qui sert uniquement à tirer les images : droit AcrPull (lecture seule) sur ce registre.
# Pas de compte admin ACR ni de mot de passe de registre.
if ! az identity show --name "${IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --output none 2>/dev/null; then
  echo "Création de l'identité ${IDENTITY_NAME}"
  az identity create --name "${IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" --tags projet=quiz-app --output none
fi
IDENTITY_ID="$(az identity show --name "${IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query id --output tsv)"
IDENTITY_PRINCIPAL="$(az identity show --name "${IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query principalId --output tsv)"

if [ -z "$(az role assignment list --assignee "${IDENTITY_PRINCIPAL}" --scope "${ACR_ID}" --role AcrPull --query '[0].id' --output tsv)" ]; then
  echo "Attribution du rôle AcrPull à ${IDENTITY_NAME} sur ${ACR_NAME}"
  az role assignment create \
    --assignee-object-id "${IDENTITY_PRINCIPAL}" \
    --assignee-principal-type ServicePrincipal \
    --role AcrPull \
    --scope "${ACR_ID}" \
    --output none
  # La propagation du rôle prend un peu de temps : sans cette pause, le premier tirage d'image peut échouer.
  sleep 30
fi

# Backend : ingress interne, accessible uniquement depuis l'environnement (donc depuis le frontend).
# Les secrets sont stockés côté Azure et référencés par "secretref:", ils n'apparaissent pas dans la config des révisions.
# allow-insecure : Nginx appelle le backend en HTTP à l'intérieur de l'environnement, sans cela l'ingress répond par une redirection HTTPS.
BACKEND_SECRETS=(
  "database-url=${DATABASE_URL}"
  "resend-api-key=${RESEND_API_KEY}"
  "admin-password=${ADMIN_PASSWORD}"
  "jwt-secret=${JWT_SECRET}"
)
BACKEND_ENV=(
  "PORT=3007"
  "DATABASE_URL=secretref:database-url"
  "RESEND_API_KEY=secretref:resend-api-key"
  "ADMIN_PASSWORD=secretref:admin-password"
  "JWT_SECRET=secretref:jwt-secret"
  "ADMIN_USERNAME=${ADMIN_USERNAME}"
  "FROM_EMAIL=${FROM_EMAIL}"
)
BACKEND_IMAGE_REF="${LOGIN_SERVER}/${BACKEND_IMAGE}:${IMAGE_TAG}"

if az containerapp show --name "${BACKEND_APP}" --resource-group "${RESOURCE_GROUP}" --output none 2>/dev/null; then
  echo "Mise à jour de ${BACKEND_APP} avec ${IMAGE_TAG}"
  az containerapp secret set --name "${BACKEND_APP}" --resource-group "${RESOURCE_GROUP}" \
    --secrets "${BACKEND_SECRETS[@]}" --output none
  az containerapp update --name "${BACKEND_APP}" --resource-group "${RESOURCE_GROUP}" \
    --image "${BACKEND_IMAGE_REF}" --set-env-vars "${BACKEND_ENV[@]}" --output none
else
  echo "Création de ${BACKEND_APP}"
  az containerapp create \
    --name "${BACKEND_APP}" \
    --resource-group "${RESOURCE_GROUP}" \
    --environment "${CONTAINERAPPS_ENV}" \
    --image "${BACKEND_IMAGE_REF}" \
    --user-assigned "${IDENTITY_ID}" \
    --registry-server "${LOGIN_SERVER}" \
    --registry-identity "${IDENTITY_ID}" \
    --ingress internal --target-port 3007 --transport http --allow-insecure true \
    --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 2 \
    --secrets "${BACKEND_SECRETS[@]}" \
    --env-vars "${BACKEND_ENV[@]}" \
    --tags projet=quiz-app \
    --output none
fi

# Frontend : ingress externe, c'est le seul point d'entrée public.
# BACKEND_HOST est le nom de l'app backend (DNS interne de l'environnement).
# BACKEND_PORT vaut 80 : c'est le port de l'ingress, qui redirige vers le port 3007 du conteneur.
FRONTEND_ENV=(
  "BACKEND_HOST=${BACKEND_APP}"
  "BACKEND_PORT=80"
)
FRONTEND_IMAGE_REF="${LOGIN_SERVER}/${FRONTEND_IMAGE}:${IMAGE_TAG}"

if az containerapp show --name "${FRONTEND_APP}" --resource-group "${RESOURCE_GROUP}" --output none 2>/dev/null; then
  echo "Mise à jour de ${FRONTEND_APP} avec ${IMAGE_TAG}"
  az containerapp update --name "${FRONTEND_APP}" --resource-group "${RESOURCE_GROUP}" \
    --image "${FRONTEND_IMAGE_REF}" --set-env-vars "${FRONTEND_ENV[@]}" --output none
else
  echo "Création de ${FRONTEND_APP}"
  az containerapp create \
    --name "${FRONTEND_APP}" \
    --resource-group "${RESOURCE_GROUP}" \
    --environment "${CONTAINERAPPS_ENV}" \
    --image "${FRONTEND_IMAGE_REF}" \
    --user-assigned "${IDENTITY_ID}" \
    --registry-server "${LOGIN_SERVER}" \
    --registry-identity "${IDENTITY_ID}" \
    --ingress external --target-port 80 --transport http \
    --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 2 \
    --env-vars "${FRONTEND_ENV[@]}" \
    --tags projet=quiz-app \
    --output none
fi

# Résumé non sensible : adresse publique et état des révisions (preuves J4).
FRONTEND_URL="https://$(az containerapp show --name "${FRONTEND_APP}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn --output tsv)"
echo "Frontend : ${FRONTEND_URL}"
az containerapp revision list --name "${BACKEND_APP}" --resource-group "${RESOURCE_GROUP}" \
  --query "[].{app:'${BACKEND_APP}', revision:name, actif:properties.active, etat:properties.runningState, trafic:properties.trafficWeight}" --output table
az containerapp revision list --name "${FRONTEND_APP}" --resource-group "${RESOURCE_GROUP}" \
  --query "[].{app:'${FRONTEND_APP}', revision:name, actif:properties.active, etat:properties.runningState, trafic:properties.trafficWeight}" --output table
echo "Test : curl -i ${FRONTEND_URL}/health"
