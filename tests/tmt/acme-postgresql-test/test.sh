#!/bin/bash
# Generated IPACTA TMT port of Dogtag tests/tmt/acme-postgresql-test
# (GHA .github/workflows/acme-postgresql-test.yml). Packaged forge IPACTA.
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

step "Retrieve ACME images"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Retrieve ACME images"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Retrieve ACME images (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Load ACME images"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker image inspect "$IPA_IMAGE" >/dev/null
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Load ACME images (rc=$_rc)" >&2
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

step "Install CA in PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_ca
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA in PKI container (rc=$_rc)" >&2
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
docker exec "$CONTAINER" pki -n caadmin ca-user-show caadmin
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install CA admin cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check initial CA certs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki ca-cert-find | tee output

# there should be 6 certs
echo "6" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial CA certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create postgresql certificates"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Create postgresql certificates"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create postgresql certificates (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Create postgresql Docker file"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Create postgresql Docker file"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Create postgresql Docker file (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Build postgrsql image with certificates"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
# GHA: docker/build-push-action — translated to docker build
docker build -f Dockerfile-Postgresql -t postgres-ssl .
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Build postgrsql image with certificates (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Deploy postgresql"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "Deploy postgresql"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Deploy postgresql (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up database drivers"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" dnf install -y postgresql-jdbc
docker exec "$CONTAINER" ln -s /usr/share/java/postgresql-jdbc/postgresql.jar /usr/share/pki/server/common/lib
docker exec "$CONTAINER" ln -s /usr/share/java/ongres-scram/scram-client.jar /usr/share/pki/server/common/lib
docker exec "$CONTAINER" ln -s /usr/share/java/ongres-scram/scram-common.jar /usr/share/pki/server/common/lib
docker exec "$CONTAINER" ln -s /usr/share/java/ongres-stringprep/saslprep.jar /usr/share/pki/server/common/lib/
docker exec "$CONTAINER" ln -s /usr/share/java/ongres-stringprep/stringprep.jar /usr/share/pki/server/common/lib/
docker exec "$CONTAINER" pki-server restart --wait
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up database drivers (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install ACME in PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_install_acme
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install ACME in PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME database config"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" cat /etc/pki/pki-tomcat/acme/database.conf
docker exec "$CONTAINER" pki-server acme-database-show
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME database config (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check ACME issuer config"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" cat /etc/pki/pki-tomcat/acme/issuer.conf
docker exec "$CONTAINER" pki-server acme-issuer-show
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME issuer config (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check ACME realm config"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" cat /etc/pki/pki-tomcat/acme/realm.conf
docker exec "$CONTAINER" pki-server acme-realm-show
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME realm config (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Run PKI healthcheck in PKI container"
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
    echo "FAIL: Run PKI healthcheck in PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Verify ACME in PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki acme-info
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Verify ACME in PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check initial ACME accounts"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM accounts' \
    acme | tee output

# there should be no accounts
echo "0" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial ACME accounts (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check initial ACME orders"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM orders' \
    acme | tee output

# there should be no orders
echo "0" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial ACME orders (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check initial ACME authorizations"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM authorizations' \
    acme | tee output

# there should be no authorizations
echo "0" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial ACME authorizations (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check initial ACME challenges"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM authorization_challenges' \
    acme | tee output

# there should be no challenges
echo "0" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial ACME challenges (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check initial ACME certs"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM certificates' \
    acme | tee output

# there should be no certs
echo "0" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check initial ACME certs (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA certs after ACME installation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki ca-cert-find | tee output

# there should be 7 certs
echo "7" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA certs after ACME installation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Set up client container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
omit "extra client container; run ACME client in IPA container if needed"
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Set up client container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Install certbot in client container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client dnf install -y certbot
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Install certbot in client container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Register ACME account"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client certbot register \
    --server http://pki.example.com:8080/acme/directory \
    --email testuser@example.com \
    --agree-tos \
    --non-interactive
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Register ACME account (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME accounts after registration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM accounts LEFT JOIN account_contacts ON accounts.id = account_contacts.account_id' \
    acme | tee output
    
# there should be one account
echo "1" > expected
cat output | wc -l > actual
diff expected actual

# status should be valid
echo "valid" > expected
cat output |  awk -F '|' '{ print $3 }'  > actual
diff expected actual

# email should be testuser@example.com
echo "mailto:testuser@example.com" > expected
cat output |  awk -F '|' '{ print $6 }' > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME accounts after registration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Enroll client cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client certbot certonly \
    --server http://pki.example.com:8080/acme/directory \
    -d client.example.com \
    --key-type rsa \
    --standalone \
    --non-interactive
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Enroll client cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check client cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client pki client-cert-import \
    --cert /etc/letsencrypt/live/client.example.com/fullchain.pem \
    client1

# store serial number
docker exec client pki nss-cert-show client1 | tee output
sed -n 's/^ *Serial Number: *\(.*\)/\1/p' output > serial1.txt

# subject should be CN=client.example.com
echo "CN=client.example.com" > expected
sed -n 's/^ *Subject DN: *\(.*\)/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check client cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME orders after enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM orders' \
    acme | tee output

# there should be one order
echo "1" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME orders after enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME authorizations after enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM authorizations' \
    acme | tee output

# there should be one authorization
echo "1" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME authorizations after enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME challenges after enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM authorization_challenges' \
    acme | tee output

# there should be one challenge
echo "1" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME challenges after enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME certs after enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM certificates' \
    acme | tee output

# there should be no certs (they are stored in CA)
echo "0" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME certs after enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA certs after enrollment"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki ca-cert-find | tee output

# there should be 8 certs
echo "8" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual

# check client cert
SERIAL=$(cat serial1.txt)
docker exec "$CONTAINER" pki ca-cert-show $SERIAL | tee output

# subject should be CN=client.example.com
echo "CN=client.example.com" > expected
sed -n 's/^ *Subject DN: *\(.*\)/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA certs after enrollment (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Renew client cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client certbot renew \
    --server http://pki.example.com:8080/acme/directory \
    --cert-name client.example.com \
    --force-renewal \
    --no-random-sleep-on-renew \
    --non-interactive
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Renew client cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check renewed client cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client pki client-cert-import \
    --cert /etc/letsencrypt/live/client.example.com/fullchain.pem \
    client2

# store serial number
docker exec client pki nss-cert-show client2 | tee output
sed -n 's/^ *Serial Number: *\(.*\)/\1/p' output > serial2.txt

# subject should be CN=client.example.com
echo "CN=client.example.com" > expected
sed -n 's/^ *Subject DN: *\(.*\)/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check renewed client cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME orders after renewal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM orders' \
    acme | tee output

# there should be two orders
echo "2" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME orders after renewal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME authorizations after renewal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM authorizations' \
    acme | tee output

# there should be two authorizations
echo "2" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME authorizations after renewal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME challenges after renewal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM authorization_challenges' \
    acme | tee output

# there should be two challenges
echo "2" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME challenges after renewal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME certs after renewal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM certificates' \
    acme | tee output

# there should be no certs (they are stored in CA)
echo "0" > expected
cat output | wc -l > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME certs after renewal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA certs after renewal"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki ca-cert-find | tee output

# there should be 9 certs
echo "9" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual

# check renewed client cert
SERIAL=$(cat serial2.txt)
docker exec "$CONTAINER" pki ca-cert-show $SERIAL | tee output

# subject should be CN=client.example.com
echo "CN=client.example.com" > expected
sed -n 's/^ *Subject DN: *\(.*\)/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA certs after renewal (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Revoke client cert"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client certbot revoke \
    --server http://pki.example.com:8080/acme/directory \
    --cert-name client.example.com \
    --non-interactive
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Revoke client cert (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check CA certs after revocation"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pki ca-cert-find | tee output

# there should be 9 certs
echo "9" > expected
{ grep "Serial Number:" output || true; } | wc -l > actual
diff expected actual

# check original client cert
SERIAL=$(cat serial1.txt)
docker exec "$CONTAINER" pki ca-cert-show $SERIAL | tee output

# status should be valid
echo "VALID" > expected
sed -n 's/^ *Status: *\(.*\)/\1/p' output > actual
diff expected actual

# check renewed-then-revoked client cert
SERIAL=$(cat serial2.txt)
docker exec "$CONTAINER" pki ca-cert-show $SERIAL | tee output

# status should be revoked
echo "REVOKED" > expected
sed -n 's/^ *Status: *\(.*\)/\1/p' output > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check CA certs after revocation (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Update ACME account"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client certbot update_account \
    --server http://pki.example.com:8080/acme/directory \
    --email newuser@example.com \
    --non-interactive
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Update ACME account (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME accounts after update"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM accounts LEFT JOIN account_contacts ON accounts.id = account_contacts.account_id' \
    acme | tee output

# there should be one account
echo "1" > expected
cat output | wc -l > actual
diff expected actual

# email should be newuser@example.com
echo "mailto:newuser@example.com" > expected
cat output |  awk -F '|' '{ print $6 }' > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME accounts after update (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove ACME account"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec client certbot unregister \
    --server http://pki.example.com:8080/acme/directory \
    --non-interactive
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove ACME account (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Check ACME accounts after unregistration"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec  postgresql psql -U acme \
    -t -A -c 'SELECT * FROM accounts LEFT JOIN account_contacts ON accounts.id = account_contacts.account_id' \
    acme | tee output

# there should be one account
echo "1" > expected
cat output | wc -l > actual
diff expected actual

# status should be deactivated
echo "deactivated" > expected
cat output |  awk -F '|' '{ print $3 }' > actual
diff expected actual
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME accounts after unregistration (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove ACME from PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
docker exec "$CONTAINER" pkidestroy -s ACME -v
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove ACME from PKI container (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi
fi

step "Remove CA from PKI container"
if [[ "$GHA_FAILED" -eq 0 ]]; then
set +e
(
set -euo pipefail
ipacta_uninstall
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Remove CA from PKI container (rc=$_rc)" >&2
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

step "Check ACME debug log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec "$CONTAINER" find /var/lib/pki/pki-tomcat/logs/acme -name "debug.*" -exec cat {} \;
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check ACME debug log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

step "Check certbot log"
# GHA if: always() — run even after prior step failures; may fail the test
set +e
(
set -euo pipefail
docker exec client cat /var/log/letsencrypt/letsencrypt.log
)
_rc=$?
set -euo pipefail
if [[ $_rc -ne 0 ]]; then
    echo "FAIL: Check certbot log (rc=$_rc)" >&2
    GHA_FAILED=$_rc
fi

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== acme-postgresql-test FAILED ===="
    exit "$GHA_FAILED"
fi
echo "==== acme-postgresql-test PASSED ===="

if [[ "$GHA_FAILED" -ne 0 ]]; then
    echo "==== IPACTA acme-postgresql-test FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2
    exit "$GHA_FAILED"
fi
echo "==== IPACTA acme-postgresql-test PASSED ===="

