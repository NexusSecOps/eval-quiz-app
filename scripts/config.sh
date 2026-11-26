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
# La policy "Allowed resource deployment regions" de l'abonnement Azure for Students autorise :
# denmarkeast, francecentral, belgiumcentral, spaincentral, germanywestcentral.
# denmarkeast est exclue : Container Apps n'y est pas disponible, J4 serait bloqué.
# francecentral : ACR, Container Apps et profil Consumption disponibles, région la plus proche.
# Repli possible : germanywestcentral, mêmes services disponibles.
LOCATION="${LOCATION:-francecentral}"

# Nom du registre : unique dans tout Azure, 5 à 50 caractères, minuscules et chiffres uniquement.
# Le suffixe évite une collision avec un autre groupe de la promo.
ACR_NAME="${ACR_NAME:-acrquiznexussecops}"

# Noms des dépôts d'images dans le registre, alignés sur les services du Compose.
FRONTEND_IMAGE="${FRONTEND_IMAGE:-frontend}"
BACKEND_IMAGE="${BACKEND_IMAGE:-backend}"

# Tag : hash court du commit Git courant.
# On sait ainsi exactement quel code se trouve dans chaque image, la CI/CD utilisera la même règle.
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"
