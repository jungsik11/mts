# Build stage
FROM node:20-alpine AS build-stage
WORKDIR /app
ARG VITE_ACCOUNT_SERVER_URL
ARG VITE_TRADING_SERVER_URL
ENV VITE_ACCOUNT_SERVER_URL=$VITE_ACCOUNT_SERVER_URL
ENV VITE_TRADING_SERVER_URL=$VITE_TRADING_SERVER_URL
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Production stage
FROM nginx:stable-alpine
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build-stage /app/.htpasswd /etc/nginx/.htpasswd
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
