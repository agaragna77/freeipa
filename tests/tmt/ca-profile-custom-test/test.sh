#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-profile-custom-test
# (GHA .github/workflows/ca-profile-custom-test.yml). Packaged forge IPACTA.
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

step "Set up authentication database"
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
ou: People
aci: (target = "ldap:///ou=people,dc=example,dc=com")
 (targetattr=objectClass||dc||ou||uid||cn||sn||givenName)
 (version 3.0; acl "Allow anyone to read and search basic attributes"; allow (search, read) userdn = "ldap:///anyone";)
aci: (target = "ldap:///ou=people,dc=example,dc=com")
 (targetattr=*)
 (version 3.0; acl "Allow anyone to read and search itself"; allow (search, read) userdn = "ldap:///self";)

dn: uid=testuser,ou=people,dc=example,dc=com
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: testuser
cn: 鄧麗君
sn: 鄧
userPassword: Secret.123
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up authentication database (rc=$_rc)" >&2
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

step "Configure UserDirEnrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.UserDirEnrollment.pluginName UidPwdDirAuth
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.UserDirEnrollment.ldap.basedn dc=example,dc=com
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.UserDirEnrollment.ldap.ldapauth.authtype BasicAuth
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.UserDirEnrollment.ldap.ldapauth.bindDN "cn=Directory Manager"
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.UserDirEnrollment.ldap.ldapauth.bindPWPrompt internaldb
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.UserDirEnrollment.ldap.ldapconn.host ds.example.com
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.UserDirEnrollment.ldap.ldapconn.port 3389
docker exec "$CONTAINER" pki-server ca-config-set auths.instance.UserDirEnrollment.ldap.ldapconn.secureConn false
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure UserDirEnrollment (rc=$_rc)" >&2
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

step "Install CA admin cert"
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
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Retrieve caDirUserCert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-profile-show \
    --output $SHARED/CustomProfile.xml \
    caDirUserCert

cat CustomProfile.xml
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Retrieve caDirUserCert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create custom profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# allow updates
sudo chmod go+w CustomProfile.xml

# update profile ID
xmlstarlet edit --inplace \
    -u "/Profile/@id" \
    -v "CustomProfile" \
    CustomProfile.xml

# update profile name
xmlstarlet edit --inplace \
    -u "/Profile/name" \
    -v "中文 Cert Profile" \
    CustomProfile.xml

# update profile description
xmlstarlet edit --inplace \
    -u "/Profile/description" \
    -v "Certificate profile in 中文" \
    CustomProfile.xml

cat CustomProfile.xml
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create custom profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Add custom profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-profile-add \
    $SHARED/CustomProfile.xml
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Add custom profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enable custom profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-profile-enable \
    CustomProfile
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enable custom profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check custom profile info"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-profile-show \
    CustomProfile \
    | tee output

sed -n \
    -e "/^\s*Name:/p" \
    -e "/^\s*Description:/p" \
    output > actual

cat > expected << EOF
  Name: 中文 Cert Profile
  Description: Certificate profile in 中文
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check custom profile info (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check custom profile config"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-profile-show \
    --raw \
    CustomProfile \
    | tee output

sed -n \
    -e "/^name=/p" \
    -e "/^desc=/p" \
    output > actual

cat > expected << EOF
desc=Certificate profile in 中文
name=中文 Cert Profile
EOF
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check custom profile config (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check custom profile config file"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" cat /var/lib/pki/pki-tomcat/ca/profiles/ca/CustomProfile.cfg \
    | tee output

sed -n \
    -e "/^name=/p" \
    -e "/^desc=/p" \
    output > actual

cat > expected << EOF
desc=Certificate profile in 中文
name=中文 Cert Profile
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check custom profile config file (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create cert request"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki nss-cert-request \
    --subject "UID=testuser,OU=people,DC=example,DC=com" \
    --csr testuser.csr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create cert request (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "Secret.123" > password.txt

docker exec "$CONTAINER" pki ca-cert-issue \
    --profile CustomProfile \
    --username testuser \
    --password-file $SHARED/password.txt \
    --csr-file testuser.csr \
    --output-file testuser.crt

# import cert
docker exec "$CONTAINER" pki nss-cert-import testuser --cert testuser.crt
docker exec "$CONTAINER" pki nss-cert-show testuser | tee output

# normalize output
sed \
    -e '/^ *Serial Number:/d' \
    -e '/^ *Not Valid Before:/d' \
    -e '/^ *Not Valid After:/d' \
    output > actual

cat > expected << EOF
  Nickname: testuser
  Subject DN: UID=testuser,OU=people,DC=example,DC=com
  Issuer DN: CN=CA Signing Certificate,OU=pki-tomcat,O=EXAMPLE
  Trust Flags: u,u,u
EOF

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Disable custom profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-profile-disable \
    CustomProfile
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Disable custom profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove custom profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-profile-del \
    CustomProfile
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove custom profile (rc=$_rc)" >&2
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

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== ca-profile-custom-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-profile-custom-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-profile-custom-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-profile-custom-test PASSED ===="

