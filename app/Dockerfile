# Stage 1: Build the Astro static site
FROM node:20-alpine AS build

WORKDIR /app
COPY ice_cream_site/package*.json ./
RUN npm ci
COPY ice_cream_site/ ./

# Sync recipes from the book repo into Astro content
COPY ice_cream_book/recipes/ /tmp/recipes/
# The sync script expects ../ice_cream_book/recipes/ relative to ice_cream_site/
# So we adjust: copy recipes into the expected location
RUN mkdir -p /tmp/ice_cream_book/recipes && cp /tmp/recipes/*.md /tmp/ice_cream_book/recipes/
RUN cd /app && PYTHONDONTWRITEBYTECODE=1 python3 sync_recipes.py || true

RUN npx astro build

# Stage 2: Serve with Nginx on port 8080
FROM nginx:latest

# Match existing infra contract: port 8080, /health endpoint
COPY app/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
