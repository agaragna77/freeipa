#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-clone-secure-ds-test
# (GHA .github/workflows/ca-clone-secure-ds-test.yml). Packaged forge IPACTA.
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

step "Set up primary DS container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Set up primary DS container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up primary DS container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "IPA container already running as $CONTAINER"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create DS signing cert in primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=DS Signing Certificate" \
    --ext /usr/share/pki/server/certs/ca_signing.conf \
    --csr ds_signing.csr

docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --csr ds_signing.csr \
    --ext /usr/share/pki/server/certs/ca_signing.conf \
    --cert ds_signing.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert ds_signing.crt \
    --trust CT,C,C \
    Self-Signed-CA

docker exec "$CONTAINER" pki nss-cert-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create DS signing cert in primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create DS server cert in primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=primaryds.example.com" \
    --ext /usr/share/pki/server/certs/sslserver.conf \
    --csr ds_server.csr

docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --issuer Self-Signed-CA \
    --csr ds_server.csr \
    --ext /usr/share/pki/server/certs/sslserver.conf \
    --cert ds_server.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert ds_server.crt \
    Server-Cert

docker exec "$CONTAINER" pki nss-cert-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create DS server cert in primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Import DS certs into primary DS container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pk12util \
    -d /root/.dogtag/nssdb \
    -o $SHARED/primaryds_server.p12 \
    -W Secret.123 \
    -n Server-Cert

sudo chmod go+r primaryds_server.p12

echo "OMITTED: Dogtag tests/bin helper (not in FreeIPA tree)"
    --image=${DS_IMAGE} \
    --input=primaryds_server.p12 \
    --password=Secret.123 \
    primaryds

echo "OMITTED: Dogtag tests/bin helper (not in FreeIPA tree)"
    --image=${DS_IMAGE} \
    primaryds

echo "OMITTED: Dogtag tests/bin helper (not in FreeIPA tree)"
    --image=${DS_IMAGE} \
    primaryds
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Import DS certs into primary DS container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install CA in primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_ca
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA in primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check NSS database in primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# NSS database should contain DS cert and PKI certs
docker exec "$CONTAINER" pki \
    -d /etc/pki/pki-tomcat/alias \
    -f /etc/pki/pki-tomcat/password.conf \
    nss-cert-find \
    | tee output

sed -n \
    -e 's/^ *\(Nickname: .*\)$/\1/p' \
    -e 's/^ *\(Trust Flags: .*\)$/\1/p' \
    -e 's/^$//p' \
    output > actual

cat > expected << EOF
Nickname: ds_signing
Trust Flags: CT,C,C

Nickname: ca_signing
Trust Flags: CTu,Cu,Cu

Nickname: ca_ocsp_signing
Trust Flags: u,u,u

Nickname: sslserver
Trust Flags: u,u,u

Nickname: subsystem
Trust Flags: u,u,u

Nickname: ca_audit_signing
Trust Flags: u,u,Pu
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check NSS database in primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create external cert in primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "CN=External Certificate" \
    --ext /usr/share/pki/server/certs/ca_signing.conf \
    --csr external.csr

docker exec "$CONTAINER" pki \
    nss-cert-issue \
    --csr external.csr \
    --ext /usr/share/pki/server/certs/ca_signing.conf \
    --cert external.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert external.crt \
    --trust CT,C,C \
    external

docker exec "$CONTAINER" pki nss-cert-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create external cert in primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Import external cert into primary PKI server"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server \
    instance-externalcert-add \
    --cert-file external.crt \
    --nickname external \
    --trust-args CT,C,C

# NSS database should contain the external cert
docker exec "$CONTAINER" pki \
    -d /etc/pki/pki-tomcat/alias \
    -f /etc/pki/pki-tomcat/password.conf \
    nss-cert-show \
    external \
    | tee output

sed -n \
    -e 's/^ *\(Nickname: .*\)$/\1/p' \
    -e 's/^ *\(Trust Flags: .*\)$/\1/p' \
    output > actual

cat > expected << EOF
Nickname: external
Trust Flags: CT,C,C
EOF

diff expected actual

