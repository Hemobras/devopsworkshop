# Production stage - apenas serve os arquivos estáticos
FROM nginx:1.28.0-alpine

# Remove a configuração padrão do nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copie a configuração customizada para porta 8080
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copie os arquivos estáticos já buildados do diretório dist/
COPY dist/ /usr/share/nginx/html/

# Exponha a porta 8080
EXPOSE 8080

# Inicie o nginx (como root, que é o padrão e necessário)
CMD ["nginx", "-g", "daemon off;"]