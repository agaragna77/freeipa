#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-existing-certs-test
# (GHA .github/workflows/ca-existing-certs-test.yml). Packaged forge IPACTA.
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

step "Create CA signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=CA Signing Certificate" \
    --ext /usr/share/pki/server/certs/ca_signing.conf \
    --csr ca_signing.csr
docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --csr ca_signing.csr \
    --ext /usr/share/pki/server/certs/ca_signing.conf \
    --cert ca_signing.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert ca_signing.crt \
    --trust CT,C,C \
    ca_signing

# check original cert
docker exec "$CONTAINER" pki \
    nss-cert-show \
    ca_signing | tee ca_signing.crt.before

# check original key
docker exec "$CONTAINER" pki \
    nss-key-find \
    --nickname ca_signing | tee ca_signing.key.before

docker exec "$CONTAINER" pki nss-cert-verify \
    --cert-usage SSLCA \
    ca_signing
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create CA signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create CA OCSP signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=OCSP Signing Certificate" \
    --ext /usr/share/pki/server/certs/ocsp_signing.conf \
    --csr ca_ocsp_signing.csr
docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --issuer ca_signing \
    --csr ca_ocsp_signing.csr \
    --ext /usr/share/pki/server/certs/ocsp_signing.conf \
    --cert ca_ocsp_signing.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert ca_ocsp_signing.crt \
    ca_ocsp_signing

# check original cert
docker exec "$CONTAINER" pki \
    nss-cert-show \
    ca_ocsp_signing | tee ca_ocsp_signing.crt.before

# check original key
docker exec "$CONTAINER" pki \
    nss-key-find \
    --nickname ca_ocsp_signing | tee ca_ocsp_signing.key.before

docker exec "$CONTAINER" pki nss-cert-verify \
    --cert-usage StatusResponder \
    ca_ocsp_signing
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create CA OCSP signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create CA audit signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=Audit Signing Certificate" \
    --ext /usr/share/pki/server/certs/audit_signing.conf \
    --csr ca_audit_signing.csr
docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --issuer ca_signing \
    --csr ca_audit_signing.csr \
    --ext /usr/share/pki/server/certs/audit_signing.conf \
    --cert ca_audit_signing.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert ca_audit_signing.crt \
    --trust ,,P \
    ca_audit_signing

# check original cert
docker exec "$CONTAINER" pki \
    nss-cert-show \
    ca_audit_signing | tee ca_audit_signing.crt.before

# check original key
docker exec "$CONTAINER" pki \
    nss-key-find \
    --nickname ca_audit_signing | tee ca_audit_signing.key.before

docker exec "$CONTAINER" pki nss-cert-verify \
    --cert-usage ObjectSigner \
    ca_audit_signing
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create CA audit signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create subsystem cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=Subsystem Certificate" \
    --ext /usr/share/pki/server/certs/subsystem.conf \
    --csr subsystem.csr
docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --issuer ca_signing \
    --csr subsystem.csr \
    --ext /usr/share/pki/server/certs/subsystem.conf \
    --cert subsystem.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert subsystem.crt \
    subsystem

# check original cert
docker exec "$CONTAINER" pki \
    nss-cert-show \
    subsystem | tee subsystem.crt.before

# check original key
docker exec "$CONTAINER" pki \
    nss-key-find \
    --nickname subsystem | tee subsystem.key.before

docker exec "$CONTAINER" pki nss-cert-verify \
    --cert-usage SSLClient \
    subsystem
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create subsystem cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create SSL server cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=pki.example.com" \
    --ext /usr/share/pki/server/certs/sslserver.conf \
    --csr sslserver.csr
docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --issuer ca_signing \
    --csr sslserver.csr \
    --ext /usr/share/pki/server/certs/sslserver.conf \
    --cert sslserver.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert sslserver.crt \
    sslserver

# check original cert
docker exec "$CONTAINER" pki \
    nss-cert-show \
    sslserver | tee sslserver.crt.before

# check original key
docker exec "$CONTAINER" pki \
    nss-key-find \
    --nickname sslserver | tee sslserver.key.before

docker exec "$CONTAINER" pki nss-cert-verify \
    --cert-usage SSLServer \
    sslserver
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create SSL server cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Export system certs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    pkcs12-export \
    --pkcs12 ca-certs.p12 \
    --password Secret.123 \
    ca_signing \
    ca_ocsp_signing \
    ca_audit_signing \
    subsystem \
    sslserver
docker exec "$CONTAINER" pki \
    pkcs12-cert-find \
    --pkcs12 ca-certs.p12 \
    --password Secret.123
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Export system certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create self-signed admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create cert request
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=Administrator" \
    --ext /usr/share/pki/server/certs/admin.conf \
    --csr admin.csr

# create self-signed cert
docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --csr admin.csr \
    --ext /usr/share/pki/server/certs/admin.conf \
    --cert admin.crt

# import cert
docker exec "$CONTAINER" pki \
    nss-cert-import \
    --cert admin.crt \
    caadmin

# check cert
docker exec "$CONTAINER" pki nss-cert-show caadmin

# cert should be invalid
docker exec "$CONTAINER" pki nss-cert-verify caadmin \
    > stdout 2> stderr || true

cat > expected << EOF
ERROR: Invalid certificate: Unable to validate certificate signature: CN=Administrator
EOF

diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create self-signed admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install CA with existing system certs and self-signed admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# run step 1
docker exec "$CONTAINER" pkispawn \
    -f /usr/share/pki/server/examples/installation/ca.cfg \
    -s CA \
    -D pki_ds_url=ldap://ds.example.com:3389 \
    -D pki_external=True \
    -D pki_external_step_two=False \
    -v

# run step 2
rc=0
docker exec "$CONTAINER" pkispawn \
    -f /usr/share/pki/server/examples/installation/ca.cfg \
    -s CA \
    -D pki_ds_url=ldap://ds.example.com:3389 \
    -D pki_external=True \
    -D pki_external_step_two=True \
    -D pki_pkcs12_path=ca-certs.p12 \
    -D pki_pkcs12_password=Secret.123 \
    -D pki_ca_signing_csr_path=ca_signing.csr \
    -D pki_ocsp_signing_csr_path=ca_ocsp_signing.csr \
    -D pki_audit_signing_csr_path=ca_audit_signing.csr \
    -D pki_subsystem_csr_path=subsystem.csr \
    -D pki_sslserver_csr_path=sslserver.csr \
    -D pki_admin_cert_path=admin.crt \
    -D pki_admin_csr_path=admin.csr \
    -v \
    || rc=$?

# pkispawn should fail
[ $rc -ne 0 ]
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA with existing system certs and self-signed admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create CA-signed admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# remove old cert
docker exec "$CONTAINER" pki nss-cert-del caadmin

# create CA-signed cert
docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --issuer ca_signing \
    --csr admin.csr \
    --ext /usr/share/pki/server/certs/admin.conf \
    --cert admin.crt

# import new cert
docker exec "$CONTAINER" pki \
    nss-cert-import \
    --cert admin.crt \
    caadmin

# check new cert
docker exec "$CONTAINER" pki nss-cert-show caadmin

# cert should be valid
docker exec "$CONTAINER" pki nss-cert-verify caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create CA-signed admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install CA with existing system certs and CA-signed admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# run step 1
docker exec "$CONTAINER" pkispawn \
    -f /usr/share/pki/server/examples/installation/ca.cfg \
    -s CA \
    -D pki_ds_url=ldap://ds.example.com:3389 \
    -D pki_external=True \
    -D pki_external_step_two=False \
    -v

# run step 2
docker exec "$CONTAINER" pkispawn \
    -f /usr/share/pki/server/examples/installation/ca.cfg \
    -s CA \
    -D pki_ds_url=ldap://ds.example.com:3389 \
    -D pki_external=True \
    -D pki_external_step_two=True \
    -D pki_pkcs12_path=ca-certs.p12 \
    -D pki_pkcs12_password=Secret.123 \
    -D pki_ca_signing_csr_path=ca_signing.csr \
    -D pki_ocsp_signing_csr_path=ca_ocsp_signing.csr \
    -D pki_audit_signing_csr_path=ca_audit_signing.csr \
    -D pki_subsystem_csr_path=subsystem.csr \
    -D pki_sslserver_csr_path=sslserver.csr \
    -D pki_admin_cert_path=admin.crt \
    -D pki_admin_csr_path=admin.csr \
    -v

# pkispawn should succeed
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA with existing system certs and CA-signed admin cert (rc=$_rc)" >&2
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

step "Check CA signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-show \
    ca_signing | tee ca_signing.crt.after

# cert should not change
diff ca_signing.crt.before ca_signing.crt.after

docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-key-find \
    --nickname ca_signing | tee ca_signing.key.after

# key should not change
diff ca_signing.key.before ca_signing.key.after
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA OCSP signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-show \
    ca_ocsp_signing | tee ca_ocsp_signing.crt.after

# cert should not change
diff ca_ocsp_signing.crt.before ca_ocsp_signing.crt.after

docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-key-find \
    --nickname ca_ocsp_signing | tee ca_ocsp_signing.key.after

# key should not change
diff ca_ocsp_signing.key.before ca_ocsp_signing.key.after
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA OCSP signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA audit signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-show \
    ca_audit_signing | tee ca_audit_signing.crt.after

# cert should not change
diff ca_audit_signing.crt.before ca_audit_signing.crt.after

docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-key-find \
    --nickname ca_audit_signing | tee ca_audit_signing.key.after

# key should not change
diff ca_audit_signing.key.before ca_audit_signing.key.after
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA audit signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check subsystem cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-show \
    subsystem | tee subsystem.crt.after

# cert should not change
diff subsystem.crt.before subsystem.crt.after

docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-key-find \
    --nickname subsystem | tee subsystem.key.after

# key should not change
diff subsystem.key.before subsystem.key.after
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check subsystem cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check SSL server cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-show \
    sslserver | tee sslserver.crt.after

# cert should not change
diff sslserver.crt.before sslserver.crt.after

docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-key-find \
    --nickname sslserver | tee sslserver.key.after

# key should not change
diff sslserver.key.before sslserver.key.after
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check SSL server cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA certs and requests"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki ca-cert-find
docker exec "$CONTAINER" pki -n caadmin ca-cert-request-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA certs and requests (rc=$_rc)" >&2
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
    echo "==== ca-existing-certs-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-existing-certs-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-existing-certs-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-existing-certs-test PASSED ===="

