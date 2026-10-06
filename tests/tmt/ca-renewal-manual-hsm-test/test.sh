#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-renewal-manual-hsm-test
# (GHA .github/workflows/ca-renewal-manual-hsm-test.yml). Packaged forge IPACTA.
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

step "Create SoftHSM token"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Create SoftHSM token"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create SoftHSM token (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure short-lived SSL server cert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set cert validity to 3 minute
VALIDITY_DEFAULT="2.default.params"
docker exec "$CONTAINER" sed -i \
    -e "s/^$VALIDITY_DEFAULT.range=.*$/$VALIDITY_DEFAULT.range=3/" \
    -e "/^$VALIDITY_DEFAULT.range=.*$/a $VALIDITY_DEFAULT.rangeUnit=minute" \
    /usr/share/pki/ca/conf/rsaServerCert.profile

# check updated profile
docker exec "$CONTAINER" cat /usr/share/pki/ca/conf/rsaServerCert.profile
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure short-lived SSL server cert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure short-lived subsystem cert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set cert validity to 3 minute
VALIDITY_DEFAULT="2.default.params"
docker exec "$CONTAINER" sed -i \
    -e "s/^$VALIDITY_DEFAULT.range=.*$/$VALIDITY_DEFAULT.range=3/" \
    -e "/^$VALIDITY_DEFAULT.range=.*$/a $VALIDITY_DEFAULT.rangeUnit=minute" \
    /usr/share/pki/ca/conf/rsaSubsystemCert.profile

# check updated profile
docker exec "$CONTAINER" cat /usr/share/pki/ca/conf/rsaSubsystemCert.profile
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure short-lived subsystem cert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure short-lived audit signing cert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set cert validity to 3 minute
VALIDITY_DEFAULT="2.default.params"
docker exec "$CONTAINER" sed -i \
    -e "s/^$VALIDITY_DEFAULT.range=.*$/$VALIDITY_DEFAULT.range=3/" \
    -e "/^$VALIDITY_DEFAULT.range=.*$/a $VALIDITY_DEFAULT.rangeUnit=minute" \
    /usr/share/pki/ca/conf/caAuditSigningCert.profile

# check updated profile
docker exec "$CONTAINER" cat /usr/share/pki/ca/conf/caAuditSigningCert.profile
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure short-lived audit signing cert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure short-lived OCSP signing cert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set cert validity to 3 minute
VALIDITY_DEFAULT="2.default.params"
docker exec "$CONTAINER" sed -i \
    -e "s/^$VALIDITY_DEFAULT.range=.*$/$VALIDITY_DEFAULT.range=3/" \
    -e "/^$VALIDITY_DEFAULT.range=.*$/a $VALIDITY_DEFAULT.rangeUnit=minute" \
    /usr/share/pki/ca/conf/caOCSPCert.profile

# check updated profile
docker exec "$CONTAINER" cat /usr/share/pki/ca/conf/caOCSPCert.profile
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure short-lived OCSP signing cert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Configure short-lived admin cert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# set cert validity to 3 minute
VALIDITY_DEFAULT="2.default.params"
docker exec "$CONTAINER" sed -i \
    -e "s/^$VALIDITY_DEFAULT.range=.*$/$VALIDITY_DEFAULT.range=3/" \
    -e "/^$VALIDITY_DEFAULT.range=.*$/a $VALIDITY_DEFAULT.rangeUnit=minute" \
    /usr/share/pki/ca/conf/rsaAdminCert.profile

# check updated profile
docker exec "$CONTAINER" cat /usr/share/pki/ca/conf/rsaAdminCert.profile
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Configure short-lived admin cert profile (rc=$_rc)" >&2
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

step "Check system cert keys"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-find

# get keys in internal token
echo "Secret.123" > password.internal
docker exec "$CONTAINER" certutil -K \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f $SHARED/password.internal \
    | sed -n 's/<.*> \+\(\S\+\) \+\(\S\+\) \+\(.*\)/\1 \2 \3/p' \
    | sort \
    | tee keys.internal.orig

# get keys in HSM
echo "Secret.HSM" > password.HSM
docker exec "$CONTAINER" certutil -K \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f $SHARED/password.HSM \
    -h HSM \
    | sed -n 's/<.*> \+\(\S\+\) \+\(\S\+\) \+\(.*\)/\1 \2 \3/p' \
    | sort \
    | tee keys.HSM.orig
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check system cert keys (rc=$_rc)" >&2
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
    # healthcheck should generate warnings
    docker exec "$CONTAINER" pki-healthcheck --failures-only \
        > stdout 2> stderr || true

    echo "Expiring in a day: ocsp_signing" > expected
    echo "Expiring in a day: sslserver" >> expected
    echo "Expiring in a day: subsystem" >> expected
    echo "Expiring in a day: audit_signing" >> expected
    diff expected stderr
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
docker exec "$CONTAINER" pki nss-cert-show caadmin

# check CA admin cert
docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin

