FROM node:20-bookworm-slim

# Create app directory
WORKDIR /app

# Install dependencies first (leverages Docker layer cache)
COPY financial-dashboard/package*.json ./financial-dashboard/
RUN cd financial-dashboard \
    && npm ci

# Copy the rest of the repo (includes server code and database schemas)
COPY . .

# Environment
ENV NODE_ENV=production
ENV PORT=8080

# Set working dir to the app
WORKDIR /app/financial-dashboard

# Cloud Run will send traffic to $PORT; expose for local runs
EXPOSE 8080

# Run the server using tsx (installed via devDependencies)
CMD ["npm", "run", "server"]

