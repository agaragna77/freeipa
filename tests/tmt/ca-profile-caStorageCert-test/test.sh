#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-profile-caStorageCert-test
# (GHA .github/workflows/ca-profile-caStorageCert-test.yml). Packaged forge IPACTA.
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

step "Enroll cert using PKCS10Client"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate PKCS #10 request
docker exec "$CONTAINER" PKCS10Client \
    -d /root/.dogtag/nssdb \
    -n "CN=test-PKCS10Client" \
    -o test-PKCS10Client.csr

docker exec "$CONTAINER" cat test-PKCS10Client.csr

docker exec "$CONTAINER" AtoB test-PKCS10Client.csr test-PKCS10Client.der

# ignore invalid PKCS #10 data
docker exec "$CONTAINER" dumpasn1 test-PKCS10Client.der || true

# issue cert
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --profile caStorageCert \
    --csr-file test-PKCS10Client.csr \
    --output-file test-PKCS10Client.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import \
    --cert test-PKCS10Client.crt \
    test-PKCS10Client

docker exec "$CONTAINER" pki nss-cert-show test-PKCS10Client | tee output

# normalize output
sed \
    -e '/^ *Serial Number:/d' \
    -e '/^ *Not Valid Before:/d' \
    -e '/^ *Not Valid After:/d' \
    output > actual

