#!/bin/sh
set -e

# Instala o PEC só na primeira subida (o volume guarda a instalação)
if [ ! -d /opt/e-SUS/webserver ]; then
  java -jar /installer/pec.jar -console -continue \
    -url="jdbc:postgresql://db:5432/esus" \
    -username=postgres -password="$DB_PASSWORD"

  if [ ! -d /opt/e-SUS/webserver ]; then
    echo "ERRO: instalação do PEC não gerou /opt/e-SUS/webserver"
    ls -la /opt/e-SUS || true
    exit 1
  fi
fi

# ⚠️ confirme o caminho do arquivo dentro do /opt/e-SUS
PROPS=/opt/e-SUS/webserver/config/application.properties

set_prop() {
  if grep -q "^$1=" "$PROPS"; then
    sed -i "s|^$1=.*|$1=$2|" "$PROPS"
  else
    echo "$1=$2" >> "$PROPS"
  fi
}

# HTTPS direto no PEC (reaplicado a cada subida)
set_prop server.port 8443
set_prop server.ssl.enabled true
set_prop server.ssl.key-store /certs/localhost.p12
set_prop server.ssl.key-store-type PKCS12
set_prop server.ssl.key-store-password changeit

# ⚠️ confirme o nome do script de inicialização
exec /opt/e-SUS/webserver/standalone.sh