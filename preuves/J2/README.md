# J2 : sécurité des images avec Trivy

Date des scans : 26 novembre 2026. Les résultats d'un scan évoluent chaque jour avec la base de vulnérabilités de Trivy : les rapports ci-dessous sont datés pour cette raison.

## Méthode

- Outil : Trivy 0.76.2, exécuté dans son image Docker officielle (aucune installation sur la machine).
- Commande : `scripts/trivy-scan.sh avant` puis `scripts/trivy-scan.sh apres`.
- Le script scanne toutes les images du `docker-compose.yml` (frontend, backend, base).
- Sévérités rapportées : HIGH et CRITICAL.
- Contrôle bloquant : le script sort en code 1 s'il trouve au moins une CRITICAL. C'est ce même principe qui sera utilisé dans la CI (J6-A).
- Les rapports « avant » ont été générés sur l'état de J1, avant toute correction.

## Résultats avant et après

| Image | Avant (HIGH, CRITICAL) | Après |
|---|---|---|
| Frontend | 70 : 67 HIGH, 3 CRITICAL | 0 |
| Backend | 10 : 10 HIGH | 0 |
| Base PostgreSQL | 27 : 26 HIGH, 1 CRITICAL | 0 |

Code de sortie du script : 1 avant (CRITICAL présentes), 0 après.

Rapports détaillés :

- Avant : [frontend](avant-eval-quiz-app-frontend.txt), [backend](avant-eval-quiz-app-backend.txt), [base](avant-postgres_16-alpine.txt).
- Après : [frontend](apres-quiz-frontend_local.txt), [backend](apres-quiz-backend_local.txt), [base](apres-quiz-db_local.txt).

Les images avant s'appellent `eval-quiz-app-*` et `postgres:16-alpine`, les images après `quiz-*:local`, car les noms d'images ont été fixés dans le Compose entre les deux scans. Le rapport « après » du backend est long : il liste chaque paquet Node avec zéro vulnérabilité.

## Corrections et justifications

### Frontend : 3 CRITICAL, 67 HIGH

- Cause : l'image `nginx:1.27-alpine` repose sur Alpine 3.21.3, une version qui n'est plus supportée (EOSL). Les failles touchent openssl, curl, expat, brotli et c-ares, et presque toutes ont un correctif dans une version plus récente d'Alpine.
- Correction : passage à `nginx:1.31-alpine` dans le `Dockerfile`, basée sur Alpine 3.24.
- Vérification : on a aussi testé `nginxinc/nginx-unprivileged:1.31-alpine`, qui s'exécute sans root, mais elle contenait 1 CRITICAL et 13 HIGH le jour du scan. Elle a donc été écartée.

### Backend : 10 HIGH

- Cause : les 10 failles sont toutes dans `/usr/local/lib/node_modules/npm/`, c'est-à-dire dans npm lui-même, livré avec l'image Node. Aucune ne concerne les 166 dépendances de l'application.
- Correction : npm et npx sont supprimés de l'image finale dans `backend/Dockerfile`, car ils ne servent qu'à installer les dépendances et pas à exécuter le serveur.
- Conséquence : on ne peut plus lancer `npm` dans le conteneur en production, ce qui est voulu.

### Base de données : pourquoi une image maison (`database/Dockerfile`)

L'image officielle `postgres:16-alpine` contient 27 vulnérabilités HIGH ou CRITICAL, voir [le rapport avant](avant-postgres_16-alpine.txt) :

- 1 HIGH dans libxml2, avec un correctif disponible dans les dépôts Alpine.
- 1 CRITICAL et 25 HIGH dans le binaire `usr/local/bin/gosu`, fourni avec l'image. Il est compilé avec Go 1.24.6, dont la bibliothèque standard est vulnérable.

La version `postgres:17-alpine` présente les mêmes failles : changer de tag ne règle donc rien. Nous ne contrôlons pas la compilation de gosu, d'où la création d'une image dérivée :

1. `apk upgrade libxml2` corrige la faille HIGH.
2. gosu est remplacé par `su-exec`, une alternative écrite en C et fournie par Alpine. Le script d'entrée de l'image appelle `gosu` uniquement pour abandonner les droits root : le lien `gosu` vers `su-exec` suffit, avec la même syntaxe.
3. La suppression du binaire et la création du lien sont dans deux instructions `RUN` distinctes. Dans un premier essai, le lien était créé dans la même couche : le fonctionnement était correct, mais Trivy continuait de signaler le binaire d'origine, resté dans une couche inférieure de l'image. Avec deux couches, la suppression est visible et le rapport est exact : voir [le rapport après](apres-quiz-db_local.txt).

Vérifications effectuées après ce changement :

- Initialisation sur un volume neuf : `init.sql` s'exécute, les 3 tables sont créées, PostgreSQL tourne sous l'utilisateur `postgres`.
- Remplacement de l'image sur le volume existant : les données déjà enregistrées sont conservées.
- Les healthchecks, `/health` via Nginx et la création d'un utilisateur via l'API fonctionnent toujours.

## Vulnérabilités résiduelles

Plus aucune HIGH ni CRITICAL le 26 novembre 2026. Il reste des vulnérabilités de sévérité moindre, non corrigées et non bloquantes :

| Image | MEDIUM | LOW | Paquets principaux |
|---|---|---|---|
| Frontend | 4 | 0 | libexpat, zlib |
| Backend | 9 | 4 | libcrypto3, libssl3, zlib, glob, minimatch |
| Base | 6 | 4 | libcrypto3, libssl3 |

Choix assumé : elles ne bloquent pas la livraison. Elles seront traitées en reconstruisant les images régulièrement, car la plupart disparaissent avec les mises à jour d'Alpine. Ces chiffres ont été obtenus en relançant Trivy avec `--severity LOW,MEDIUM`, le script ne les rapporte pas.

Deux limites à connaître :

- Un scan montre l'état à un instant donné : une nouvelle faille peut apparaître demain sans changement de notre part. La CI de J6-A refera ce contrôle à chaque Pull Request.
- Les tags utilisés (`nginx:1.31-alpine`, `postgres:16-alpine`, `node:22-alpine`) évoluent dans le temps. Épingler les images par empreinte (digest) renforcerait la reproductibilité mais compliquerait les mises à jour : décision à prendre plus tard.

## Reproduire

```bash
docker compose up -d --build
./scripts/trivy-scan.sh apres
```
