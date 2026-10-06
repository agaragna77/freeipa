#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-container-existing-config-test
# (GHA .github/workflows/ca-container-existing-config-test.yml). Packaged forge IPACTA.
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

step "Set up client container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "extra client container; run ACME client in IPA container if needed"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up client container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA info"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-export \
    --cert-file ca_signing.crt \
    ca_signing

docker cp pki:ca_signing.crt .

docker exec client pki nss-cert-import \
    --cert $SHARED/ca_signing.crt \
    --trust CT,C,C \
    ca_signing

docker exec client pki \
    -U https://ca.example.com:8443 \
    info
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA info (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin user"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker cp pki:/root/.dogtag/pki-tomcat/ca_admin_cert.p12 .

docker exec client pki pkcs12-import \
    --pkcs12 $SHARED/ca_admin_cert.p12 \
    --password Secret.123

docker exec client pki \
    -U https://ca.example.com:8443 \
    -n caadmin \
    ca-user-show \
    caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Stop CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server stop --wait
docker network disconnect example pki
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Stop CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Export certs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
mkdir certs

# export system certs and keys
docker exec "$CONTAINER" pki \
    -v \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    pkcs12-export \
    --pkcs12 $SHARED/certs/server.p12 \
    --password Secret.123 \
    ca_signing \
    ca_ocsp_signing \
    ca_audit_signing \
    subsystem \
    sslserver

docker exec "$CONTAINER" pki pkcs12-cert-find \
    --pkcs12 $SHARED/certs/server.p12 \
    --password Secret.123

# export system cert requests
docker exec "$CONTAINER" cp \
    /var/lib/pki/pki-tomcat/conf/certs/ca_signing.csr \
    $SHARED/certs/ca_signing.csr
docker exec "$CONTAINER" cp \
    /var/lib/pki/pki-tomcat/conf/certs/ca_ocsp_signing.csr \
    $SHARED/certs/ca_ocsp_signing.csr
docker exec "$CONTAINER" cp \
    /var/lib/pki/pki-tomcat/conf/certs/ca_audit_signing.csr \
    $SHARED/certs/audit_signing.csr
docker exec "$CONTAINER" cp \
    /var/lib/pki/pki-tomcat/conf/certs/subsystem.csr \
    $SHARED/certs/subsystem.csr
docker exec "$CONTAINER" cp \
    /var/lib/pki/pki-tomcat/conf/certs/sslserver.csr \
    $SHARED/certs/sslserver.csr

ls -la certs
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Export certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Export config files"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker cp pki:/etc/pki/pki-tomcat conf

ls -la conf
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Export config files (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Export log files"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker cp pki:/var/log/pki/pki-tomcat logs

ls -la logs
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Export log files (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up CA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker run \
    --name ca \
    --hostname ca.example.com \
    --network example \
    --network-alias ca.example.com \
    -v $PWD/certs:/certs \
    -v $PWD/conf:/conf \
    -v $PWD/logs:/logs \
    -e PKI_DS_URL=ldap://ds.example.com:3389 \
    -e PKI_DS_PASSWORD=Secret.123 \
    -e PKI_CA_SIGNING_NICKNAME=ca_signing \
    -e PKI_OCSP_SIGNING_NICKNAME=ca_ocsp_signing \
    -e PKI_AUDIT_SIGNING_NICKNAME=ca_audit_signing \
    -e PKI_SUBSYSTEM_NICKNAME=subsystem \
    -e PKI_SSLSERVER_NICKNAME=sslserver \
    --detach \
    pki-ca

# wait for CA to start
docker exec client curl \
    --retry 180 \
    --retry-delay 0 \
    --retry-connrefused \
    -s \
    -k \
    -o /dev/null \
    https://ca.example.com:8443
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up CA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Get Tomcat flavor"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
iexec systemctl cat "$IPACTA_UNIT" | head -20 || true
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Get Tomcat flavor (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check conf dir"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec ca ls -l /conf \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\S* *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3/' \
    | tee output

# everything should be owned by root group
# TODO: review owners/permissions
cat > expected_old << EOF
drwxrwx--- root Catalina
drwxrwx--- root alias
drwxrwx--- root ca
-rw-r--r-- root catalina.policy
lrwxrwxrwx root catalina.properties -> /usr/share/pki/server/conf/catalina.properties
drwxrwx--- root certs
lrwxrwxrwx root context.xml -> /etc/tomcat/context.xml
lrwxrwxrwx root logging.properties -> /usr/share/pki/server/conf/logging.properties
-rw-rw---- root password.conf
-rw-rw---- root server.xml
-rw-rw---- root serverCertNick.conf
-rw-rw---- root tomcat.conf
lrwxrwxrwx root web.xml -> /etc/tomcat/web.xml
EOF

cat > expected_new << EOF
drwxrwx--- root Catalina
drwxrwx--- root alias
drwxrwx--- root ca
-rw-r--r-- root catalina.policy
lrwxrwxrwx root catalina.properties -> /usr/share/pki/server/conf/catalina.properties
drwxrwx--- root certs
lrwxrwxrwx root context.xml -> /etc/tomcat/context.xml
lrwxrwxrwx root logging.properties -> /usr/share/pki/server/conf/logging.properties
-rw-rw---- root password.conf
-rw-rw---- root server.xml
-rw-rw---- root serverCertNick.conf
-rw-rw---- root tomcat.conf
lrwxrwxrwx root web.xml -> /etc/tomcat/web.xml
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check conf dir (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check conf/ca dir"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec ca ls -l /conf/ca \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\S* *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3/' \
        -e '/^\S* *\S* *\S* *CS.cfg.bak /d' \
    | tee output

# everything should be owned by root group
# TODO: review owners/permissions
cat > expected_old << EOF
-rw-rw---- root CS.cfg
-rw-rw---- root adminCert.profile
drwxr-xr-x root archives
-rw-rw---- root caAuditSigningCert.profile
-rw-rw---- root caCert.profile
-rw-rw---- root caOCSPCert.profile
drwxrwx--- root emails
-rw-rw---- root flatfile.txt
drwxrwx--- root profiles
-rw-rw---- root proxy.conf
-rw-rw---- root registry.cfg
-rw-rw---- root serverCert.profile
-rw-rw---- root subsystemCert.profile
EOF

cat > expected_new << EOF
-rw-rw---- root CS.cfg
-rw-rw---- root adminCert.profile
drwxr-xr-x root archives
-rw-rw---- root caAuditSigningCert.profile
-rw-rw---- root caCert.profile
-rw-rw---- root caOCSPCert.profile
drwxrwx--- root emails
-rw-rw---- root flatfile.txt
drwxrwx--- root profiles
-rw-rw---- root proxy.conf
-rw-rw---- root registry.cfg
-rw-rw---- root serverCert.profile
-rw-rw---- root subsystemCert.profile
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check conf/ca dir (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check logs dir"
if [[ "$GHA_FAILED" -eq 0 ]] && [[ "${FEDORA_VERSION}" -lt 43 ]]; then
set +e
(
set -euo pipefail
docker exec ca ls -l /logs \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\S* *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3/' \
    | tee output

DATE=$(date +'%Y-%m-%d')

# everything should be owned by root group
# TODO: review owners/permissions
cat > expected << EOF
drwxrwx--- root backup
drwxrwx--- root ca
-rw-rw---- root localhost.$DATE.log
-rw-r--r-- root localhost_access_log.$DATE.txt
drwxrwx--- root pki
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check logs dir (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check logs dir"
if [[ "$GHA_FAILED" -eq 0 ]] && [[ "${FEDORA_VERSION}" -ge 43 ]]; then
set +e
(
set -euo pipefail
docker exec ca ls -l /logs \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\S* *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3/' \
    | tee output

DATE=$(date +'%Y-%m-%d')

# everything should be owned by root group
# TODO: review owners/permissions
cat > expected_old << EOF
drwxrwx--- root backup
drwxrwx--- root ca
-rw-r--r-- root localhost_access_log.$DATE.txt
EOF

cat > expected_new << EOF
drwxrwx--- root backup
drwxrwx--- root ca
-rw-r----- root localhost_access_log.$DATE.txt
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check logs dir (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin user again"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
#TODO: OCSPServlet fails since AuthorityMonitor is disabled in container
docker exec client pki \
    -U https://ca.example.com:8443 \
    -n caadmin \
    --ignore-cert-status OCSP_SERVER_ERROR \
    ca-user-show \
    caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin user again (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client pki \
    -U https://ca.example.com:8443 \
    --ignore-cert-status OCSP_SERVER_ERROR \
    client-cert-request \
    uid=testuser | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"

docker exec client pki \
    -U https://ca.example.com:8443 \
    -n caadmin \
    --ignore-cert-status OCSP_SERVER_ERROR \
    ca-cert-request-approve \
    $REQUEST_ID \
    --force
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert enrollment (rc=$_rc)" >&2
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

step "Check CA container logs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker logs ca 2>&1
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA container logs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CA container debug logs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec ca find /var/lib/pki/pki-tomcat/logs/ca -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA container debug logs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== ca-container-existing-config-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-container-existing-config-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-container-existing-config-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-container-existing-config-test PASSED ===="

