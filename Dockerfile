FROM node:22-bookworm-slim

WORKDIR /app/financial-dashboard

# This Dockerfile uses the repository root as its build context.
COPY financial-dashboard/package.json financial-dashboard/package-lock.json ./
# The API runs TypeScript directly; tsx is a required runtime devDependency.
RUN npm ci --include=dev

COPY financial-dashboard/tsconfig.server.json ./
COPY financial-dashboard/server ./server
COPY financial-dashboard/scripts ./scripts
COPY financial-dashboard/public/momentum ./public/momentum

ENV NODE_ENV=production PORT=8080
EXPOSE 8080

CMD ["node", "--import", "tsx", "server/index.ts"]
