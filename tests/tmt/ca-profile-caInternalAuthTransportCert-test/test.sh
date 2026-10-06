#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-profile-caInternalAuthTransportCert-test
# (GHA .github/workflows/ca-profile-caInternalAuthTransportCert-test.yml). Packaged forge IPACTA.
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

step "Get Fedora version"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
FEDORA_VERSION=$(iexec sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"')
echo "FEDORA_VERSION=$FEDORA_VERSION"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Get Fedora version (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enable ML-DSA in default crypto-policies"
if [[ "$GHA_FAILED" -eq 0 ]] && [[ "${FEDORA_VERSION}" -lt 44 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" sed -i \
    's/smime-key-exchange:ECDSA/smime-key-exchange:ML-DSA-65:ECDSA/' \
    /etc/crypto-policies/back-ends/nss.config
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enable ML-DSA in default crypto-policies (rc=$_rc)" >&2
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

step "Configure caInternalAuthTransportCert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# allow ML-KEM-768 via allowedKeys (after RSA allowedKeys block)
docker exec "$CONTAINER" sed -i \
    -e '/^policyset\.transportCertSet\.3\.constraint\.params\.allowedKeys\.RSA\.4096=true/a policyset.transportCertSet.3.constraint.params.allowedKeys.MLKEM.768=true' \
    /var/lib/pki/pki-tomcat/ca/profiles/ca/caInternalAuthTransportCert.cfg

# restart CA
docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure caInternalAuthTransportCert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up CA admin"
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
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up CA admin (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create SD session"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# authenticate as security domain admin
docker exec "$CONTAINER" curl \
    -k \
    -s \
    -H "Accept: application/json" \
    --user caadmin:Secret.123 \
    --cookie-jar cookies \
    https://pki.example.com:8443/ca/v2/account/login \
    | python -m json.tool

# create security domain session
docker exec "$CONTAINER" curl \
    -k \
    -s \
    --cookie cookies \
    "https://pki.example.com:8443/ca/v2/securityDomain/installToken?hostname=pki.example.com&subsystem=CA" \
    | python -m json.tool \
    | tee session.json

# TODO: implement pki sd-session-create
# docker exec "$CONTAINER" pki \
#     -u caadmin \
#     -w Secret.123 \
#     sd-session-create \
#     --session-file session.json

# store install token
jq -r '.token' session.json > install-token
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create SD session (rc=$_rc)" >&2
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
    -a mlkem \
    -l 768 \
    -t false \
    -f caInternalAuthTransportCert \
    -n "CN=test-CRMFPopClient-without-POP" \
    -q POP_NONE \
    -o test-CRMFPopClient-without-POP.csr

docker exec "$CONTAINER" certutil -K -d /root/.dogtag/nssdb

docker exec "$CONTAINER" cat test-CRMFPopClient-without-POP.csr

docker exec "$CONTAINER" AtoB test-CRMFPopClient-without-POP.csr test-CRMFPopClient-without-POP.der
docker exec "$CONTAINER" dumpasn1 test-CRMFPopClient-without-POP.der

# issue cert
docker exec "$CONTAINER" pki \
    ca-cert-issue \
    --install-token $SHARED/install-token \
    --request-type crmf \
    --profile caInternalAuthTransportCert \
    --subject CN=test-CRMFPopClient-without-POP \
    --csr-file test-CRMFPopClient-without-POP.csr \
    --output-file test-CRMFPopClient-without-POP.crt

docker exec "$CONTAINER" openssl x509 -text -noout -in test-CRMFPopClient-without-POP.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import \
    --cert test-CRMFPopClient-without-POP.crt \
    test-CRMFPopClient-without-POP

docker exec "$CONTAINER" certutil -K -d /root/.dogtag/nssdb

docker exec "$CONTAINER" pki nss-cert-show test-CRMFPopClient-without-POP | tee output

# normalize output
sed \
    -e '/^ *Serial Number:/d' \
    -e '/^ *Not Valid Before:/d' \
    -e '/^ *Not Valid After:/d' \
    output > actual

# the cert should match the key (trust attributes must be u,u,u)
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

step "Enroll cert using PKI CLI with CRMF request without POP"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate CRMF request
docker exec "$CONTAINER" pki nss-cert-request \
    --type crmf \
    --key-type MLKEM \
    --subject "CN=test-PKI-CLI-CRMF-without-POP" \
    --csr test-PKI-CLI-CRMF-without-POP.csr

docker exec "$CONTAINER" cat test-PKI-CLI-CRMF-without-POP.csr

docker exec "$CONTAINER" AtoB test-PKI-CLI-CRMF-without-POP.csr test-PKI-CLI-CRMF-without-POP.der
docker exec "$CONTAINER" dumpasn1 test-PKI-CLI-CRMF-without-POP.der

# issue cert
docker exec "$CONTAINER" pki \
    ca-cert-issue \
    --install-token $SHARED/install-token \
    --request-type crmf \
    --profile caInternalAuthTransportCert \
    --subject CN=test-PKI-CLI-CRMF-without-POP \
    --csr-file test-PKI-CLI-CRMF-without-POP.csr \
    --output-file test-PKI-CLI-CRMF-without-POP.crt

docker exec "$CONTAINER" openssl x509 -text -noout -in test-PKI-CLI-CRMF-without-POP.crt

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

# the cert should match the key (trust attributes must be u,u,u)
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

step "Remove SD session"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# remove security domain session
# TODO: implement REST API

# TODO: implement pki sd-session-del
# docker exec "$CONTAINER" pki \
#     -u caadmin \
#     -w Secret.123 \
#     sd-session-del \
#     --session-file session.json
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove SD session (rc=$_rc)" >&2
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
    echo "==== ca-profile-caInternalAuthTransportCert-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-profile-caInternalAuthTransportCert-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-profile-caInternalAuthTransportCert-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-profile-caInternalAuthTransportCert-test PASSED ===="

