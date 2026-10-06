#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/kra-sskg-test
# (GHA .github/workflows/kra-sskg-test.yml). Packaged forge IPACTA.
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

step "Check KRA connector in CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-export \
    --cert-file $SHARED/kra_transport.crt \
    kra_transport

TRANSPORT_CERT=$(openssl x509 \
    -in kra_transport.crt \
    -outform der \
    | base64 --wrap=0)

docker exec "$CONTAINER" pki-server ca-config-find | grep ^ca\.connector.KRA\. | tee output

# by default KRA connector should contain transport cert data
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
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA connector in CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Update KRA connector in CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# drop transport cert data from KRA connector
docker exec "$CONTAINER" pki-server ca-config-unset ca.connector.KRA.transportCert

# check transport cert in NSS database
docker exec "$CONTAINER" pki-server cert-show kra_transport

# set transport cert nickname in KRA connector
docker exec "$CONTAINER" pki-server ca-config-set ca.connector.KRA.transportCertNickname kra_transport

docker exec "$CONTAINER" pki-server ca-config-find | grep ^ca\.connector.KRA\. | tee output

# KRA connector should contain transport cert nickname
cat > expected << EOF
ca.connector.KRA.enable=true
ca.connector.KRA.host=pki.example.com
ca.connector.KRA.local=false
ca.connector.KRA.nickName=subsystem
ca.connector.KRA.port=8443
ca.connector.KRA.timeout=30
ca.connector.KRA.transportCertNickname=kra_transport
ca.connector.KRA.uri=/kra/agent/kra/connector
EOF

diff expected output

docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Update KRA connector in CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-export \
    --cert-file $SHARED/ca_signing.crt \
    ca_signing

docker exec "$CONTAINER" pki nss-cert-import \
    --cert $SHARED/ca_signing.crt \
    --trust CT,C,C \
    ca_signing

docker exec "$CONTAINER" pki nss-cert-import \
    --cert $SHARED/kra_transport.crt \
    kra_transport

docker exec "$CONTAINER" pki pkcs12-import \
    --pkcs12 /root/.dogtag/pki-tomcat/ca_admin_cert.p12 \
    --password Secret.123

docker exec "$CONTAINER" pki nss-cert-find

docker exec "$CONTAINER" pki -n admin ca-user-show caadmin

docker exec "$CONTAINER" pki -n admin kra-user-show kraadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create request template for caServerKeygen_UserCert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# get request template
docker exec "$CONTAINER" curl \
    -s \
    -o - \
    --cacert $SHARED/ca_signing.crt \
    https://pki.example.com:8443/ca/v2/certrequests/profiles/caServerKeygen_UserCert \
    | tee caServerKeygen_UserCert.json

# configure request to create 2048-bit RSA key
cat caServerKeygen_UserCert.json \
    | jq '.Input[0].Attribute[1].Value|="RSA" | .Input[0].Attribute[2].Value|="2048"' \
    | tee template.json
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create request template for caServerKeygen_UserCert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Submit request with good password"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create request with good password for user test1
#
# by default the password must be at least 20 characters,
# contain at least 2 upper case letters, and contain at
# least 1 special character.
cat template.json \
    | jq '.Input[0].Attribute[0].Value|="k342r09cmIJmklOLIJ,lwerkln234lik-[df"' \
    | jq '.Input[1].Attribute[0].Value|="test1"' \
    | tee request.json

# submit request
docker exec "$CONTAINER" curl \
    -s \
    -o - \
    --cacert $SHARED/ca_signing.crt \
    --json @$SHARED/request.json \
    https://pki.example.com:8443/ca/v2/certrequests \
    | tee response.json

# request should be pending
jq -r '.entries[0].requestStatus' response.json > actual

cat > expected << EOF
pending
EOF

diff expected actual

# approve request
REQUEST_ID=$(jq -r '.entries[0].requestID' response.json)
docker exec "$CONTAINER" pki \
    -n admin \
    ca-cert-request-approve \
    --force \
    $REQUEST_ID \
    | tee output

