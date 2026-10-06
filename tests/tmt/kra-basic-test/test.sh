#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/kra-basic-test
# (GHA .github/workflows/kra-basic-test.yml). Packaged forge IPACTA.
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

step "Check pki kra CLI help messages"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki kra
docker exec "$CONTAINER" pki kra --help

docker exec "$CONTAINER" pki kra-key-find --help
docker exec "$CONTAINER" pki kra-key-show --help
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check pki kra CLI help messages (rc=$_rc)" >&2
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

step "Check keywrap config in CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# OAEP should be disabled
docker exec "$CONTAINER" pki-server ca-config-find \
    | sed -n \
        -e '/^keyWrap\./p' \
    | sort \
    | tee output

diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check keywrap config in CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check security domain config in CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# CA should run security domain service
cat > expected << EOF
securitydomain.checkIP=false
securitydomain.checkinterval=300000
securitydomain.flushinterval=86400000
securitydomain.host=pki.example.com
securitydomain.httpport=8080
securitydomain.httpsadminport=8443
securitydomain.name=EXAMPLE
securitydomain.select=new
securitydomain.source=ldap
EOF

docker exec "$CONTAINER" pki-server ca-config-find | grep ^securitydomain. | sort | tee actual
diff expected actual

docker exec "$CONTAINER" pki-server cert-export ca_signing --cert-file ${SHARED}/ca_signing.crt

docker exec "$CONTAINER" pki nss-cert-import \
    --cert $SHARED/ca_signing.crt \
    --trust CT,C,C \
    ca_signing

# REST API should return security domain info
cat > expected << EOF
  Domain: EXAMPLE

  CA Subsystem:

    Host ID: CA pki.example.com 8443
    Hostname: pki.example.com
    Port: 8080
    Secure Port: 8443
    Domain Manager: TRUE

EOF
docker exec "$CONTAINER" pki securitydomain-show | tee output
diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check security domain config in CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ls -la /root/.dogtag/pki-tomcat
docker exec "$CONTAINER" cat /root/.dogtag/pki-tomcat/ca_admin.cert
docker exec "$CONTAINER" openssl x509 -text -noout -in /root/.dogtag/pki-tomcat/ca_admin.cert
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install KRA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_kra
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install KRA (rc=$_rc)" >&2
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

step "Check PKI server base dir after installation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /var/lib/pki/pki-tomcat \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

# TODO: review permissions
cat > expected_old << EOF
lrwxrwxrwx pkiuser pkiuser alias -> /var/lib/pki/pki-tomcat/conf/alias
lrwxrwxrwx pkiuser pkiuser bin -> /usr/share/tomcat/bin
drwxrwx--- pkiuser pkiuser ca
drwxrwx--- pkiuser pkiuser common
lrwxrwxrwx pkiuser pkiuser conf -> /etc/pki/pki-tomcat
drwxrwx--- pkiuser pkiuser kra
lrwxrwxrwx pkiuser pkiuser lib -> /usr/share/pki/server/lib
lrwxrwxrwx pkiuser pkiuser logs -> /var/log/pki/pki-tomcat
drwxrwx--- pkiuser pkiuser temp
drwxrwx--- pkiuser pkiuser webapps
drwxrwx--- pkiuser pkiuser work
EOF

cat > expected_new << EOF
lrwxrwxrwx pkiuser pkiuser alias -> /var/lib/pki/pki-tomcat/conf/alias
lrwxrwxrwx pkiuser pkiuser bin -> /usr/share/tomcat/bin
drwxrwx--- pkiuser pkiuser ca
drwxrwx--- pkiuser pkiuser common
lrwxrwxrwx pkiuser pkiuser conf -> /etc/pki/pki-tomcat
drwxrwx--- pkiuser pkiuser kra
lrwxrwxrwx pkiuser pkiuser lib -> /usr/share/pki/server/lib
lrwxrwxrwx pkiuser pkiuser logs -> /var/log/pki/pki-tomcat
drwxrwx--- pkiuser pkiuser temp
drwxrwx--- pkiuser pkiuser webapps
drwxrwx--- pkiuser pkiuser work
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server base dir after installation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server conf dir after installation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /etc/pki/pki-tomcat \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