# the cert should match the key (trust flags must be u,u,u)
cat > expected << EOF
  Nickname: test-PKCS10Client
  Subject DN: CN=test-PKCS10Client
  Issuer DN: CN=CA Signing Certificate,OU=pki-tomcat,O=EXAMPLE
  Trust Flags: u,u,u
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll cert using PKCS10Client (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll cert using CRMFPopClient without POP"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate CRMF request
docker exec "$CONTAINER" CRMFPopClient \
    -d /root/.dogtag/nssdb \
    -p "" \
    -n "CN=test-CRMFPopClient-without-POP" \
    -q POP_NONE \
    -o test-CRMFPopClient-without-POP.csr \
    -v

docker exec "$CONTAINER" cat test-CRMFPopClient-without-POP.csr

docker exec "$CONTAINER" AtoB test-CRMFPopClient-without-POP.csr test-CRMFPopClient-without-POP.der
docker exec "$CONTAINER" dumpasn1 test-CRMFPopClient-without-POP.der

# issue cert
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --request-type crmf \
    --profile caStorageCert \
    --subject CN=test-CRMFPopClient-without-POP \
    --csr-file test-CRMFPopClient-without-POP.csr \
    --output-file test-CRMFPopClient-without-POP.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import \
    --cert test-CRMFPopClient-without-POP.crt \
    test-CRMFPopClient-without-POP

docker exec "$CONTAINER" pki nss-cert-show test-CRMFPopClient-without-POP | tee output

# normalize output
sed \
    -e '/^ *Serial Number:/d' \
    -e '/^ *Not Valid Before:/d' \
    -e '/^ *Not Valid After:/d' \
    output > actual

# the cert should match the key (trust flags must be u,u,u)
cat > expected << EOF
  Nickname: test-CRMFPopClient-without-POP
  Subject DN: CN=test-CRMFPopClient-without-POP
  Issuer DN: CN=CA Signing Certificate,OU=pki-tomcat,O=EXAMPLE
  Trust Flags: u,u,u
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll cert using CRMFPopClient without POP (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll cert using CRMFPopClient with POP"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate CRMF request
docker exec "$CONTAINER" CRMFPopClient \
    -d /root/.dogtag/nssdb \
    -p "" \
    -n "CN=test-CRMFPopClient-with-POP" \
    -o test-CRMFPopClient-with-POP.csr \
    -v

docker exec "$CONTAINER" cat test-CRMFPopClient-with-POP.csr

docker exec "$CONTAINER" AtoB test-CRMFPopClient-with-POP.csr test-CRMFPopClient-with-POP.der
docker exec "$CONTAINER" dumpasn1 test-CRMFPopClient-with-POP.der

# issue cert
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --request-type crmf \
    --profile caStorageCert \
    --subject CN=test-CRMFPopClient-with-POP \
    --csr-file test-CRMFPopClient-with-POP.csr \
    --output-file test-CRMFPopClient-with-POP.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import \
    --cert test-CRMFPopClient-with-POP.crt \
    test-CRMFPopClient-with-POP

docker exec "$CONTAINER" pki nss-cert-show test-CRMFPopClient-with-POP | tee output

# normalize output
sed \
    -e '/^ *Serial Number:/d' \
    -e '/^ *Not Valid Before:/d' \
    -e '/^ *Not Valid After:/d' \
    output > actual

# the cert should match the key (trust flags must be u,u,u)
cat > expected << EOF
  Nickname: test-CRMFPopClient-with-POP
  Subject DN: CN=test-CRMFPopClient-with-POP
  Issuer DN: CN=CA Signing Certificate,OU=pki-tomcat,O=EXAMPLE
  Trust Flags: u,u,u
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll cert using CRMFPopClient with POP (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll cert using PKI CLI with PKCS #10 request"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate PKCS #10 request
docker exec "$CONTAINER" pki nss-cert-request \
    --subject "CN=test-PKI-CLI-PKCS10" \
    --csr test-PKI-CLI-PKCS10.csr

docker exec "$CONTAINER" cat test-PKI-CLI-PKCS10.csr

docker exec "$CONTAINER" AtoB test-PKI-CLI-PKCS10.csr test-PKI-CLI-PKCS10.der

# ignore invalid PKCS #10 data
docker exec "$CONTAINER" dumpasn1 test-PKI-CLI-PKCS10.der || true

# issue cert
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --profile caStorageCert \
    --csr-file test-PKI-CLI-PKCS10.csr \
    --output-file test-PKI-CLI-PKCS10.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import \
    --cert test-PKI-CLI-PKCS10.crt \
    test-PKI-CLI-PKCS10

docker exec "$CONTAINER" pki nss-cert-show test-PKI-CLI-PKCS10 | tee output

# normalize output
sed \
    -e '/^ *Serial Number:/d' \
    -e '/^ *Not Valid Before:/d' \
    -e '/^ *Not Valid After:/d' \
    output > actual

# the cert should match the key (trust flags must be u,u,u)
cat > expected << EOF
  Nickname: test-PKI-CLI-PKCS10
  Subject DN: CN=test-PKI-CLI-PKCS10
  Issuer DN: CN=CA Signing Certificate,OU=pki-tomcat,O=EXAMPLE
  Trust Flags: u,u,u
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll cert using PKI CLI with PKCS #10 request (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll cert using PKI CLI with CRMF request without POP"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate CRMF request
docker exec "$CONTAINER" pki nss-cert-request \
    --type crmf \
    --subject "CN=test-PKI-CLI-CRMF-without-POP" \
    --csr test-PKI-CLI-CRMF-without-POP.csr

docker exec "$CONTAINER" cat test-PKI-CLI-CRMF-without-POP.csr

docker exec "$CONTAINER" AtoB test-PKI-CLI-CRMF-without-POP.csr test-PKI-CLI-CRMF-without-POP.der
docker exec "$CONTAINER" dumpasn1 test-PKI-CLI-CRMF-without-POP.der

# issue cert
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --request-type crmf \
    --profile caStorageCert \
    --subject CN=test-PKI-CLI-CRMF-without-POP \
    --csr-file test-PKI-CLI-CRMF-without-POP.csr \
    --output-file test-PKI-CLI-CRMF-without-POP.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import \
    --cert test-PKI-CLI-CRMF-without-POP.crt \
    test-PKI-CLI-CRMF-without-POP

docker exec "$CONTAINER" pki nss-cert-show test-PKI-CLI-CRMF-without-POP | tee output

# normalize output
sed \
    -e '/^ *Serial Number:/d' \
    -e '/^ *Not Valid Before:/d' \
    -e '/^ *Not Valid After:/d' \
    output > actual

# the cert should match the key (trust flags must be u,u,u)
cat > expected << EOF
  Nickname: test-PKI-CLI-CRMF-without-POP
  Subject DN: CN=test-PKI-CLI-CRMF-without-POP
  Issuer DN: CN=CA Signing Certificate,OU=pki-tomcat,O=EXAMPLE
  Trust Flags: u,u,u
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll cert using PKI CLI with CRMF request without POP (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll cert using PKI CLI with CRMF request with POP"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate CRMF request
docker exec "$CONTAINER" pki nss-cert-request \
    --type crmf \
    --pop \
    --subject "CN=test-PKI-CLI-CRMF-with-POP" \
    --csr test-PKI-CLI-CRMF-with-POP.csr

docker exec "$CONTAINER" cat test-PKI-CLI-CRMF-with-POP.csr

docker exec "$CONTAINER" AtoB test-PKI-CLI-CRMF-with-POP.csr test-PKI-CLI-CRMF-with-POP.der
docker exec "$CONTAINER" dumpasn1 test-PKI-CLI-CRMF-with-POP.der

# issue cert
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --request-type crmf \
    --profile caStorageCert \
    --subject CN=test-PKI-CLI-CRMF-with-POP \
    --csr-file test-PKI-CLI-CRMF-with-POP.csr \
    --output-file test-PKI-CLI-CRMF-with-POP.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import \
    --cert test-PKI-CLI-CRMF-with-POP.crt \
    test-PKI-CLI-CRMF-with-POP

docker exec "$CONTAINER" pki nss-cert-show test-PKI-CLI-CRMF-with-POP | tee output

# normalize output
sed \
    -e '/^ *Serial Number:/d' \
    -e '/^ *Not Valid Before:/d' \
    -e '/^ *Not Valid After:/d' \
    output > actual

# the cert should match the key (trust flags must be u,u,u)
cat > expected << EOF
  Nickname: test-PKI-CLI-CRMF-with-POP
  Subject DN: CN=test-PKI-CLI-CRMF-with-POP
  Issuer DN: CN=CA Signing Certificate,OU=pki-tomcat,O=EXAMPLE
  Trust Flags: u,u,u
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll cert using PKI CLI with CRMF request with POP (rc=$_rc)" >&2
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

step "Check for core dumps"
# GHA if: failure() — run only if a prior step failed
if [[ "$GHA_FAILED" -ne 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ls -l
docker exec "$CONTAINER" find / -path /proc -prune -o -name "hs_err_pid*.log" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check for core dumps (rc=$_rc)" >&2
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
    echo "==== ca-profile-caStorageCert-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-profile-caStorageCert-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-profile-caStorageCert-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-profile-caStorageCert-test PASSED ===="

