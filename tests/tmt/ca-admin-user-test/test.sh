#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-admin-user-test
# (GHA .github/workflows/ca-admin-user-test.yml). Packaged forge IPACTA.
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

step "Check CA users"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-user-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA users (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA groups"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-group-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA groups (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin user"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-user-show caadmin | tee output

echo "adminType" > expected
sed -n 's/^ *Type: *\(.*\)$/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check auth with CA admin password"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# import CA signing cert
docker exec "$CONTAINER" pki-server cert-export ca_signing --cert-file ca_signing.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert ca_signing.crt \
    --trust CT,C,C \
    ca_signing

# correct password should work
docker exec "$CONTAINER" pki -u caadmin -w Secret.123 ca-user-find

# wrong password should not work
docker exec "$CONTAINER" pki -u caadmin -w wrong ca-user-find \
    > stdout 2> stderr || true

echo "UnauthorizedException: " > expected
diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check auth with CA admin password (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Change CA admin password"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-user-mod --password new caadmin

# original password should no longer work
docker exec "$CONTAINER" pki -u caadmin -w Secret.123 ca-user-find \
    > stdout 2> stderr || true

echo "UnauthorizedException: " > expected
diff expected stderr

# new password should work
docker exec "$CONTAINER" pki -u caadmin -w new ca-user-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Change CA admin password (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Change CA admin password with file"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo secret > secret.txt
docker exec "$CONTAINER" pki-server ca-user-mod --password-file $SHARED/secret.txt caadmin

# password file should work
docker exec "$CONTAINER" pki -u caadmin -w secret ca-user-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Change CA admin password with file (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA admin password"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA admin password (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check certs assigned to CA admin user"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-user-cert-find caadmin | tee output

# get admin cert ID
sed -n 's/^ *Cert ID: *\(.*\)$/\1/p' output > cert.id
CERT_ID=$(cat cert.id)
echo "CERT_ID: $CERT_ID"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs assigned to CA admin user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check auth with CA admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# import admin cert
docker exec "$CONTAINER" pki pkcs12-import \
    --pkcs12 /root/.dogtag/pki-tomcat/ca_admin_cert.p12 \
    --pkcs12-password Secret.123

# admin cert should work
docker exec "$CONTAINER" pki -n caadmin ca-user-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check auth with CA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Unassign certs from CA admin user"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_ID=$(cat cert.id)
echo "CERT_ID: $CERT_ID"

docker exec "$CONTAINER" pki-server ca-user-cert-del caadmin "$CERT_ID"

# admin user should have no certs
docker exec "$CONTAINER" pki-server ca-user-cert-find caadmin | tee actual
diff /dev/null actual

# admin cert should no longer work
docker exec "$CONTAINER" pki -n caadmin ca-user-find \
    > stdout 2> stderr || true

echo "UnauthorizedException: " > expected
diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Unassign certs from CA admin user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Reassign certs to CA admin user"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_ID=$(cat cert.id)
echo "CERT_ID: $CERT_ID"

docker exec "$CONTAINER" pki nss-cert-export caadmin > caadmin.crt
cat caadmin.crt | docker exec -i pki "$CONTAINER"-server ca-user-cert-add caadmin

# new admin cert ID should match the original admin cert ID
docker exec "$CONTAINER" pki-server ca-user-cert-find caadmin | tee output
sed -n 's/^ *Cert ID: *\(.*\)$/\1/p' output > actual
diff cert.id actual

# admin cert should work again
docker exec "$CONTAINER" pki -n caadmin ca-user-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Reassign certs to CA admin user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin roles"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-user-role-find caadmin | tee output

echo "Administrators" > expected
echo "Certificate Manager Agents" >> expected
echo "Enterprise CA Administrators" >> expected
echo "Enterprise EST Administrators" >> expected
echo "Enterprise KRA Administrators" >> expected
echo "Enterprise OCSP Administrators" >> expected
echo "Enterprise RA Administrators" >> expected
echo "Enterprise TKS Administrators" >> expected
echo "Enterprise TPS Administrators" >> expected
echo "Security Domain Administrators" >> expected

sed -n 's/^ *Role ID: *\(.*\)$/\1/p' output | sort > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin roles (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA admin role"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA admin role (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Authorization with CA admin cert should not work"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki -n caadmin ca-user-find \
    > stdout 2> stderr || true

echo "ForbiddenException: Authorization Error" > expected
diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Authorization with CA admin cert should not work (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Restore CA admin role"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-user-role-add caadmin Administrators
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Restore CA admin role (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Authorization with CA admin cert should work again"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki -n caadmin ca-user-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Authorization with CA admin cert should work again (rc=$_rc)" >&2
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
    echo "==== ca-admin-user-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-admin-user-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-admin-user-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-admin-user-test PASSED ===="

