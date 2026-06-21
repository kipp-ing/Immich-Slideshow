#!/usr/bin/env bash
#
# Reproducible local TLS integration check for NIOMQTTTransport.
#
# Spins up a throwaway certificate authority + server cert, writes a mosquitto
# config with a TLS listener and password auth, then runs the gated integration
# test (Tests/HAControlMQTTTests) which drives the real transport against that
# broker: TLS connect, retained publish, subscribe round-trip, and reconnect.
#
# Nothing here is wired into CI. Requires: mosquitto + openssl (brew install mosquitto).
#
# Usage:  Packages/HAControlKit/Scripts/mqtt-integration.sh
set -euo pipefail

RIG="${MQTT_RIG_DIR:-/tmp/mqtt-it}"
HOST="localhost"
PORT="18883"
USER="hauser"
PASS="hapass"

MOSQUITTO_BIN="$(command -v mosquitto || ls /opt/homebrew/sbin/mosquitto /usr/local/sbin/mosquitto 2>/dev/null | head -1)"
PASSWD_BIN="$(command -v mosquitto_passwd || ls /opt/homebrew/bin/mosquitto_passwd 2>/dev/null | head -1)"
[ -x "$MOSQUITTO_BIN" ] || { echo "mosquitto not found (brew install mosquitto)"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Generating test CA + server cert in $RIG"
rm -rf "$RIG"; mkdir -p "$RIG"; cd "$RIG"
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt -days 5 \
  -subj "/CN=ImmichSlideshow-Test-CA" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr \
  -subj "/CN=localhost" >/dev/null 2>&1
printf 'subjectAltName = DNS:localhost,IP:127.0.0.1\n' > san.ext
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 5 -extfile san.ext >/dev/null 2>&1
"$PASSWD_BIN" -c -b passwd "$USER" "$PASS" 2>/dev/null

cat > mosquitto.conf <<EOF
listener $PORT 127.0.0.1
allow_anonymous false
password_file $RIG/passwd
cafile $RIG/ca.crt
certfile $RIG/server.crt
keyfile $RIG/server.key
tls_version tlsv1.2
EOF

echo "==> Running gated integration test"
cd "$PACKAGE_DIR"
MQTT_INTEGRATION=1 \
MQTT_MOSQUITTO_BIN="$MOSQUITTO_BIN" \
MQTT_CONF="$RIG/mosquitto.conf" \
MQTT_CA="$RIG/ca.crt" \
MQTT_HOST="$HOST" MQTT_PORT="$PORT" MQTT_USER="$USER" MQTT_PASS="$PASS" \
  swift test --filter NIOMQTTTransportIntegrationTests

echo "==> Done"
