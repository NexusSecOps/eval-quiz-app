#!/usr/bin/env bash
# J5 : initialisation du schéma sur le PostgreSQL cloud (Neon) à partir de database/init.sql.
# Prérequis : Docker démarré, DATABASE_URL défini (environnement ou fichier .env.azure, ignoré par Git).
# L'URL doit contenir sslmode=require : c'est elle qui impose le chiffrement TLS vers Neon.
# psql est lancé dans un conteneur postgres:16-alpine, rien à installer sur la machine.
# Script idempotent : si le schéma existe déjà, il n'est pas recréé (init.sql n'est pas rejouable tel quel).
set -euo pipefail

cd "$(dirname "$0")/.."

# Même fichier de secrets que deploy.sh, lu sans "source" (voir charger_secrets dans config.sh).
source scripts/config.sh
charger_secrets

if [ -z "${DATABASE_URL:-}" ]; then
  echo "Erreur : DATABASE_URL n'est pas défini (environnement ou fichier .env.azure)." >&2
  exit 1
fi

# Sans TLS, les identifiants et les données circuleraient en clair : on refuse.
case "${DATABASE_URL}" in
  *sslmode=require*|*sslmode=verify-full*|*sslmode=verify-ca*) ;;
  *)
    echo "Erreur : DATABASE_URL doit contenir sslmode=require (connexion chiffrée)." >&2
    exit 1
    ;;
esac

# Le mot de passe passe par une variable d'environnement du conteneur, pas par la ligne de commande :
# il n'apparaît donc pas dans la liste des processus.
PSQL=(docker run --rm -i -e DATABASE_URL postgres:16-alpine sh -c)

# Preuve du chiffrement, côté client : \conninfo affiche le protocole TLS réellement négocié par libpq.
# pg_stat_ssl n'est pas utilisable ici : sur Neon, le TLS se termine sur un proxy devant la base,
# la vue indique donc ssl = f même quand la connexion du client est chiffrée.
# grep ne garde que la ligne TLS : la commande complète affiche aussi le nom d'hôte de la base.
echo "Connexion à la base, vérification du chiffrement :"
"${PSQL[@]}" 'psql "$DATABASE_URL" --no-psqlrc -v ON_ERROR_STOP=1 -c "\conninfo"' | grep "SSL connection"

# On ne crée le schéma que si la table users est absente.
EXISTE="$("${PSQL[@]}" 'psql "$DATABASE_URL" --no-psqlrc -tA -v ON_ERROR_STOP=1 -c "SELECT to_regclass('"'"'public.users'"'"') IS NOT NULL;"')"
if [ "${EXISTE}" = "t" ]; then
  echo "Le schéma existe déjà, rien à créer."
else
  echo "Création du schéma (database/init.sql)"
  # init.sql est envoyé sur l'entrée standard du conteneur.
  "${PSQL[@]}" 'psql "$DATABASE_URL" --no-psqlrc -v ON_ERROR_STOP=1 -f -' < database/init.sql
fi

# Preuve J5 : tables présentes et nombre de lignes, sans afficher de données personnelles.
echo "Tables du schéma :"
"${PSQL[@]}" 'psql "$DATABASE_URL" --no-psqlrc -v ON_ERROR_STOP=1 -c "\dt"'
