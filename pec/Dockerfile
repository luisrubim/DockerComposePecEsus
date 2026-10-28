FROM eclipse-temurin:8-jre

RUN apt-get update \
 && apt-get install -y --no-install-recommends file procps \
 && rm -rf /var/lib/apt/lists/* \
 && { [ -e /sbin/init ] || ln -s /bin/sh /sbin/init; }

WORKDIR /installer
COPY eSUS-AB-PEC-5.5.28-Linux64.jar pec.jar
COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 8443
ENTRYPOINT ["/entrypoint.sh"]
