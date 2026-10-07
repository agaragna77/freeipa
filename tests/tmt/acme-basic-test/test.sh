#!/bin/bash
# IPACTA acme-basic-test — same functional coverage as dogtagpki/pki
# tests/tmt/acme-basic-test (GHA acme-basic-test.yml), FreeIPA ACME path.
#
# Model: single IPA container + stock ipa-server-install with packaged
# forge IPACTA. ACME via ipa-acme-manage + https://ipa-ca.$DOMAIN/acme/directory
# and certbot (HTTP-01 standalone on the IPA host, as in ipatests test_acme).
#
# Dogtag-only layout (Tomcat ACME dirs, DS sidecar, caddy client, pki acme
# CLI probes) is omitted. Failures are collected; script exits non-zero at end.
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
HOST="ipa.${DOMAIN}"
ACME_HOST="ipa-ca.${DOMAIN}"
ACME_SERVER="https://${ACME_HOST}/acme/directory"
WORKDIR=/tmp/acme-basic-workdir

FAILS=()
CURRENT="setup"

cleanup() {
    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker network rm example 2>/dev/null || true
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

step() {
    CURRENT="$*"
    echo
    echo "==== $* ===="
}

fail() {
    echo "FAIL: ${CURRENT}: $*" >&2
    FAILS+=("${CURRENT}: $*")
}

finish_report() {
    echo
    if [[ ${#FAILS[@]} -eq 0 ]]; then
        echo "==== IPACTA ACME basic test PASSED ===="
        return 0
    fi
    echo "==== IPACTA ACME basic test FAILED (${#FAILS[@]} check(s)) ===="
    local item
    for item in "${FAILS[@]}"; do
        echo " - ${item}"
    done
    return 1
}

iexec() { docker exec "$CONTAINER" "$@"; }
ibash() { docker exec "$CONTAINER" bash -lc "$*"; }

run_check() {
    # Run a check without aborting the script; record failures.
    set +e
    "$@"
    local _rc=$?
    set -e
    if [[ $_rc -ne 0 ]]; then
        fail "rc=$_rc"
        return 1
    fi
    return 0
}

if ! command -v docker >/dev/null; then
    echo "ERROR: docker not found" >&2
    exit 1
fi
if ! docker image inspect "$IPA_IMAGE" >/dev/null 2>&1; then
    cat >&2 <<EOF
ERROR: Docker image '$IPA_IMAGE' not found.
Prepare should have built it (tests/tmt/bin/build-ipa-runner.sh).
Override with IPA_IMAGE=... or SKIP_IPA_BUILD=1 only if the image already exists.
EOF
    exit 1
fi

mkdir -p "$WORKDIR"

step "Create network"
docker network inspect example >/dev/null 2>&1 || docker network create example
docker rm -f "$CONTAINER" 2>/dev/null || true

step "Set up IPA container"
docker run -d --name "$CONTAINER" \
    --hostname="$HOST" \
    --network=example \
    --network-alias="$HOST" \
    --network-alias="$ACME_HOST" \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 \
    --privileged \
    -v "$WORKDIR:$WORKDIR" \
    "$IPA_IMAGE" \
    /usr/sbin/init

for _i in $(seq 1 90); do
    if iexec systemctl is-system-running --wait 2>/dev/null \
        || iexec systemctl is-system-running 2>/dev/null | grep -Eq 'running|degraded'; then
        break
    fi
    sleep 2
done

step "Get Fedora version"
FEDORA_VERSION=$(iexec sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"')
echo "FEDORA_VERSION=$FEDORA_VERSION"

step "Check ipa-acme-manage CLI help (mapped from pki acme CLI)"
run_check iexec ipa-acme-manage --help >/dev/null

step "Install CA (ipa-server-install + packaged IPACTA)"
# Fail-hard: without CA the rest is meaningless
iexec ipa-server-install \
    -U \
    --domain "$DOMAIN" \
    -r "$REALM" \
    -p "$PASSWORD" \
    -a "$PASSWORD" \
    --no-host-dns \
    --no-ntp

step "Check ACME status before enable"
run_check bash -c '
    out=$(docker exec '"$CONTAINER"' ipa-acme-manage status 2>&1) || true
    echo "$out"
    echo "$out" | grep -qi disabled
'

step "Verify ACME directory unavailable before enable"
# curl --fail exits non-zero on 4xx/5xx — expected before enable
set +e
iexec curl --fail -sk "$ACME_SERVER" >/dev/null 2>&1
_curl_rc=$?
set -e
if [[ $_curl_rc -eq 0 ]]; then
    fail "directory responded OK before enable"
else
    echo "directory unavailable before enable (curl rc=$_curl_rc) — OK"
fi

step "Enable ACME (ipa-acme-manage enable)"
iexec ipa-acme-manage enable
# Dogtag ACME may need a short settle (ipatests waits/retries)
for _i in $(seq 1 10); do
    if iexec curl --fail -sk "$ACME_SERVER" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

step "Check ACME status after enable"
run_check bash -c '
    out=$(docker exec '"$CONTAINER"' ipa-acme-manage status 2>&1)
    echo "$out"
    echo "$out" | grep -qi enabled
'

step "Verify ACME directory in IPA container"
run_check iexec curl --fail -sk "$ACME_SERVER"

step "Install certbot"
run_check iexec dnf install -y certbot

step "Register ACME account"
run_check iexec bash -lc "
    rm -rf /etc/letsencrypt/accounts /etc/letsencrypt/archive \
           /etc/letsencrypt/csr /etc/letsencrypt/keys \
           /etc/letsencrypt/live /etc/letsencrypt/renewal \
           /etc/letsencrypt/renewal-hooks
    certbot --server '$ACME_SERVER' register \
        -m nobody@example.test \
        --agree-tos \
        --no-eff-email
"

step "Enroll client cert (certbot standalone HTTP-01)"
# FreeIPA pattern: stop httpd so certbot can bind :80
run_check iexec bash -lc "
    systemctl stop httpd
    certbot --server '$ACME_SERVER' certonly \
        --domain '$HOST' \
        --standalone \
        --key-type rsa \
        --force-renewal \
        --non-interactive
    systemctl start httpd
"

step "Check client cert"
run_check iexec bash -lc "
    test -f /etc/letsencrypt/live/$HOST/fullchain.pem
    test -f /etc/letsencrypt/live/$HOST/privkey.pem
    openssl x509 -in /etc/letsencrypt/live/$HOST/fullchain.pem -noout -subject -issuer
"

step "Renew client cert"
run_check iexec bash -lc "
    systemctl stop httpd
    certbot --server '$ACME_SERVER' renew --force-renewal --non-interactive
    systemctl start httpd
"

step "Check renewed client cert"
run_check iexec bash -lc "
    test -f /etc/letsencrypt/live/$HOST/fullchain.pem
    openssl x509 -in /etc/letsencrypt/live/$HOST/fullchain.pem -noout -dates
"

step "Revoke client cert"
run_check iexec bash -lc "
    certbot --server '$ACME_SERVER' revoke \
        --cert-path /etc/letsencrypt/live/$HOST/fullchain.pem \
        --non-interactive \
        --delete-after-revoke || \
    certbot --server '$ACME_SERVER' revoke \
        --cert-path /etc/letsencrypt/live/$HOST/fullchain.pem \
        --non-interactive
"

step "Update ACME account"
run_check iexec bash -lc "
    certbot --server '$ACME_SERVER' update_account \
        -m updated@example.test \
        --non-interactive
"

step "Remove ACME account"
run_check iexec bash -lc "
    certbot --server '$ACME_SERVER' unregister --non-interactive
"

step "Disable ACME"
run_check iexec ipa-acme-manage disable

step "Check ACME status after disable"
run_check bash -c '
    out=$(docker exec '"$CONTAINER"' ipa-acme-manage status 2>&1) || true
    echo "$out"
    echo "$out" | grep -qi disabled
'

step "Remove CA (ipa-server-install --uninstall)"
iexec ipa-server-install --uninstall -U --ignore-topology-disconnect --ignore-last-of-role \
    || iexec ipa-server-install --uninstall -U || true

finish_report
