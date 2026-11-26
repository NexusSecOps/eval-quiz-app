# Image de base : Node 22 LTS sur Alpine, légère donc moins de vulnérabilités à corriger.
FROM node:22-alpine

# Mode production : npm n'installe pas les outils de développement.
ENV NODE_ENV=production

WORKDIR /app

# On copie d'abord package.json seul : tant qu'il ne change pas,
# la couche des dépendances reste en cache et le build est rapide.
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# Le code vient après les dépendances, pour la même raison de cache.
COPY server.js ./

# On n'exécute pas l'application en root.
USER node

# Documentation du port d'écoute. Il ne publie rien vers l'hôte.
EXPOSE 3007

CMD ["node", "server.js"]
