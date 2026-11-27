# J5 : PostgreSQL cloud (Neon)

Date des preuves : 27 novembre 2026. Aucun secret dans ces fichiers : le nom d'hôte Neon, l'utilisateur et le mot de passe sont masqués.

## Résultat

| Exigence | État | Preuve |
|---|---|---|
| Connexion chiffrée à PostgreSQL distant | Fait | `01-tls.txt` : TLS 1.3 négocié côté client, et une connexion `sslmode=disable` est refusée par Neon |
| Initialisation du schéma | Fait | `02-schema.txt` : 3 tables créées avec `database/init.sql` par `scripts/db-init.sh`, relançable sans erreur |
| Inscription et enregistrement d'un résultat | Fait | `03-inscription.txt` : `POST /api/users` et `POST /api/results`, HTTP 201, via l'URL publique du frontend |
| Persistance | Fait | `04-persistance.txt` : mêmes données dans Neon avant et après redémarrage du backend, relues aussi via l'API admin |
| Gestion des secrets | Fait | `05-secrets-revisions.txt` : `DATABASE_URL` est un secret Container Apps, référencé par `secretref` |

## Gestion des secrets

- L'URL de connexion Neon vit dans `.env.azure`, ignoré par Git, et dans un secret Container Apps (`database-url`). Elle n'est ni dans le dépôt, ni dans les scripts, ni dans les logs.
- Le conteneur reçoit seulement une référence (`secretref:database-url`). La configuration de la révision ne contient pas la valeur.
- `db-init.sh` refuse de tourner si l'URL ne contient pas `sslmode=require`, et passe le mot de passe au conteneur `psql` par variable d'environnement, pas par la ligne de commande.

## Choix et points d'attention

- **TLS vérifié côté client.** `pg_stat_ssl` affiche `ssl = f` sur Neon même quand la connexion est chiffrée : le TLS se termine sur un proxy devant la base. La preuve valable est `\conninfo` (protocole négocié par libpq) et le refus d'une connexion non chiffrée. Le backend n'a aucune option TLS dans son `pg.Pool` : le chiffrement vient entièrement de `sslmode=require` dans l'URL, comme prévu dans le plan de répartition.
- **URL directe, sans pooler.** Le nom d'hôte ne contient pas `-pooler`.
- **Un secret modifié ne redémarre pas l'app.** Après `az containerapp secret set`, la révision existante garde l'ancienne valeur en mémoire (Azure le signale par un avertissement). `deploy.sh` force désormais une nouvelle révision à chaque mise à jour du backend (`--revision-suffix`). La nouvelle révision `quiz-backend--r1127104217` est celle qui a servi aux tests.
- **Lecture de `.env.azure`.** L'URL Neon contient `&channel_binding=require`. Avec `source`, le shell interprète `&` et la variable restait vide. `charger_secrets` (dans `scripts/config.sh`) lit le fichier ligne par ligne sans interprétation.
- **E-mails non démontrés.** La réponse de `POST /api/results` contient « email sent », mais le backend attrape l'erreur d'envoi et la journalise : le message est inconditionnel. La clé Resend est factice, l'e-mail n'est donc pas réellement envoyé. Cela n'empêche pas l'enregistrement du résultat, qui a lieu avant. Une vraie clé Resend et un domaine d'expédition vérifié seraient nécessaires pour le démontrer.
- **Données de test.** L'utilisateur `TestJ5` (`test-j5@example.com`) et son résultat sont encore dans la base, pour la démonstration. Ils se suppriment depuis la page d'administration.

## Reproduire

```bash
# DATABASE_URL (URL directe Neon avec sslmode=require) dans .env.azure
./scripts/db-init.sh
./scripts/deploy.sh
```
