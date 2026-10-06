#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/ca-clone-ssnv1-test
# (GHA .github/workflows/ca-clone-ssnv1-test.yml). Packaged forge IPACTA.
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

step "Set up primary DS container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Set up primary DS container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up primary DS container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up primary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "IPA container already running as $CONTAINER"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up primary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create primary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pkispawn \
    -f /usr/share/pki/server/examples/installation/ca.cfg \
    -s CA \
    -D pki_ds_url=ldap://primaryds.example.com:3389 \
    -D pki_request_id_generator=legacy \
    -D pki_request_number_range_start=1 \
    -D pki_request_number_range_end=10 \
    -D pki_request_number_range_increment=10 \
    -D pki_request_number_range_minimum=5 \
    -D pki_request_number_range_transfer=5 \
    -D pki_cert_id_generator=legacy \
    -D pki_serial_number_range_start=1 \
    -D pki_serial_number_range_end=12 \
    -D pki_serial_number_range_increment=12 \
    -D pki_serial_number_range_minimum=9 \
    -D pki_serial_number_range_transfer=9 \
    -v
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enable serial number management in primary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-config-set dbs.enableSerialManagement true

# disable serial number update background task
docker exec "$CONTAINER" pki-server ca-config-set ca.serialNumberUpdateInterval 0

# enable serial number update manual job
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.enabled true
docker exec "$CONTAINER" pki-server ca-config-set jobsScheduler.job.serialNumberUpdate.enabled true

# restart primary CA
docker exec "$CONTAINER" pki-server ca-redeploy --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enable serial number management in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install admin cert in primary CA"
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

docker exec "$CONTAINER" pki pkcs12-import \
    --pkcs12 /root/.dogtag/pki-tomcat/ca_admin_cert.p12 \
    --pkcs12-password Secret.123
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install admin cert in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check requests"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-request-find | tee output
sed -n "s/^ *Request ID: *\(.*\)$/\1/p" output > actual

# there should be 6 requests
seq 1 6 > expected

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check certs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-find | tee output
sed -n "s/^ *Serial Number: *\(.*\)$/\1/p" output > actual

# there should be 6 certs
seq 1 6 | while read n; do printf "0x%x\n" $n; done > expected

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-config.sh primary | tee output

# request range should be 1 - 10 decimal (size: 10, remaining: 4)
cat > expected << EOF
dbs.beginRequestNumber=1
dbs.endRequestNumber=10
dbs.nextBeginRequestNumber=11
dbs.nextEndRequestNumber=20
dbs.requestCloneTransferNumber=5
dbs.requestIncrement=10
dbs.requestLowWaterMark=5
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-config.sh primary | tee output

# cert range should be 1 - 12 hex (size: 18, remaining: 12)
cat > expected << EOF
dbs.beginSerialNumber=1
dbs.endSerialNumber=12
dbs.serialCloneTransferNumber=9
dbs.serialIncrement=12
dbs.serialLowWaterMark=9
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh primaryds | tee output

# since the remaining numbers in the current range are below
# the minimum, a new request range was allocated
cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh primaryds | tee output

 # since the remaining numbers in the current range are not
 # less than the minimum, no new cert range was allocated
 diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh primaryds | tee output

# since there's an allocated request range, the nextRange
# should be endRange + 1 which is 21 decimal
cat > expected << EOF
nextRange: 21
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh primaryds | tee output

# since there's no allocated cert range, the nextRange should be
# dbs.endSerialNumber + 1 which is 13 hex (19 decimal), but due
# to a bug in SubsystemRangeUpdateCLI.updateSerialNumberRange()
# this is stored as 13 decimal
cat > expected << EOF
nextRange: 13
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Set up secondary DS container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Set up secondary DS container"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up secondary DS container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up secondary PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
echo "IPA container already running as $CONTAINER"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up secondary PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Create secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enable serial number management in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Enable serial number management in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enable serial number management in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install admin cert in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Install admin cert in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install admin cert in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check requests"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-request-find | tee output
sed -n "s/^ *Request ID: *\(.*\)$/\1/p" output > actual

