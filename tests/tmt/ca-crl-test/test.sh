#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-crl-test
# (GHA .github/workflows/ca-crl-test.yml). Packaged forge IPACTA.
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

step "Install dependencies"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Install dependencies"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install dependencies (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

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

step "Check pki ca-crl CLI help messages"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki ca-crl-update --help
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check pki ca-crl CLI help messages (rc=$_rc)" >&2
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

step "Configure caUserCert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set cert validity to 1 minute
VALIDITY_DEFAULT="policyset.userCertSet.2.default.params"
docker exec "$CONTAINER" sed -i \
    -e "s/^$VALIDITY_DEFAULT.range=.*$/$VALIDITY_DEFAULT.range=1/" \
    -e "/^$VALIDITY_DEFAULT.range=.*$/a $VALIDITY_DEFAULT.rangeUnit=minute" \
    /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caUserCert.cfg

# check updated profile
docker exec "$CONTAINER" cat /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caUserCert.cfg
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure caUserCert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CRL issuing points"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-crl-ip-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CRL issuing points (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Update CRL configuration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# update cert status every minute
docker exec "$CONTAINER" pki-server ca-config-set ca.certStatusUpdateInterval 60

# update CRL immediately after each cert revocation
docker exec "$CONTAINER" pki-server ca-crl-ip-mod -D alwaysUpdate=true MasterCRL

docker exec "$CONTAINER" pki-server ca-crl-ip-show MasterCRL
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Update CRL configuration (rc=$_rc)" >&2
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

step "Check initial CRL"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be no revoked certs
docker exec "$CONTAINER" pki-server ca-crl-record-show MasterCRL | tee output

sed -n \
    -e '/^\s*CRL Number:/p' \
    -e '/^\s*CRL Size:/p' \
    output > actual

cat > expected << EOF
  CRL Number: 0x1
  CRL Size: 0
EOF

diff expected actual

docker exec "$CONTAINER" pki-server ca-crl-record-cert-find MasterCRL | tee output

diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial CRL (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll user 1 cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki client-cert-request uid=testuser1 | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"

docker exec "$CONTAINER" pki -n caadmin ca-cert-request-approve $REQUEST_ID --force | tee output
CERT_ID=$(sed -n -e 's/^ *Certificate ID: *\(.*\)$/\1/p' output)
echo "CERT_ID: $CERT_ID"
echo $CERT_ID > cert.id

docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be valid
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll user 1 cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Revoke user 1 cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_ID=$(cat cert.id)
docker exec "$CONTAINER" pki -n caadmin ca-cert-hold $CERT_ID --force

docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be revoked
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "REVOKED" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Revoke user 1 cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CRL after user 1 cert revocation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be one revoked cert
docker exec "$CONTAINER" pki-server ca-crl-record-show MasterCRL | tee output

sed -n \
    -e '/^\s*CRL Number:/p' \
    -e '/^\s*CRL Size:/p' \
    output > actual

cat > expected << EOF
  CRL Number: 0x2
  CRL Size: 1
EOF

diff expected actual

docker exec "$CONTAINER" pki-server ca-crl-record-cert-find MasterCRL | tee output

sed -n \
    -e '/^\s*Serial Number:/p' \
    -e '/^\s*Reason:/p' \
    output > actual

CERT_ID=$(cat cert.id)
cat > expected << EOF
  Serial Number: $CERT_ID
  Reason: CERTIFICATE_HOLD
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CRL after user 1 cert revocation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check VLV usage in DS access log"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# Check if VLV index was used during CRL generation
# The query for revoked certs should use the allRevokedCertsByIssuer VLV index
echo "Checking DS access log for VLV usage during CRL generation:"
docker exec "$CONTAINER" sh -c "grep 'certStatus=REVOKED' /var/log/dirsrv/slapd-localhost/access* || true"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check VLV usage in DS access log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Unrevoke user 1 cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_ID=$(cat cert.id)
docker exec "$CONTAINER" pki -n caadmin ca-cert-release-hold $CERT_ID --force

docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be valid
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Unrevoke user 1 cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CRL after user 1 cert unrevocation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be no revoked certs
docker exec "$CONTAINER" pki-server ca-crl-record-show MasterCRL | tee output

sed -n \
    -e '/^\s*CRL Number:/p' \
    -e '/^\s*CRL Size:/p' \
    output > actual

cat > expected << EOF
  CRL Number: 0x3
  CRL Size: 0
EOF

diff expected actual

docker exec "$CONTAINER" pki-server ca-crl-record-cert-find MasterCRL | tee output

diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CRL after user 1 cert unrevocation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll user 2 cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki client-cert-request uid=testuser2 | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"

docker exec "$CONTAINER" pki -n caadmin ca-cert-request-approve $REQUEST_ID --force | tee output
CERT_ID=$(sed -n -e 's/^ *Certificate ID: *\(.*\)$/\1/p' output)
echo "CERT_ID: $CERT_ID"
echo $CERT_ID > cert.id

docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be valid
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll user 2 cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Revoke user 2 cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_ID=$(cat cert.id)
docker exec "$CONTAINER" pki -n caadmin ca-cert-hold $CERT_ID --force

docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be revoked
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "REVOKED" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Revoke user 2 cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CRL after user 2 cert revocation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be one revoked cert
docker exec "$CONTAINER" pki-server ca-crl-record-show MasterCRL | tee output

sed -n \
    -e '/^\s*CRL Number:/p' \
    -e '/^\s*CRL Size:/p' \
    output > actual

cat > expected << EOF
  CRL Number: 0x4
  CRL Size: 1
EOF

diff expected actual

docker exec "$CONTAINER" pki-server ca-crl-record-cert-find MasterCRL | tee output

sed -n \
    -e '/^\s*Serial Number:/p' \
    -e '/^\s*Reason:/p' \
    output > actual

CERT_ID=$(cat cert.id)
cat > expected << EOF
  Serial Number: $CERT_ID
  Reason: CERTIFICATE_HOLD
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CRL after user 2 cert revocation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Wait for user 2 cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
sleep 120

CERT_ID=$(cat cert.id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be revoked and expired
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "REVOKED_EXPIRED" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Wait for user 2 cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Force CRL update after user 2 cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# force CRL update
docker exec "$CONTAINER" pki -n caadmin ca-crl-update

# wait for CRL update
sleep 10
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Force CRL update after user 2 cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CRL after user 2 cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# there should be no revoked certs
docker exec "$CONTAINER" pki-server ca-crl-record-show MasterCRL | tee output

sed -n \
    -e '/^\s*CRL Number:/p' \
    -e '/^\s*CRL Size:/p' \
    output > actual

cat > expected << EOF
  CRL Number: 0x5
  CRL Size: 0
EOF

diff expected actual

docker exec "$CONTAINER" pki-server ca-crl-record-cert-find MasterCRL | tee output

diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CRL after user 2 cert expiration (rc=$_rc)" >&2
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
    echo "==== ca-crl-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-crl-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-crl-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-crl-test PASSED ===="

