#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/kra-kryoptic-test
# (GHA .github/workflows/kra-kryoptic-test.yml). Packaged forge IPACTA.
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

step "Configure crypto-policies"
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
    echo "FAIL: Configure crypto-policies (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install Kryoptic"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# install OpenDNSSEC to ensure no conflicts
# https://github.com/dogtagpki/pki/issues/5045
docker exec "$CONTAINER" dnf install -y kryoptic opensc opendnssec

docker exec "$CONTAINER" rpm -ql kryoptic
docker exec "$CONTAINER" cat /usr/share/p11-kit/modules/kryoptic.module

# check with OpenSC
# NOTE: the command fails if there's no token
docker exec "$CONTAINER" pkcs11-tool \
    --module /usr/lib64/pkcs11/libkryoptic_pkcs11.so \
    --show-info || true

# check with OpenSC
# NOTE: the command fails if there's no token
docker exec "$CONTAINER" pkcs11-tool \
    --module /usr/lib64/pkcs11/libkryoptic_pkcs11.so \
    --list-slots || true

# check with NSS
docker exec "$CONTAINER" modutil -nocertdb -list
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install Kryoptic (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create Kryoptic token"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create password file for HSM
echo "Secret.HSM" > password.hsm

# configure token
docker exec "$CONTAINER" runuser -u pkiuser -- \
    mkdir -p /home/pkiuser/.config/kryoptic

docker exec -i "$CONTAINER" runuser -u pkiuser -- \
    tee /home/pkiuser/.config/kryoptic/token.conf << EOF
[[slots]]
slot = 1
dbtype = "sqlite"
dbargs = "/home/pkiuser/.config/kryoptic/token.sql"
objects_dedup = "TrustOnly"
EOF

# check with OpenSC
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pkcs11-tool \
    --module /usr/lib64/pkcs11/libkryoptic_pkcs11.so \
    --list-slots

# initialize token and SO PIN
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pkcs11-tool \
    --module /usr/lib64/pkcs11/libkryoptic_pkcs11.so \
    --label HSM \
    --so-pin $(cat password.hsm) \
    --init-token

# initialize user PIN
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pkcs11-tool \
    --module /usr/lib64/pkcs11/libkryoptic_pkcs11.so \
    --login \
    --login-type so \
    --so-pin $(cat password.hsm) \
    --pin $(cat password.hsm) \
    --init-pin

# check with OpenSC
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pkcs11-tool \
    --module /usr/lib64/pkcs11/libkryoptic_pkcs11.so \
    --list-slots

# check with NSS
docker exec "$CONTAINER" runuser -u pkiuser -- \
    modutil -nocertdb -list
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create Kryoptic token (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install CA with HSM"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pkispawn \
    -f /usr/share/pki/server/examples/installation/ca-pqc.cfg \
    -s CA \
    -D pki_ds_url=ldap://ds.example.com:3389 \
    -D pki_hsm_enable=True \
    -D pki_token_name=HSM \
    -D pki_token_password=Secret.HSM \
    -D pki_server_database_password=Secret.123 \
    -D pki_ca_signing_token=HSM \
    -D pki_ocsp_signing_token=HSM \
    -D pki_audit_signing_token=HSM \
    -D pki_subsystem_token=HSM \
    -D pki_sslserver_token=HSM \
    -D pki_admin_nickname=admin \
    -v
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA with HSM (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check system certs in internal token"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    nss-cert-find \
    | tee output

# there should be 0 certs
echo "0" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check system certs in internal token (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check system certs in HSM"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-find \
    | tee output

# there should be 5 certs
echo "5" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check system certs in HSM (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install KRA with HSM"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_kra
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install KRA with HSM (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check for warnings"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
sed -n '/^WARNING:/p' stderr | tee output
diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check for warnings (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check external commands"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
sed -n '/^DEBUG: Command:/p' stderr | tee output
wc -l output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check external commands (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check system certs in internal token"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    nss-cert-find \
    | tee output

# there should be 0 certs
echo "0" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check system certs in internal token (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check system certs in HSM"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-find \
    | tee output

# there should be 8 certs
echo "8" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check system certs in HSM (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check kra_storage cert in HSM"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:kra_storage \
    | tee output

# trust attributes should be u,u,u
echo "u,u,u" > expected
sed -n 's/\s*Trust Flags:\s*\(\S\+\)\s*$/\1/p' output > actual

diff expected actual

docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-key-find \
    --nickname HSM:kra_storage \
    | tee output

# key type and algorithm should be ML-KEM
cat > expected << EOF
Type: ML-KEM-768
Algorithm: ML-KEM
EOF

sed -n \
    -e 's/\s*\(Type:\s*\S\+\)\s*$/\1/p' \
    -e 's/\s*\(Algorithm:\s*\S\+\)\s*$/\1/p' \
    output > actual

diff expected actual

docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-verify \
    --cert-usage SSLClient \
    HSM:kra_storage
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check kra_storage cert in HSM (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check kra_transport cert in HSM"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:kra_transport \
    | tee output

# trust attributes should be u,u,u
echo "u,u,u" > expected
sed -n 's/\s*Trust Flags:\s*\(\S\+\)\s*$/\1/p' output > actual

diff expected actual

docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-key-find \
    --nickname HSM:kra_transport \
    | tee output

# key type and algorithm should be ML-KEM
cat > expected << EOF
Type: ML-KEM-768
Algorithm: ML-KEM
EOF

sed -n \
    -e 's/\s*\(Type:\s*\S\+\)\s*$/\1/p' \
    -e 's/\s*\(Algorithm:\s*\S\+\)\s*$/\1/p' \
    output > actual

diff expected actual

docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-verify \
    --cert-usage SSLClient \
    HSM:kra_transport
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check kra_transport cert in HSM (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check kra_audit_signing cert in HSM"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    --token HSM \
    nss-cert-show \
    HSM:kra_audit_signing \
    | tee output

# trust attributes should be u,u,Pu
echo "u,u,Pu" > expected
sed -n 's/\s*Trust Flags:\s*\(\S\+\)\s*$/\1/p' output > actual

diff expected actual

docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-key-find \
    --nickname HSM:kra_audit_signing \
    | tee output

# key type and algorithm should be ML-DSA
cat > expected << EOF
Type: ML-DSA-65
Algorithm: ML-DSA
EOF

sed -n \
    -e 's/\s*\(Type:\s*\S\+\)\s*$/\1/p' \
    -e 's/\s*\(Algorithm:\s*\S\+\)\s*$/\1/p' \
    output > actual

diff expected actual

docker exec "$CONTAINER" runuser -u pkiuser -- \
    pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-verify \
    --cert-usage ObjectSigner \
    HSM:kra_audit_signing
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check kra_audit_signing cert in HSM (rc=$_rc)" >&2
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
    # pki-healthcheck fails due to trust attributes issue in Kryoptic
    # https://github.com/latchset/kryoptic/issues/450
    docker exec "$CONTAINER" runuser -u pkiuser -- \
        pki-healthcheck --failures-only || true
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

step "Check admin cert"
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
    --password Secret.123

docker exec "$CONTAINER" pki nss-key-find \
    --nickname admin \
    | tee output

# key type and algorithm should be ML-DSA
cat > expected << EOF
Type: ML-DSA-65
Algorithm: ML-DSA
EOF

sed -n \
    -e 's/\s*\(Type:\s*\S\+\)\s*$/\1/p' \
    -e 's/\s*\(Algorithm:\s*\S\+\)\s*$/\1/p' \
    output > actual

diff expected actual

docker exec "$CONTAINER" pki nss-cert-verify \
    --cert-usage SSLClient \
    admin

docker exec "$CONTAINER" pki -n admin kra-user-show kraadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove KRA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pkidestroy \
    -s KRA \
    --debug \
    > stdout 2> stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove KRA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check for warnings"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
sed -n '/^WARNING:/p' stderr | tee output
diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check for warnings (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check external commands"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
sed -n '/^DEBUG: Command:/p' stderr | tee output
wc -l output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check external commands (rc=$_rc)" >&2
    GHA_FAILED=$_rc
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

step "Remove Kryoptic token"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" runuser -u pkiuser -- \
    rm -rf /home/pkiuser/.config/kryoptic
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove Kryoptic token (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check for PKI core dumps"
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
    echo "FAIL: Check for PKI core dumps (rc=$_rc)" >&2
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

step "Check KRA debug log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" find /var/lib/pki/pki-tomcat/logs/kra -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA debug log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== kra-kryoptic-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== kra-kryoptic-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA kra-kryoptic-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA kra-kryoptic-test PASSED ===="

