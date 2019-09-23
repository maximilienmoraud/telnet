#!/bin/bash

NomSiteWeb=Default
randompw=Default
randompwdb=Default
databaseIP=Default

randompwdb=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)

echo "Please enter the name of the web site you want to create do not use an existing name this name will be used both for the service and the subdomain name"
read NomSiteWeb


if [ -d "/$NomSiteWeb" ];then
echo "$NomSiteWeb is already existing!";
exit 1
fi

mkdir /$NomSiteWeb

touch /$NomSiteWeb/docker-compose.yml

echo 'version: "3.3"

services:


  nginx:
    container_name: nginx_'$NomSiteWeb'
    image: wodby/nginx:latest
    volumes:
      - ./www:/var/www/html
    depends_on:
      - php
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.'$NomSiteWeb'.rule=Host(`'$NomSiteWeb'.moraud.xyz`)"
      - "traefik.http.routers.'$NomSiteWeb'.entrypoints=websecure"
      - "traefik.http.routers.'$NomSiteWeb'.tls.certresolver=myhttpchallenge"
      - traefik.docker.network=web

      - "traefik.http.routers.'$NomSiteWeb'-http.rule=Host(`'$NomSiteWeb'.moraud.xyz`)"
      - "traefik.http.routers.'$NomSiteWeb'-http.entrypoints=web"

      - traefik.http.routers.'$NomSiteWeb'-http.middlewares='$NomSiteWeb'-redirect
      - traefik.http.middlewares.'$NomSiteWeb'-redirect.redirectscheme.scheme=https
      - traefik.http.middlewares.'$NomSiteWeb'-redirect.redirectscheme.permanent=true
    environment:
      NGINX_BACKEND_HOST: php
      NGINX_VHOST_PRESET: php
      NGINX_STATIC_OPEN_FILE_CACHE: "off"
    networks:
      - internal
      - web

  db:
    image: mariadb:latest
    container_name: db_'$NomSiteWeb'
    volumes:
      - ./database:/var/lib/mysql:rw
    depends_on:
      - nginx
    environment:
      - MYSQL_ROOT_PASSWORD='$randompwdb'
    labels:
      - "traefik.enable=true"
      - traefik.docker.network='$NomSiteWeb'
    container_name: db_'$NomSiteWeb'
    networks:
      - internal

  php:
    image: wodby/php:latest
    volumes:
      - ./www:/var/www/html
    labels:
      - "traefik.enable=true"
      - traefik.docker.network='$NomSiteWeb'
      
    container_name: php_'$NomSiteWeb'
    networks:
      - internal

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: phpmyadmin_'$NomSiteWeb'
    environment:
      PMA_ARBITRARY: 1
    depends_on:
      - db
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.'$NomSiteWeb'-phpmyadmin.rule=Host(`'$NomSiteWeb'-phpmyadmin.moraud.xyz`)"
      - "traefik.http.routers.'$NomSiteWeb'-phpmyadmin.entrypoints=websecure"
      - "traefik.http.routers.'$NomSiteWeb'-phpmyadmin.tls.certresolver=myhttpchallenge"
      - traefik.docker.network=web

      - "traefik.http.routers.'$NomSiteWeb'-http-phpmyadmin.rule=Host(`'$NomSiteWeb'-phpmyadmin.moraud.xyz`)"
      - "traefik.http.routers.'$NomSiteWeb'-http-phpmyadmin.entrypoints=web"

      - traefik.http.routers.'$NomSiteWeb'-http-phpmyadmin.middlewares='$NomSiteWeb'-redirect-phpmyadmin
      - traefik.http.middlewares.'$NomSiteWeb'-redirect-phpmyadmin.redirectscheme.scheme=https
      - traefik.http.middlewares.'$NomSiteWeb'-redirect-phpmyadmin.redirectscheme.permanent=true
    networks:
      - internal
      - web


networks:
  internal:
  web:
    external: true' > /$NomSiteWeb/docker-compose.yml

docker-compose -f /$NomSiteWeb/docker-compose.yml up -d

useradd $NomSiteWeb

databaseIP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' db_$NomSiteWeb)

randompw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)

echo $NomSiteWeb:$randompw | chpasswd

sudo usermod -a -G $NomSiteWeb $NomSiteWeb
sudo chmod g+w /$NomSiteWeb/www

echo "UserID: $NomSiteWeb has been created with the following password: $randompw The IP of the ftp is ..."
echo "Don't forget to create the subdomaine"
echo "The password of the database is: $randompwdb The link to phpmyadmin is : $NomSiteWeb -phpmyadmin The ip of the database is : $databaseIP"