# check CA admin password
docker exec "$CONTAINER" pki -u caadmin -w Secret.123 ca-user-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Restart PKI server with expired certs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# wait for SSL server cert to expire
sleep 180

docker exec "$CONTAINER" pki-server restart --wait \
    > stdout 2> stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Restart PKI server with expired certs (rc=$_rc)" >&2
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
    # healthcheck should fail
    docker exec "$CONTAINER" pki-healthcheck --failures-only \
        > stdout 2> stderr || true

    echo "Expired Cert: ocsp_signing" > expected
    echo "Expired Cert: sslserver" >> expected
    echo "Expired Cert: subsystem" >> expected
    echo "Expired Cert: audit_signing" >> expected
    echo "Internal server error 404 Client Error:  for url: https://pki.example.com:8443/ca/admin/ca/getStatus" >> expected
    diff expected stderr
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

step "Check CA admin"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# client should fail
docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin \
    > stdout 2> stderr || true

echo "ERROR: EXPIRED_CERTIFICATE encountered on 'CN=pki.example.com,OU=pki-tomcat,O=EXAMPLE' results in a denied SSL server cert!" > expected
grep "^ERROR:" stderr > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create temp SSL server cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# create temp cert
docker exec "$CONTAINER" pki-server cert-create sslserver --temp

# delete current cert
docker exec "$CONTAINER" pki-server cert-del sslserver

# import temp cert
docker exec "$CONTAINER" pki-server cert-import sslserver

docker exec "$CONTAINER" pki-server cert-show sslserver
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create temp SSL server cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Restart PKI server with temp SSL server cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# disable selftests
docker exec "$CONTAINER" pki-server selftest-disable

# restart server
docker exec "$CONTAINER" pki-server restart --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Restart PKI server with temp SSL server cert (rc=$_rc)" >&2
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
    # healthcheck should fail
    docker exec "$CONTAINER" pki-healthcheck --failures-only \
        > stdout 2> stderr || true

    echo "Expired Cert: ocsp_signing" > expected
    echo "Expired Cert: subsystem" >> expected
    echo "Expired Cert: audit_signing" >> expected
    diff expected stderr
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

