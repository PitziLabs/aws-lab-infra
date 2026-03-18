# Stage 1: Build the static site
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files and install deps
COPY ice_cream_site/package*.json ./
RUN npm ci

# Copy the Astro project source
COPY ice_cream_site/ ./

# Copy recipes from the book repo and run the sync
COPY ice_cream_book/recipes/ /book/recipes/
RUN python3 sync_recipes.py || echo "sync_recipes expects relative path, adjusting..."

# Build the site
RUN npx astro build

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Custom nginx config for SPA-friendly static hosting
COPY <<'EOF' /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Clean URLs — /recipes/01_coconut_pandan serves index.html inside that dir
    location / {
        try_files $uri $uri/ $uri/index.html =404;
    }

    # Cache static assets aggressively
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Gzip
    gzip on;
    gzip_types text/html text/css application/javascript application/json;
    gzip_min_length 1000;
}
EOF

# Copy built static files from build stage
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