# there should be 7 requests
seq 1 7 > expected

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check certs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-find | tee output
sed -n "s/^ *Serial Number: *\(.*\)$/\1/p" output > actual

# there should be 7 certs
seq 1 7 | while read n; do printf "0x%x\n" $n; done > expected

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-config.sh primary | tee output

# request range should be the same (size: 10, remaining: 3)
cat > expected << EOF
dbs.beginRequestNumber=1
dbs.endRequestNumber=10
dbs.nextBeginRequestNumber=11
dbs.nextEndRequestNumber=15
dbs.requestCloneTransferNumber=5
dbs.requestIncrement=10
dbs.requestLowWaterMark=5
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check request range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-config.sh primary | tee output

# cert range should be reduced into 1 - 9 hex (size: 9, remaining: 2)
# the other half was transferred to the secondary CA
cat > expected << EOF
dbs.beginSerialNumber=1
dbs.endSerialNumber=9
dbs.serialCloneTransferNumber=9
dbs.serialIncrement=12
dbs.serialLowWaterMark=9
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check cert range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check request range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh secondaryds | tee output

# request range should be the same
# NOTE: there's no indication that half of the range has
# been transfered to the secondary CA
cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh secondaryds | tee output

# cert range should be the same
diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh secondaryds | tee output

# request nextRange should be the same
cat > expected << EOF
nextRange: 21
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh secondaryds | tee output

# cert nextRange should be the same
cat > expected << EOF
nextRange: 13
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Enroll 2 cert in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    nss-cert-request \
    --subject "uid=testuser" \
    --ext /usr/share/pki/tools/examples/certs/testuser.conf \
    --csr testuser.csr

for i in $(seq 1 2); do
    docker exec "$CONTAINER" pki \
        -n caadmin \
        ca-cert-issue \
        --profile caUserCert \
        --csr-file testuser.csr \
        --output-file testuser.crt

    docker exec "$CONTAINER" openssl x509 -in testuser.crt -serial -noout
done
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll 2 cert in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Enroll 5 certs in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Enroll 5 certs in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll 5 certs in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check requests"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-request-find | tee output
sed -n "s/^ *Request ID: *\(.*\)$/\1/p" output > actual

# there should be 14 requests
seq 1 9 > expected     # primary CA
seq 16 20 >> expected  # secondary CA

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check certs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-find | tee output
sed -n "s/^ *Serial Number: *\(.*\)$/\1/p" output > actual

# there should be 14 certs
seq 1 14 | while read n; do printf "0x%x\n" $n; done > expected

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-config.sh primary | tee output

# request range should be the same (size: 10, remaining: 1)
cat > expected << EOF
dbs.beginRequestNumber=1
dbs.endRequestNumber=10
dbs.nextBeginRequestNumber=11
dbs.nextEndRequestNumber=15
dbs.requestCloneTransferNumber=5
dbs.requestIncrement=10
dbs.requestLowWaterMark=5
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check request range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-config.sh primary | tee output

# cert range should be exhausted (size: 9, remaining: 0)
cat > expected << EOF
dbs.beginSerialNumber=1
dbs.endSerialNumber=9
dbs.serialCloneTransferNumber=9
dbs.serialIncrement=12
dbs.serialLowWaterMark=9
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check cert range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check request range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh primaryds | tee output

# request range should be the same
cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh primaryds | tee output

# cert range should be the same
diff /dev/null output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh primaryds | tee output

# request nextRange should be the same
cat > expected << EOF
nextRange: 21
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh primaryds | tee output

# cert nextRange should be the same
cat > expected << EOF
nextRange: 13
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Enroll a cert when cert range is exhausted"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --profile caUserCert \
    --csr-file testuser.csr \
    --output-file testuser.crt \
    > stdout 2> stderr || true

cat > expected << EOF
PKIException: Server Internal Error: Request 10 was completed with errors.
CA has exhausted all available serial numbers
EOF

diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll a cert when cert range is exhausted (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Enroll a cert when request range is exhausted"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-cert-issue \
    --profile caUserCert \
    --csr-file testuser.csr \
    --output-file testuser.crt \
    > stdout 2> stderr || true

cat > expected << EOF
PKIException: Unable to create enrollment request: Unable to create enrollment request: All serial numbers are used. The max serial number is 20
EOF

diff expected stderr
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll a cert when request range is exhausted (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check requests"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-request-find | tee output
sed -n "s/^ *Request ID: *\(.*\)$/\1/p" output > actual

# there should be 15 requests
seq 1 9 > expected     # primary CA
seq 16 20 >> expected  # secondary CA
echo 10 >> expected    # primary CA

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check certs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-find | tee output
sed -n "s/^ *Serial Number: *\(.*\)$/\1/p" output > actual

# there should be 14 certs
seq 1 14 | while read n; do printf "0x%x\n" $n; done > expected

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-config.sh primary | tee output

# request range should be the same (size: 10, remaining: 0)
cat > expected << EOF
dbs.beginRequestNumber=1
dbs.endRequestNumber=10
dbs.nextBeginRequestNumber=11
dbs.nextEndRequestNumber=15
dbs.requestCloneTransferNumber=5
dbs.requestIncrement=10
dbs.requestLowWaterMark=5
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check request range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-config.sh primary | tee output

# cert range should be exhausted (size: 9, remaining: 0)
cat > expected << EOF
dbs.beginSerialNumber=1
dbs.endSerialNumber=9
dbs.serialCloneTransferNumber=9
dbs.serialIncrement=12
dbs.serialLowWaterMark=9
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check cert range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Allocate new ranges"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-job-start \
    serialNumberUpdate

docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-job-start \
    serialNumberUpdate

# wait for DS replication
sleep 5
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Allocate new ranges (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh primaryds | tee output

# since the remaining numbers are below the minimum in the
# secondary CA, a new cert request should be allocated for it
cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

SecurePort: 8443
beginRange: 21
endRange: 30
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh primaryds | tee output

# since the remaining numbers are below the minimum in both primary
# and secondary CA, new cert ranges should be allocated for them
cat > expected << EOF
SecurePort: 8443
beginRange: 13
endRange: 30
host: primary.example.com

SecurePort: 8443
beginRange: 31
endRange: 48
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh primaryds | tee output

# request nextRange should be 31 decimal
cat > expected << EOF
nextRange: 31
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh primaryds | tee output

# cert nextRange should be 49 decimal
cat > expected << EOF
nextRange: 49
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Enroll 5 certs in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
for i in $(seq 1 5); do
    docker exec "$CONTAINER" pki \
        -n caadmin \
        ca-cert-issue \
        --profile caUserCert \
        --csr-file testuser.csr \
        --output-file testuser.crt

    docker exec "$CONTAINER" openssl x509 -in testuser.crt -serial -noout
done
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll 5 certs in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Enroll 10 certs in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Enroll 10 certs in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll 10 certs in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check requests"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-request-find | tee output
sed -n "s/^ *Request ID: *\(.*\)$/\1/p" output > actual

# there should be 25 requests
seq 1 9 > expected     # primary CA
seq 16 20 >> expected  # secondary CA
seq 10 15 >> expected  # primary CA
seq 21 30 >> expected  # secondary CA

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check certs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-find | tee output
sed -n "s/^ *Serial Number: *\(.*\)$/\1/p" output > actual

# there should be 29 certs. since the certs were issued by
# different CAs with different ranges, it's normal to have
# a gap temporarily, and the gap should disappear when the
# ranges are exhausted.
#
# however, currently the code is creating non-contiguous
# ranges so the gap will never close.

seq 1 23 | while read n; do printf "0x%x\n" $n; done > expected
seq 49 54 | while read n; do printf "0x%x\n" $n; done >> expected

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-config.sh primary | tee output

# request range should be 11 - 15 decimal (size: 5, remaining: 0)
cat > expected << EOF
dbs.beginRequestNumber=11
dbs.endRequestNumber=15
dbs.requestCloneTransferNumber=5
dbs.requestIncrement=10
dbs.requestLowWaterMark=5
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check request range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-config.sh primary | tee output

# according to the range object, the cert range should have
# been d - 1e hex (13 - 30 decimal), but the actual range is
# 13 - 24 hex (19 - 36 decimal)
cat > expected << EOF
dbs.beginSerialNumber=13
dbs.endSerialNumber=24
dbs.serialCloneTransferNumber=9
dbs.serialIncrement=12
dbs.serialLowWaterMark=9
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check cert range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check request range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh primaryds | tee output

# request ranges should remain the same
cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

SecurePort: 8443
beginRange: 21
endRange: 30
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh primaryds | tee output

# cert ranges should remain the same
cat > expected << EOF
SecurePort: 8443
beginRange: 13
endRange: 30
host: primary.example.com

SecurePort: 8443
beginRange: 31
endRange: 48
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh primaryds | tee output

# request nextRange should remain the same
cat > expected << EOF
nextRange: 31
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh primaryds | tee output

# cert nextRange should remain the same
cat > expected << EOF
nextRange: 49
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Stop the CAs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server stop
docker exec "$CONTAINER" pki-server stop
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Stop the CAs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Switch primary to legacy2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-id-generator-update -v --type legacy2 request
docker exec "$CONTAINER" pki-server ca-id-generator-update -v --type legacy2 cert
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Switch primary to legacy2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range objects for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh primaryds | tee output

# request ranges should remain the same
cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

SecurePort: 8443
beginRange: 21
endRange: 30
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range objects for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh -t legacy2 primaryds | tee output

# request ranges should remain the same
cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh primaryds | tee output

# request nextRange should remain the same
cat > expected << EOF
nextRange: 31
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh -t legacy2 primaryds | tee output

# request nextRange should remain the same
cat > expected << EOF
nextRange: 21
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh primaryds | tee output

# cert ranges should remain the same but converted from hex to decimal
# the range value for the primary move from 13-30 (hex) to 19-48 (dec) 
cat > expected << EOF
SecurePort: 8443
beginRange: 13
endRange: 30
host: primary.example.com

SecurePort: 8443
beginRange: 31
endRange: 48
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh -t legacy2 primaryds | tee output

# cert ranges should remain the same but converted from hex to decimal
# the range value for the primary move from 13-30 (hex) to 19-48 (dec) 
cat > expected << EOF
SecurePort: 8443
beginRange: 19
endRange: 48
host: primary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh primaryds | tee output

# next range should remain the same
cat > expected << EOF
nextRange: 49
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh -t legacy2 primaryds | tee output

# next range should be endRange + 1
cat > expected << EOF
nextRange: 49
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Switch secondary to legacy2"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Switch secondary to legacy2"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Switch secondary to legacy2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Start the CAs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server start --wait
docker exec "$CONTAINER" pki-server start --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Start the CAs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-config.sh primary | tee output

cat > expected << EOF
dbs.beginRequestNumber=11
dbs.endRequestNumber=15
dbs.nextBeginRequestNumber=31
dbs.nextEndRequestNumber=40
dbs.requestCloneTransferNumber=5
dbs.requestIncrement=10
dbs.requestLowWaterMark=5
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check request range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check the radix for the new generator in all CAs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-config-show dbs.request.id.radix | tee output
docker exec "$CONTAINER" pki-server ca-config-show dbs.request.id.radix | tee -a output
docker exec "$CONTAINER" pki-server ca-config-show dbs.cert.id.radix | tee -a output
docker exec "$CONTAINER" pki-server ca-config-show dbs.cert.id.radix | tee -a output

cat > expected <<EOF                                                                                                                                                                                                                                 
10
10
16
16
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check the radix for the new generator in all CAs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check the new range object is configured in a different DN in all CAs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-config-show dbs.serialRangeDN | tee output
docker exec "$CONTAINER" pki-server ca-config-show dbs.requestRangeDN | tee -a output
docker exec "$CONTAINER" pki-server ca-config-show dbs.serialRangeDN | tee -a output
docker exec "$CONTAINER" pki-server ca-config-show dbs.requestRangeDN | tee -a output

cat > expected <<EOF
ou=certificateRepository,ou=ranges_v2
ou=requests,ou=ranges_v2
ou=certificateRepository,ou=ranges_v2
ou=requests,ou=ranges_v2
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check the new range object is configured in a different DN in all CAs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-config.sh primary | tee output

cat > expected << EOF
dbs.beginSerialNumber=0x13
dbs.endSerialNumber=0x30
dbs.serialCloneTransferNumber=0x9
dbs.serialIncrement=0x12
dbs.serialLowWaterMark=0x9
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check cert range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check request range objects for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh primaryds | tee output

cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

SecurePort: 8443
beginRange: 21
endRange: 30
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range objects for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh -t legacy2 primaryds | tee output

cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

SecurePort: 8443
beginRange: 21
endRange: 30
host: secondary.example.com

SecurePort: 8443
beginRange: 31
endRange: 40
host: primary.example.com

SecurePort: 8443
beginRange: 41
endRange: 50
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh primaryds | tee output

cat > expected << EOF
nextRange: 31
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh -t legacy2 primaryds | tee output

cat > expected << EOF
nextRange: 51
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh primaryds | tee output

# cert ranges should remain the same
cat > expected << EOF
SecurePort: 8443
beginRange: 13
endRange: 30
host: primary.example.com

SecurePort: 8443
beginRange: 31
endRange: 48
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh -t legacy2 primaryds | tee output

# cert ranges should remain the same but in dec.
# the range value for the primary move from 13-30 (hex) to 19-48 (dec)
# the range value for the secondary move from 31-48 (hex) to 49-72 (dec)          
cat > expected << EOF
SecurePort: 8443
beginRange: 19
endRange: 48
host: primary.example.com

SecurePort: 8443
beginRange: 49
endRange: 72
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh primaryds | tee output

# next range should remain the same
cat > expected << EOF
nextRange: 49
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh -t legacy2 primaryds | tee output

# next range should be endRange + 1
cat > expected << EOF
nextRange: 73
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Enroll certs in primary and secondary"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Enroll certs in primary and secondary"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll certs in primary and secondary (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Allocate new ranges"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-job-start \
    serialNumberUpdate

docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-job-start \
    serialNumberUpdate

# wait for DS replication
sleep 5
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Allocate new ranges (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Enroll certs in primary and secondary"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Enroll certs in primary and secondary"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll certs in primary and secondary (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Allocate new ranges"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-job-start \
    serialNumberUpdate

docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-job-start \
    serialNumberUpdate
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Allocate new ranges (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Enroll certs in secondary"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Enroll certs in secondary"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll certs in secondary (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Allocate new ranges"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki \
    -n caadmin \
    ca-job-start \
    serialNumberUpdate
# wait for DS replication
sleep 5
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Allocate new ranges (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-config.sh primary | tee output

cat > expected << EOF
dbs.beginRequestNumber=51
dbs.endRequestNumber=60
dbs.nextBeginRequestNumber=81
dbs.nextEndRequestNumber=90
dbs.requestCloneTransferNumber=5
dbs.requestIncrement=10
dbs.requestLowWaterMark=5
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check request range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check cert range config in primary CA"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-config.sh primary | tee output

cat > expected << EOF
dbs.beginSerialNumber=0x13
dbs.endSerialNumber=0x30
dbs.nextBeginSerialNumber=0x5b
dbs.nextEndSerialNumber=0x6c
dbs.serialCloneTransferNumber=0x9
dbs.serialIncrement=0x12
dbs.serialLowWaterMark=0x9
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range config in secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check cert range config in secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range config in secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check request range objects for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh primaryds | tee output

cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

SecurePort: 8443
beginRange: 21
endRange: 30
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request range objects for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-range-objects.sh -t legacy2 primaryds | tee output

cat > expected << EOF
SecurePort: 8443
beginRange: 11
endRange: 20
host: primary.example.com

SecurePort: 8443
beginRange: 21
endRange: 30
host: secondary.example.com

SecurePort: 8443
beginRange: 31
endRange: 40
host: primary.example.com

SecurePort: 8443
beginRange: 41
endRange: 50
host: secondary.example.com

SecurePort: 8443
beginRange: 51
endRange: 60
host: primary.example.com

SecurePort: 8443
beginRange: 61
endRange: 70
host: secondary.example.com

SecurePort: 8443
beginRange: 71
endRange: 80
host: secondary.example.com

SecurePort: 8443
beginRange: 81
endRange: 90
host: primary.example.com

SecurePort: 8443
beginRange: 91
endRange: 100
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request range objects for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh primaryds | tee output

cat > expected << EOF
nextRange: 31
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check request next range for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-request-next-range.sh -t legacy2 primaryds | tee output

cat > expected << EOF
nextRange: 101
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check request next range for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh primaryds | tee output

# cert ranges should remain the same
cat > expected << EOF
SecurePort: 8443
beginRange: 13
endRange: 30
host: primary.example.com

SecurePort: 8443
beginRange: 31
endRange: 48
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert range objects for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-range-objects.sh -t legacy2 primaryds | tee output

cat > expected << EOF
SecurePort: 8443
beginRange: 19
endRange: 48
host: primary.example.com

SecurePort: 8443
beginRange: 49
endRange: 72
host: secondary.example.com

SecurePort: 8443
beginRange: 73
endRange: 90
host: secondary.example.com

SecurePort: 8443
beginRange: 91
endRange: 108
host: primary.example.com

SecurePort: 8443
beginRange: 109
endRange: 126
host: secondary.example.com

EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert range objects for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range for SSNv1"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh primaryds | tee output

# next range should remain the same
cat > expected << EOF
nextRange: 49
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range for SSNv1 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check cert next range for SSNv2"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
tests/ca/bin/ca-cert-next-range.sh -t legacy2 primaryds | tee output

# next range should be endRange + 1
cat > expected << EOF
nextRange: 127
EOF

diff expected output
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check cert next range for SSNv2 (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check requests"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-request-find | tee output
sed -n "s/^ *Request ID: *\(.*\)$/\1/p" output > actual

# there should be 25 requests
seq 1 9 > expected     # primary CA
seq 16 20 >> expected  # secondary CA
seq 10 15 >> expected  # primary CA
seq 21 30 >> expected  # secondary CA
seq 31 40 >> expected  # primary CA
seq 41 50 >> expected  # secondary CA
seq 51 60 >> expected  # primary CA
seq 61 70 >> expected  # secondary CA
seq 71 80 >> expected  # secondary CA

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check requests (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check certs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki-server ca-cert-find | tee output
sed -n "s/^ *Serial Number: *\(.*\)$/\1/p" output > actual


# There is only a permanent gap generated with legagy id generator

seq 1 43 | while read n; do printf "0x%x\n" $n; done > expected
seq 49 84 | while read n; do printf "0x%x\n" $n; done >> expected

diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Remove secondary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Remove secondary CA"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove secondary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove primary CA"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pkidestroy -s CA -v
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove primary CA (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check primary DS server systemd journal"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec primaryds journalctl -x --no-pager -u dirsrv@localhost.service
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check primary DS server systemd journal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check primary DS container logs"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker logs primaryds
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check primary DS container logs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check primary PKI server systemd journal"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" journalctl -x --no-pager -u pki-tomcatd@pki-tomcat.service
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check primary PKI server systemd journal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check primary PKI server access log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" find /var/log/pki/pki-tomcat -name "localhost_access_log.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check primary PKI server access log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check primary CA debug log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" find /var/lib/pki/pki-tomcat/logs/ca -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check primary CA debug log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check secondary DS server systemd journal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check secondary DS server systemd journal"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check secondary DS server systemd journal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check secondary DS container logs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check secondary DS container logs"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check secondary DS container logs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check secondary PKI server systemd journal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check secondary PKI server systemd journal"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check secondary PKI server systemd journal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check secondary PKI server access log"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check secondary PKI server access log"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check secondary PKI server access log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check secondary CA debug log"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "parity gap for ca-clone-ssnv1-test: Check secondary CA debug log"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check secondary CA debug log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA ca-clone-ssnv1-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA ca-clone-ssnv1-test PASSED ===="

