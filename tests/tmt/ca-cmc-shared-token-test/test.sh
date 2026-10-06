#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-cmc-shared-token-test
# (GHA .github/workflows/ca-cmc-shared-token-test.yml). Packaged forge IPACTA.
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

step "Install CA admin cert"
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
    echo "FAIL: Install CA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create issuance protection cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate cert request
docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-request \
    --subject "CN=CA Issuance Protection" \
    --csr ca_issuance_protection.csr

# check generated CSR
docker exec "$CONTAINER" openssl req -text -noout -in ca_issuance_protection.csr

# create CMC request
docker exec "$CONTAINER" CMCRequest \
    /usr/share/pki/server/examples/cmc/ca_issuance_protection-cmc-request.cfg \

# submit CMC request
docker exec "$CONTAINER" HttpClient \
    /usr/share/pki/server/examples/cmc/ca_issuance_protection-cmc-submit.cfg \

# convert CMC response (DER PKCS #7) into PEM PKCS #7 cert chain
docker exec "$CONTAINER" CMCResponse \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -i ca_issuance_protection.cmc-response \
    -o ca_issuance_protection.p7b | tee output

echo "SUCCESS" > expected
sed -n 's/^ *Status: *\(.*\)/\1/p' output > actual
diff expected actual

# check issued cert chain
docker exec "$CONTAINER" openssl pkcs7 \
    -print_certs \
    -in ca_issuance_protection.p7b

# import cert chain
docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    pkcs7-import \
    --pkcs7 ca_issuance_protection.p7b \
    ca_issuance_protection

# check imported cert chain
docker exec "$CONTAINER" pki \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f /var/lib/pki/pki-tomcat/conf/password.conf \
    nss-cert-find

# configure issuance protection nickname
docker exec "$CONTAINER" pki-server ca-config-set ca.cert.issuance_protection.nickname ca_issuance_protection
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create issuance protection cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure shared token auth"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# update schema
docker exec "$CONTAINER" ldapmodify \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -f /usr/share/pki/ca/auth/ds/schema.ldif

# add user subtree
docker exec "$CONTAINER" ldapadd \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -f /usr/share/pki/ca/auth/ds/create.ldif

# add user records
docker exec "$CONTAINER" ldapadd \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -f /usr/share/pki/ca/auth/ds/example.ldif

# configure CMC shared token authentication
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.SharedToken.ldap.basedn ou=people,dc=example,dc=com
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.SharedToken.ldap.ldapauth.authtype BasicAuth
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.SharedToken.ldap.ldapauth.bindDN "cn=Directory Manager"
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.SharedToken.ldap.ldapauth.bindPWPrompt "Rule SharedToken"
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.SharedToken.ldap.ldapconn.host ds.example.com
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.SharedToken.ldap.ldapconn.port 3389
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.SharedToken.ldap.ldapconn.secureConn false
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.SharedToken.pluginName SharedToken
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.SharedToken.shrTokAttr shrTok

# enable caFullCMCSharedTokenCert profile
docker exec "$CONTAINER" sed -i \
    -e "s/^\(enable\)=.*/\1=true/" \
    /var/lib/pki/pki-tomcat/ca/profiles/ca/caFullCMCSharedTokenCert.cfg

# enable caFullCMCUserSignedCert profile
docker exec "$CONTAINER" sed -i \
    -e "s/^\(enable\)=.*/\1=true/" \
    /var/lib/pki/pki-tomcat/ca/profiles/ca/caFullCMCUserSignedCert.cfg