# TODO: review permissions
cat > expected_old << EOF
drwxrwx--- pkiuser pkiuser Catalina
drwxrwx--- pkiuser pkiuser alias
drwxrwx--- pkiuser pkiuser ca
-rw-r--r-- pkiuser pkiuser catalina.policy
lrwxrwxrwx pkiuser pkiuser catalina.properties -> /usr/share/pki/server/conf/catalina.properties
drwxrwx--- pkiuser pkiuser certs
lrwxrwxrwx pkiuser pkiuser context.xml -> /etc/tomcat/context.xml
drwxrwx--- pkiuser pkiuser kra
lrwxrwxrwx pkiuser pkiuser logging.properties -> /usr/share/pki/server/conf/logging.properties
-rw-rw---- pkiuser pkiuser password.conf
-rw-rw---- pkiuser pkiuser server.xml
-rw-rw---- pkiuser pkiuser serverCertNick.conf
-rw-rw---- pkiuser pkiuser tomcat.conf
lrwxrwxrwx pkiuser pkiuser web.xml -> /etc/tomcat/web.xml
EOF

cat > expected_new << EOF
drwxrwx--- pkiuser pkiuser Catalina
drwxrwx--- pkiuser pkiuser alias
drwxrwx--- pkiuser pkiuser ca
-rw-r--r-- pkiuser pkiuser catalina.policy
lrwxrwxrwx pkiuser pkiuser catalina.properties -> /usr/share/pki/server/conf/catalina.properties
drwxrwx--- pkiuser pkiuser certs
lrwxrwxrwx pkiuser pkiuser context.xml -> /etc/tomcat/context.xml
drwxrwx--- pkiuser pkiuser kra
lrwxrwxrwx pkiuser pkiuser logging.properties -> /usr/share/pki/server/conf/logging.properties
-rw-rw---- pkiuser pkiuser password.conf
-rw-rw---- pkiuser pkiuser server.xml
-rw-rw---- pkiuser pkiuser serverCertNick.conf
-rw-rw---- pkiuser pkiuser tomcat.conf
lrwxrwxrwx pkiuser pkiuser web.xml -> /etc/tomcat/web.xml
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server conf dir after installation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check server.xml"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" cat /etc/pki/pki-tomcat/server.xml
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check server.xml (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check PKI server conf/alias dir after installation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /etc/pki/pki-tomcat/alias \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

# TODO: review permissions
cat > expected << EOF
-rw------- pkiuser pkiuser ca.crt
-rw------- pkiuser pkiuser cert9.db
-rw------- pkiuser pkiuser key4.db
-rw------- pkiuser pkiuser pkcs11.txt
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server conf/alias dir after installation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server conf/Catalina/localhost dir after installation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /etc/pki/pki-tomcat/Catalina/localhost \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

# TODO: review permissions
cat > expected << EOF
-rw-rw---- pkiuser pkiuser ROOT.xml
-rw-rw---- pkiuser pkiuser ca.xml
-rw-rw---- pkiuser pkiuser kra.xml
-rw-rw---- pkiuser pkiuser pki.xml
lrwxrwxrwx pkiuser pkiuser rewrite.config -> /usr/share/pki/server/conf/Catalina/localhost/rewrite.config
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server conf/Catalina/localhost dir after installation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server logs dir after installation"
if [[ "$GHA_FAILED" -eq 0 ]] && [[ "${FEDORA_VERSION}" -lt 43 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /var/log/pki/pki-tomcat \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

DATE=$(date +'%Y-%m-%d')

# TODO: review permissions
cat > expected << EOF
drwxrwx--- pkiuser pkiuser backup
drwxrwx--- pkiuser pkiuser ca
drwxrwx--- pkiuser pkiuser kra
-rw-r--r-- pkiuser pkiuser localhost.$DATE.log
-rw-r--r-- pkiuser pkiuser localhost_access_log.$DATE.txt
drwxr-xr-x pkiuser pkiuser pki
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server logs dir after installation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server logs dir after installation"
if [[ "$GHA_FAILED" -eq 0 ]] && [[ "${FEDORA_VERSION}" -ge 43 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /var/log/pki/pki-tomcat \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

DATE=$(date +'%Y-%m-%d')

# TODO: review permissions
cat > expected_old << EOF
drwxrwx--- pkiuser pkiuser backup
drwxrwx--- pkiuser pkiuser ca
drwxrwx--- pkiuser pkiuser kra
-rw-r--r-- pkiuser pkiuser localhost_access_log.$DATE.txt
EOF

cat > expected_new << EOF
drwxrwx--- pkiuser pkiuser backup
drwxrwx--- pkiuser pkiuser ca
drwxrwx--- pkiuser pkiuser kra
-rw-r----- pkiuser pkiuser localhost_access_log.$DATE.txt
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server logs dir after installation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check KRA base dir"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /var/lib/pki/pki-tomcat/kra \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

# TODO: review permissions
cat > expected_old << EOF
lrwxrwxrwx pkiuser pkiuser alias -> /var/lib/pki/pki-tomcat/alias
lrwxrwxrwx pkiuser pkiuser conf -> /var/lib/pki/pki-tomcat/conf/kra
lrwxrwxrwx pkiuser pkiuser logs -> /var/lib/pki/pki-tomcat/logs/kra
lrwxrwxrwx pkiuser pkiuser registry -> /etc/sysconfig/pki/tomcat/pki-tomcat
EOF

cat > expected_new << EOF
lrwxrwxrwx pkiuser pkiuser alias -> /var/lib/pki/pki-tomcat/alias
lrwxrwxrwx pkiuser pkiuser conf -> /var/lib/pki/pki-tomcat/conf/kra
lrwxrwxrwx pkiuser pkiuser logs -> /var/lib/pki/pki-tomcat/logs/kra
lrwxrwxrwx pkiuser pkiuser registry -> /etc/sysconfig/pki/tomcat/pki-tomcat
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA base dir (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check KRA conf dir"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /var/lib/pki/pki-tomcat/conf/kra \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

# TODO: review permissions
cat > expected_old << EOF
-rw-rw---- pkiuser pkiuser CS.cfg
-rw-rw---- pkiuser pkiuser registry.cfg
EOF

cat > expected_new << EOF
-rw-rw---- pkiuser pkiuser CS.cfg
-rw-rw---- pkiuser pkiuser registry.cfg
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA conf dir (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check keywrap config in KRA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# OAEP should be disabled
docker exec "$CONTAINER" pki-server kra-config-find \
    | sed -n \
        -e '/^keyWrap\./p' \
    | sort \
    | tee output

diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check keywrap config in KRA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check transport unit config in KRA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server kra-config-find \
    | sed -n \
        -e '/^kra\.transportUnit\./p' \
    | sort \
    | tee output

cat > expected << EOF
kra.transportUnit.nickName=kra_transport
kra.transportUnit.signingAlgorithm=SHA256withRSA
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check transport unit config in KRA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check storage unit config in KRA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server kra-config-find \
    | sed -n \
        -e '/^kra\.storageUnit\.wrapping\._/d' \
        -e '/^kra\.storageUnit\./p' \
    | sort \
    | tee output

cat > expected << EOF
kra.storageUnit.nickName=kra_storage
kra.storageUnit.wrapping.0.payloadEncryptionAlgorithm=DESede
kra.storageUnit.wrapping.0.payloadEncryptionIV=AQEBAQEBAQE=
kra.storageUnit.wrapping.0.payloadEncryptionMode=CBC
kra.storageUnit.wrapping.0.payloadEncryptionPadding=PKCS5Padding
kra.storageUnit.wrapping.0.payloadWrapAlgorithm=DES3/CBC/Pad
kra.storageUnit.wrapping.0.payloadWrapIV=AQEBAQEBAQE=
kra.storageUnit.wrapping.0.sessionKeyKeyGenAlgorithm=DESede
kra.storageUnit.wrapping.0.sessionKeyLength=168
kra.storageUnit.wrapping.0.sessionKeyType=DESede
kra.storageUnit.wrapping.0.sessionKeyWrapAlgorithm=RSA
kra.storageUnit.wrapping.1.payloadEncryptionAlgorithm=AES
kra.storageUnit.wrapping.1.payloadEncryptionIVLen=16
kra.storageUnit.wrapping.1.payloadEncryptionMode=CBC
kra.storageUnit.wrapping.1.payloadEncryptionPadding=PKCS5Padding
kra.storageUnit.wrapping.1.payloadWrapAlgorithm=AES KeyWrap/Padding
kra.storageUnit.wrapping.1.sessionKeyKeyGenAlgorithm=AES
kra.storageUnit.wrapping.1.sessionKeyLength=128
kra.storageUnit.wrapping.1.sessionKeyType=AES
kra.storageUnit.wrapping.1.sessionKeyWrapAlgorithm=RSA
kra.storageUnit.wrapping.2.payloadEncryptionAlgorithm=AES
kra.storageUnit.wrapping.2.payloadEncryptionIVLen=16
kra.storageUnit.wrapping.2.payloadEncryptionMode=CBC
kra.storageUnit.wrapping.2.payloadEncryptionPadding=PKCS5Padding
kra.storageUnit.wrapping.2.payloadWrapAlgorithm=AES KeyWrap/Padding
kra.storageUnit.wrapping.2.sessionKeyLength=256
kra.storageUnit.wrapping.2.sessionKeyType=AES
kra.storageUnit.wrapping.choice=1
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check storage unit config in KRA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKCS #12 encryption config in KRA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# PKCS #12 encryption should not be configured
docker exec "$CONTAINER" pki-server kra-config-find \
    | sed -n \
        -e '/^kra\.legacyPKCS12=/p' \
        -e '/^kra\.nonLegacyAlg=/p' \
    | sort \
    | tee output

diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKCS #12 encryption config in KRA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server system certs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-find
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server system certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server status"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server status | tee output

# CA should be a domain manager, but KRA should not
echo "True" > expected
echo "False" >> expected
sed -n 's/^ *SD Manager: *\(.*\)$/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server status (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check KRA storage cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-export \
    --cert-file kra_storage.crt \
    kra_storage

docker exec "$CONTAINER" openssl req -text -noout \
    -in /var/lib/pki/pki-tomcat/conf/certs/kra_storage.csr

docker exec "$CONTAINER" openssl x509 -text -noout -in kra_storage.crt

docker exec "$CONTAINER" pki-server cert-validate kra_storage
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
docker exec "$CONTAINER" pki-server cert-export \
    --cert-file kra_transport.crt \
    kra_transport

docker exec "$CONTAINER" openssl req -text -noout \
    -in /var/lib/pki/pki-tomcat/conf/certs/kra_transport.csr

docker exec "$CONTAINER" openssl x509 -text -noout -in kra_transport.crt

docker exec "$CONTAINER" pki-server cert-validate kra_transport
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA transport cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check subsystem cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-export \
    --cert-file subsystem.crt \
    subsystem

docker exec "$CONTAINER" openssl req -text -noout \
    -in /var/lib/pki/pki-tomcat/conf/certs/subsystem.csr

docker exec "$CONTAINER" openssl x509 -text -noout -in subsystem.crt

docker exec "$CONTAINER" pki-server cert-validate subsystem
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
docker exec "$CONTAINER" pki-server cert-export \
    --cert-file sslserver.crt \
    sslserver

docker exec "$CONTAINER" openssl req -text -noout \
    -in /var/lib/pki/pki-tomcat/conf/certs/sslserver.csr

docker exec "$CONTAINER" openssl x509 -text -noout -in sslserver.crt

docker exec "$CONTAINER" pki-server cert-validate sslserver
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check SSL server cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin cert after installing KRA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ls -la /root/.dogtag/pki-tomcat
docker exec "$CONTAINER" cat /root/.dogtag/pki-tomcat/ca_admin.cert

docker exec "$CONTAINER" openssl x509 -text -noout \
    -in /root/.dogtag/pki-tomcat/ca_admin.cert
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin cert after installing KRA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check security domain after installing KRA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# KRA should join security domain in CA
cat > expected << EOF
securitydomain.host=pki.example.com
securitydomain.httpport=8080
securitydomain.httpsadminport=8443
securitydomain.name=EXAMPLE
securitydomain.select=existing
EOF

docker exec "$CONTAINER" pki-server kra-config-find | grep ^securitydomain. | sort | tee actual
diff expected actual

# REST API should return security domain info
cat > expected << EOF
  Domain: EXAMPLE

  CA Subsystem:

    Host ID: CA pki.example.com 8443
    Hostname: pki.example.com
    Port: 8080
    Secure Port: 8443
    Domain Manager: TRUE

  KRA Subsystem:

    Host ID: KRA pki.example.com 8443
    Hostname: pki.example.com
    Port: 8080
    Secure Port: 8443
    Domain Manager: FALSE

EOF

docker exec "$CONTAINER" pki securitydomain-show | tee output
diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check security domain after installing KRA (rc=$_rc)" >&2
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
    docker exec "$CONTAINER" pki-healthcheck \
        --failures-only \
        --debug \
        > stdout 2> stderr
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

step "Check external commands"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
sed -n '/^Command:/p' stderr | tee output
wc -l output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check external commands (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CA info"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
cat > expected << EOF
{
    "ArchivalMechanism": "keywrap",
    "EncryptionAlgorithm": "AES/CBC/PKCS5Padding",
    "KeyWrapAlgorithm": "AES KeyWrap/Padding",
    "RsaPublicKeyWrapAlgorithm": "RSA",
    "CaRsaPublicKeyWrapAlgorithm": "RSA",
    "Attributes": {
        "Attribute": []
    }
}
EOF

docker exec "$CONTAINER" curl -ks https://pki.example.com:8443/ca/v2/info \
    | python -m json.tool \
    | tee actual

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA info (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check KRA info"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
cat > expected << EOF
{
    "ArchivalMechanism": "keywrap",
    "RecoveryMechanism": "keywrap",
    "EncryptionAlgorithm": "AES/CBC/PKCS5Padding",
    "WrapAlgorithm": "AES KeyWrap/Padding",
    "RsaPublicKeyWrapAlgorithm": "RSA",
    "Attributes": {
        "Attribute": []
    }
}
EOF

docker exec "$CONTAINER" curl -ks https://pki.example.com:8443/kra/v2/info \
    | python -m json.tool \
    | tee actual

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA info (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check KRA admin"
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

docker exec "$CONTAINER" pki nss-cert-verify \
    --cert-usage SSLClient \
    caadmin

docker exec "$CONTAINER" pki -n caadmin kra-user-show kraadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA admin (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check KRA connector in CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
TRANSPORT_CERT=$(docker exec "$CONTAINER" openssl x509 \
    -in kra_transport.crt \
    -outform der \
    | base64 --wrap=0)

docker exec "$CONTAINER" pki-server ca-config-find | grep ^ca\.connector.KRA\. | tee output

# KRA connector should be configured
cat > expected << EOF
ca.connector.KRA.enable=true
ca.connector.KRA.host=pki.example.com
ca.connector.KRA.local=false
ca.connector.KRA.nickName=subsystem
ca.connector.KRA.port=8443
ca.connector.KRA.timeout=30
ca.connector.KRA.transportCert=$TRANSPORT_CERT
ca.connector.KRA.uri=/kra/agent/kra/connector
EOF

diff expected output

docker exec "$CONTAINER" pki-server ca-connector-find | tee output

# KRA connector should be configured
cat > expected << EOF
  Connector ID: KRA
  Enabled: true
  URL: https://pki.example.com:8443
  Nickname: subsystem
EOF

diff expected output

# REST API should return KRA connector info
docker exec "$CONTAINER" pki -n caadmin ca-kraconnector-show | tee output
sed -n 's/\s*Host:\s\+\(\S\+\):.*/\1/p' output > actual
echo pki.example.com > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA connector in CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Import transport cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki nss-cert-import \
    --cert kra_transport.crt \
    kra_transport
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Import transport cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check initial key requests"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-request-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/entries matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

diff /dev/null actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial key requests (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check initial keys"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/key(s) matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

diff /dev/null actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial keys (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Generate AES key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-generate \
    --key-algorithm AES \
    --key-size 256 \
    --usages encrypt,decrypt \
    test-aes-keygen \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/Key generation request info/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

cat > expected << EOF
  Type: symkeyGenRequest
  Status: complete
EOF

diff expected actual

sed -n 's/^ *Key ID: *\(.*\)$/\1/p' output > test-aes-keygen.key_id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Generate AES key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check key requests after AES key generation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-request-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/entries matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 1 key request
cat > expected << EOF
  Type: symkeyGenRequest
  Status: complete
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check key requests after AES key generation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check keys after AES key generation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/key(s) matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 1 key
cat > expected << EOF
  Client Key ID: test-aes-keygen
  Status: active
  Algorithm: AES
  Size: 256
  Owner: kraadmin
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check keys after AES key generation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Generate RSA key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-generate \
    --key-algorithm RSA \
    --key-size 2048 \
    test-rsa-keygen \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/Key generation request info/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

cat > expected << EOF
  Type: asymkeyGenRequest
  Status: complete
EOF

diff expected actual

sed -n 's/^ *Key ID: *\(.*\)$/\1/p' output > test-rsa-keygen.key_id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Generate RSA key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check key requests after RSA key generation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-request-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/entries matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 2 key requests
cat > expected << EOF
  Type: symkeyGenRequest
  Status: complete

  Type: asymkeyGenRequest
  Status: complete
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check key requests after RSA key generation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check keys after RSA key generation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/key(s) matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 2 keys
cat > expected << EOF
  Client Key ID: test-aes-keygen
  Status: active
  Algorithm: AES
  Size: 256
  Owner: kraadmin

  Client Key ID: test-rsa-keygen
  Status: active
  Algorithm: RSA
  Size: 2048
  Owner: kraadmin
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check keys after RSA key generation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll cert with key archival"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate key and cert request
# https://github.com/dogtagpki/pki/wiki/Generating-Certificate-Request-with-PKI-NSS
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --type crmf \
    --subject UID=testuser \
    --transport kra_transport \
    --csr testuser.csr

docker exec "$CONTAINER" cat testuser.csr

# issue cert
# https://github.com/dogtagpki/pki/wiki/Issuing-Certificates
docker exec "$CONTAINER" pki \
    -u caadmin \
    -w Secret.123 \
    ca-cert-issue \
    --request-type crmf \
    --profile caUserCert \
    --subject UID=testuser \
    --csr-file testuser.csr \
    --output-file testuser.crt

# import cert into NSS database
docker exec "$CONTAINER" pki nss-cert-import --cert testuser.crt testuser

# the cert should match the key (trust flags must be u,u,u)
echo "u,u,u" > expected
docker exec "$CONTAINER" pki nss-cert-show testuser | tee output
sed -n "s/^\s*Trust Flags:\s*\(\S*\)$/\1/p" output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll cert with key archival (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check key requests after enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-request-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/entries matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 3 key requests
cat > expected << EOF
  Type: symkeyGenRequest
  Status: complete

  Type: asymkeyGenRequest
  Status: complete

  Type: enrollment
  Status: complete
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check key requests after enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check keys after enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/key(s) matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 3 keys
cat > expected << EOF
  Client Key ID: test-aes-keygen
  Status: active
  Algorithm: AES
  Size: 256
  Owner: kraadmin

  Client Key ID: test-rsa-keygen
  Status: active
  Algorithm: RSA
  Size: 2048
  Owner: kraadmin

  Algorithm: 1.2.840.113549.1.1.1
  Size: 2048
  Owner: UID=testuser
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check keys after enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check archived cert key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# find archived key by owner
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    --owner UID=testuser \
    | tee output

KEY_ID=$(sed -n "s/^\s*Key ID:\s*\(\S*\)$/\1/p" output)
echo "Key ID: $KEY_ID"
echo $KEY_ID > cert.key_id

DEC_KEY_ID=$(python -c "print(int('$KEY_ID', 16))")
echo "Dec Key ID: $DEC_KEY_ID"

# get key record
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "cn=$DEC_KEY_ID,ou=keyRepository,ou=kra,dc=kra,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -LLL | tee output

# encryption mode should be "false" by default
echo "false" > expected
sed -n 's/^metaInfo:\s*payloadEncrypted:\(.*\)$/\1/p' output > actual
diff expected actual

# key wrap algorithm should be "AES KeyWrap/Padding" by default
echo "AES KeyWrap/Padding" > expected
sed -n 's/^metaInfo:\s*payloadWrapAlgorithm:\(.*\)$/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check archived cert key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Retrieve cert key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
KEY_ID=$(cat cert.key_id)
echo "Key ID: $KEY_ID"

# export cert into Base64-encoded format
BASE64_CERT=$(docker exec "$CONTAINER" pki nss-cert-export --format DER testuser | base64 --wrap=0)
echo "Cert: $BASE64_CERT"

# create retrieval request with key ID, cert, and passphrase
cat > request.json <<EOF
{
  "ClassName" : "com.netscape.certsrv.key.KeyRecoveryRequest",
  "Attributes" : {
    "Attribute" : [ {
      "name" : "keyId",
      "value" : "$KEY_ID"
    }, {
      "name" : "certificate",
      "value" : "$BASE64_CERT"
    }, {
      "name" : "passphrase",
      "value" : "Secret.123"
    } ]
  }
}
EOF

# retrieve archived cert and key into PKCS #12 file
# https://github.com/dogtagpki/pki/wiki/Retrieving-Archived-Key
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-retrieve \
    --input $SHARED/request.json \
    --transport kra_transport \
    --output-data archived.p12

# import PKCS #12 file into NSS database with the passphrase
docker exec "$CONTAINER" pki \
    -d nssdb \
    pkcs12-import \
    --pkcs12 archived.p12 \
    --password Secret.123

# remove archived cert from NSS database
docker exec "$CONTAINER" pki -d nssdb nss-cert-del UID=testuser

# import original cert into NSS database
docker exec "$CONTAINER" pki -d nssdb nss-cert-import --cert testuser.crt testuser

# the original cert should match the archived key (trust flags must be u,u,u)
echo "u,u,u" > expected
docker exec "$CONTAINER" pki -d nssdb nss-cert-show testuser | tee output
sed -n "s/^\s*Trust Flags:\s*\(\S*\)$/\1/p" output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Retrieve cert key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check key requests after retrieval"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-request-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/entries matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 4 key requests
cat > expected << EOF
  Type: symkeyGenRequest
  Status: complete

  Type: asymkeyGenRequest
  Status: complete

  Type: enrollment
  Status: complete

  Type: recovery
  Status: complete
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check key requests after retrieval (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check keys after retrieval"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/key(s) matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 3 keys
cat > expected << EOF
  Client Key ID: test-aes-keygen
  Status: active
  Algorithm: AES
  Size: 256
  Owner: kraadmin

  Client Key ID: test-rsa-keygen
  Status: active
  Algorithm: RSA
  Size: 2048
  Owner: kraadmin

  Algorithm: 1.2.840.113549.1.1.1
  Size: 2048
  Owner: UID=testuser
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check keys after retrieval (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Deactivate cert key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
KEY_ID=$(cat cert.key_id)
echo "KEY_ID: $KEY_ID"

docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-mod \
    --status inactive \
    $KEY_ID \
    | tee output

cat > expected << EOF
  Key ID: $KEY_ID
  Status: inactive
  Algorithm: 1.2.840.113549.1.1.1
  Size: 2048
  Owner: UID=testuser
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Deactivate cert key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check key requests after deactivation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-request-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/entries matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 4 key requests
cat > expected << EOF
  Type: symkeyGenRequest
  Status: complete

  Type: asymkeyGenRequest
  Status: complete

  Type: enrollment
  Status: complete

  Type: recovery
  Status: complete
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check key requests after deactivation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check keys after deactivation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/key(s) matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 3 keys
cat > expected << EOF
  Client Key ID: test-aes-keygen
  Status: active
  Algorithm: AES
  Size: 256
  Owner: kraadmin

  Client Key ID: test-rsa-keygen
  Status: active
  Algorithm: RSA
  Size: 2048
  Owner: kraadmin

  Status: inactive
  Algorithm: 1.2.840.113549.1.1.1
  Size: 2048
  Owner: UID=testuser
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check keys after deactivation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Archive secret"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate random secret
head -c 1K < /dev/urandom > secret.archived

docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-archive \
    --clientKeyID test-secret \
    --transport kra_transport \
    --input-data $SHARED/secret.archived \
    -v

# get key ID
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    --clientKeyID test-secret | tee output

sed -n 's/^ *Key ID: *\(.*\)$/\1/p' output > cert.key_id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Archive secret (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check key requests after secret archival"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-request-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/entries matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 5 key requests
cat > expected << EOF
  Type: symkeyGenRequest
  Status: complete

  Type: asymkeyGenRequest
  Status: complete

  Type: enrollment
  Status: complete

  Type: recovery
  Status: complete

  Type: securityDataEnrollment
  Status: complete
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check key requests after secret archival (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check keys after secret archival"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/key(s) matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 4 keys
cat > expected << EOF
  Client Key ID: test-aes-keygen
  Status: active
  Algorithm: AES
  Size: 256
  Owner: kraadmin

  Client Key ID: test-rsa-keygen
  Status: active
  Algorithm: RSA
  Size: 2048
  Owner: kraadmin

  Status: inactive
  Algorithm: 1.2.840.113549.1.1.1
  Size: 2048
  Owner: UID=testuser

  Client Key ID: test-secret
  Status: active
  Owner: kraadmin
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check keys after secret archival (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Retrieve secret"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
KEY_ID=$(cat cert.key_id)
echo "KEY_ID: $KEY_ID"

docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-retrieve \
    --keyID $KEY_ID \
    --transport kra_transport \
    --output-data $SHARED/secret.retrieved \
    -v

diff secret.archived secret.retrieved
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Retrieve secret (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check key requests after secret retrieval"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-request-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/entries matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 6 key requests
cat > expected << EOF
  Type: symkeyGenRequest
  Status: complete

  Type: asymkeyGenRequest
  Status: complete

  Type: enrollment
  Status: complete

  Type: recovery
  Status: complete

  Type: securityDataEnrollment
  Status: complete

  Type: securityDataRecovery
  Status: complete
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check key requests after secret retrieval (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check keys after secret retrieval"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    kra-key-find \
    | tee output

# normalize output
sed \
    -e '/-----/d' \
    -e '/key(s) matched/d' \
    -e '/Number of entries returned/d' \
    -e '/^ *Request ID:/d' \
    -e '/^ *Key ID:/d' \
    -e '/^ *Creation Time:/d' \
    -e '/^ *Modification Time:/d' \
    output > actual

# there should be 4 keys
cat > expected << EOF
  Client Key ID: test-aes-keygen
  Status: active
  Algorithm: AES
  Size: 256
  Owner: kraadmin

  Client Key ID: test-rsa-keygen
  Status: active
  Algorithm: RSA
  Size: 2048
  Owner: kraadmin

  Status: inactive
  Algorithm: 1.2.840.113549.1.1.1
  Size: 2048
  Owner: UID=testuser

  Client Key ID: test-secret
  Status: active
  Owner: kraadmin
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check keys after secret retrieval (rc=$_rc)" >&2
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

step "Check PKI server base dir after removal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /var/lib/pki/pki-tomcat \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

# TODO: review permissions
cat > expected_old << EOF
lrwxrwxrwx pkiuser pkiuser conf -> /etc/pki/pki-tomcat
lrwxrwxrwx pkiuser pkiuser logs -> /var/log/pki/pki-tomcat
EOF

cat > expected_new << EOF
lrwxrwxrwx pkiuser pkiuser conf -> /etc/pki/pki-tomcat
lrwxrwxrwx pkiuser pkiuser logs -> /var/log/pki/pki-tomcat
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server base dir after removal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server conf dir after removal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /etc/pki/pki-tomcat \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

# TODO: review permissions
cat > expected_old << EOF
drwxrwx--- pkiuser pkiuser Catalina
drwxrwx--- pkiuser pkiuser alias
drwxrwx--- pkiuser pkiuser ca
-rw-r--r-- pkiuser pkiuser catalina.policy
lrwxrwxrwx pkiuser pkiuser catalina.properties -> /usr/share/pki/server/conf/catalina.properties
drwxrwx--- pkiuser pkiuser certs
lrwxrwxrwx pkiuser pkiuser context.xml -> /etc/tomcat/context.xml
drwxrwx--- pkiuser pkiuser kra
lrwxrwxrwx pkiuser pkiuser logging.properties -> /usr/share/pki/server/conf/logging.properties
-rw-rw---- pkiuser pkiuser password.conf
-rw-rw---- pkiuser pkiuser server.xml
-rw-rw---- pkiuser pkiuser serverCertNick.conf
-rw-rw---- pkiuser pkiuser tomcat.conf
lrwxrwxrwx pkiuser pkiuser web.xml -> /etc/tomcat/web.xml
EOF

cat > expected_new << EOF
drwxrwx--- pkiuser pkiuser Catalina
drwxrwx--- pkiuser pkiuser alias
drwxrwx--- pkiuser pkiuser ca
-rw-r--r-- pkiuser pkiuser catalina.policy
lrwxrwxrwx pkiuser pkiuser catalina.properties -> /usr/share/pki/server/conf/catalina.properties
drwxrwx--- pkiuser pkiuser certs
lrwxrwxrwx pkiuser pkiuser context.xml -> /etc/tomcat/context.xml
drwxrwx--- pkiuser pkiuser kra
lrwxrwxrwx pkiuser pkiuser logging.properties -> /usr/share/pki/server/conf/logging.properties
-rw-rw---- pkiuser pkiuser password.conf
-rw-rw---- pkiuser pkiuser server.xml
-rw-rw---- pkiuser pkiuser serverCertNick.conf
-rw-rw---- pkiuser pkiuser tomcat.conf
lrwxrwxrwx pkiuser pkiuser web.xml -> /etc/tomcat/web.xml
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server conf dir after removal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server logs dir after removal"
if [[ "$GHA_FAILED" -eq 0 ]] && [[ "${FEDORA_VERSION}" -lt 43 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /var/log/pki/pki-tomcat \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

DATE=$(date +'%Y-%m-%d')

# TODO: review permissions
cat > expected << EOF
drwxrwx--- pkiuser pkiuser backup
drwxrwx--- pkiuser pkiuser ca
drwxrwx--- pkiuser pkiuser kra
-rw-r--r-- pkiuser pkiuser localhost.$DATE.log
-rw-r--r-- pkiuser pkiuser localhost_access_log.$DATE.txt
drwxr-xr-x pkiuser pkiuser pki
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server logs dir after removal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server logs dir after removal"
if [[ "$GHA_FAILED" -eq 0 ]] && [[ "${FEDORA_VERSION}" -ge 43 ]]; then
set +e
(
set -euo pipefail
# check file types, owners, and permissions
docker exec "$CONTAINER" ls -l /var/log/pki/pki-tomcat \
    | sed \
        -e '/^total/d' \
        -e 's/^\(\S*\)\./\1/' \
        -e 's/^\(\S*\) *\S* *\(\S*\) *\(\S*\) *\S* *\S* *\S* *\S* *\(.*\)$/\1 \2 \3 \4/' \
    | tee output

DATE=$(date +'%Y-%m-%d')

# TODO: review permissions
cat > expected_old << EOF
drwxrwx--- pkiuser pkiuser backup
drwxrwx--- pkiuser pkiuser ca
drwxrwx--- pkiuser pkiuser kra
-rw-r--r-- pkiuser pkiuser localhost_access_log.$DATE.txt
EOF

cat > expected_new << EOF
drwxrwx--- pkiuser pkiuser backup
drwxrwx--- pkiuser pkiuser ca
drwxrwx--- pkiuser pkiuser kra
-rw-r----- pkiuser pkiuser localhost_access_log.$DATE.txt
EOF

diff expected_$TOMCAT_FLAVOR output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server logs dir after removal (rc=$_rc)" >&2
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

step "Check PKI server access log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" find /var/log/pki/pki-tomcat -name "localhost_access_log.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server access log (rc=$_rc)" >&2
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
    echo "==== kra-basic-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== kra-basic-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA kra-basic-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA kra-basic-test PASSED ===="

