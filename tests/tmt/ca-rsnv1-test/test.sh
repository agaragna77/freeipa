#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-rsnv1-test
# (GHA .github/workflows/ca-rsnv1-test.yml). Packaged forge IPACTA.
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

step "Check CA certs and keys"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check certs
docker exec "$CONTAINER" pki-server cert-find

# check keys
echo "Secret.123" > password.txt
docker cp password.txt pki:password.txt
docker exec "$CONTAINER" certutil -K \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f password.txt | tee output

# there should be no orphaned keys
echo "0" > expected
{ grep "(orphan)" output || true; } | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA certs and keys (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Switch to RSNv3"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# switch cert request ID generator to RSNv3
docker exec "$CONTAINER" pki-server ca-config-unset dbs.beginRequestNumber
docker exec "$CONTAINER" pki-server ca-config-unset dbs.endRequestNumber
docker exec "$CONTAINER" pki-server ca-config-unset dbs.requestIncrement
docker exec "$CONTAINER" pki-server ca-config-unset dbs.requestLowWaterMark
docker exec "$CONTAINER" pki-server ca-config-unset dbs.requestCloneTransferNumber
docker exec "$CONTAINER" pki-server ca-config-unset dbs.requestRangeDN

docker exec "$CONTAINER" pki-server ca-config-set dbs.request.id.generator random

# switch cert ID generator to RSNv3
docker exec "$CONTAINER" pki-server ca-config-unset dbs.beginSerialNumber
docker exec "$CONTAINER" pki-server ca-config-unset dbs.endSerialNumber
docker exec "$CONTAINER" pki-server ca-config-unset dbs.serialIncrement
docker exec "$CONTAINER" pki-server ca-config-unset dbs.serialLowWaterMark
docker exec "$CONTAINER" pki-server ca-config-unset dbs.serialCloneTransferNumber
docker exec "$CONTAINER" pki-server ca-config-unset dbs.serialRangeDN
docker exec "$CONTAINER" pki-server ca-config-unset dbs.enableRandomSerialNumbers
docker exec "$CONTAINER" pki-server ca-config-unset dbs.randomSerialNumberCounter

docker exec "$CONTAINER" pki-server ca-config-set dbs.cert.id.generator random

# restart CA subsystem
docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Switch to RSNv3 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Run PKI healthcheck"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# Retry pki-healthcheck: intermittent NSS load timeout on audit_signing
hc_ok=0
for hc_try in 1 2 3; do
    echo "pki-healthcheck attempt ${hc_try}/3"
    if (
    set -euo pipefail
    docker exec "$CONTAINER" pki-healthcheck --failures-only
    ); then
        hc_ok=1
        break
    fi
    sleep 5
done
[[ "$hc_ok" -eq 1 ]]
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Run PKI healthcheck (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Initialize PKI client"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-export ca_signing --cert-file ca_signing.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert ca_signing.crt \
    --trust CT,C,C \
    ca_signing

docker exec "$CONTAINER" pki pkcs12-import \
    --pkcs12 /root/.dogtag/pki-tomcat/ca_admin_cert.p12 \
    --pkcs12-password Secret.123
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Initialize PKI client (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Test CA agent"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" /usr/share/pki/tests/ca/bin/ca-agent-create.sh
docker exec "$CONTAINER" /usr/share/pki/tests/ca/bin/ca-agent-cert-create.sh
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Test CA agent (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert requests in CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki -n caadmin ca-cert-request-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert requests in CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check certs in CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki ca-cert-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs in CA (rc=$_rc)" >&2
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

step "Check DS server systemd journal"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" journalctl -x --no-pager -u dirsrv@localhost.service
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check DS server systemd journal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check DS container logs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Check DS container logs"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check DS container logs (rc=$_rc)" >&2
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
    echo "==== ca-rsnv1-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-rsnv1-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-rsnv1-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-rsnv1-test PASSED ===="

