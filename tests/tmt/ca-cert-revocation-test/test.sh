#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-cert-revocation-test
# (GHA .github/workflows/ca-cert-revocation-test.yml). Packaged forge IPACTA.
# Dogtag-only layout (DS sidecar, HSM, extra PKI containers) is OMITTED.
# Remaining pki CLI / REST steps run against the IPA container and FAIL
# if IPACTA does not cover them.
set -euo pipefail

REPO_ROOT="${TMT_TREE:-}"
if [[ -z "$REPO_ROOT" || ! -f "$REPO_ROOT/tests/tmt/bin/ipacta-tmt-common.sh" ]]; then
    REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
fi
source "$REPO_ROOT/tests/tmt/bin/ipacta-tmt-common.sh"
export GITHUB_WORKSPACE="$REPO_ROOT"
export SHARED="${SHARED:-/tmp/workdir/pki}"
export GITHUB_ENV="${TMPDIR:-/tmp}/gha-env-$$"
touch "$GITHUB_ENV"
source_gha_env() { set -a; source "$GITHUB_ENV" 2>/dev/null || true; set +a; }
mkdir -p "$GITHUB_WORKSPACE"
export LC_ALL=C
trap ipacta_cleanup EXIT
GHA_FAILED=0
ipacta_start_container

step "Clone repository"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Clone repository"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Clone repository (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Retrieve PKI images"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Retrieve PKI images"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Retrieve PKI images (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Load PKI images"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker image inspect "$IPA_IMAGE" >/dev/null
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Load PKI images (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create network"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "network example already created"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create network (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up DS container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Set up DS container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up DS container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "IPA container already running as $CONTAINER"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_ca
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Update CA configuration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set buffer size to 0 so that revocation takes effect immediately
docker exec "$CONTAINER" pki-server ca-config-set auths.revocationChecking.bufferSize 0

# restart CA subsystem
docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Update CA configuration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-export \
    --cert-file ca_signing.crt \
     ca_signing

docker exec "$CONTAINER" pki nss-cert-import \
    --cert ca_signing.crt \
    --trust CT,C,C \
    ca_signing

docker exec "$CONTAINER" pki pkcs12-import \
    --pkcs12 /root/.dogtag/pki-tomcat/ca_admin_cert.p12 \
    --pkcs12-password Secret.123
docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create test certs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki client-cert-request uid=testuser1 | tee output

CERT1_REQUEST_ID=$(sed -n "s/^\s*Request ID:\s*\(\S*\)$/\1/p" output)
echo "Cert 1 request ID: $CERT1_REQUEST_ID"

docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-request-approve \
    --force \
    $CERT1_REQUEST_ID | tee output

CERT1_ID=$(sed -n "s/^\s*Certificate ID:\s*\(\S*\)$/\1/p" output)
echo "Cert 1 ID: $CERT1_ID"
echo "$CERT1_ID" > cert1.id

docker exec "$CONTAINER" pki client-cert-request uid=testuser2 | tee output

CERT2_REQUEST_ID=$(sed -n "s/^\s*Request ID:\s*\(\S*\)$/\1/p" output)
echo "Cert 2 request ID: $CERT2_REQUEST_ID"

docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-request-approve \
    --force \
    $CERT2_REQUEST_ID | tee output

CERT2_ID=$(sed -n "s/^\s*Certificate ID:\s*\(\S*\)$/\1/p" output)
echo "Cert 2 ID: $CERT2_ID"
echo "$CERT2_ID" > cert2.id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create test certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert revocation using pki ca-cert commands"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT1_ID=$(cat cert1.id)
CERT2_ID=$(cat cert2.id)

# place certs on-hold
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-hold \
    --force \
    $CERT1_ID $CERT2_ID | tee output

# both certs should be revoked
echo "REVOKED" > expected
echo "REVOKED" >> expected
sed -n "s/^\s*Status:\s*\(\S*\)$/\1/p" output > actual
diff expected actual

# place certs off-hold
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-release-hold \
    --force \
    $CERT1_ID $CERT2_ID | tee output

# both certs should be valid
echo "VALID" > expected
echo "VALID" >> expected
sed -n "s/^\s*Status:\s*\(\S*\)$/\1/p" output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert revocation using pki ca-cert commands (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert revocation using revoker tool"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT1_ID=$(cat cert1.id)
CERT2_ID=$(cat cert2.id)

docker exec "$CONTAINER" revoker -V

# place certs on-hold
docker exec "$CONTAINER" revoker \
    -d /root/.dogtag/nssdb \
    -n caadmin \
    -r 6 \
    -s $CERT1_ID,$CERT2_ID \
    pki.example.com:8443 | tee output

# both certs should be revoked
echo "REVOKED" > expected
echo "REVOKED" >> expected
sed -n "s/^\s*Status:\s*\(\S*\)$/\1/p" output > actual
diff expected actual

# place certs off-hold
docker exec "$CONTAINER" revoker \
    -d /root/.dogtag/nssdb \
    -n caadmin \
    -u \
    -s $CERT1_ID,$CERT2_ID \
    pki.example.com:8443 | tee output

# both certs should be valid
echo "VALID" > expected
echo "VALID" >> expected
sed -n "s/^\s*Status:\s*\(\S*\)$/\1/p" output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert revocation using revoker tool (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA agent cert revocation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" /usr/share/pki/tests/ca/bin/ca-agent-create.sh
docker exec "$CONTAINER" /usr/share/pki/tests/ca/bin/ca-agent-cert-create.sh
docker exec "$CONTAINER" /usr/share/pki/tests/ca/bin/ca-agent-cert-revoke.sh
docker exec "$CONTAINER" /usr/share/pki/tests/ca/bin/ca-agent-cert-unrevoke.sh
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA agent cert revocation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server systemd journal"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" journalctl -x --no-pager -u pki-tomcatd@pki-tomcat.service
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server systemd journal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CA debug log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" find /var/lib/pki/pki-tomcat/logs/ca -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA debug log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== ca-cert-revocation-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-cert-revocation-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-cert-revocation-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-cert-revocation-test PASSED ===="

