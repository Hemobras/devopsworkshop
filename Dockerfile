# Production stage - apenas serve os arquivos estáticos
FROM nginx:1.28.0-alpine

# Remove a configuração padrão do nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copie a configuração customizada para porta 8080
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copie os arquivos estáticos já buildados do diretório dist/
COPY dist/ /usr/share/nginx/html/

# Crie o diretório de logs e ajuste permissões
RUN mkdir -p /var/log/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /usr/share/nginx/html

# Exponha a porta 8080
EXPOSE 8080

# Use o usuário nginx (boa prática de segurança)
USER nginx

# Inicie o nginx
CMD ["nginx", "-g", "daemon off;"]