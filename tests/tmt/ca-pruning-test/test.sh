#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-pruning-test
# (GHA .github/workflows/ca-pruning-test.yml). Packaged forge IPACTA.
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

step "Configure server cert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set cert validity to 1 minute
VALIDITY_DEFAULT="policyset.serverCertSet.2.default.params"
docker exec "$CONTAINER" sed -i \
    -e "s/^$VALIDITY_DEFAULT.range=.*$/$VALIDITY_DEFAULT.range=1/" \
    -e "/^$VALIDITY_DEFAULT.range=.*$/a $VALIDITY_DEFAULT.rangeUnit=minute" \
    /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caServerCert.cfg

# check updated profile
docker exec "$CONTAINER" cat /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caServerCert.cfg
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure server cert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure user cert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set cert validity to 4 minute
VALIDITY_DEFAULT="policyset.userCertSet.2.default.params"
docker exec "$CONTAINER" sed -i \
    -e "s/^$VALIDITY_DEFAULT.range=.*$/$VALIDITY_DEFAULT.range=4/" \
    -e "/^$VALIDITY_DEFAULT.range=.*$/a $VALIDITY_DEFAULT.rangeUnit=minute" \
    /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caUserCert.cfg

# check updated profile
docker exec "$CONTAINER" cat /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caUserCert.cfg
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure user cert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure cert status update task"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# configure task to run every minute
docker exec "$CONTAINER" pki-server ca-config-set ca.certStatusUpdateInterval 60
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure cert status update task (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure pruning job"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# configure pruning to run manually without retention time
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.enabled true
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.job.pruning.enabled true
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.job.pruning.certRetentionTime 0
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.job.pruning.certRetentionUnit minute
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.job.pruning.requestRetentionTime 0
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.job.pruning.requestRetentionUnit minute
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure pruning job (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Restart CA subsystem"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Restart CA subsystem (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install CA admin cert"
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
docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check initial certs and requests"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be 6 requests initially
docker exec "$CONTAINER" pki -n caadmin ca-cert-request-find | tee output

echo "6" > expected
{ grep "Request ID:" output || true; } | wc -l > actual
diff expected actual

# there should be 6 certs initially
docker exec "$CONTAINER" pki ca-cert-find | tee output

echo "6" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial certs and requests (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll server cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki client-cert-request \
    --profile caServerCert \
    cn=server.example.com | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"
echo $REQUEST_ID > server-request-id

docker exec "$CONTAINER" pki -n caadmin ca-cert-request-approve $REQUEST_ID --force | tee output
CERT_ID=$(sed -n -e 's/^ *Certificate ID: *\(.*\)$/\1/p' output)
echo "CERT_ID: $CERT_ID"
echo $CERT_ID > server-cert-id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll server cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create incomplete server cert request"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki client-cert-request \
    --profile caServerCert \
    cn=server.example.com | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"
echo $REQUEST_ID > incomplete-server-request-id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create incomplete server cert request (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll user cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki client-cert-request \
    --profile caUserCert \
    uid=testuser | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"
echo $REQUEST_ID > user-request-id

docker exec "$CONTAINER" pki -n caadmin ca-cert-request-approve $REQUEST_ID --force | tee output
CERT_ID=$(sed -n -e 's/^ *Certificate ID: *\(.*\)$/\1/p' output)
echo "CERT_ID: $CERT_ID"
echo $CERT_ID > user-cert-id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll user cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create incomplete user cert request"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki client-cert-request \
    --profile caUserCert \
    uid=testuser | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"
echo $REQUEST_ID > incomplete-user-request-id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create incomplete user cert request (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check certs after enrollments"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be 8 certs now
docker exec "$CONTAINER" pki ca-cert-find | tee output

echo "8" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual

# the server cert should exist
CERT_ID=$(cat server-cert-id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# the server cert should be valid
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual

# the user cert should exist
CERT_ID=$(cat user-cert-id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# the user cert should be valid
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs after enrollments (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check requests after enrollments"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be 10 requests now
docker exec "$CONTAINER" pki -n caadmin ca-cert-request-find | tee output

echo "10" > expected
{ grep "Request ID:" output || true; } | wc -l > actual
diff expected actual

# the completed server request should exist
REQUEST_ID=$(cat server-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID

# the incomplete server request should exist
REQUEST_ID=$(cat incomplete-server-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID

# the completed user request should exist
REQUEST_ID=$(cat user-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID

# the incomplete user request should exist
REQUEST_ID=$(cat incomplete-user-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests after enrollments (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Wait for server cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
sleep 120
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Wait for server cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check certs after server cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should still be 8 certs
docker exec "$CONTAINER" pki ca-cert-find | tee output

echo "8" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual

# the server cert should still exist
CERT_ID=$(cat server-cert-id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# the server cert should be expired now
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "EXPIRED" > expected
diff expected actual

# the user cert should still exist
CERT_ID=$(cat user-cert-id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# the user cert should still be valid
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs after server cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check requests after server cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should still be 10 requests
docker exec "$CONTAINER" pki -n caadmin ca-cert-request-find | tee output

echo "10" > expected
{ grep "Request ID:" output || true; } | wc -l > actual
diff expected actual

# the completed server request should still exist
REQUEST_ID=$(cat server-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID

# the incomplete server request should still exist
REQUEST_ID=$(cat incomplete-server-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID

# the completed user request should still exist
REQUEST_ID=$(cat user-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID

# the incomplete user request should still exist
REQUEST_ID=$(cat incomplete-user-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests after server cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Start the first pruning"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki -n caadmin ca-job-start pruning

sleep 30
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Start the first pruning (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check certs after the first pruning"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be 7 certs now
docker exec "$CONTAINER" pki ca-cert-find | tee output

echo "7" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual

# the expired server cert should be removed
CERT_ID=$(cat server-cert-id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID \
    > stdout 2> stderr || true

echo "CertNotFoundException: Certificate ID $CERT_ID not found" > expected
diff expected stderr

# the user cert should still exist
CERT_ID=$(cat user-cert-id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# the user cert should still be valid
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs after the first pruning (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check requests after the first pruning"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be 7 requests now
docker exec "$CONTAINER" pki -n caadmin ca-cert-request-find | tee output

echo "7" > expected
{ grep "Request ID:" output || true; } | wc -l > actual
diff expected actual

# the completed server request should be removed
REQUEST_ID=$(cat server-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID \
    > stdout 2> stderr || true

echo "RequestNotFoundException: Request ID $REQUEST_ID not found" > expected
diff expected stderr

# the incomplete server request should be removed
REQUEST_ID=$(cat incomplete-server-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID \
    > stdout 2> stderr || true

echo "RequestNotFoundException: Request ID $REQUEST_ID not found" > expected
diff expected stderr

# the completed user request should still exist
REQUEST_ID=$(cat user-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID

# the incomplete user request should be removed
REQUEST_ID=$(cat incomplete-user-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID \
    > stdout 2> stderr || true

echo "RequestNotFoundException: Request ID $REQUEST_ID not found" > expected
diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests after the first pruning (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Wait for user cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
sleep 120
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Wait for user cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check certs after user cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should still be 7 certs
docker exec "$CONTAINER" pki ca-cert-find | tee output

echo "7" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual

# the user cert should still exist
CERT_ID=$(cat user-cert-id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# the user cert should be expired now
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "EXPIRED" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs after user cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check requests after user cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should still be 7 requests
docker exec "$CONTAINER" pki -n caadmin ca-cert-request-find | tee output

echo "7" > expected
{ grep "Request ID:" output || true; } | wc -l > actual
diff expected actual

# the completed user request should still exist
REQUEST_ID=$(cat user-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests after user cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Start the second pruning"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki -n caadmin ca-job-start pruning

sleep 30
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Start the second pruning (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check certs after the second pruning"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be 6 certs again
docker exec "$CONTAINER" pki ca-cert-find | tee output

echo "6" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual

# the expired user cert should be removed
CERT_ID=$(cat user-cert-id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID \
    > stdout 2> stderr || true

echo "CertNotFoundException: Certificate ID $CERT_ID not found" > expected
diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs after the second pruning (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check requests after the second pruning"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be 6 requests again
docker exec "$CONTAINER" pki -n caadmin ca-cert-request-find | tee output

echo "6" > expected
{ grep "Request ID:" output || true; } | wc -l > actual
diff expected actual

# the completed user request should be removed
REQUEST_ID=$(cat user-request-id)
docker exec "$CONTAINER" pki ca-cert-request-show $REQUEST_ID \
    > stdout 2> stderr || true

echo "RequestNotFoundException: Request ID $REQUEST_ID not found" > expected
diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests after the second pruning (rc=$_rc)" >&2
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
    echo "==== ca-pruning-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-pruning-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-pruning-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-pruning-test PASSED ===="

