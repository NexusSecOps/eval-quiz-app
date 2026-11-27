#!/usr/bin/env bash
# Configuration commune aux scripts Azure du projet Quiz App.
# Ce fichier est chargé par les autres scripts avec la commande "source".
# Il ne contient aucun secret, uniquement des noms de ressources.
# Chaque valeur peut être remplacée par une variable d'environnement,
# exemple : LOCATION=germanywestcentral ./scripts/acr-create.sh

# Groupe de ressources qui contient tout le projet.
# Le supprimer supprime aussi tout ce qu'il contient, voir destroy.sh.
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-quiz-app}"

# Région Azure.
# La policy "Allowed resource deployment regions" de l'abonnement Azure for Students utilisé
# (compte supdevinci) autorise : norwayeast, polandcentral, germanywestcentral, switzerlandnorth,
# denmarkeast. francecentral, utilisée en J3 sur l'abonnement d'Elyes, est refusée ici.
# germanywestcentral : ACR et Container Apps disponibles, région autorisée la plus proche.
# denmarkeast est exclue : Container Apps n'y est pas disponible.
LOCATION="${LOCATION:-germanywestcentral}"

# Nom du registre : unique dans tout Azure, 5 à 50 caractères, minuscules et chiffres uniquement.
# acrquiznexussecops (J3) est déjà pris par l'abonnement d'Elyes : d'où ce nom.
ACR_NAME="${ACR_NAME:-acrquiznexusdev}"

# Noms des dépôts d'images dans le registre, identiques aux noms d'images du Compose.
# En local le tag est "local", dans ACR le tag est le hash du commit.
# quiz-db n'est pas poussée : en cloud, la base est un PostgreSQL managé chez Neon, voir J5.
FRONTEND_IMAGE="${FRONTEND_IMAGE:-quiz-frontend}"
BACKEND_IMAGE="${BACKEND_IMAGE:-quiz-backend}"

# Tag : hash court du commit Git courant.
# On sait ainsi exactement quel code se trouve dans chaque image, la CI/CD utilisera la même règle.
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"

# J4 : environnement et applications Azure Container Apps.
# L'environnement est le réseau et le domaine partagés par les deux applications.
CONTAINERAPPS_ENV="${CONTAINERAPPS_ENV:-cae-quiz-app}"
# Région de l'environnement, distincte de celle de l'ACR. Constaté avec az : l'abonnement est limité à
# 1 environnement, et germanywestcentral refuse d'en créer un en mode WorkloadProfiles
# (MaxNumberOfEnvironmentsInSubExceeded), alors que switzerlandnorth, région autorisée, l'accepte.
# Les images sont tirées depuis l'ACR d'une autre région : cela fonctionne, avec un peu de latence au tirage.
ENV_LOCATION="${ENV_LOCATION:-switzerlandnorth}"
FRONTEND_APP="${FRONTEND_APP:-quiz-frontend}"
# Le nom de l'app backend sert de nom DNS interne : le frontend l'appelle via BACKEND_HOST.
BACKEND_APP="${BACKEND_APP:-quiz-backend}"

# Chargement du fichier de secrets local (.env.azure, ignoré par Git).
# Lecture ligne par ligne sans "source" : le shell n'interprète pas le contenu. Avec "source", une URL de
# connexion contenant "&" (ex. Neon : ...?sslmode=require&channel_binding=require) lancerait une commande
# en arrière-plan et la variable resterait vide. Les guillemets autour de la valeur sont facultatifs.
charger_secrets() {
  local fichier="${1:-.env.azure}" ligne cle valeur
  [ -f "${fichier}" ] || return 0
  while IFS= read -r ligne || [ -n "${ligne}" ]; do
    case "${ligne}" in ''|'#'*) continue ;; esac
    cle="${ligne%%=*}"
    valeur="${ligne#*=}"
    case "${valeur}" in
      \"*\") valeur="${valeur#\"}"; valeur="${valeur%\"}" ;;
      \'*\') valeur="${valeur#\'}"; valeur="${valeur%\'}" ;;
    esac
    export "${cle}=${valeur}"
  done < "${fichier}"
}
