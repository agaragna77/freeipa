#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/kra-cmc-test
# (GHA .github/workflows/kra-cmc-test.yml). Packaged forge IPACTA.
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

step "Set up CA DS container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Set up CA DS container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up CA DS container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up CA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "runner-init skipped; IPA container already running"
    --hostname=ca.example.com \
    --network=example \
    --network-alias=ca.example.com \
    ca
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up CA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install CA in CA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_ca
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA in CA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Initialize CA admin in CA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec ca pki-server cert-export ca_signing --cert-file $SHARED/ca_signing.crt

docker exec ca pki nss-cert-import \
    --cert $SHARED/ca_signing.crt \
    --trust CT,C,C \
    ca_signing

docker exec ca pki pkcs12-import \
    --pkcs12 /root/.dogtag/pki-tomcat/ca_admin_cert.p12 \
    --pkcs12-password Secret.123
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Initialize CA admin in CA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up KRA DS container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Set up KRA DS container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up KRA DS container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up KRA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "runner-init skipped; IPA container already running"
    --hostname=kra.example.com \
    --network=example \
    --network-alias=kra.example.com \
    kra
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up KRA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install KRA in KRA container (step 1)"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_kra
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install KRA in KRA container (step 1) (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue KRA storage cert with CMC"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check cert request
docker exec ca openssl req -text -noout -in $SHARED/kra_storage.csr

# create CMC request
docker exec ca cp $SHARED/kra_storage.csr kra_storage.csr
docker exec ca CMCRequest \
    /usr/share/pki/server/examples/cmc/kra_storage-cmc-request.cfg

# submit CMC request
docker exec ca HttpClient \
    /usr/share/pki/server/examples/cmc/kra_storage-cmc-submit.cfg

# convert CMC response (DER PKCS #7) into PEM PKCS #7 cert chain
docker exec ca CMCResponse \
    -d /root/.dogtag/nssdb \
    -i kra_storage.cmc-response \
    -o $SHARED/kra_storage.p7b

# check issued cert chain
docker exec ca openssl pkcs7 -print_certs -in $SHARED/kra_storage.p7b
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue KRA storage cert with CMC (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue KRA transport cert with CMC"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check cert request
docker exec ca openssl req -text -noout -in $SHARED/kra_transport.csr

# create CMC request
docker exec ca cp $SHARED/kra_transport.csr kra_transport.csr
docker exec ca CMCRequest \
    /usr/share/pki/server/examples/cmc/kra_transport-cmc-request.cfg

# submit CMC request
docker exec ca HttpClient \
    /usr/share/pki/server/examples/cmc/kra_transport-cmc-submit.cfg

# convert CMC response (DER PKCS #7) into PEM PKCS #7 cert chain
docker exec ca CMCResponse \
    -d /root/.dogtag/nssdb \
    -i kra_transport.cmc-response \
    -o $SHARED/kra_transport.p7b

# check issued cert chain
docker exec ca openssl pkcs7 -print_certs -in $SHARED/kra_transport.p7b
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue KRA transport cert with CMC (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue subsystem cert with CMC"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check cert request
docker exec ca openssl req -text -noout -in $SHARED/subsystem.csr

# create CMC request
docker exec ca cp $SHARED/subsystem.csr subsystem.csr
docker exec ca CMCRequest \
    /usr/share/pki/server/examples/cmc/subsystem-cmc-request.cfg

# submit CMC request
docker exec ca HttpClient \
    /usr/share/pki/server/examples/cmc/subsystem-cmc-submit.cfg

# convert CMC response (DER PKCS #7) into PEM PKCS #7 cert chain
docker exec ca CMCResponse \
    -d /root/.dogtag/nssdb \
    -i subsystem.cmc-response \
    -o $SHARED/subsystem.p7b

# check issued cert chain
docker exec ca openssl pkcs7 -print_certs -in $SHARED/subsystem.p7b
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue subsystem cert with CMC (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue SSL server cert with CMC"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check cert request
docker exec ca openssl req -text -noout -in $SHARED/sslserver.csr

# create CMC request
docker exec ca cp $SHARED/sslserver.csr sslserver.csr
docker exec ca CMCRequest \
    /usr/share/pki/server/examples/cmc/sslserver-cmc-request.cfg

# submit CMC request
docker exec ca HttpClient \
    /usr/share/pki/server/examples/cmc/sslserver-cmc-submit.cfg

# convert CMC response (DER PKCS #7) into PEM PKCS #7 cert chain
docker exec ca CMCResponse \
    -d /root/.dogtag/nssdb \
    -i sslserver.cmc-response \
    -o $SHARED/sslserver.p7b

# check issued cert chain
docker exec ca openssl pkcs7 -print_certs -in $SHARED/sslserver.p7b
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue SSL server cert with CMC (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue KRA audit signing cert with CMC"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check cert request
docker exec ca openssl req -text -noout -in $SHARED/kra_audit_signing.csr

# create CMC request
docker exec ca cp $SHARED/kra_audit_signing.csr audit_signing.csr
docker exec ca CMCRequest \
    /usr/share/pki/server/examples/cmc/audit_signing-cmc-request.cfg

# submit CMC request
docker exec ca HttpClient \
    /usr/share/pki/server/examples/cmc/audit_signing-cmc-submit.cfg

# convert CMC response (DER PKCS #7) into PEM PKCS #7 cert chain
docker exec ca CMCResponse \
    -d /root/.dogtag/nssdb \
    -i audit_signing.cmc-response \
    -o $SHARED/kra_audit_signing.p7b

# check issued cert chain
docker exec ca openssl pkcs7 -print_certs -in $SHARED/kra_audit_signing.p7b
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue KRA audit signing cert with CMC (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Issue KRA admin cert with CMC"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# check cert request
docker exec ca openssl req -text -noout -in $SHARED/kra_admin.csr

# create CMC request
docker exec ca cp $SHARED/kra_admin.csr admin.csr
docker exec ca CMCRequest \
    /usr/share/pki/server/examples/cmc/admin-cmc-request.cfg

# submit CMC request
docker exec ca HttpClient \
    /usr/share/pki/server/examples/cmc/admin-cmc-submit.cfg

# convert CMC response (DER PKCS #7) into PEM PKCS #7 cert chain
docker exec ca CMCResponse \
    -d /root/.dogtag/nssdb \
    -i admin.cmc-response \
    -o kra_admin.p7b

# pki_admin_cert_path only supports a single cert so the admin cert
# needs to be exported from the PKCS #7 cert chain
# TODO: fix pki_admin_cert_path to support PKCS #7 cert chain
docker exec ca pki pkcs7-cert-export \
    --pkcs7 kra_admin.p7b \
    --output-prefix kra_admin- \
    --output-suffix .crt
docker exec ca cp kra_admin-1.crt $SHARED/kra_admin.crt

# check issued cert
docker exec ca openssl x509 -text -noout -in $SHARED/kra_admin.crt
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Issue KRA admin cert with CMC (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install KRA in KRA container (step 2)"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_kra
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install KRA in KRA container (step 2) (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Verify KRA admin"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pki nss-cert-import \
    --cert $SHARED/ca_signing.crt \
    --trust CT,C,C \
    ca_signing

docker exec kra pki pkcs12-import \
    --pkcs12 /root/.dogtag/pki-tomcat/kra_admin_cert.p12 \
    --pkcs12-password Secret.123
docker exec kra pki -n kraadmin kra-user-show kraadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Verify KRA admin (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove KRA from KRA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec kra pkidestroy -s KRA -v
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove KRA from KRA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA from CA container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA from CA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check PKI server systemd journal in CA container"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec ca journalctl -x --no-pager -u pki-tomcatd@pki-tomcat.service
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server systemd journal in CA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check CA debug log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec ca find /var/lib/pki/pki-tomcat/logs/ca -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA debug log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check PKI server systemd journal in KRA container"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec kra journalctl -x --no-pager -u pki-tomcatd@pki-tomcat.service
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check PKI server systemd journal in KRA container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check KRA debug log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec kra find /var/lib/pki/pki-tomcat/logs/kra -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check KRA debug log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== kra-cmc-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== kra-cmc-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA kra-cmc-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA kra-cmc-test PASSED ===="