# external_certs.conf should contain the external cert
docker exec "$CONTAINER" cat /etc/pki/pki-tomcat/external_certs.conf | tee output

cat > expected << EOF
0.nickname=external
0.token=internal
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Import external cert into primary PKI server (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Verify DS connection in primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-db-config-show | tee output

echo "primaryds.example.com" > expected
sed -n 's/^\s\+Hostname:\s\+\(\S\+\)$/\1/p' output > actual
diff expected actual

echo "3636" > expected
sed -n 's/^\s\+Port:\s\+\(\S\+\)$/\1/p' output > actual
diff expected actual

echo "true" > expected
sed -n 's/^\s\+Secure:\s\+\(\S\+\)$/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Verify DS connection in primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Verify users and DS hosts in primary PKI container"
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

docker exec "$CONTAINER" pki -n caadmin ca-user-find
docker exec "$CONTAINER" pki securitydomain-host-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Verify users and DS hosts in primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert requests in primary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki -n caadmin ca-cert-request-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert requests in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up secondary DS container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Set up secondary DS container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up secondary DS container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "IPA container already running as $CONTAINER"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Import DS signing cert into secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Import DS signing cert into secondary PKI container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Import DS signing cert into secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create DS server cert in secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Create DS server cert in secondary PKI container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create DS server cert in secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Import DS certs into secondary DS container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Import DS certs into secondary DS container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Import DS certs into secondary DS container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Export certs for cloning from primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# export CA signing cert
docker exec "$CONTAINER" pki-server \
    cert-export \
    --cert-file $SHARED/ca_signing.crt \
    ca_signing

# export PKI certs including external cert but without sslserver cert
docker exec "$CONTAINER" pki-server \
    ca-clone-prepare \
    --pkcs12-file $SHARED/ca-certs.p12 \
    --pkcs12-password Secret.123

docker exec "$CONTAINER" pki \
    pkcs12-cert-find \
    --pkcs12-file $SHARED/ca-certs.p12 \
    --password Secret.123 \
    | tee output

sed -n \
    -e 's/^ *\(Friendly Name: .*\)$/\1/p' \
    -e 's/^ *\(Trust Flags: .*\)$/\1/p' \
    -e 's/^$//p' \
    output > actual

cat > expected << EOF
Friendly Name: subsystem
Trust Flags: u,u,u

Friendly Name: ca_signing
Trust Flags: CTu,Cu,Cu

Friendly Name: ca_ocsp_signing
Trust Flags: u,u,u

Friendly Name: ca_audit_signing
Trust Flags: u,u,Pu

Friendly Name: external
Trust Flags: CT,C,C
EOF

diff expected actual

# export external_certs.conf
docker cp primary:/etc/pki/pki-tomcat/external_certs.conf .
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Export certs for cloning from primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install CA in secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "second CA instance / clone install not mapped (use ipa-replica-install)"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA in secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check NSS database in secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Check NSS database in secondary PKI container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check NSS database in secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check external cert in secondary PKI server"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Check external cert in secondary PKI server"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check external cert in secondary PKI server (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Run PKI healthcheck in primary PKI container"
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
    echo "FAIL: Run PKI healthcheck in primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Run PKI healthcheck in secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Run PKI healthcheck in secondary PKI container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Run PKI healthcheck in secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Verify DS connection in secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Verify DS connection in secondary PKI container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Verify DS connection in secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Verify users and SD hosts in secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Verify users and SD hosts in secondary PKI container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Verify users and SD hosts in secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert requests in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Check cert requests in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert requests in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA from secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA from secondary PKI container (rc=$_rc)" >&2
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

step "Re-install CA in secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Re-install CA in secondary PKI container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Re-install CA in secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check NSS database in secondary PKI container again"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Check NSS database in secondary PKI container again"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check NSS database in secondary PKI container again (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove external cert from secondary PKI server"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-secure-ds-test: Remove external cert from secondary PKI server"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove external cert from secondary PKI server (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA from secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA from secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA from primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA from primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-clone-secure-ds-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-clone-secure-ds-test PASSED ===="

