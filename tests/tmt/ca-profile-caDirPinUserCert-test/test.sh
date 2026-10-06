#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-profile-caDirPinUserCert-test
# (GHA .github/workflows/ca-profile-caDirPinUserCert-test.yml). Packaged forge IPACTA.
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

step "Add LDAP users"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec -i "$CONTAINER" ldapadd \
    -H ldap://ds.example.com:3389 \
    -D "cn=Directory Manager" \
    -w Secret.123 << EOF
dn: ou=people,dc=example,dc=com
objectclass: top
objectclass: organizationalUnit
ou: people
aci: (target="ldap:///ou=people,dc=example,dc=com")
 (targetattr=objectClass||dc||ou||uid||cn||sn||givenName)
 (version 3.0; acl "Allow anyone to read and search basic attributes"; allow (search, read) userdn = "ldap:///anyone";)
aci: (target="ldap:///ou=people,dc=example,dc=com")
 (targetattr=*)
 (version 3.0; acl "Allow anyone to read and search itself"; allow (search, read) userdn = "ldap:///self";)

dn: uid=testuser1,ou=people,dc=example,dc=com
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: testuser1
cn: Test User 1
sn: User
userPassword: Secret.123

dn: uid=testuser2,ou=people,dc=example,dc=com
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: testuser2
cn: Test User 2
sn: User
userPassword: Secret.123

dn: uid=testuser3,ou=people,dc=example,dc=com
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: testuser3
cn: Test User 3
sn: User
userPassword: Secret.123
EOF
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Add LDAP users (rc=$_rc)" >&2
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

step "Set up PIN database"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# configure setpin
docker exec "$CONTAINER" sed \
    -e "s/^host=.*$/host=ds.example.com/" \
    -e "s/^port=.*$/port=3389/" \
    -e "s/^binddn=.*$/binddn=cn=Directory Manager/" \
    -e "s/^bindpw=.*$/bindpw=Secret.123/" \
    -e "s/^pinmanager=.*$/pinmanager=uid=pinmanager,dc=example,dc=com/" \
    -e "s/^pinmanagerpwd=.*$/pinmanagerpwd=Secret.123/" \
    -e "s/^basedn=.*$/basedn=ou=people,dc=example,dc=com/" \
    /usr/share/pki/tools/setpin.conf | tee setpin.conf