# restart CA subsystem
docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure shared token auth (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Generate shared token for user"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# generate shared token
docker exec "$CONTAINER" CMCSharedToken \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -p Secret.123 \
    -n ca_issuance_protection \
    -s Secret.123 \
    -o $SHARED/testuser.b64

# convert into a single line
sed -e :a -e 'N;s/\r\n//;ba' testuser.b64 > token.txt
SHARED_TOKEN=$(cat token.txt)
echo "SHARED_TOKEN: $SHARED_TOKEN"

cat > add.ldif << EOF
dn: uid=testuser,ou=people,dc=example,dc=com
changetype: modify
add: objectClass
objectClass: extensibleobject
-
add: shrTok
shrTok: $SHARED_TOKEN
-
EOF
cat add.ldif

# add shared token into user record
docker exec "$CONTAINER" ldapmodify \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -f $SHARED/add.ldif
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Generate shared token for user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue user cert with shared token"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create key
docker exec "$CONTAINER" pki nss-key-create --output-format json | tee output
KEY_ID=$(jq -r '.keyId' output)
echo "KEY_ID: $KEY_ID"

# generated cert request
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --key-id $KEY_ID \
    --subject "uid=testuser" \
    --ext /usr/share/pki/tools/examples/certs/testuser.conf \
    --csr testuser.csr

# check generated CSR
docker exec "$CONTAINER" openssl req -text -noout -in testuser.csr

# insert key ID into CMCRequest config
docker cp \
    pki:/usr/share/pki/tools/examples/cmc/testuser-cmc-request.cfg \
    testuser-cmc-request.cfg
sed -i \
    -e "s/^\(request.privKeyId\)=.*/\1=$KEY_ID/" \
    testuser-cmc-request.cfg
cat testuser-cmc-request.cfg

# create CMC request
docker exec "$CONTAINER" CMCRequest \
    $SHARED/testuser-cmc-request.cfg

# submit CMC request
docker exec "$CONTAINER" HttpClient \
    /usr/share/pki/tools/examples/cmc/testuser-cmc-submit.cfg

# convert CMC response (DER PKCS #7) into PEM PKCS #7 cert chain
docker exec "$CONTAINER" CMCResponse \
    -d /root/.dogtag/nssdb \
    -i testuser.cmc-response \
    -o testuser.p7b | tee output

echo "SUCCESS" > expected
sed -n 's/^ *Status: *\(.*\)/\1/p' output > actual
diff expected actual

# check issued cert chain
docker exec "$CONTAINER" pki \
    pkcs7-cert-find \
    --pkcs7 testuser.p7b

# import cert chain
docker exec "$CONTAINER" pki \
    pkcs7-import \
    --pkcs7 testuser.p7b \
    testuser

# check imported user cert
docker exec "$CONTAINER" pki nss-cert-show testuser | tee output

# get user cert serial number
sed -n 's/^ *Serial Number: *\(.*\)/\1/p' output > testuser.serial
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue user cert with shared token (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Revoke user cert with shared token"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
HEX_SERIAL=$(cat testuser.serial)
echo "Hex serial: $HEX_SERIAL"

DEC_SERIAL=$(python -c "print(int('$HEX_SERIAL', 16))")
echo "Dec serial: $DEC_SERIAL"

SHARED_TOKEN=$(cat token.txt)

cat > modify.ldif << EOF
dn: cn=$DEC_SERIAL,ou=certificateRepository,ou=ca,dc=ca,dc=pki,dc=example,dc=com
changetype: modify
add: metaInfo
metaInfo: revShrTok:$SHARED_TOKEN
-
EOF
cat modify.ldif

# add shared token into cert record
docker exec "$CONTAINER" ldapmodify \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -f $SHARED/modify.ldif

# insert user cert serial number into CMCRequest config
docker cp \
    pki:/usr/share/pki/tools/examples/cmc/testuser-cmc-revocation-request.cfg \
    testuser-cmc-revocation-request.cfg
sed -i \
    -e "s/^\(revRequest.serial\)=.*/\1=$HEX_SERIAL/" \
    testuser-cmc-revocation-request.cfg
cat testuser-cmc-revocation-request.cfg

# create CMC request
docker exec "$CONTAINER" CMCRequest \
    $SHARED/testuser-cmc-revocation-request.cfg

# submit CMC request
docker exec "$CONTAINER" HttpClient \
    /usr/share/pki/tools/examples/cmc/testuser-cmc-revocation-submit.cfg

# process CMC response
docker exec "$CONTAINER" CMCResponse \
    -d /root/.dogtag/nssdb \
    -i testuser.cmc-revocation-response | tee output

echo "SUCCESS" > expected
sed -n 's/^ *Status: *\(.*\)/\1/p' output > actual
diff expected actual

# check cert status
docker exec "$CONTAINER" pki ca-cert-show $HEX_SERIAL | tee output

echo "REVOKED" > expected
sed -n 's/^ *Status: *\(.*\)/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Revoke user cert with shared token (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CMC_USER_SIGNED_REQUEST_SIG_VERIFY events"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" grep \
    "\[AuditEvent=CMC_USER_SIGNED_REQUEST_SIG_VERIFY\]" \
    /var/lib/pki/pki-tomcat/logs/ca/signedAudit/ca_audit | tee output

# there should be 1 event from user cert enrollment
echo "1" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CMC_USER_SIGNED_REQUEST_SIG_VERIFY events (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CERT_STATUS_CHANGE_REQUEST_PROCESSED events"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" grep \
    "\[AuditEvent=CERT_STATUS_CHANGE_REQUEST_PROCESSED\]" \
    /var/lib/pki/pki-tomcat/logs/ca/signedAudit/ca_audit | tee output

# there should be 1 event from user cert revocation
echo "1" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CERT_STATUS_CHANGE_REQUEST_PROCESSED events (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CMC_REQUEST_RECEIVED events"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" grep \
    "\[AuditEvent=CMC_REQUEST_RECEIVED\]" \
    /var/lib/pki/pki-tomcat/logs/ca/signedAudit/ca_audit | tee output

# there should be 3 events from issuance protection cert enrollment,
# user cert enrollment, user cert revocation
echo "3" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CMC_REQUEST_RECEIVED events (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CMC_RESPONSE_SENT events"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" grep \
    "\[AuditEvent=CMC_RESPONSE_SENT\]" \
    /var/lib/pki/pki-tomcat/logs/ca/signedAudit/ca_audit | tee output

# there should be 3 events from issuance protection cert enrollment,
# user cert enrollment, user cert revocation
echo "3" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CMC_RESPONSE_SENT events (rc=$_rc)" >&2
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
    echo "==== ca-cmc-shared-token-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-cmc-shared-token-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-cmc-shared-token-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-cmc-shared-token-test PASSED ===="

