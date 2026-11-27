# Image de base : Node 22 LTS sur Alpine, légère donc moins de vulnérabilités à corriger.
FROM node:22-alpine

# Mode production : npm n'installe pas les outils de développement.
ENV NODE_ENV=production

WORKDIR /app

# On copie d'abord package.json seul : tant qu'il ne change pas,
# la couche des dépendances reste en cache et le build est rapide.
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# npm ne sert qu'à installer les dépendances. On le retire de l'image finale :
# il embarque ses propres paquets, source de 10 vulnérabilités HIGH
# (voir preuves/J2/avant-eval-quiz-app-backend.txt), et réduit la surface d'attaque.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Le code vient après les dépendances, pour la même raison de cache.
COPY server.js ./

# On n'exécute pas l'application en root.
USER node

# Documentation du port d'écoute. Il ne publie rien vers l'hôte.
EXPOSE 3007

CMD ["node", "server.js"]
