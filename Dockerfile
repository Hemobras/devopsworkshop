# Build stage - compila a aplicação
FROM node:18-alpine AS build

WORKDIR /app

# Copie os arquivos de dependências
COPY package*.json ./

# Instale as dependências
RUN npm ci --only=production

# Copie todo o código fonte
COPY . .

# Execute o build (isso vai criar o diretório dist/)
RUN npm run build

# Production stage - serve com nginx
FROM nginx:1.28.0-alpine

# Remove a configuração padrão do nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copie a configuração customizada para porta 8080
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copie os arquivos buildados do stage anterior
COPY --from=build /app/dist /usr/share/nginx/html

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