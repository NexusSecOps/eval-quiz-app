#!/usr/bin/env bash
# J3 : création du groupe de ressources et du registre de conteneurs ACR.
# Prérequis : Azure CLI installé et connexion faite avec "az login".
# Script idempotent : le relancer ne recrée pas ce qui existe déjà.

# Options de sécurité du script :
# -e : arrêt dès qu'une commande échoue.
# -u : arrêt si une variable n'est pas définie, protège des fautes de frappe.
# -o pipefail : une erreur au milieu d'un pipe fait aussi échouer le script.
set -euo pipefail

# On se place à la racine du dépôt, quel que soit le dossier de lancement.
cd "$(dirname "$0")/.."
source scripts/config.sh

# Vérification de la connexion : on affiche le nom de l'abonnement, jamais son identifiant.
echo "Abonnement utilisé :"
az account show --query "name" --output tsv

# Création du groupe de ressources. S'il existe déjà avec la même région, Azure le laisse tel quel.
# Le tag projet=quiz-app permet de suivre les coûts dans le portail.
echo "Groupe de ressources : ${RESOURCE_GROUP}, région : ${LOCATION}"
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags projet=quiz-app \
  --output none

# On crée le registre seulement s'il n'existe pas encore dans notre groupe.
if az acr show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" --output none 2>/dev/null; then
  echo "Le registre ${ACR_NAME} existe déjà, rien à faire."
else
  # Le nom d'un ACR est global à tout Azure : on vérifie qu'il est libre avant de créer.
  if [ "$(az acr check-name --name "${ACR_NAME}" --query nameAvailable --output tsv)" != "true" ]; then
    echo "Erreur : le nom ${ACR_NAME} est déjà pris. Relancer avec ACR_NAME=unautrenom." >&2
    exit 1
  fi

  # SKU Basic : le moins cher, largement suffisant pour deux images.
  # admin-enabled false : pas de compte admin avec un mot de passe partagé.
  # En J4, les Container Apps tireront les images avec une identité managée.
  echo "Création du registre ${ACR_NAME}"
  az acr create \
    --name "${ACR_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku Basic \
    --admin-enabled false \
    --tags projet=quiz-app \
    --output none
fi

# Résumé non sensible du registre, utilisable directement comme preuve J3.
az acr show \
  --name "${ACR_NAME}" \
  --query "{nom:name, serveur:loginServer, sku:sku.name, region:location, admin:adminUserEnabled}" \
  --output table