step "Check PKI client"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# client should work
docker exec "$CONTAINER" pki info
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI client (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Renew SSL server cert using pki ca-cert-issue"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# get current serial number
docker exec "$CONTAINER" pki-server cert-show sslserver | tee output
CERT_ID=$(sed -n "s/^\s*Serial Number:\s*\(\S*\)$/\1/p" output)

# renew cert
# NOTE: since OCSP cert is expired certificate validation fails and marked as revoked
docker exec "$CONTAINER" pki \
    -u caadmin \
    -w Secret.123 \
    --ignore-cert-status REVOKED_CERTIFICATE \
    ca-cert-issue \
    --profile caManualRenewal \
    --serial $CERT_ID \
    --renewal \
    --output-file sslserver.crt

# delete current cert
docker exec "$CONTAINER" pki-server cert-del sslserver

# install new cert
docker exec "$CONTAINER" pki-server cert-import sslserver --input sslserver.crt

docker exec "$CONTAINER" pki-server cert-show sslserver
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Renew SSL server cert using pki ca-cert-issue (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Renew subsystem cert using pki ca-cert-issue"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# get current serial number
docker exec "$CONTAINER" pki-server cert-show subsystem | tee output
CERT_ID=$(sed -n "s/^\s*Serial Number:\s*\(\S*\)$/\1/p" output)

# renew cert
# NOTE: since OCSP cert is expired certificate validation fails and marked as revoked
docker exec "$CONTAINER" pki \
    -u caadmin \
    -w Secret.123 \
    --ignore-cert-status REVOKED_CERTIFICATE \
    ca-cert-issue \
    --profile caManualRenewal \
    --serial $CERT_ID \
    --renewal \
    --output-file subsystem.crt

# delete current cert
docker exec "$CONTAINER" pki-server cert-del subsystem

# install new cert
docker exec "$CONTAINER" pki-server cert-import subsystem --input subsystem.crt

docker exec "$CONTAINER" pki-server cert-show subsystem
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Renew subsystem cert using pki ca-cert-issue (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Update subsystem user cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# get cert ID
docker exec "$CONTAINER" pki-server ca-user-cert-find CA-pki.example.com-8443 | tee output
CERT_ID=$(sed -n "s/^\s*Cert ID:\s*\(.*\)$/\1/p" output)
echo "CERT_ID: $CERT_ID"

# remove current cert
docker exec "$CONTAINER" pki-server ca-user-cert-del CA-pki.example.com-8443 "$CERT_ID"

# install new cert
docker exec "$CONTAINER" pki-server ca-user-cert-add CA-pki.example.com-8443 --cert subsystem.crt

docker exec "$CONTAINER" pki-server ca-user-cert-find CA-pki.example.com-8443
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Update subsystem user cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Renew audit signing cert using pki ca-cert-issue"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# get current serial number
docker exec "$CONTAINER" pki-server cert-show ca_audit_signing | tee output
CERT_ID=$(sed -n "s/^\s*Serial Number:\s*\(\S*\)$/\1/p" output)

# renew cert
# NOTE: since OCSP cert is expired certificate validation fails and marked as revoked
docker exec "$CONTAINER" pki \
    -u caadmin \
    -w Secret.123 \
    --ignore-cert-status REVOKED_CERTIFICATE \
    ca-cert-issue \
    --profile caManualRenewal \
    --serial $CERT_ID \
    --renewal \
    --output-file ca_audit_signing.crt

# delete current cert
docker exec "$CONTAINER" pki-server cert-del ca_audit_signing

# install new cert
docker exec "$CONTAINER" pki-server cert-import ca_audit_signing --input ca_audit_signing.crt

docker exec "$CONTAINER" pki-server cert-show ca_audit_signing
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Renew audit signing cert using pki ca-cert-issue (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Renew OCSP signing cert using pki ca-cert-issue"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# get current serial number
docker exec "$CONTAINER" pki-server cert-show ca_ocsp_signing | tee output
CERT_ID=$(sed -n "s/^\s*Serial Number:\s*\(\S*\)$/\1/p" output)

# renew cert
# NOTE: since OCSP cert is expired certificate validation fails and marked as revoked
docker exec "$CONTAINER" pki \
    -u caadmin \
    -w Secret.123 \
    --ignore-cert-status REVOKED_CERTIFICATE \
    ca-cert-issue \
    --profile caManualRenewal \
    --serial $CERT_ID \
    --renewal \
    --output-file ca_ocsp_signing.crt

# delete current cert
docker exec "$CONTAINER" pki-server cert-del ca_ocsp_signing

# install new cert
docker exec "$CONTAINER" pki-server cert-import ca_ocsp_signing --input ca_ocsp_signing.crt

docker exec "$CONTAINER" pki-server cert-show ca_ocsp_signing
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Renew OCSP signing cert using pki ca-cert-issue (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Renew admin cert using pki ca-cert-issue"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# get current serial number
docker exec "$CONTAINER" pki nss-cert-show caadmin | tee output
CERT_ID=$(sed -n "s/^\s*Serial Number:\s*\(\S*\)$/\1/p" output)

# renew cert
# NOTE: since OCSP cert is expired certificate validation fails and marked as revoked
docker exec "$CONTAINER" pki \
    -u caadmin \
    -w Secret.123 \
    --ignore-cert-status REVOKED_CERTIFICATE \
    ca-cert-issue \
    --profile caManualRenewal \
    --serial $CERT_ID \
    --renewal \
    --output-file caadmin.crt

# delete current cert
docker exec "$CONTAINER" pki nss-cert-del caadmin

# install new cert
docker exec "$CONTAINER" pki nss-cert-import caadmin --cert caadmin.crt

docker exec "$CONTAINER" pki nss-cert-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Renew admin cert using pki ca-cert-issue (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Update admin user cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# get cert ID
docker exec "$CONTAINER" pki-server ca-user-cert-find caadmin | tee output
CERT_ID=$(sed -n "s/^\s*Cert ID:\s*\(.*\)$/\1/p" output)
echo "CERT_ID: $CERT_ID"

# remove current cert
docker exec "$CONTAINER" pki-server ca-user-cert-del caadmin "$CERT_ID"

# install new cert
docker exec "$CONTAINER" pki-server ca-user-cert-add caadmin --cert caadmin.crt

docker exec "$CONTAINER" pki-server ca-user-cert-find caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Update admin user cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Restart PKI server with renewed certs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# enable selftests
docker exec "$CONTAINER" pki-server selftest-enable

docker exec "$CONTAINER" pki-server restart --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Restart PKI server with renewed certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check system certs after renewal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server cert-find

# get keys in internal token
docker exec "$CONTAINER" certutil -K \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f $SHARED/password.internal \
    | sed -n 's/<.*> \+\(\S\+\) \+\(\S\+\) \+\(.*\)/\1 \2 \3/p' \
    | sort \
    | tee keys.internal.after

# the keys should not change
diff keys.internal.orig keys.internal.after

# get keys in HSM
docker exec "$CONTAINER" certutil -K \
    -d /var/lib/pki/pki-tomcat/conf/alias \
    -f $SHARED/password.HSM \
    -h HSM \
    | sed -n 's/<.*> \+\(\S\+\) \+\(\S\+\) \+\(.*\)/\1 \2 \3/p' \
    | sort \
    | tee keys.HSM.after

# the keys should not change
diff keys.HSM.orig keys.HSM.after
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check system certs after renewal (rc=$_rc)" >&2
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
    # healthcheck should not fail
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
    echo "FAIL: Run PKI healthcheck (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# client should not fail
docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin (rc=$_rc)" >&2
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

step "Check CA selftests log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" cat /var/lib/pki/pki-tomcat/logs/ca/selftests.log
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA selftests log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== ca-renewal-manual-hsm-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-renewal-manual-hsm-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-renewal-manual-hsm-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-renewal-manual-hsm-test PASSED ===="

