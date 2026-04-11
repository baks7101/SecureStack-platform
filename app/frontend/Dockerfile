# Stage 1: Install dependencies (cached layer)
FROM node:18-alpine AS deps

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# Stage 2: Build React app
FROM node:18-alpine AS build

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG REACT_APP_API
ENV REACT_APP_API=$REACT_APP_API

RUN npm run build

# Stage 3: Production image (Nginx)
FROM nginx:alpine

# Security: remove default nginx config and server tokens
RUN rm -rf /etc/nginx/conf.d/default.conf && \
    sed -i 's/# server_tokens off;/server_tokens off;/' /etc/nginx/nginx.conf

# Copy custom nginx config with security headers
COPY default.conf /etc/nginx/conf.d/default.conf

# Copy React build output
COPY --from=build /app/build /usr/share/nginx/html

# Security: set proper permissions
RUN chmod -R 755 /usr/share/nginx/html && \
    chown -R nginx:nginx /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80 || exit 1

CMD ["nginx", "-g", "daemon off;"]
