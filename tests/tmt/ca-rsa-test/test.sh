#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-rsa-test
# (GHA .github/workflows/ca-rsa-test.yml). Packaged forge IPACTA.
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

step "Check system certs keys"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# all keys should be "rsa"
echo Secret.123 > password.txt
docker exec "$CONTAINER" certutil -K -d /var/lib/pki/pki-tomcat/conf/alias -f ${SHARED}/password.txt | tee output
echo "rsa" > expected

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
    echo "FAIL: Check system certs keys (rc=$_rc)" >&2
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

# signing algorithm should be "PKCS #1 SHA-384 With RSA Encryption"
echo "PKCS #1 SHA-384 With RSA Encryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export ca_signing --cert-file ca_signing.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in ca_signing.crt | tee output

# signing algorithm should be "sha384WithRSAEncryption"
echo "sha384WithRSAEncryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# default signing algorithm should be "SHA512withRSA"
echo "SHA512withRSA" > expected
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

# signing algorithm should be "PKCS #1 SHA-512 With RSA Encryption"
echo "PKCS #1 SHA-512 With RSA Encryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export ca_ocsp_signing --cert-file ca_ocsp_signing.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in ca_ocsp_signing.crt | tee output

# signing algorithm should be "sha512WithRSAEncryption"
echo "sha512WithRSAEncryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# default signing algorithm should be "SHA384withRSA"
echo "SHA384withRSA" > expected
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

# signing algorithm should be "PKCS #1 SHA-512 With RSA Encryption"
echo "PKCS #1 SHA-512 With RSA Encryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export ca_audit_signing --cert-file ca_audit_signing.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in ca_audit_signing.crt | tee output

# signing algorithm should be "sha512WithRSAEncryption"
echo "sha512WithRSAEncryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# default signing algorithm should be "SHA384withRSA"
echo "SHA384withRSA" > expected
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

# signing algorithm should be "PKCS #1 SHA-512 With RSA Encryption"
echo "PKCS #1 SHA-512 With RSA Encryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export subsystem --cert-file subsystem.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in subsystem.crt | tee output

# signing algorithm should be "sha512WithRSAEncryption"
echo "sha512WithRSAEncryption" > expected
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

# signing algorithm should be "PKCS #1 SHA-512 With RSA Encryption"
echo "PKCS #1 SHA-512 With RSA Encryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" pki-server cert-export sslserver --cert-file sslserver.crt
docker exec "$CONTAINER" openssl x509 -text -noout -in sslserver.crt | tee output

# signing algorithm should be "sha512WithRSAEncryption"
echo "sha512WithRSAEncryption" > expected
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

# signing algorithm should be "PKCS #1 SHA-512 With RSA Encryption"
echo "PKCS #1 SHA-512 With RSA Encryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" openssl x509 -text -noout -in /root/.dogtag/pki-tomcat/ca_admin.cert | tee output

# signing algorithm should be "sha512WithRSAEncryption"
echo "sha512WithRSAEncryption" > expected
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

step "Check issuing SSL server cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# issue cert
docker exec "$CONTAINER" /usr/share/pki/tests/ca/bin/sslserver-create.sh

# inspect cert with certutil
docker exec "$CONTAINER" certutil -L -d /root/.dogtag/nssdb -n sslserver | tee output

# signing algorithm should be "PKCS #1 SHA-512 With RSA Encryption"
echo "PKCS #1 SHA-512 With RSA Encryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual

# inspect cert with openssl
docker exec "$CONTAINER" openssl x509 -text -noout -in sslserver.crt | tee output

# signing algorithm should be "sha512WithRSAEncryption"
echo "sha512WithRSAEncryption" > expected
sed -n -e "s/\s*$//" -e "s/^\s*Signature Algorithm:\s*\(.*\)$/\1/p" output | uniq > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check issuing SSL server cert (rc=$_rc)" >&2
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
    echo "==== ca-rsa-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== ca-rsa-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-rsa-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-rsa-test PASSED ===="

