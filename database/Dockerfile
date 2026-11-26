# Image PostgreSQL durcie, basée sur l'image officielle Alpine.
# Pourquoi une image maison : l'image officielle postgres:16-alpine contient
# 26 vulnérabilités dont 1 CRITICAL (voir preuves/J2/avant-postgres_16-alpine.txt),
# et la version 17 a les mêmes. Changer de tag ne les corrige donc pas.
FROM postgres:16-alpine

# 1. Mise à jour de libxml2 : 1 HIGH, le correctif existe dans les dépôts Alpine.
# 2. Remplacement de gosu par su-exec : le script d'entrée de l'image appelle
#    "gosu" pour abandonner les droits root. Le gosu fourni est compilé avec
#    un Go vulnérable (1 CRITICAL et 25 HIGH, bibliothèque standard Go 1.24.6).
#    su-exec est une alternative en C, fournie par Alpine, avec la même syntaxe
#    pour cet usage : la commande gosu pointe simplement vers lui.
RUN apk upgrade --no-cache libxml2 \
 && apk add --no-cache su-exec \
 && rm -f /usr/local/bin/gosu

# Le lien est créé dans une couche séparée : la suppression ci-dessus crée alors
# une vraie marque de suppression dans l'image. Sans cela, le binaire d'origine
# reste présent dans une couche inférieure et Trivy continue de le signaler.
RUN ln -s /sbin/su-exec /usr/local/bin/gosu