# export cert
CERT_ID=$(sed -n 's/^\s*Certificate ID:\s*\(\S*\)$/\1/p' output)
docker exec "$CONTAINER" pki ca-cert-export \
    --output-file $SHARED/test1.crt \
    $CERT_ID
echo "Cert ID: $CERT_ID"
echo $CERT_ID > test1.cert_id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Submit request with good password (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Find generated key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# find generated key by owner
docker exec "$CONTAINER" pki \
    -n admin \
    kra-key-find \
    --owner UID=test1 \
    | tee output

KEY_ID=$(sed -n 's/^\s*Key ID:\s*\(\S*\)$/\1/p' output)
echo "Key ID: $KEY_ID"
echo $KEY_ID > test1.key_id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Find generated key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Retrieve generated key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
KEY_ID=$(cat test1.key_id)
echo "Key ID: $KEY_ID"

# export cert into Base64-encoded format
BASE64_CERT=$(openssl x509 -in test1.crt -outform DER | base64 --wrap=0)
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

# retrieve cert and key into PKCS #12 file
docker exec "$CONTAINER" pki \
    -n admin \
    kra-key-retrieve \
    --input $SHARED/request.json \
    --transport kra_transport \
    --output-data test1.p12

docker exec "$CONTAINER" pki pkcs12-cert-find \
    --pkcs12 test1.p12 \
    --password Secret.123

docker exec "$CONTAINER" pki pkcs12-key-find \
    --pkcs12 test1.p12 \
    --password Secret.123
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Retrieve generated key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Import retrieved key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# import PKCS #12 file into NSS database with the passphrase
docker exec "$CONTAINER" pki \
    -d nssdb \
    pkcs12-import \
    --pkcs12 test1.p12 \
    --password Secret.123

# remove retrieved cert from NSS database
docker exec "$CONTAINER" pki \
    -d nssdb \
    nss-cert-del \
    UID=test1

# import original cert into NSS database
docker exec "$CONTAINER" pki \
    -d nssdb \
    nss-cert-import \
    --cert $SHARED/test1.crt \
    test1

# the original cert should match the retrieved key (trust flags must be u,u,u)
docker exec "$CONTAINER" pki \
    -d nssdb \
    nss-cert-show \
    test1 \
    | tee output

cat > expected << EOF
u,u,u
EOF

sed -n 's/^\s*Trust Flags:\s*\(\S\+\)$/\1/p' output > actual

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Import retrieved key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Submit request with short password"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create request with short password for user test2
cat template.json \
    | jq '.Input[0].Attribute[0].Value|="k342r0"' \
    | jq '.Input[1].Attribute[0].Value|="test2"' \
    | tee request.json

# submit request
docker exec "$CONTAINER" curl \
    -s \
    -o - \
    --cacert $SHARED/ca_signing.crt \
    --json @$SHARED/request.json \
    https://pki.example.com:8443/ca/v2/certrequests \
    | tee response.json

# request should be rejected
jq -r '.entries[0].requestStatus, .entries[0].errorMessage' response.json > actual

cat > expected <<EOF
rejected
The password must be at least 20 characters
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Submit request with short password (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Submit request with numeric password"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create request with numeric password for user test3
cat template.json \
    | jq '.Input[0].Attribute[0].Value|="1234567890246801357938"' \
    | jq '.Input[1].Attribute[0].Value|="test3"' \
    | tee request.json

# submit request
docker exec "$CONTAINER" curl \
    -s \
    -o - \
    --cacert $SHARED/ca_signing.crt \
    --json @$SHARED/request.json \
    https://pki.example.com:8443/ca/v2/certrequests \
    | tee response.json

# request should be rejected
jq -r '.entries[0].requestStatus, .entries[0].errorMessage' response.json > actual

cat > expected <<EOF
rejected
The password requires at least 2 upper case letter(s)
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Submit request with numeric password (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Disable PKCS #12 password constraint"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# disable p12ExportPasswordConstraintImpl
docker exec "$CONTAINER" sed -i \
    's/^policyset.userCertSet.list=1,10,2,3,4,5,6,7,8,9,11/policyset.userCertSet.list=1,10,2,3,4,5,6,7,8,9/' \
    /etc/pki/pki-tomcat/ca/profiles/ca/caServerKeygen_UserCert.cfg

docker exec "$CONTAINER" pki-server ca redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Disable PKCS #12 password constraint (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Submit request with minimal password"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create request with minimal password for user test4
cat template.json \
    | jq '.Input[0].Attribute[0].Value|="1"' \
    | jq '.Input[1].Attribute[0].Value|="test4"' \
    | tee request.json

# submit request
docker exec "$CONTAINER" curl \
    -s \
    -o - \
    --cacert $SHARED/ca_signing.crt \
    --json @$SHARED/request.json \
    https://pki.example.com:8443/ca/v2/certrequests \
    | tee response.json

# request should be pending
jq -r '.entries[0].requestStatus' response.json > actual

cat > expected << EOF
pending
EOF

diff expected actual

# approve request
REQUEST_ID=$(jq -r '.entries[0].requestID' response.json)
docker exec "$CONTAINER" pki \
    -n admin \
    ca-cert-request-approve \
    --force \
    $REQUEST_ID \
    | tee output

# export cert
CERT_ID=$(sed -n 's/^\s*Certificate ID:\s*\(\S*\)$/\1/p' output)
docker exec "$CONTAINER" pki ca-cert-export \
    --output-file $SHARED/test4.crt \
    $CERT_ID
echo "Cert ID: $CERT_ID"
echo $CERT_ID > test4.cert_id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Submit request with minimal password (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Find generated key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# find generated key by owner
docker exec "$CONTAINER" pki \
    -n admin \
    kra-key-find \
    --owner UID=test4 \
    | tee output

KEY_ID=$(sed -n 's/^\s*Key ID:\s*\(\S*\)$/\1/p' output)
echo "Key ID: $KEY_ID"
echo $KEY_ID > test4.key_id
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Find generated key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Retrieve generated key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
KEY_ID=$(cat test4.key_id)
echo "Key ID: $KEY_ID"

# export cert into Base64-encoded format
BASE64_CERT=$(openssl x509 -in test4.crt -outform DER | base64 --wrap=0)
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

# retrieve cert and key into PKCS #12 file
docker exec "$CONTAINER" pki \
    -n admin \
    kra-key-retrieve \
    --input $SHARED/request.json \
    --transport kra_transport \
    --output-data test4.p12

docker exec "$CONTAINER" pki pkcs12-cert-find \
    --pkcs12 test4.p12 \
    --password Secret.123

docker exec "$CONTAINER" pki pkcs12-key-find \
    --pkcs12 test4.p12 \
    --password Secret.123
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Retrieve generated key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Import generated key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# import PKCS #12 file into NSS database with the passphrase
docker exec "$CONTAINER" pki \
    -d nssdb \
    pkcs12-import \
    --pkcs12 test4.p12 \
    --password Secret.123

# remove retrieved cert from NSS database
docker exec "$CONTAINER" pki \
    -d nssdb \
    nss-cert-del \
    UID=test4

# import original cert into NSS database
docker exec "$CONTAINER" pki \
    -d nssdb \
    nss-cert-import \
    --cert $SHARED/test4.crt \
    test4

# the original cert should match the retrieved key (trust flags must be u,u,u)
docker exec "$CONTAINER" pki \
    -d nssdb \
    nss-cert-show \
    test4 \
    | tee output

cat > expected << EOF
u,u,u
EOF

sed -n 's/^\s*Trust Flags:\s*\(\S\+\)$/\1/p' output > actual

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Import generated key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove KRA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pkidestroy -s KRA -v
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove KRA (rc=$_rc)" >&2
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
    echo "==== kra-sskg-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== kra-sskg-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA kra-sskg-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA kra-sskg-test PASSED ===="

