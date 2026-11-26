# Etape 1 : build du frontend avec Vite.
FROM node:22-alpine AS build
WORKDIR /app

# package-lock.json existe à la racine, donc npm ci donne un build reproductible.
COPY package.json package-lock.json ./
RUN npm ci

# On copie le reste des sources, le .dockerignore filtre ce qui est inutile.
COPY . .
RUN npm run build

# Etape 2 : image finale, uniquement Nginx et les fichiers statiques.
# Node et les sources ne sont pas dans l'image finale, elle est donc plus petite et plus sûre.
# Version 1.31 : la 1.27 repose sur Alpine 3.21, qui n'est plus supporté
# (3 CRITICAL et 67 HIGH, voir preuves/J2/avant-eval-quiz-app-frontend.txt).
FROM nginx:1.31-alpine

# Les fichiers du dossier templates sont traités au démarrage par l'image Nginx :
# les variables d'environnement définies (BACKEND_HOST, BACKEND_PORT) y sont remplacées.
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
