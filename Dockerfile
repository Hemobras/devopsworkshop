# Dockerfile definitivo
FROM nginx:1.28-alpine

# garantir /run gravável para o usuário nginx (UID 101 na imagem oficial)
RUN mkdir -p /run && chown -R 101:101 /run

# copiar configuração e conteúdo estático
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./conf.d/ /etc/nginx/conf.d/
COPY ./dist /usr/share/nginx/html

CMD ["nginx", "-g", "daemon off;"]
