#!/bin/bash
# IPACTA CA smoke — parity with dogtagpki/pki tests/tmt/ca-basic-smoke.
# Uses IPA-hosted IPACTA (ipa-server-install --internal-ca), not pkispawn.
set -euo pipefail

REPO_ROOT="${TMT_TREE:-}"
if [[ -z "$REPO_ROOT" || ! -f "$REPO_ROOT/ipaserver/install/server/install.py" ]]; then
    REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
fi

IPA_IMAGE="${IPA_IMAGE:-freeipa-ipacta:latest}"
CONTAINER="${CONTAINER_NAME:-ipa}"
DOMAIN="${IPA_DOMAIN:-example.com}"
REALM="${IPA_REALM:-EXAMPLE.COM}"
PASSWORD="${IPA_PASSWORD:-Secret.123}"

cleanup() {
    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker network rm example 2>/dev/null || true
}
trap cleanup EXIT

if ! command -v docker >/dev/null; then
    echo "ERROR: docker not found" >&2
    exit 1
fi

if ! docker image inspect "$IPA_IMAGE" >/dev/null 2>&1; then
    cat >&2 <<EOF
ERROR: Docker image '$IPA_IMAGE' not found.

Override with IPA_IMAGE=... (image must include FreeIPA + IPACTA from IPAthinCA).
Known local default: freeipa-ipacta:latest
EOF
    exit 1
fi

echo "==> Create network"
docker network create example

echo "==> Start IPA container ($IPA_IMAGE)"
# Privileged + systemd-friendly flags commonly required for ipa-server-install
docker run -d --name "$CONTAINER" \
    --hostname="ipa.${DOMAIN}" \
    --network=example \
    --network-alias="ipa.${DOMAIN}" \
    --network-alias="ipa-ca.${DOMAIN}" \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 \
    --privileged \
    "$IPA_IMAGE" \
    /usr/sbin/init

# Wait for systemd
for i in $(seq 1 60); do
    if docker exec "$CONTAINER" systemctl is-system-running --wait 2>/dev/null \
        || docker exec "$CONTAINER" systemctl is-system-running 2>/dev/null | grep -Eq 'running|degraded'; then
        break
    fi
    sleep 2
done

echo "==> ipa-server-install --internal-ca (IPACTA)"
docker exec "$CONTAINER" ipa-server-install \
    -U \
    --domain "$DOMAIN" \
    -r "$REALM" \
    -p "$PASSWORD" \
    -a "$PASSWORD" \
    --no-host-dns \
    --no-ntp \
    --internal-ca

echo "==> kinit + ipa ping"
docker exec "$CONTAINER" bash -c "echo '$PASSWORD' | kinit admin"
docker exec "$CONTAINER" ipa ping

echo "==> CA visibility (IPA cert APIs — Dogtag-compatible via IPACTA)"
docker exec "$CONTAINER" ipa cert-find --all | head -n 50
docker exec "$CONTAINER" ipa certprofile-find | head -n 50

# Optional: REST health if exposed like Dogtag /ca/rest/info
if docker exec "$CONTAINER" curl -sfk "https://ipa.${DOMAIN}:8443/ca/rest/info" >/tmp/ca-info.json 2>/dev/null \
    || docker exec "$CONTAINER" curl -sfk "https://127.0.0.1:8443/ca/rest/info" -o /tmp/ca-info.json 2>/dev/null; then
    echo "==> /ca/rest/info OK"
    docker exec "$CONTAINER" cat /tmp/ca-info.json || true
else
    echo "==> /ca/rest/info not probed successfully (non-fatal for smoke)"
fi

echo "==> Uninstall IPA"
docker exec "$CONTAINER" ipa-server-install --uninstall -U

echo "==> IPACTA CA basic smoke PASSED"
