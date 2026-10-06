#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-publishing-user-cert-test
# (GHA .github/workflows/ca-publishing-user-cert-test.yml). Packaged forge IPACTA.
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

step "Prepare publishing subtree"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec -i "$CONTAINER" ldapadd \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 << EOF
dn: ou=people,dc=pki,dc=example,dc=com
objectClass: organizationalUnit
ou: people

dn: uid=testuser1,ou=people,dc=pki,dc=example,dc=com
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: testuser1
cn: Test User 1
sn: User 1

dn: uid=testuser2,ou=people,dc=pki,dc=example,dc=com
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: testuser2
cn: Test User 2
sn: User 2
EOF
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Prepare publishing subtree (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure user cert publishing"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# configure LDAP connection
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.ldappublish.enable true
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.ldappublish.ldap.ldapauth.authtype BasicAuth
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.ldappublish.ldap.ldapauth.bindDN "cn=Directory Manager"
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.ldappublish.ldap.ldapauth.bindPWPrompt internaldb
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.ldappublish.ldap.ldapconn.host ds.example.com
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.ldappublish.ldap.ldapconn.port 3389
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.ldappublish.ldap.ldapconn.secureConn false

# configure LDAP-based user cert publisher
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.publisher.instance.LdapUserCertPublisher.certAttr "userCertificate;binary"
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.publisher.instance.LdapUserCertPublisher.pluginName LdapUserCertPublisher

# configure user cert mapper
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.mapper.instance.LdapUserCertMap.dnPattern "uid=\$subj.UID,ou=people,dc=pki,dc=example,dc=com"
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.mapper.instance.LdapUserCertMap.pluginName LdapSimpleMap

# configure user cert publishing rule
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapUserCertRule.enable true
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapUserCertRule.mapper LdapUserCertMap
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapUserCertRule.pluginName Rule
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapUserCertRule.predicate ""
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapUserCertRule.publisher LdapUserCertPublisher
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapUserCertRule.type certs

# enable publishing
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.enable true
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure user cert publishing (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure caUserCert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set cert validity to 1 minute
VALIDITY_DEFAULT="policyset.userCertSet.2.default.params"
docker exec "$CONTAINER" sed -i \
    -e "s/^$VALIDITY_DEFAULT.range=.*$/$VALIDITY_DEFAULT.range=1/" \
    -e "/^$VALIDITY_DEFAULT.range=.*$/a $VALIDITY_DEFAULT.rangeUnit=minute" \
    /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caUserCert.cfg

# check updated profile
docker exec "$CONTAINER" cat /var/lib/pki/pki-tomcat/conf/ca/profiles/ca/caUserCert.cfg
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure caUserCert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure cert status update task"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# configure task to run every minute
docker exec "$CONTAINER" pki-server ca-config-set ca.certStatusUpdateInterval 60
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure cert status update task (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure unpublish expired job to run automatically"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# configure job to run every minute
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.enabled true
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.job.unpublishExpiredCerts.cron "* * * * *"
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.job.unpublishExpiredCerts.enabled true
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.job.unpublishExpiredCerts.summary.enabled false
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure unpublish expired job to run automatically (rc=$_rc)" >&2
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

step "Check user 1 before enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=testuser1,ou=people,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t | tee output

# there should be no cert attributes
{ grep "userCertificate;binary:" output || true; } | wc -l > actual
echo "0" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check user 1 before enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll user 1 cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki client-cert-request uid=testuser1 | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"

docker exec "$CONTAINER" pki -n caadmin ca-cert-request-approve $REQUEST_ID --force | tee output
CERT_ID=$(sed -n -e 's/^ *Certificate ID: *\(.*\)$/\1/p' output)
echo "CERT_ID: $CERT_ID"
echo $CERT_ID > cert.id

docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be valid
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll user 1 cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check user 1 after enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=testuser1,ou=people,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t | tee output

# there should be one cert attribute
{ grep "userCertificate;binary:" output || true; } | wc -l > actual
echo "1" > expected
diff expected actual

FILENAME=$(sed -n 's/userCertificate;binary:< file:\/\/\(.*\)$/\1/p' output)
echo "FILENAME: $FILENAME"

# check the cert
docker exec "$CONTAINER" openssl x509 \
    -in "$FILENAME" \
    -inform DER \
    -text -noout
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check user 1 after enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Revoke user 1 cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_ID=$(cat cert.id)
docker exec "$CONTAINER" pki -n caadmin ca-cert-hold $CERT_ID --force

docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be revoked
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "REVOKED" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Revoke user 1 cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check user 1 after revocation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=testuser1,ou=people,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t | tee output

# there should be no cert attributes
{ grep "userCertificate;binary:" output || true; } | wc -l > actual
echo "0" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check user 1 after revocation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Unrevoke user 1 cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_ID=$(cat cert.id)
docker exec "$CONTAINER" pki -n caadmin ca-cert-release-hold $CERT_ID --force

docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be valid again
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Unrevoke user 1 cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check user 1 after unrevocation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=testuser1,ou=people,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t | tee output

# there should be one cert attribute
{ grep "userCertificate;binary:" output || true; } | wc -l > actual
echo "1" > expected
diff expected actual

FILENAME=$(sed -n 's/userCertificate;binary:< file:\/\/\(.*\)$/\1/p' output)
echo "FILENAME: $FILENAME"

# check the cert
docker exec "$CONTAINER" openssl x509 \
    -in "$FILENAME" \
    -inform DER \
    -text -noout
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check user 1 after unrevocation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Wait for user 1 cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
sleep 120

CERT_ID=$(cat cert.id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be expired
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "EXPIRED" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Wait for user 1 cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check user 1 after expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=testuser1,ou=people,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t | tee output

# there should be no cert attributes
{ grep "userCertificate;binary:" output || true; } | wc -l > actual
echo "0" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check user 1 after expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure unpublish expired job to run manually"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-config-unset jobsScheduler.job.unpublishExpiredCerts.cron
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure unpublish expired job to run manually (rc=$_rc)" >&2
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

step "Check user 2 before enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=testuser2,ou=people,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t | tee output

# there should be no cert attributes
{ grep "userCertificate;binary:" output || true; } | wc -l > actual
echo "0" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check user 2 before enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll user 2 cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki client-cert-request uid=testuser2 | tee output

REQUEST_ID=$(sed -n -e 's/^ *Request ID: *\(.*\)$/\1/p' output)
echo "REQUEST_ID: $REQUEST_ID"

docker exec "$CONTAINER" pki -n caadmin ca-cert-request-approve $REQUEST_ID --force | tee output
CERT_ID=$(sed -n -e 's/^ *Certificate ID: *\(.*\)$/\1/p' output)
echo "CERT_ID: $CERT_ID"
echo $CERT_ID > cert.id

docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be valid
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "VALID" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll user 2 cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check user 2 after enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=testuser2,ou=people,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t | tee output

# there should be one cert attribute
{ grep "userCertificate;binary:" output || true; } | wc -l > actual
echo "1" > expected
diff expected actual

FILENAME=$(sed -n 's/userCertificate;binary:< file:\/\/\(.*\)$/\1/p' output)
echo "FILENAME: $FILENAME"

# check the cert
docker exec "$CONTAINER" openssl x509 \
    -in "$FILENAME" \
    -inform DER \
    -text -noout
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check user 2 after enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Wait for user 2 cert expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
sleep 120

CERT_ID=$(cat cert.id)
docker exec "$CONTAINER" pki ca-cert-show $CERT_ID | tee output

# cert should be expired
sed -n "s/^ *Status: \(.*\)$/\1/p" output > actual
echo "EXPIRED" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Wait for user 2 cert expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check user 2 after expiration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=testuser2,ou=people,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t | tee output

# there should still be one cert attribute
{ grep "userCertificate;binary:" output || true; } | wc -l > actual
echo "1" > expected
diff expected actual

FILENAME=$(sed -n 's/userCertificate;binary:< file:\/\/\(.*\)$/\1/p' output)
echo "FILENAME: $FILENAME"

# check the cert
docker exec "$CONTAINER" openssl x509 \
    -in "$FILENAME" \
    -inform DER \
    -text -noout
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check user 2 after expiration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Run unpublish job manually"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki -n caadmin ca-job-start unpublishExpiredCerts
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Run unpublish job manually (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check user 2 after manual execution"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
sleep 10

docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "uid=testuser2,ou=people,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t | tee output

# there should be no cert attributes
{ grep "userCertificate;binary:" output || true; } | wc -l > actual
echo "0" > expected
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check user 2 after manual execution (rc=$_rc)" >&2
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
    echo "==== ca-publishing-user-cert-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-publishing-user-cert-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-publishing-user-cert-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-publishing-user-cert-test PASSED ===="

