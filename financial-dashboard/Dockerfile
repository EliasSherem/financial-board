# Build stage
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
# Install all deps (incl. dev deps used for build), then make local bins executable
RUN npm ci && chmod +x node_modules/.bin/* || true
COPY . .
# Use VITE_API_URL at build time
ARG VITE_API_URL
ARG VITE_SS_DASHBOARD
ARG VITE_SS_INVOICES
ARG VITE_SS_PROJECTS
ARG VITE_SS_RECURRING
ARG VITE_GOOGLE_CLIENT_ID
ENV VITE_API_URL=${VITE_API_URL}
ENV VITE_SS_DASHBOARD=${VITE_SS_DASHBOARD}
ENV VITE_SS_INVOICES=${VITE_SS_INVOICES}
ENV VITE_SS_PROJECTS=${VITE_SS_PROJECTS}
ENV VITE_SS_RECURRING=${VITE_SS_RECURRING}
ENV VITE_GOOGLE_CLIENT_ID=${VITE_GOOGLE_CLIENT_ID}
# Run TypeScript + Vite builds explicitly via node to avoid any exec-bit issues
RUN node ./node_modules/typescript/bin/tsc -b && node ./node_modules/vite/bin/vite.js build

# Serve stage
FROM nginx:1.27-alpine
WORKDIR /usr/share/nginx/html
COPY --from=build /app/dist .
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
