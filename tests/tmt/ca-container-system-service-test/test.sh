#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-container-system-service-test
# (GHA .github/workflows/ca-container-system-service-test.yml). Packaged forge IPACTA.
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

step "Install Podman"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" dnf install -y podman sqlite
docker exec "$CONTAINER" ls -lR /usr/share/containers
docker exec "$CONTAINER" cat /usr/share/containers/containers.conf
docker exec "$CONTAINER" cat /usr/share/containers/storage.conf
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install Podman (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure Podman"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
OS_VERSION=$(lsb_release -r -s | sed 's/\..*$//')
echo "OS_VERSION: $OS_VERSION"

# workaround for Podman issue on Ubuntu 24
# https://github.com/containers/podman/issues/21683
if [ "$OS_VERSION" -ge "24" ]; then
    docker exec -i "$CONTAINER" sqlite3 /var/lib/containers/storage/db.sql << EOF
update DBConfig set GraphDriver = 'overlay' where GraphDriver = '';
EOF
fi

docker exec "$CONTAINER" podman info --format=json | tee output

# rootless should be disabled
echo "false" > expected
jq -r '.host.security.rootless' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure Podman (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Load PKI images into root user's space"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker image inspect "$IPA_IMAGE" >/dev/null
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Load PKI images into root user's space (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create shared folders in PKI user's home directory"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create folders with default owner and permissions
docker exec "$CONTAINER" ls -lR /home
docker exec -u pkiuser "$CONTAINER" mkdir /home/pkiuser/certs
docker exec -u pkiuser "$CONTAINER" mkdir /home/pkiuser/conf
docker exec -u pkiuser "$CONTAINER" mkdir /home/pkiuser/logs

docker exec "$CONTAINER" ls -l /home/pkiuser
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create shared folders in PKI user's home directory (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create CA system service"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create container unit file
# https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
docker exec -i "$CONTAINER" tee /etc/containers/systemd/pki-ca.container << EOF
[Unit]
Description=PKI CA

[Container]
Image=pki-ca
Network=host
# run CA container as PKI user
User=pkiuser
Group=pkiuser
# use shared folders in PKI home directory
Volume=/home/pkiuser/certs:/certs
Volume=/home/pkiuser/conf:/conf
Volume=/home/pkiuser/logs:/logs
# connect to DS container
Environment=PKI_DS_URL=ldap://ds.example.com:3389
Environment=PKI_DS_PASSWORD=Secret.123

[Install]
WantedBy=multi-user.target
EOF

# check service unit file generated by Quadlet
docker exec "$CONTAINER" /usr/libexec/podman/quadlet -dryrun

# reload service unit files
docker exec "$CONTAINER" systemctl daemon-reload
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create CA system service (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Run CA system service"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" systemctl start pki-ca.service
docker exec "$CONTAINER" podman ps

# wait for CA to start
docker exec "$CONTAINER" curl \
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
    echo "FAIL: Run CA system service (rc=$_rc)" >&2
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
docker exec "$CONTAINER" ls -l /home/pkiuser/conf \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\S* *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3/' \
    | tee output

# everything should be owned by pkiuser group
# TODO: review owners/permissions
cat > expected_old << EOF
drwxrwx--- pkiuser Catalina
drwxrwx--- pkiuser alias
drwxrwx--- pkiuser ca
-rw-rw---- pkiuser catalina.policy
lrwxrwxrwx pkiuser catalina.properties -> /usr/share/pki/server/conf/catalina.properties
drwxrwx--- pkiuser certs
lrwxrwxrwx pkiuser context.xml -> /etc/tomcat/context.xml
-rw-rw---- pkiuser jss.conf
lrwxrwxrwx pkiuser logging.properties -> /usr/share/pki/server/conf/logging.properties
-rw-rw---- pkiuser password.conf
-rw-rw---- pkiuser server.xml
-rw-rw---- pkiuser serverCertNick.conf
-rw-rw---- pkiuser tomcat.conf
lrwxrwxrwx pkiuser web.xml -> /etc/tomcat/web.xml
EOF

cat > expected_new << EOF
drwxrwx--- pkiuser Catalina
drwxrwx--- pkiuser alias
drwxrwx--- pkiuser ca
-rw-rw---- pkiuser catalina.policy
lrwxrwxrwx pkiuser catalina.properties -> /usr/share/pki/server/conf/catalina.properties
drwxrwx--- pkiuser certs
lrwxrwxrwx pkiuser context.xml -> /etc/tomcat/context.xml
-rw-rw---- pkiuser jss.conf
lrwxrwxrwx pkiuser logging.properties -> /usr/share/pki/server/conf/logging.properties
-rw-rw---- pkiuser password.conf
-rw-rw---- pkiuser server.xml
-rw-rw---- pkiuser serverCertNick.conf
-rw-rw---- pkiuser tomcat.conf
lrwxrwxrwx pkiuser web.xml -> /etc/tomcat/web.xml
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check conf dir (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check conf/alias dir"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ls -l /home/pkiuser/conf/alias \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\S* *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3/' \
    | tee output

# everything should be owned by pkiuser group
# TODO: review owners/permissions
cat > expected_old << EOF
-rw-rw-rw- pkiuser ca.crt
-rw------- pkiuser cert9.db
-rw------- pkiuser key4.db
-rw------- pkiuser pkcs11.txt
EOF

cat > expected_new << EOF
-rw-rw-rw- pkiuser ca.crt
-rw------- pkiuser cert9.db
-rw------- pkiuser key4.db
-rw------- pkiuser pkcs11.txt
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check conf/alias dir (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check conf/ca dir"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ls -l /home/pkiuser/conf/ca \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\S* *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3/' \
        -e '/^\S* *\S* *\S* *CS.cfg.bak /d' \
    | tee output

# everything should be owned by pkiuser group
# TODO: review owners/permissions
cat > expected_old << EOF
-rw-rw---- pkiuser CS.cfg
-rw-rw---- pkiuser adminCert.profile
drwxrwxrwx pkiuser archives
-rw-rw---- pkiuser caAuditSigningCert.profile
-rw-rw---- pkiuser caCert.profile
-rw-rw---- pkiuser caOCSPCert.profile
drwxrwx--- pkiuser emails
-rw-rw---- pkiuser flatfile.txt
drwxrwx--- pkiuser profiles
-rw-rw---- pkiuser proxy.conf
-rw-rw---- pkiuser registry.cfg
-rw-rw---- pkiuser serverCert.profile
-rw-rw---- pkiuser subsystemCert.profile
EOF

cat > expected_new << EOF
-rw-rw---- pkiuser CS.cfg
-rw-rw---- pkiuser adminCert.profile
drwxrwxrwx pkiuser archives
-rw-rw---- pkiuser caAuditSigningCert.profile
-rw-rw---- pkiuser caCert.profile
-rw-rw---- pkiuser caOCSPCert.profile
drwxrwx--- pkiuser emails
-rw-rw---- pkiuser flatfile.txt
drwxrwx--- pkiuser profiles
-rw-rw---- pkiuser proxy.conf
-rw-rw---- pkiuser registry.cfg
-rw-rw---- pkiuser serverCert.profile
-rw-rw---- pkiuser subsystemCert.profile
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
docker exec "$CONTAINER" ls -l /home/pkiuser/logs \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\S* *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3/' \
    | tee output

DATE=$(date +'%Y-%m-%d')

# everything should be owned by pkiuser group
# TODO: review owners/permissions
cat > expected << EOF
drwxrwx--- pkiuser backup
drwxrwx--- pkiuser ca
-rw-rw---- pkiuser localhost.$DATE.log
-rw-rw-rw- pkiuser localhost_access_log.$DATE.txt
drwxrwx--- pkiuser pki
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
docker exec "$CONTAINER" ls -l /home/pkiuser/logs \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\S* *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3/' \
    | tee output

DATE=$(date +'%Y-%m-%d')

# everything should be owned by pkiuser group
# TODO: review owners/permissions
cat > expected_old << EOF
drwxrwx--- pkiuser backup
drwxrwx--- pkiuser ca
-rw-rw-rw- pkiuser localhost_access_log.$DATE.txt
EOF

cat > expected_new << EOF
drwxrwx--- pkiuser backup
drwxrwx--- pkiuser ca
-rw-rw-rw- pkiuser localhost_access_log.$DATE.txt
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

step "Check CA info"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" podman exec systemd-pki-ca \
    pki-server cert-export \
    --cert-file /conf/certs/ca_signing.crt \
    ca_signing

docker exec "$CONTAINER" pki nss-cert-import \
    --cert /home/pkiuser/conf/certs/ca_signing.crt \
    --trust CT,C,C \
    ca_signing

docker exec "$CONTAINER" pki info
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA info (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Initialize CA database"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" podman exec systemd-pki-ca \
    pki-server ca-db-init -v
docker exec "$CONTAINER" podman exec systemd-pki-ca \
    pki-server ca-db-index-add -v
docker exec "$CONTAINER" podman exec systemd-pki-ca \
    pki-server ca-db-index-rebuild -v
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Initialize CA database (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create cert request
docker exec "$CONTAINER" pki nss-cert-request \
    --subject "CN=Administrator" \
    --ext /usr/share/pki/server/certs/admin.conf \
    --csr admin.csr

docker exec "$CONTAINER" podman cp admin.csr systemd-pki-ca:/home/pkiuser

# issue cert
docker exec "$CONTAINER" podman exec systemd-pki-ca pki-server ca-cert-create \
    --csr /home/pkiuser/admin.csr \
    --profile /usr/share/pki/ca/conf/rsaAdminCert.profile \
    --cert /home/pkiuser/admin.crt \
    --import-cert

docker exec "$CONTAINER" podman cp systemd-pki-ca:/home/pkiuser/admin.crt .

# import cert
docker exec "$CONTAINER" pki nss-cert-import \
    --cert admin.crt \
    admin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Add CA admin user"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create CA admin user
docker exec "$CONTAINER" podman exec systemd-pki-ca \
    pki-server ca-user-add \
    --full-name Administrator \
    --type adminType \
    --cert /home/pkiuser/admin.crt \
    admin

# add CA admin user into CA groups
docker exec "$CONTAINER" podman exec systemd-pki-ca \
    pki-server ca-user-role-add admin "Administrators"
docker exec "$CONTAINER" podman exec systemd-pki-ca \
    pki-server ca-user-role-add admin "Certificate Manager Agents"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Add CA admin user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin user"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n admin \
    ca-user-show \
    admin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    client-cert-request \
    uid=testuser | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"

docker exec "$CONTAINER" pki \
    -n admin \
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

step "Check CA container systemd journal"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" journalctl -x --no-pager -u pki-ca.service
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA container systemd journal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CA container logs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" podman logs systemd-pki-ca 2>&1
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA container logs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CA debug logs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" find /home/pkiuser/logs/ca -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA debug logs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== ca-container-system-service-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-container-system-service-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-container-system-service-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-container-system-service-test PASSED ===="

