#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-pqc-test
# (GHA .github/workflows/ca-pqc-test.yml). Packaged forge IPACTA.
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

step "Enable ML-DSA in default crypto-policies"
if [[ "$GHA_FAILED" -eq 0 ]] && [[ "${FEDORA_VERSION}" -lt 44 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" sed -i \
    's/smime-key-exchange:ECDSA/smime-key-exchange:ML-DSA-65:ML-DSA-87:ECDSA/' \
    /etc/crypto-policies/back-ends/nss.config
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enable ML-DSA in default crypto-policies (rc=$_rc)" >&2
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
# all keys should be "mldsa"
echo Secret.123 > password.txt
docker exec "$CONTAINER" certutil -K -d /var/lib/pki/pki-tomcat/conf/alias -f ${SHARED}/password.txt | tee output
echo "mldsa" > expected

grep ca_signing output | sed -n 's/<.*>\s\(\S\+\)\s.*/\1/p' > actual
diff expected actual

grep ca_ocsp_signing output | sed -n 's/<.*>\s\(\S\+\)\s.*/\1/p' > actual
diff expected actual

grep ca_audit_signing output | sed -n 's/<.*>\s\(\S\+\)\s.*/\1/p' > actual
diff expected actual

grep subsystem output | sed -n 's/<.*>\s\(\S\+\)\s.*/\1/p' > actual
diff expected actual

grep sslserver output | sed -n 's/<.*>\s\(\S\+\)\s.*/\1/p' > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check system cert keys (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /var/lib/pki/pki-tomcat/conf/alias -f ${SHARED}/password.txt -n ca_signing | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export ca_signing --cert-file ca_signing.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in ca_signing.crt | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# default signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
docker exec "$CONTAINER" pki-server ca-config-show ca.signing.defaultSigningAlgorithm | tee actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA OCSP signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /var/lib/pki/pki-tomcat/conf/alias -f ${SHARED}/password.txt -n ca_ocsp_signing | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export ca_ocsp_signing --cert-file ca_ocsp_signing.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in ca_ocsp_signing.crt | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# default signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
docker exec "$CONTAINER" pki-server ca-config-show ca.ocsp_signing.defaultSigningAlgorithm | tee actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA OCSP signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA audit signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /var/lib/pki/pki-tomcat/conf/alias -f ${SHARED}/password.txt -n ca_audit_signing | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export ca_audit_signing --cert-file ca_audit_signing.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in ca_audit_signing.crt | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# default signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
docker exec "$CONTAINER" pki-server ca-config-show ca.audit_signing.defaultSigningAlgorithm | tee actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA audit signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check subsystem cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /var/lib/pki/pki-tomcat/conf/alias -f ${SHARED}/password.txt -n subsystem | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export subsystem --cert-file subsystem.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in subsystem.crt | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# default signing algorithm should not exist
echo "ERROR: No such parameter: ca.subsystem.defaultSigningAlgorithm" > expected
docker exec "$CONTAINER" pki-server ca-config-show ca.subsystem.defaultSigningAlgorithm \
    > stdout 2> stderr || true
diff expected stderr
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
# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /var/lib/pki/pki-tomcat/conf/alias -f ${SHARED}/password.txt -n sslserver | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export sslserver --cert-file sslserver.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in sslserver.crt | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# default signing algorithm should not exist
echo "ERROR: No such parameter: ca.sslserver.defaultSigningAlgorithm" > expected
docker exec "$CONTAINER" pki-server ca-config-show ca.sslserver.defaultSigningAlgorithm \
    > stdout 2> stderr || true
diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check SSL server cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enable audit signing"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server stop --wait
docker exec "$CONTAINER" pki-server ca-audit-config-mod --logSigning True
docker exec "$CONTAINER" pki-server start --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enable audit signing (rc=$_rc)" >&2
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

step "Check authenticating as CA admin user"
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

docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check authenticating as CA admin user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /root/.dogtag/nssdb -n caadmin | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" openssl x509 -text -noout -in /root/.dogtag/pki-tomcat/ca_admin.cert | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check issuing SSL server cert with RSA key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# issue cert
docker exec "$CONTAINER" /usr/share/pki/tests/ca/bin/sslserver-create.sh

# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /root/.dogtag/nssdb -n sslserver | tee output

# key type should be "PKCS #1 RSA Encryption"
echo "PKCS #1 RSA Encryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Public Key Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" openssl x509 -text -noout -in sslserver.crt | tee output

# signing algorithm should be "ML-DSA-65"
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check issuing SSL server cert with RSA key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check issuing SSL server cert with ML-DSA-65 key"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" certutil -F -d /root/.dogtag/nssdb -n sslserver

# issue cert
docker exec "$CONTAINER" pki nss-cert-request \
        --subject "CN=pki.example.com" \
        --ext /usr/share/pki/server/certs/sslserver.conf \
        --csr sslserver_mldsa.csr \
        --key-type MLDSA \
        --key-strength 65

docker exec "$CONTAINER"  pki -n caadmin ca-cert-issue \
        --profile caMLDSAServerCert \
        --csr-file sslserver_mldsa.csr \
        --output-file sslserver_mldsa.crt

docker exec "$CONTAINER" pki nss-cert-import sslserver --cert sslserver_mldsa.crt

echo "ML-DSA-65" > expected

# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /root/.dogtag/nssdb -n sslserver | tee output

# key type should be "ML-DSA-65"
sed -n -e "s/\s*$//" -e "s/^\s*Public Key Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# signing algorithm should be "ML-DSA-65"
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" openssl x509 -text -noout -in sslserver_mldsa.crt | tee output

# signing algorithm should be "ML-DSA-65"
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check issuing SSL server cert with ML-DSA-65 key (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check audit get signed"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" cat /var/log/pki/pki-tomcat/ca/signedAudit/ca_audit | grep AuditEvent=AUDIT_LOG_SIGNING | tee output
grep -q . output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check audit get signed (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enable caMLDSAUserCert profile"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki -n caadmin ca-profile-enable caMLDSAUserCert
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enable caMLDSAUserCert profile (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll OCSP test cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki nss-cert-request \
    --subject "UID=ocsp-test" \
    --csr ocsp_test.csr \
    --key-type MLDSA \
    --key-strength 65

docker exec "$CONTAINER" pki -n caadmin ca-cert-issue \
    --profile caMLDSAUserCert \
    --csr-file ocsp_test.csr \
    --output-file ocsp_test.crt

docker exec "$CONTAINER" openssl x509 -in ocsp_test.crt -noout -serial | tee output
CERT_SERIAL="0x$(sed 's/serial=//i' output)"
echo "$CERT_SERIAL" > ocsp_cert.id
echo "Issued OCSP test cert with serial: $CERT_SERIAL"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll OCSP test cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check good cert OCSP response signed with ML-DSA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_SERIAL=$(cat ocsp_cert.id)

docker exec "$CONTAINER" openssl ocsp \
    -url http://pki.example.com:8080/ca/ocsp \
    -CAfile ca_signing.crt \
    -issuer ca_signing.crt \
    -serial $CERT_SERIAL \
    -resp_text \
    | tee output

# cert status should be good
sed -n "/^$CERT_SERIAL:/p" output > actual
echo "$CERT_SERIAL: good" > expected
diff expected actual

# OCSP response signature algorithm should be ML-DSA-65
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check good cert OCSP response signed with ML-DSA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Revoke OCSP test cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_SERIAL=$(cat ocsp_cert.id)

docker exec "$CONTAINER" pki -n caadmin ca-cert-hold \
    --force \
    $CERT_SERIAL
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Revoke OCSP test cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check revoked cert OCSP response signed with ML-DSA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
CERT_SERIAL=$(cat ocsp_cert.id)

docker exec "$CONTAINER" openssl ocsp \
    -url http://pki.example.com:8080/ca/ocsp \
    -CAfile ca_signing.crt \
    -issuer ca_signing.crt \
    -serial $CERT_SERIAL \
    -resp_text \
    | tee output

# cert status should be revoked
sed -n "/^$CERT_SERIAL:/p" output > actual
echo "$CERT_SERIAL: revoked" > expected
diff expected actual

# OCSP response signature algorithm should be ML-DSA-65
echo "ML-DSA-65" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check revoked cert OCSP response signed with ML-DSA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Generating new sslserver certificate with CMC"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check cert request
docker exec "$CONTAINER" openssl req -text -noout -in /etc/pki/pki-tomcat/certs/sslserver.csr

# create CMC request
docker exec "$CONTAINER" cp /etc/pki/pki-tomcat/certs/sslserver.csr sslserver.csr
docker exec "$CONTAINER" CMCRequest \
    /usr/share/pki/server/examples/cmc/sslserver-cmc-request.cfg

# copy the submit and update the profile to use
docker exec "$CONTAINER" \
    cp /usr/share/pki/server/examples/cmc/sslserver-cmc-submit.cfg \
    /tmp/sslserver-cmc-submit.cfg
docker exec "$CONTAINER" sed -i 's/profileId=caCMCserverCert/profileId=caCMCMLDSAserverCert/' /tmp/sslserver-cmc-submit.cfg
docker exec "$CONTAINER" sed -i 's/host=ca.example.com/host=pki.example.com/' /tmp/sslserver-cmc-submit.cfg

# submit CMC request
docker exec "$CONTAINER" HttpClient \
    /tmp/sslserver-cmc-submit.cfg

# convert CMC response (DER PKCS #7) into PEM PKCS #7 cert chain
docker exec "$CONTAINER" CMCResponse \
    -d /root/.dogtag/nssdb \
    -i sslserver.cmc-response \
    -o $SHARED/sslserver.p7b

# check issued cert chain
docker exec "$CONTAINER" openssl pkcs7 -print_certs -in $SHARED/sslserver.p7b
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Generating new sslserver certificate with CMC (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA and cleanup home"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA and cleanup home (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create ML-DSA-87 configuration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" cp /usr/share/pki/server/examples/installation/ca-pqc.cfg ca-pqc.cfg
docker exec "$CONTAINER" sed -i 's/65$/87/' ca-pqc.cfg
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create ML-DSA-87 configuration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install CA with ML-DSA-87 and default buffer (65536 for PQC)"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pkispawn \
    -f ca-pqc.cfg \
    -s CA \
    -D pki_ds_url=ldap://ds.example.com:3389 \
    -D pki_enable_access_log=False \
    -v
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA with ML-DSA-87 and default buffer (65536 for PQC) (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA signing cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /var/lib/pki/pki-tomcat/conf/alias -f ${SHARED}/password.txt -n ca_signing | tee output

# signing algorithm should be "ML-DSA-87"
echo "ML-DSA-87" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export ca_signing --cert-file ca_signing.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in ca_signing.crt | tee output

# signing algorithm should be "ML-DSA-87"
echo "ML-DSA-87" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# default signing algorithm should be "ML-DSA-87"
echo "ML-DSA-87" > expected
docker exec "$CONTAINER" pki-server ca-config-show ca.signing.defaultSigningAlgorithm | tee actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA signing cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check authenticating as CA admin user"
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

docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check authenticating as CA admin user (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA admin cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /root/.dogtag/nssdb -n caadmin | tee output

# signing algorithm should be "ML-DSA-87"
echo "ML-DSA-87" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" openssl x509 -text -noout -in /root/.dogtag/pki-tomcat/ca_admin.cert | tee output

# signing algorithm should be "ML-DSA-87"
echo "ML-DSA-87" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA admin cert (rc=$_rc)" >&2
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

step "Install CA with ML-DSA-87 with legacy buffer size"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" sed -i \
    's/-Dredhat.crypto-policies=false/-Dredhat.crypto-policies=false -Djdk.tls.maxHandshakeMessageSize=18713/' \
    /usr/share/pki/server/conf/tomcat.conf

docker exec "$CONTAINER" pkispawn \
    -f ca-pqc.cfg \
    -s CA \
    -D pki_ds_url=ldap://ds.example.com:3389 \
    -D pki_enable_access_log=False \
    -v || echo "Failed" | tee output

echo "Failed" > expected
tail -n 1 output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA with ML-DSA-87 with legacy buffer size (rc=$_rc)" >&2
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
    echo "==== ca-pqc-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-pqc-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-pqc-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-pqc-test PASSED ===="

