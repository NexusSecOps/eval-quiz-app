# Répartition des jalons : Quiz App

> **Proposition, à valider avec Elyes.** Binôme : Nicolas et Elyes, un seul compte Azure Student partagé.
> Le relecteur est toujours l'autre personne : chacun doit pouvoir expliquer l'ensemble du projet à l'oral, sans IA.

## Tableau des jalons

| Jalon | Intitulé | Responsable | Relecteur | Preuves à produire | Dépend de | Statut |
|---|---|---|---|---|---|---|
| **J0** | Vérification préalable du compte Azure (quotas, région, droits ACR / Container Apps) **et possibilité de créer une identité de service pour GitHub Actions** (sinon le CD J6-B est bloqué) | Elyes | Nicolas | Sortie `az` non sensible, blocages signalés au formateur | n/a | Fait |
| **J1** | Conteneurisation locale : Dockerfiles, `docker-compose.yml`, `.env.example`, persistance du volume, schéma d'architecture locale. **Nginx : upstream backend configurable** (pas de `backend:3007` codé en dur, voir notes) | Nicolas | Elyes | Dockerfiles, Compose, logs expurgés, captures, explication du volume, schéma | n/a | Fait |
| **J2** | Sécurité des images : scan Trivy initial, corrections, second scan | Nicolas | Elyes | Rapport avant/après, commandes, vulnérabilités résiduelles justifiées | J1 | Fait |
| **J3** | Azure CLI et ACR : groupe de ressources, registre, push d'images taguées | Elyes | Nicolas | Scripts, sorties non sensibles, images et tags dans l'ACR | J0, J1 | Fait |
| **J4** | Frontend et backend sur Azure Container Apps (ingress, réseau, révisions, `/health`). Le backend exige `RESEND_API_KEY` au démarrage, même factice | Elyes | Nicolas | Config, logs et état des révisions, test `/health` (code HTTP + réponse) ou diagnostic | J3 | À faire |
| **J5** | PostgreSQL cloud (Neon) : TLS via l'URL de connexion, schéma `init.sql`, inscription et résultat, persistance | Elyes (suggéré : préparable sans images pendant l'attente de J1) | Nicolas | Démo, logs non sensibles, gestion des secrets | J4 | À faire |
| **J6-A** | CI sur Pull Request : build, Trivy bloquant sur CRITICAL, protection de `main`, approbation | Nicolas | Elyes | URL de PR, runs CI, rapports Trivy, règle de protection active | J1, J2 | À faire |
| **J6-B** | CD après fusion dans `main` : push ACR (tag = commit) et mise à jour des Container Apps | Elyes | Nicolas | Runs de déploiement, digests/tags, nouvelles révisions Azure | J3, J4, J6-A | À faire |

## Tâches communes

| Tâche | Responsable | Relecteur | Statut |
|---|---|---|---|
| Schéma d'architecture cloud | Elyes | Nicolas | À faire |
| Section « Usage de l'IA » dans le README | Nicolas | Elyes | À faire |
| `scripts/deploy.sh` et `scripts/destroy.sh` | Elyes | Nicolas | À faire |
| Diapositives de soutenance (6 max) | Les deux | Les deux | À faire |
| Dossier `preuves/J1` à `J6` (captures expurgées) | Chacun pour ses jalons | L'autre | À faire |

## À caler ensemble dès le début

| Sujet | À décider | Pourquoi |
|---|---|---|
| Noms des images et services, ports | Ex. `frontend`, `backend`. Si Nginx passe en non-root (J2), le port passe souvent de 80 à 8080 : l'ingress de J4 doit suivre. | J1/J2 définissent ce que J3/J4 déploient |
| Variables et secrets du backend | Liste partagée : `DATABASE_URL`, `RESEND_API_KEY` (**obligatoire même factice**), `FROM_EMAIL`, `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `JWT_SECRET` | Sans `RESEND_API_KEY`, le backend plante au lancement |
| Tags d'images | Hash court du commit Git (pas seulement `latest`) | Exigé par la CI/CD, partagé entre J3, J6-A et J6-B |
| Workflows GitHub Actions | Deux fichiers : `ci.yml` (déclenché sur PR) et `cd.yml` (déclenché sur push dans `main`) | J6-A et J6-B touchent le même dossier, évite les conflits |
| Compte Azure de base | Quel compte sert de base ; l'autre y accède avec un **rôle minimal limité au groupe de ressources** | Pas d'accès à tout l'abonnement, pas de partage d'identifiants |
| Config Nginx | Nicolas écrit le Dockerfile frontend en J1 ; Elyes doit le faire marcher sur Container Apps en J4. Prévoir la config dès J1 pour éviter une reprise. | Voir notes |

## Ce qui est faisable sans images (pendant que J1 avance)

Elyes peut avancer sans attendre : J0, création du groupe de ressources et de l'ACR, écriture de `deploy.sh` / `destroy.sh`, préparation de l'identité de service pour le CD, et création de la base Neon avec initialisation du schéma (J5). **Les images, donc J3 (push) et J4, dépendent de J1.**

## Notes

- **J1 doit être validé par le formateur avant tout déploiement cloud.**
- **Compte Azure unique :** décider qui crée les ressources et comment l'autre y accède (rôle minimal sur le groupe de ressources, pas de partage d'identifiants). Vérifier dès J0 si le compte de l'école autorise la création d'une identité de service (OIDC ou secret) pour GitHub Actions : sinon le CD (J6-B) est bloqué.
- **Backend (vérifié dans `backend/server.js`) :**
  - `new Resend(process.env.RESEND_API_KEY)` s'exécute au chargement du module : sans clé, le backend est censé planter avant `app.listen` (à confirmer par un test).
  - `GET /health` ne touche pas la base ; la base n'est contactée qu'à la première requête qui en a besoin. Un blocage de démarrage en J4 viendrait donc de Resend, pas de PostgreSQL.
  - Aucune option TLS dans le `pg.Pool` : le chiffrement vers Neon passe par l'URL de connexion (`sslmode=require`), à vérifier par un test en J5.
- **`nginx/nginx.conf` fourni :** l'upstream `backend:3007` est codé en dur pour Docker Compose. Sur Container Apps, le backend ne sera sans doute pas joignable ainsi (port d'ingress, résolution du nom, en-tête `Host` transmis par `proxy_set_header Host $host`). Rendre l'upstream configurable (variable d'environnement) en J1 et tester en J4.
- **Aucun secret dans le dépôt, les logs ou les captures** (mots de passe, `DATABASE_URL`, clé Resend, secrets CI).
- Les PR visent `main` **de notre fork**, jamais le dépôt du formateur.
- Le formateur peut demander à chacun une modification ou un diagnostic en direct, sans IA, sur n'importe quelle partie.
- Répartition modifiable : la mettre à jour ici au fil du projet.


elyes