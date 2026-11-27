# J6-B : CD après fusion dans `main`

Date des preuves : 27 novembre 2026. Dépôt : https://github.com/NexusSecOps/eval-quiz-app. Aucun secret dans ces fichiers : les identifiants Azure (client, tenant, abonnement) sont des secrets du dépôt et n'apparaissent pas.

## Résultat

| Exigence | État | Preuve |
|---|---|---|
| Déclenchement après fusion dans `main` | Fait | Run https://github.com/NexusSecOps/eval-quiz-app/actions/runs/45984555456, événement `push` sur `main`, commit `b8ca8b3` |
| Publication dans l'ACR avec un tag traçable | Fait | `03-acr-et-revisions.txt` : tag `b8ca8b3` (hash du commit fusionné) dans `quiz-frontend` et `quiz-backend` |
| Mise à jour automatique des Container Apps | Fait | `02-run-cd.txt` : nouvelle révision `--0000001` de chaque app, image `b8ca8b3`, 100 % du trafic |
| Application saine après déploiement | Fait | Étape « Test de santé » du run, puis `/health` : HTTP 200 `{"status":"ok"}` |
| Authentification sans mot de passe, droits minimaux | Fait | OIDC : `04-identite-et-roles.txt` |
| Contrôle Trivy refait avant publication | Fait | Étape « Scan Trivy, bloquant sur CRITICAL » du run, rapports en artefact `rapports-trivy-cd` |
| Pas de déploiement depuis une PR | Fait | `cd.yml` n'a pour déclencheurs que `push` sur `main` et `workflow_dispatch`. L'identifiant fédéré n'accepte que le sujet `refs/heads/main` : une PR ne peut pas obtenir de jeton Azure. |

## Fonctionnement

`.github/workflows/cd.yml` : construction des images, Trivy bloquant sur CRITICAL, connexion Azure par OIDC, `scripts/acr-push.sh` (le même script qu'en local), `scripts/aca-update.sh`, puis test de `/health` pendant 2 minutes au plus.

`aca-update.sh` ne change que l'image : les secrets applicatifs, dont `DATABASE_URL` de J5, restent dans Azure et le CD n'en a pas besoin. Les données de J5 sont toujours dans Neon après le déploiement.

## Authentification : OIDC avec une identité managée

L'abonnement interdit la création d'une inscription d'application Entra ID (`allowedToCreateApps: false`). Le script `scripts/cd-identity-create.sh` utilise donc une **identité managée** (`id-quiz-github-cd`) avec un **identifiant fédéré**, qui n'a besoin que de droits sur le groupe de ressources.

- Rôles : `AcrPush` sur l'ACR seulement, `Contributor` sur `rg-quiz-app` seulement.
- Identité distincte de `id-quiz-acr` (qui ne fait que tirer les images) : une identité, un rôle.
- Secrets du dépôt : `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`. Ce sont des identifiants, pas des mots de passe, et ils sont masqués dans les logs.

## Incident au premier run : AADSTS700213

Le premier run a échoué à l'étape « Connexion à Azure » : `No matching federated identity record found`. Détail dans `01-echec-oidc-puis-correction.txt`.

- **Cause.** Le dépôt a le réglage GitHub `use_immutable_subject`, qui met les identifiants numériques du propriétaire et du dépôt dans le sujet du jeton : `repo:NexusSecOps@361464339/eval-quiz-app@1472868932:ref:refs/heads/main`. L'identifiant fédéré avait été créé avec l'ancien format, `repo:NexusSecOps/eval-quiz-app:ref:refs/heads/main`.
- **Correction.** Ajout d'un identifiant fédéré avec le sujet exact (`github-main-immutable`), puis relance du run. On n'a pas désactivé le réglage : il est plus sûr, car un dépôt renommé ou recréé sous le même nom ne peut pas usurper l'identité.
- **Script corrigé.** `cd-identity-create.sh` lit désormais le préfixe réel avec `gh api .../oidc/customization/sub` et retombe sur l'ancien format si le réglage n'est pas actif. Relancé sur l'abonnement actuel, il reconnaît l'identifiant existant et ne crée rien.
- **Reste dans Azure.** L'ancien identifiant `github-main` n'est plus utilisé : il ne correspond à aucun jeton émis par ce dépôt. Il peut être supprimé.

## Pour rejouer

```bash
./scripts/acr-create.sh && ./scripts/acr-push.sh && ./scripts/deploy.sh   # une fois
./scripts/cd-identity-create.sh                                           # identité OIDC
# puis les 3 secrets GitHub (gh secret set AZURE_CLIENT_ID ...) : voir history-commands/branch-feature-j6b-cd
```

## À compléter à la main

- [ ] Capture de la page du run : https://github.com/NexusSecOps/eval-quiz-app/actions/runs/45984555456 (les étapes en succès).
- [ ] Capture de l'onglet « Summary » du run (commit, révisions, images).
