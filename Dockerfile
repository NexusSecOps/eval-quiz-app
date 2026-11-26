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
FROM nginx:1.27-alpine

# Les fichiers du dossier templates sont traités au démarrage par l'image Nginx :
# les variables d'environnement définies (BACKEND_HOST, BACKEND_PORT) y sont remplacées.
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
