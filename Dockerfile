FROM node:20-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

LABEL version="2.3.0" description="Api to control whatsapp features through http requests." 
LABEL maintainer="Davidson Gomes" git="https://github.com/DavidsonGomes"
LABEL contact="contato@evolution-api.com"

WORKDIR /evolution

# Definir ARGs para variáveis necessárias no build
ARG DATABASE_PROVIDER=postgresql
ARG DATABASE_CONNECTION_URI
ARG AUTHENTICATION_API_KEY
ARG SERVER_PORT=8080
ARG CORS_ORIGIN=*
ARG LOG_LEVEL=ERROR,WARN,DEBUG,INFO,LOG,VERBOSE,DARK

# Converter ARGs em ENVs para o build stage
ENV DATABASE_PROVIDER=${DATABASE_PROVIDER}
ENV DATABASE_CONNECTION_URI=${DATABASE_CONNECTION_URI}
ENV DATABASE_URL=${DATABASE_CONNECTION_URI}
ENV AUTHENTICATION_API_KEY=${AUTHENTICATION_API_KEY}
ENV SERVER_PORT=${SERVER_PORT}
ENV CORS_ORIGIN=${CORS_ORIGIN}
ENV LOG_LEVEL=${LOG_LEVEL}
ENV DOCKER_ENV=true

COPY ./package.json ./tsconfig.json ./

RUN npm install

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./runWithProvider.js ./
COPY ./tsup.config.ts ./

COPY ./Docker ./Docker

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

RUN ./Docker/scripts/generate_database.sh

RUN npm run build

FROM node:20-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo

WORKDIR /evolution

# Redefinir ARGs para o final stage
ARG DATABASE_PROVIDER=postgresql
ARG DATABASE_CONNECTION_URI
ARG AUTHENTICATION_API_KEY
ARG SERVER_PORT=8080
ARG CORS_ORIGIN=*
ARG LOG_LEVEL=ERROR,WARN,DEBUG,INFO,LOG,VERBOSE,DARK
ARG CONFIG_SESSION_PHONE_CLIENT="Evolution API"
ARG CONFIG_SESSION_PHONE_NAME="Chrome"
ARG QRCODE_LIMIT=30
ARG QRCODE_COLOR="#175197"
ARG LANGUAGE=en

# Configurar todas as ENVs necessárias para runtime
ENV DATABASE_PROVIDER=${DATABASE_PROVIDER}
ENV DATABASE_CONNECTION_URI=${DATABASE_CONNECTION_URI}
ENV DATABASE_URL=${DATABASE_CONNECTION_URI}
ENV AUTHENTICATION_API_KEY=${AUTHENTICATION_API_KEY}
ENV SERVER_PORT=${SERVER_PORT}
ENV CORS_ORIGIN=${CORS_ORIGIN}
ENV LOG_LEVEL=${LOG_LEVEL}
ENV CONFIG_SESSION_PHONE_CLIENT=${CONFIG_SESSION_PHONE_CLIENT}
ENV CONFIG_SESSION_PHONE_NAME=${CONFIG_SESSION_PHONE_NAME}
ENV QRCODE_LIMIT=${QRCODE_LIMIT}
ENV QRCODE_COLOR=${QRCODE_COLOR}
ENV LANGUAGE=${LANGUAGE}
ENV DOCKER_ENV=true

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json

COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]