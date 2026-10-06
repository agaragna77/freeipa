#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-profile-caServerCert-test
# (GHA .github/workflows/ca-profile-caServerCert-test.yml). Packaged forge IPACTA.
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

step "Configure caServerCert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# allow user-specified SAN extension
docker exec "$CONTAINER" sed -i \
    -e "s/^\(policyset.serverCertSet.list\)=\(.*\)$/\1=\2,13/" \
    -e '$ a policyset.serverCertSet.13.constraint.class_id=noConstraintImpl' \
    -e '$ a policyset.serverCertSet.13.constraint.name=No Constraint' \
    -e '$ a policyset.serverCertSet.13.default.class_id=userExtensionDefaultImpl' \
    -e '$ a policyset.serverCertSet.13.default.name=User supplied extension in CSR' \
    -e '$ a policyset.serverCertSet.13.default.params.userExtOID=2.5.29.17' \
    /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caServerCert.cfg

# require unique subject name
docker exec "$CONTAINER" sed -i \
    -e "s/^\(policyset.serverCertSet.list\)=\(.*\)$/\1=\2,14/" \
    -e '$ a policyset.serverCertSet.14.constraint.class_id=uniqueSubjectNameConstraintImpl' \
    -e '$ a policyset.serverCertSet.14.constraint.name=Unique Subject Name Constraint' \
    -e '$ a policyset.serverCertSet.14.default.class_id=noDefaultImpl' \
    -e '$ a policyset.serverCertSet.14.default.name=No Default' \
    /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caServerCert.cfg

# check updated profile
docker exec "$CONTAINER" cat /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caServerCert.cfg

docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure caServerCert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up CA admin"
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
    echo "FAIL: Set up CA admin (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create SSL server cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate cert request
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=server.example.com" \
    --ext /usr/share/pki/server/certs/sslserver.conf \
    --subjectAltName "critical, DNS:www.example.com" \
    --csr sslserver.csr

docker exec "$CONTAINER" openssl req -text -noout -in sslserver.csr | tee output

# verify SAN extension in cert request
echo "X509v3 Subject Alternative Name: critical" > expected
echo "DNS:www.example.com" >> expected
sed -En 'N; s/^ *(X509v3 Subject Alternative Name: .*)\n *(.*)$/\1\n\2/p; D' output | tee actual
diff actual expected

# issue cert
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --profile caServerCert \
    --csr-file sslserver.csr \
    --output-file sslserver.crt

docker exec "$CONTAINER" openssl x509 -text -noout -in sslserver.crt | tee output

# verfiy SAN extension in cert
echo "X509v3 Subject Alternative Name: critical" > expected
echo "DNS:www.example.com" >> expected
sed -En 'N; s/^ *(X509v3 Subject Alternative Name: .*)\n *(.*)$/\1\n\2/p; D' output | tee actual
diff actual expected
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create SSL server cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create SSL server cert with same subject name"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate cert request
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=server.example.com" \
    --ext /usr/share/pki/server/certs/sslserver.conf \
    --subjectAltName "critical, DNS:pki.example.com" \
    --csr sslserver.csr

docker exec "$CONTAINER" openssl req -text -noout -in sslserver.csr | tee output

# verify SAN extension
echo "X509v3 Subject Alternative Name: critical" > expected
echo "DNS:pki.example.com" >> expected
sed -En 'N; s/^ *(X509v3 Subject Alternative Name: .*)\n *(.*)$/\1\n\2/p; D' output | tee actual
diff actual expected

# issue cert
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --profile caServerCert \
    --csr-file sslserver.csr \
    > stdout 2> stderr || true

# request should be rejected by UniqueSubjectNameConstraint
cat > expected << EOF
ERROR: Request rejected: Subject Name Not Unique CN=server.example.com
EOF

diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create SSL server cert with same subject name (rc=$_rc)" >&2
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
    echo "==== ca-profile-caServerCert-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-profile-caServerCert-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-profile-caServerCert-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-profile-caServerCert-test PASSED ===="