# run setpin
# NOTE: currently setpin will crash due to buffer overflow
# so the operations need to be executed manually instead
# docker exec "$CONTAINER" setpin optfile=$SHARED/setpin.conf
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up PIN database (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Add PIN schema"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec -i "$CONTAINER" ldapmodify \
    -H ldap://ds.example.com:3389 \
    -D "cn=Directory Manager" \
    -w Secret.123 << EOF
dn: cn=schema
changeType: modify
add: attributeTypes
attributeTypes: ( pin-oid NAME 'pin' DESC 'User Defined Attribute' SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 SINGLE-VALUE X-ORIGIN ( 'custom for setpin' 'user defined' ) )
-
add: objectClasses
objectClasses: ( 2.16.840.1.117370.999.1.2.10 NAME 'pinPerson' DESC 'User Defined ObjectClass' SUP top STRUCTURAL MAY ( aci $ pin ) X-ORIGIN 'user defined' )
-
EOF
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Add PIN schema (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Add PIN manager"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec -i "$CONTAINER" ldapadd \
    -H ldap://ds.example.com:3389 \
    -D "cn=Directory Manager" \
    -w Secret.123 << EOF
dn: uid=pinmanager,dc=example,dc=com
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: pinmanager
cn: PIN Manager
sn: Manager
userPassword: Secret.123
EOF
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Add PIN manager (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Add PIN access control"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec -i "$CONTAINER" ldapmodify \
    -H ldap://ds.example.com:3389 \
    -D "cn=Directory Manager" \
    -w Secret.123 << EOF
dn: ou=people,dc=example,dc=com
changeType: modify
add: aci
aci: (target="ldap:///ou=people,dc=example,dc=com")(targetattr="pin")(version 3.0; acl "Pin attribute"; allow (all) userdn = "ldap:///uid=pinmanager,dc=example,dc=com"; deny(proxy,selfwrite,compare,add,write,delete,search) userdn = "ldap:///self";)
aci: (target="ldap:///ou=people,dc=example,dc=com")(targetattr="objectclass")(version 3.0; acl "Pin Objectclass"; allow (all) userdn = "ldap:///uid=pinmanager,dc=example,dc=com";)
-
EOF
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Add PIN access control (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PIN schema"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check pin attribute type
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b cn=schema \
    -o ldif_wrap=no \
    -LLL \
    attributeTypes \
    | tee output

sed -n "/^attributeTypes:\s*(\s*\S\+\s*NAME\s*'pin'/p" output > actual

cat > expected << EOF
attributeTypes: ( pin-oid NAME 'pin' DESC 'User Defined Attribute' SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 SINGLE-VALUE X-ORIGIN ( 'custom for setpin' 'user defined' ) )
EOF

diff expected actual

# check pinPerson object class
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b cn=schema \
    -o ldif_wrap=no \
    -LLL \
    objectClasses \
    | tee output

sed -n "/^objectClasses:\s*(\s*\S\+\s*NAME\s*'pinPerson'/p" output > actual

cat > expected << EOF
objectClasses: ( 2.16.840.1.117370.999.1.2.10 NAME 'pinPerson' DESC 'User Defined ObjectClass' SUP top STRUCTURAL MAY ( aci $ pin ) X-ORIGIN 'user defined' )
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PIN schema (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PIN manager"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=pinmanager,dc=example,dc=com" \
    -s base \
    -t \
    -o ldif_wrap=no \
    -LLL \
    | tee output

cat > expected << EOF
dn: uid=pinmanager,dc=example,dc=com
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: top
uid: pinmanager
cn: PIN Manager
sn: Manager
userPassword:: XXXXX
EOF

# normalize output
sed \
    -e '/^$/d' \
    -e 's/^\(userPassword\):: .*$/\1:: XXXXX/' \
    output > actual

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PIN manager (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PIN access control"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "ou=people,dc=example,dc=com" \
    -s base \
    -t \
    -o ldif_wrap=no \
    -LLL \
    aci \
    | tee output

# there should be 2 old ACI attrs and 2 new ones
cat > expected << EOF
aci: (target="ldap:///ou=people,dc=example,dc=com")(targetattr=objectClass||dc||ou||uid||cn||sn||givenName)(version 3.0; acl "Allow anyone to read and search basic attributes"; allow (search, read) userdn = "ldap:///anyone";)
aci: (target="ldap:///ou=people,dc=example,dc=com")(targetattr=*)(version 3.0; acl "Allow anyone to read and search itself"; allow (search, read) userdn = "ldap:///self";)
aci: (target="ldap:///ou=people,dc=example,dc=com")(targetattr="pin")(version 3.0; acl "Pin attribute"; allow (all) userdn = "ldap:///uid=pinmanager,dc=example,dc=com"; deny(proxy,selfwrite,compare,add,write,delete,search) userdn = "ldap:///self";)
aci: (target="ldap:///ou=people,dc=example,dc=com")(targetattr="objectclass")(version 3.0; acl "Pin Objectclass"; allow (all) userdn = "ldap:///uid=pinmanager,dc=example,dc=com";)
EOF

grep '^aci:' output > actual

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PIN access control (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Generate user PINs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# disable setup mode
sed -i "/^setup=/d" setpin.conf

# run setpin to generate PINs for all users
docker exec "$CONTAINER" setpin \
    filter="(objectClass=person)" \
    optfile=$SHARED/setpin.conf \
    output=$SHARED/setpin.out \
    write

cat setpin.out

# check users
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "ou=people,dc=example,dc=com" \
    -s one \
    -o ldif_wrap=no \
    -LLL
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Generate user PINs (rc=$_rc)" >&2
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

step "Configure PinDirEnrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.PinDirEnrollment.pluginName UidPwdPinDirAuth
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.PinDirEnrollment.ldap.basedn ou=people,dc=example,dc=com
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.PinDirEnrollment.ldap.ldapauth.authtype BasicAuth
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.PinDirEnrollment.ldap.ldapconn.host ds.example.com
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.PinDirEnrollment.ldap.ldapconn.port 3389
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure PinDirEnrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enable caDirPinUserCert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" sed -i \
    -e "s/^\(enable\)=.*/\1=true/" \
    /var/lib/pki/pki-tomcat/ca/profiles/ca/caDirPinUserCert.cfg
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enable caDirPinUserCert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Restart CA subsystem"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Restart CA subsystem (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin"
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
docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check enrollment using pki ca-cert-issue"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
PIN=$(sed -En 'N; s/^dn:uid=testuser1,.*\npin:(.*)$/\1/p; D' setpin.out)
echo "PIN: $PIN"

# generate cert request
docker exec "$CONTAINER" pki nss-cert-request \
    --subject "UID=testuser1" \
    --csr $SHARED/testuser1.csr

echo "Secret.123" > password.txt
echo "$PIN" > pin.txt

# issue cert
docker exec "$CONTAINER" pki \
    ca-cert-issue \
    --profile caDirPinUserCert \
    --username testuser1 \
    --password-file $SHARED/password.txt \
    --pin-file $SHARED/pin.txt \
    --csr-file $SHARED/testuser1.csr \
    --output-file testuser1.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import testuser1 --cert testuser1.crt
docker exec "$CONTAINER" pki nss-cert-show testuser1 | tee output

# the cert should match the key (trust flags must be u,u,u)
echo "u,u,u" > expected
sed -n "s/^\s*Trust Flags:\s*\(\S*\)$/\1/p" output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check enrollment using pki ca-cert-issue (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check enrollment using XML"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
PIN=$(sed -En 'N; s/^dn:uid=testuser2,.*\npin:(.*)$/\1/p; D' setpin.out)
echo "PIN: $PIN"

# generate cert request
docker exec "$CONTAINER" pki nss-cert-request \
    --subject "UID=testuser2" \
    --csr $SHARED/testuser2.csr

# retrieve request template using REST API v1
docker exec "$CONTAINER" curl \
    -k \
    -s \
    -H "Content-Type: application/xml" \
    -H "Accept: application/xml" \
    https://pki.example.com:8443/ca/v1/certrequests/profiles/caDirPinUserCert \
    | xmllint --format - \
    | tee testuser2-request.xml

# insert username
xmlstarlet edit --inplace \
    -s "/CertEnrollmentRequest/Attributes" --type elem --name "Attribute" -v "testuser2" \
    -i "/CertEnrollmentRequest/Attributes/Attribute[not(@name)]" -t attr -n "name" -v "uid" \
    testuser2-request.xml

# insert password
xmlstarlet edit --inplace \
    -s "/CertEnrollmentRequest/Attributes" --type elem --name "Attribute" -v "Secret.123" \
    -i "/CertEnrollmentRequest/Attributes/Attribute[not(@name)]" -t attr -n "name" -v "pwd" \
    testuser2-request.xml

# insert PIN
xmlstarlet edit --inplace \
    -s "/CertEnrollmentRequest/Attributes" --type elem --name "Attribute" -v "$PIN" \
    -i "/CertEnrollmentRequest/Attributes/Attribute[not(@name)]" -t attr -n "name" -v "pin" \
    testuser2-request.xml

# insert request type
xmlstarlet edit --inplace \
    -u "/CertEnrollmentRequest/Input/Attribute[@name='cert_request_type']/Value" \
    -v "pkcs10" \
    testuser2-request.xml

# insert CSR
xmlstarlet edit --inplace \
    -u "/CertEnrollmentRequest/Input/Attribute[@name='cert_request']/Value" \
    -v "$(cat testuser2.csr)" \
    testuser2-request.xml

cat testuser2-request.xml

# submit request using REST API v1
docker exec "$CONTAINER" curl \
    -k \
    -s \
    -X POST \
    -d @$SHARED/testuser2-request.xml \
    -H "Content-Type: application/xml" \
    -H "Accept: application/xml" \
    https://pki.example.com:8443/ca/v1/certrequests \
    | xmllint --format - \
    | tee testuser2-response.xml
CERT_ID=$(xmlstarlet sel -t -v '/CertRequestInfos/CertRequestInfo/certID' testuser2-response.xml)

# retrieve cert using REST API v1
docker exec "$CONTAINER" curl \
    -k \
    -s \
    -H "Content-Type: application/xml" \
    -H "Accept: application/xml" \
    https://pki.example.com:8443/ca/v1/certs/$CERT_ID \
    | xmllint --format - \
    | tee testuser2-cert.xml

# The XML transformation in CertData.toXML() converts "\r"
# chars in the cert into "&#13;" which need to be removed.
# TODO: Fix CertData.toXML() to avoid adding "&#13;".
xmlstarlet sel -t -v '/CertData/Encoded' testuser2-cert.xml \
    | sed 's/&#13;$//' \
    | tee testuser2.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import testuser2 --cert $SHARED/testuser2.crt
docker exec "$CONTAINER" pki nss-cert-show testuser2 | tee output

# the cert should match the key (trust flags must be u,u,u)
echo "u,u,u" > expected
sed -n "s/^\s*Trust Flags:\s*\(\S*\)$/\1/p" output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check enrollment using XML (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check enrollment using JSON"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
PIN=$(sed -En 'N; s/^dn:uid=testuser3,.*\npin:(.*)$/\1/p; D' setpin.out)
echo "PIN: $PIN"

# generate cert request
docker exec "$CONTAINER" pki nss-cert-request \
    --subject "UID=testuser3" \
    --csr $SHARED/testuser3.csr

# retrieve request template using REST API v2
docker exec "$CONTAINER" curl \
    -k \
    -s \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    https://pki.example.com:8443/ca/v2/certrequests/profiles/caDirPinUserCert \
    | python -m json.tool \
    | tee testuser3-request.json

# insert username
jq '.Attributes.Attribute[.Attributes.Attribute|length] |= . + { "name": "uid", "value": "testuser3" }' \
    testuser3-request.json | sponge testuser3-request.json

# insert password
jq '.Attributes.Attribute[.Attributes.Attribute|length] |= . + { "name": "pwd", "value": "Secret.123" }' \
    testuser3-request.json | sponge testuser3-request.json

# insert PIN
jq --arg PIN "$PIN" '.Attributes.Attribute[.Attributes.Attribute|length] |= . + { "name": "pin", "value": $PIN }' \
    testuser3-request.json | sponge testuser3-request.json

# insert request type
jq '( .Input[].Attribute[] | select(.name=="cert_request_type") ).Value |= "pkcs10"' \
    testuser3-request.json | sponge testuser3-request.json

# insert CSR
jq --rawfile cert_request testuser3.csr '( .Input[].Attribute[] | select(.name=="cert_request") ).Value |= $cert_request' \
    testuser3-request.json | sponge testuser3-request.json

cat testuser3-request.json

# submit request using REST API v2
docker exec "$CONTAINER" curl \
    -k \
    -s \
    -X POST \
    -d @$SHARED/testuser3-request.json \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    https://pki.example.com:8443/ca/v2/certrequests \
    | python -m json.tool \
    | tee testuser3-response.json
CERT_ID=$(jq -j '.entries[].certId' testuser3-response.json)

# retrieve cert using REST API v2
docker exec "$CONTAINER" curl \
    -k \
    -s \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    https://pki.example.com:8443/ca/v2/certs/$CERT_ID \
    | python -m json.tool \
    | tee testuser3-cert.json
jq -j '.Encoded' testuser3-cert.json | tee testuser3.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import testuser3 --cert $SHARED/testuser3.crt
docker exec "$CONTAINER" pki nss-cert-show testuser3 | tee output

# the cert should match the key (trust flags must be u,u,u)
echo "u,u,u" > expected
sed -n "s/^\s*Trust Flags:\s*\(\S*\)$/\1/p" output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check enrollment using JSON (rc=$_rc)" >&2
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
    echo "==== ca-profile-caDirPinUserCert-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-profile-caDirPinUserCert-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-profile-caDirPinUserCert-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-profile-caDirPinUserCert-test PASSED ===="

