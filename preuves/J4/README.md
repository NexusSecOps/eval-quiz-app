# J4 : frontend et backend sur Azure Container Apps

Date des preuves : 27 novembre 2026. Aucun secret dans ces fichiers : les valeurs sensibles sont des secrets Container Apps, seules leurs références apparaissent. Les adresses IP des logs sont masquées.

## Résultat

| Exigence | État | Preuve |
|---|---|---|
| Deux apps conteneurisées, images tirées d'ACR | Fait | `03-config-apps.txt` : images `acrquiznexusdev.azurecr.io/quiz-{frontend,backend}:ccfe726` |
| Tirage sans mot de passe de registre | Fait | Identité managée `id-quiz-acr`, rôle `AcrPull` limité à l'ACR, compte admin ACR désactivé |
| Ingress du frontend | Fait | Externe, HTTPS, port cible 80 |
| Backend non exposé | Fait | Ingress interne, port cible 3007 : `01-health.txt`, l'URL interne depuis Internet renvoie la page « Unavailable » de l'ingress |
| Révisions | Fait | `02-revisions.txt` : une révision active par app, 100 % du trafic, état `Running` |
| `GET /health` | Fait | `01-health.txt` : HTTP 200 et `{"status":"ok"}`, via le frontend puis Nginx puis le backend |
| Configuration réseau | Fait | `06-reseau.txt` : environnement sans VNet, FQDN, ingress externe/interne, ports, variables `BACKEND_HOST` et `BACKEND_PORT` |
| Images et droits dans ACR | Fait | `07-acr-images.txt` : tags et digests, rôle `AcrPull` seul, compte admin désactivé |
| Logs | Fait | `05-logs.txt` |
| Secrets | Fait | `04-env-backend.txt` : `DATABASE_URL`, `RESEND_API_KEY`, `ADMIN_PASSWORD`, `JWT_SECRET` en `secretref` |

La connexion PostgreSQL n'est pas exigée ici : `DATABASE_URL` est une valeur factice, `/health` ne touche pas la base (voir J5).

## Choix et écarts constatés

- **Autre abonnement que J3.** J3 a été fait sur l'abonnement d'Elyes (`francecentral`, `acrquiznexussecops`, preuves dans `preuves/J3`). J4 est déployé sur l'abonnement Azure for Students de Nicolas : la policy y interdit `francecentral`, et le nom de registre est déjà pris. Le registre `acrquiznexusdev` a donc été recréé en `germanywestcentral` avec les mêmes scripts, et les images y ont été poussées à nouveau.
- **Environnement en `switzerlandnorth`.** L'abonnement est limité à 1 environnement Container Apps. `germanywestcentral` a refusé la création (`MaxNumberOfEnvironmentsInSubExceeded`), `switzerlandnorth` l'a acceptée. Les images sont tirées depuis l'ACR d'une autre région, sans incident.
- **Mode d'environnement.** L'extension `containerapp` (preview 1.3.0b6) crée par défaut un environnement « Express », qui refuse `allow-insecure`. `deploy.sh` impose `--environment-mode WorkloadProfiles`.
- **Nginx.** L'en-tête `Host` envoyé au backend était `$host` (le nom du frontend) : l'ingress route selon cet en-tête, la requête aurait échoué. Il vaut maintenant `${BACKEND_HOST}`. Le frontend reçoit `BACKEND_HOST=quiz-backend` et `BACKEND_PORT=80` (port de l'ingress, qui redirige vers 3007).
- **`allow-insecure` sur le backend seulement.** Nginx l'appelle en HTTP à l'intérieur de l'environnement. Sans cela l'ingress répond par une redirection HTTPS que Nginx ne suit pas. Le frontend reste en HTTPS.
- **Réplicas** : min 1, max 2, 0,25 vCPU et 0,5 Gi par app, pour limiter le coût et éviter un démarrage à froid pendant la démonstration.

## Reproduire

```bash
./scripts/acr-create.sh && ./scripts/acr-push.sh   # images taguées avec le hash du commit
./scripts/deploy.sh                                 # secrets lus dans .env.azure (ignoré par Git)
curl -i https://<fqdn-du-frontend>/health
```

Nettoyage : `./scripts/destroy.sh`.
