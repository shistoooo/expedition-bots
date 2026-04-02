FROM node:22-slim
WORKDIR /app
COPY package*.json ./
RUN npm install --production=false
COPY . .
RUN npm run build
# Start command is overridden per Railway service via startCommand env var
CMD ["node", "dist/start-command.js"]
