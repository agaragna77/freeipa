#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-publishing-ca-cert-test
# (GHA .github/workflows/ca-publishing-ca-cert-test.yml). Packaged forge IPACTA.
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

step "Export CA cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-export ca_signing --cert-file ca_signing.crt
docker exec "$CONTAINER" openssl x509 \
    -in ca_signing.crt \
    -text \
    -noout | tee ca_signing.txt
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Export CA cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Prepare CA cert publishing subtree"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec -i "$CONTAINER" ldapadd \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 << EOF
dn: dc=crl,dc=pki,dc=example,dc=com
objectClass: domain
dc: crl
EOF
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Prepare CA cert publishing subtree (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure CA cert publishing"
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

# configure LDAP-based CA cert publisher
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.publisher.instance.LdapCaCertPublisher.caCertAttr "cACertificate;binary"
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.publisher.instance.LdapCaCertPublisher.caObjectClass pkiCA
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.publisher.instance.LdapCaCertPublisher.pluginName LdapCaCertPublisher

# configure CA cert mapper
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.mapper.instance.LdapCaCertMap.createCAEntry true
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.mapper.instance.LdapCaCertMap.dnPattern "cn=\$subj.cn,dc=crl,dc=pki,dc=example,dc=com"
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.mapper.instance.LdapCaCertMap.pluginName LdapCaSimpleMap

# configure CA cert publishing rule
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapCaCertRule.enable true
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapCaCertRule.mapper LdapCaCertMap
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapCaCertRule.pluginName Rule
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapCaCertRule.predicate ""
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapCaCertRule.publisher LdapCaCertPublisher
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.rule.instance.LdapCaCertRule.type cacert

# enable publishing
docker exec "$CONTAINER" pki-server ca-config-set ca.publish.enable true

# restart CA subsystem
docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure CA cert publishing (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check published CA cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" ldapsearch \
    -H ldap://ds.example.com:3389 \
    -x \
    -D "cn=Directory Manager" \
    -w Secret.123 \
    -b "dc=crl,dc=pki,dc=example,dc=com" \
    -o ldif_wrap=no \
    -t \
    "(objectClass=pkiCA)" | tee output

# there should be one CA cert attribute
{ grep "cACertificate;binary:" output || true; } | wc -l > actual
echo "1" > expected
diff expected actual

FILENAME=$(sed -n 's/cACertificate;binary:< file:\/\/\(.*\)$/\1/p' output)
echo "FILENAME: $FILENAME"

# compare exported and published CA certs
docker exec "$CONTAINER" openssl x509 \
    -in "$FILENAME" \
    -inform DER \
    -text \
    -noout | tee output
diff ca_signing.txt output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check published CA cert (rc=$_rc)" >&2
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
    echo "==== ca-publishing-ca-cert-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-publishing-ca-cert-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-publishing-ca-cert-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-publishing-ca-cert-test PASSED ===="

