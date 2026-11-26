# Répartition des jalons : Quiz App

> **Proposition, à valider avec Elyes.** Binôme : Nicolas et Elyes, un seul compte Azure Student partagé.
> Le relecteur est toujours l'autre personne : chacun doit pouvoir expliquer l'ensemble du projet à l'oral, sans IA.

## Tableau des jalons

| Jalon | Intitulé | Responsable | Relecteur | Preuves à produire | Dépend de | Statut |
|---|---|---|---|---|---|---|
| **J0** | Vérification préalable du compte Azure (quotas, région, droits ACR / Container Apps) | Elyes | Nicolas | Sortie `az` non sensible, blocages signalés au formateur | n/a | À faire |
| **J1** | Conteneurisation locale : Dockerfiles, `docker-compose.yml`, `.env.example`, persistance du volume, schéma d'architecture locale | Nicolas | Elyes | Dockerfiles, Compose, logs expurgés, captures, explication du volume, schéma | n/a | À faire |
| **J2** | Sécurité des images : scan Trivy initial, corrections, second scan | Nicolas | Elyes | Rapport avant/après, commandes, vulnérabilités résiduelles justifiées | J1 | À faire |
| **J3** | Azure CLI et ACR : groupe de ressources, registre, push d'images taguées | Elyes | Nicolas | Scripts, sorties non sensibles, images et tags dans l'ACR | J0, J1 | À faire |
| **J4** | Frontend et backend sur Azure Container Apps (ingress, réseau, révisions, `/health`) | Elyes | Nicolas | Config, logs et état des révisions, test `/health` (code HTTP + réponse) ou diagnostic | J3 | À faire |
| **J5** | PostgreSQL cloud (Neon) : TLS, schéma `init.sql`, inscription et résultat, persistance | À définir (les deux) | L'autre | Démo, logs non sensibles, gestion des secrets | J4 | À faire |
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

## Notes

- **J1 doit être validé par le formateur avant tout déploiement cloud.**
- **Compte Azure unique :** décider qui crée les ressources et comment l'autre y accède (invitation comme collaborateur sur l'abonnement plutôt que partage d'identifiants).
- **Aucun secret dans le dépôt, les logs ou les captures** (mots de passe, `DATABASE_URL`, clé Resend, secrets CI).
- Les PR visent `main` **de notre fork**, jamais le dépôt du formateur.
- Le formateur peut demander à chacun une modification ou un diagnostic en direct, sans IA, sur n'importe quelle partie.
- Répartition modifiable : la mettre à jour ici au fil du projet.
