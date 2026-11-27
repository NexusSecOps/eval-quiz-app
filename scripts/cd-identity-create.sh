#!/usr/bin/env bash
# J6-B : identité utilisée par GitHub Actions pour déployer sur Azure, sans aucun mot de passe.
# Méthode : identité managée avec un identifiant fédéré OIDC.
# GitHub présente un jeton signé, Azure l'accepte seulement s'il vient de notre dépôt et de la branche main.
# Avantage sur un abonnement étudiant : pas d'inscription d'application dans Entra ID,
# souvent interdite, il suffit de droits sur le groupe de ressources.
# Prérequis : "az login" sur l'abonnement qui héberge le projet, acr-create.sh et deploy.sh déjà lancés.
# Script idempotent : le relancer ne recrée pas ce qui existe déjà.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/config.sh

# Dépôt GitHub autorisé à se connecter à Azure, au format organisation/depot.
GITHUB_REPO="${GITHUB_REPO:-NexusSecOps/eval-quiz-app}"
# Identité du CD, distincte de id-quiz-acr qui tire les images : une identité, un rôle.
CD_IDENTITY="${CD_IDENTITY:-id-quiz-github-cd}"

# 1. Identité du CD.
if ! az identity show -g "${RESOURCE_GROUP}" -n "${CD_IDENTITY}" --output none 2>/dev/null; then
  echo "Création de l'identité ${CD_IDENTITY}"
  az identity create \
    --name "${CD_IDENTITY}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --tags projet=quiz-app \
    --output none
fi

# 2. Identifiant fédéré : la règle de confiance entre GitHub et Azure.
# issuer : l'émetteur des jetons, le service OIDC de GitHub Actions.
# subject : seul un workflow lancé sur la branche main de notre dépôt est accepté.
# audience : valeur standard attendue par Azure pour cet échange de jeton.
#
# Le sujet doit être EXACTEMENT celui que GitHub présente, sinon Azure répond AADSTS700213
# ("No matching federated identity record"). Depuis 2026, les dépôts récents ont le réglage
# "use_immutable_subject" : le sujet contient les identifiants numériques du propriétaire et du dépôt,
# repo:NexusSecOps@<id>/eval-quiz-app@<id>:ref:refs/heads/main, et non plus seulement les noms.
# On lit donc le préfixe réellement configuré sur le dépôt, avec la commande gh (déjà requise pour les secrets).
# Sans ce réglage, l'API ne renvoie pas de préfixe et on retombe sur l'ancien format, avec les noms seuls.
PREFIXE="$(gh api "repos/${GITHUB_REPO}/actions/oidc/customization/sub" --jq '.sub_claim_prefix // empty' 2>/dev/null || true)"
if [ -n "${PREFIXE}" ]; then
  NOM_FEDERE="github-main-immutable"
else
  PREFIXE="repo:${GITHUB_REPO}"
  NOM_FEDERE="github-main"
fi
SUBJECT="${PREFIXE}:ref:refs/heads/main"
if [ "$(az identity federated-credential list -g "${RESOURCE_GROUP}" --identity-name "${CD_IDENTITY}" --query "length([?subject=='${SUBJECT}'])" -o tsv)" = "0" ]; then
  echo "Création de l'identifiant fédéré pour ${SUBJECT}"
  az identity federated-credential create \
    --name "${NOM_FEDERE}" \
    --identity-name "${CD_IDENTITY}" \
    --resource-group "${RESOURCE_GROUP}" \
    --issuer "https://token.actions.githubusercontent.com" \
    --subject "${SUBJECT}" \
    --audiences "api://AzureADTokenExchange" \
    --output none
fi

PRINCIPAL_ID="$(az identity show -g "${RESOURCE_GROUP}" -n "${CD_IDENTITY}" --query principalId -o tsv)"
ACR_ID="$(az acr show -n "${ACR_NAME}" --query id -o tsv)"
RG_ID="$(az group show -n "${RESOURCE_GROUP}" --query id -o tsv)"

# Attribue un rôle s'il n'existe pas déjà. Paramètres : nom du rôle, puis portée.
# NOUVEAU_ROLE passe à 0 si au moins un rôle vient d'être créé : il faudra attendre sa propagation.
NOUVEAU_ROLE=1
attribuer_role() {
  if [ "$(az role assignment list --assignee "${PRINCIPAL_ID}" --scope "$2" --role "$1" --query "length(@)" -o tsv)" = "0" ]; then
    echo "Attribution du rôle $1 à ${CD_IDENTITY}"
    az role assignment create \
      --assignee-object-id "${PRINCIPAL_ID}" \
      --assignee-principal-type ServicePrincipal \
      --role "$1" \
      --scope "$2" \
      --output none
    NOUVEAU_ROLE=0
  fi
}

# 3. Rôles, au plus juste :
# AcrPush sur l'ACR seulement : pousser les nouvelles images.
# Contributor sur rg-quiz-app seulement : mettre à jour les Container Apps.
# Aucun droit sur le reste de l'abonnement.
attribuer_role AcrPush "${ACR_ID}"
attribuer_role Contributor "${RG_ID}"

if [ "${NOUVEAU_ROLE}" = "0" ]; then
  echo "Attente de 60 secondes pour la propagation des rôles"
  sleep 60
fi

# Résumé non sensible : la portée est réduite à son dernier élément,
# le chemin complet contiendrait l'identifiant d'abonnement.
echo "Identifiant fédéré :"
az identity federated-credential list -g "${RESOURCE_GROUP}" --identity-name "${CD_IDENTITY}" \
  --query "[].{nom:name, sujet:subject}" -o table
echo "Rôles de ${CD_IDENTITY} :"
az role assignment list --assignee "${PRINCIPAL_ID}" --all \
  --query "[].[roleDefinitionName, scope]" -o tsv | sed -E 's#^([^\t]+)\t.*/#\1 : #'

# Étape suivante : enregistrer les 3 identifiants dans les secrets GitHub, sans les afficher.
echo "Étape suivante : enregistrer les secrets GitHub avec les commandes gh secret set du plan J6-B."
