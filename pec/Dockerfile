FROM eclipse-temurin:8-jre

RUN apt-get update \
 && apt-get install -y --no-install-recommends file procps \
 && rm -rf /var/lib/apt/lists/* \
 && { [ -e /sbin/init ] || ln -s /bin/sh /sbin/init; }

# Versão do PEC (vem do .env via docker-compose.yml)
ARG PEC_VERSION
ENV PEC_VERSION=${PEC_VERSION}

WORKDIR /installer
COPY eSUS-AB-PEC-${PEC_VERSION}-Linux64.jar pec.jar
COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 8443
ENTRYPOINT ["/entrypoint.sh"]
