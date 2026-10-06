#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/kra-existing-hsm-test
# (GHA .github/workflows/kra-existing-hsm-test.yml). Packaged forge IPACTA.
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

step "Set up CA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "runner-init skipped; IPA container already running"
    --hostname=ca.example.com \
    --network=example \
    --network-alias=ca.example.com \
    ca
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up CA container (rc=$_rc)" >&2
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

step "Install CA admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec ca pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-export \
    --output-file $SHARED/cert_chain.pem \
    --with-chain \
    ca_signing

docker exec ca pki nss-cert-import \
    --cert $SHARED/cert_chain.pem \
    --trust CT,C,C

docker exec ca pki pkcs12-import \
    --pkcs12 /root/.dogtag/pki-tomcat/ca_admin_cert.p12 \
    --pkcs12-password Secret.123
docker exec ca pki nss-cert-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up KRA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "runner-init skipped; IPA container already running"
    --hostname=kra.example.com \
    --network=example \
    --network-alias=kra.example.com \
    kra
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up KRA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

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

step "Create SoftHSM token"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Create SoftHSM token"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create SoftHSM token (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create PKI server"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "IPA container already running as $CONTAINER"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create PKI server (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue KRA storage cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki-server cert-request \
    --token HSM \
    --subject "CN=DRM Storage Certificate" \
    --ext /usr/share/pki/server/certs/kra_storage.conf \
    kra_storage
docker exec kra cp /var/lib/pki/pki-tomcat/conf/certs/kra_storage.csr $SHARED
docker exec kra openssl req -text -noout -in $SHARED/kra_storage.csr

docker exec ca pki \
    -n caadmin \
    ca-cert-issue \
    --profile caStorageCert \
    --csr-file $SHARED/kra_storage.csr \
    --output-file $SHARED/kra_storage.crt
docker exec ca openssl x509 -text -noout -in $SHARED/kra_storage.crt
docker exec kra cp $SHARED/kra_storage.crt /var/lib/pki/pki-tomcat/conf/certs

docker exec kra pki-server cert-import \
    --token HSM \
    kra_storage

# check original cert
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:kra_storage | tee kra_storage.crt.before

# check original key
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-key-find \
    --nickname HSM:kra_storage | tee kra_storage.key.before
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue KRA storage cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue KRA transport cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki-server cert-request \
    --token HSM \
    --subject "CN=DRM Transport Certificate" \
    --ext /usr/share/pki/server/certs/kra_transport.conf \
    kra_transport
docker exec kra cp /var/lib/pki/pki-tomcat/conf/certs/kra_transport.csr $SHARED
docker exec ca openssl req -text -noout -in $SHARED/kra_transport.csr

docker exec ca pki \
    -n caadmin \
    ca-cert-issue \
    --profile caTransportCert \
    --csr-file $SHARED/kra_transport.csr \
    --output-file $SHARED/kra_transport.crt
docker exec ca openssl x509 -text -noout -in $SHARED/kra_transport.crt
docker exec kra cp $SHARED/kra_transport.crt /var/lib/pki/pki-tomcat/conf/certs

docker exec kra pki-server cert-import \
    --token HSM \
    kra_transport

# check original cert
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:kra_transport | tee kra_transport.crt.before

# check original key
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-key-find \
    --nickname HSM:kra_transport | tee kra_transport.key.before
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue KRA transport cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue KRA audit signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki-server cert-request \
    --token HSM \
    --subject "CN=Audit Signing Certificate" \
    --ext /usr/share/pki/server/certs/audit_signing.conf \
    kra_audit_signing
docker exec kra cp /var/lib/pki/pki-tomcat/conf/certs/kra_audit_signing.csr $SHARED
docker exec ca openssl req -text -noout -in $SHARED/kra_audit_signing.csr

docker exec ca pki \
    -n caadmin \
    ca-cert-issue \
    --profile caAuditSigningCert \
    --csr-file $SHARED/kra_audit_signing.csr \
    --output-file $SHARED/kra_audit_signing.crt
docker exec ca openssl x509 -text -noout -in $SHARED/kra_audit_signing.crt
docker exec kra cp $SHARED/kra_audit_signing.crt /var/lib/pki/pki-tomcat/conf/certs

docker exec kra pki-server cert-import \
    --token HSM \
    kra_audit_signing

# check original cert
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:kra_audit_signing | tee kra_audit_signing.crt.before

# check original key
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-key-find \
    --nickname HSM:kra_audit_signing | tee kra_audit_signing.key.before
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue KRA audit signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue subsystem cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki-server cert-request \
    --token HSM \
    --subject "CN=Subsystem Certificate" \
    --ext /usr/share/pki/server/certs/subsystem.conf \
    subsystem
docker exec kra cp /var/lib/pki/pki-tomcat/conf/certs/subsystem.csr $SHARED
docker exec ca openssl req -text -noout -in $SHARED/subsystem.csr

docker exec ca pki \
    -n caadmin \
    ca-cert-issue \
    --profile caSubsystemCert \
    --csr-file $SHARED/subsystem.csr \
    --output-file $SHARED/subsystem.crt
docker exec ca openssl x509 -text -noout -in $SHARED/subsystem.crt
docker exec kra cp $SHARED/subsystem.crt /var/lib/pki/pki-tomcat/conf/certs

docker exec kra pki-server cert-import \
    --token HSM \
    subsystem

# check original cert
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:subsystem | tee subsystem.crt.before

# check original key
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-key-find \
    --nickname HSM:subsystem | tee subsystem.key.before
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue subsystem cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue SSL server cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki-server cert-request \
    --subject "CN=kra.example.com" \
    --ext /usr/share/pki/server/certs/sslserver.conf \
    sslserver
docker exec kra cp /var/lib/pki/pki-tomcat/conf/certs/sslserver.csr $SHARED
docker exec ca openssl req -text -noout -in $SHARED/sslserver.csr

docker exec ca pki \
    -n caadmin \
    ca-cert-issue \
    --profile caServerCert \
    --csr-file $SHARED/sslserver.csr \
    --output-file $SHARED/sslserver.crt
docker exec ca openssl x509 -text -noout -in $SHARED/sslserver.crt
docker exec kra cp $SHARED/sslserver.crt /var/lib/pki/pki-tomcat/conf/certs

docker exec kra pki-server cert-import \
    sslserver

# check original cert
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-show \
    sslserver | tee sslserver.crt.before

# check original key
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-key-find \
    --nickname sslserver | tee sslserver.key.before
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue SSL server cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue KRA admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki nss-cert-request \
    --subject "CN=Administrator" \
    --ext /usr/share/pki/server/certs/admin.conf \
    --csr $SHARED/kra_admin.csr
docker exec ca openssl req -text -noout -in $SHARED/kra_admin.csr

docker exec ca pki \
    -n caadmin \
    ca-cert-issue \
    --profile AdminCert \
    --csr-file $SHARED/kra_admin.csr \
    --output-file $SHARED/kra_admin.crt
docker exec ca openssl x509 -text -noout -in $SHARED/kra_admin.crt

docker exec kra pki nss-cert-import \
    --cert $SHARED/kra_admin.crt \
    kraadmin

# check original cert
docker exec kra pki nss-cert-show \
    kraadmin | tee kraadmin.crt.before

# check original key
docker exec kra pki nss-key-find \
    --nickname kraadmin | tee kraadmin.key.before
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue KRA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check SoftHSM files"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra ls -lR /var/lib/softhsm/tokens
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check SoftHSM files (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install KRA with existing HSM"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_kra
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install KRA with existing HSM (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check KRA storage cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:kra_storage | tee kra_storage.crt.after

# cert should not change
diff kra_storage.crt.before kra_storage.crt.after

docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-key-find \
    --nickname HSM:kra_storage | tee kra_storage.key.after

# key should not change
diff kra_storage.key.before kra_storage.key.after
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA storage cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check KRA transport cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:kra_transport | tee kra_transport.crt.after

# cert should not change
diff kra_transport.crt.before kra_transport.crt.after

docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-key-find \
    --nickname HSM:kra_transport | tee kra_transport.key.after

# key should not change
diff kra_transport.key.before kra_transport.key.after
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA transport cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check KRA audit signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:kra_audit_signing | tee kra_audit_signing.crt.after

# cert should not change
diff kra_audit_signing.crt.before kra_audit_signing.crt.after

docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-key-find \
    --nickname HSM:kra_audit_signing | tee kra_audit_signing.key.after

# key should not change
diff kra_audit_signing.key.before kra_audit_signing.key.after
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA audit signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check subsystem cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:subsystem | tee subsystem.crt.after

# cert should not change
diff subsystem.crt.before subsystem.crt.after

docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-key-find \
    --nickname HSM:subsystem | tee subsystem.key.after

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
docker exec kra pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-show \
    sslserver | tee sslserver.crt.after

# cert should not change
diff sslserver.crt.before sslserver.crt.after

docker exec kra pki \
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

step "Check KRA admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki nss-cert-import \
    --cert $SHARED/cert_chain.pem \
    --trust CT,C,C

docker exec kra pki nss-cert-find
docker exec kra pki -n kraadmin kra-user-show kraadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Verify KRA connector in CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec ca pki -n caadmin ca-kraconnector-show | tee output
sed -n 's/\s*Host:\s\+\(\S\+\):.*/\1/p' output > actual
echo kra.example.com > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Verify KRA connector in CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove KRA from KRA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pkidestroy -s KRA -v
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove KRA from KRA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA from CA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA from CA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove SoftHSM token"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Remove SoftHSM token"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove SoftHSM token (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server systemd journal in CA container"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec ca journalctl -x --no-pager -u pki-tomcatd@pki-tomcat.service
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server systemd journal in CA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CA debug log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec ca find /var/lib/pki/pki-tomcat/logs/ca -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA debug log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check PKI server systemd journal in KRA container"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec kra journalctl -x --no-pager -u pki-tomcatd@pki-tomcat.service
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server systemd journal in KRA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check KRA debug log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec kra find /var/lib/pki/pki-tomcat/logs/kra -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA debug log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== kra-existing-hsm-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== kra-existing-hsm-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA kra-existing-hsm-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA kra-existing-hsm-test PASSED ===="

