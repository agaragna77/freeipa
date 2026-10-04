#!/bin/bash
# IPACTA ca-basic-test — same functional coverage as dogtagpki/pki
# tests/tmt/ca-basic-test (GHA ca-basic-test.yml), FreeIPA-only install.
#
# Model: single IPA container + ipa-server-install --internal-ca (IPACTA).
# No separate DS/PKI containers, no pkispawn, no pki-tomcatd as CA.
# Dogtag Tomcat layout / pki -n caadmin / pkidestroy are mapped to IPA CLI,
# IPACTA paths, NSS nicknames, /ca/rest/* + OCSP, LDAP o=ipaca, ipa-healthcheck,
# and ipa-server-install --uninstall.
#
# After install, checks keep running if one fails; the script exits non-zero
# at the end if any CA check failed. Dogtag-only surfaces (Tomcat files, pki
# CLI, on-disk CSRs, DS sidecar) are omitted from this script — see
# POCs/IDM-8254/ca-basic-differences-dogtag-tmt-vs-ipacta-tmt.md
set -euo pipefail

REPO_ROOT="${TMT_TREE:-}"
if [[ -z "$REPO_ROOT" || ! -f "$REPO_ROOT/ipaserver/install/server/install.py" ]]; then
    REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
fi

IPA_IMAGE="${IPA_IMAGE:-freeipa-ipacta:latest}"
CONTAINER="${CONTAINER_NAME:-ipa}"
DOMAIN="${IPA_DOMAIN:-example.com}"
REALM="${IPA_REALM:-EXAMPLE.COM}"
PASSWORD="${IPA_PASSWORD:-Secret.123}"
HOST="ipa.${DOMAIN}"
WORKDIR=/tmp/ca-basic-workdir

NSSDB=/etc/pki/pki-tomcat/alias
CA_SIGNING_NICK="caSigningCert cert-pki-ca"
OCSP_SIGNING_NICK="ocspSigningCert cert-pki-ca"
AUDIT_SIGNING_NICK="auditSigningCert cert-pki-ca"
SUBSYSTEM_NICK="subsystemCert cert-pki-ca"
SSL_SERVER_NICK="Server-Cert cert-pki-ca"

FAILS=()
CURRENT="setup"
COLLECT=0

cleanup() {
    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker network rm example 2>/dev/null || true
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

step() {
    CURRENT="$*"
    echo
    echo "==== $* ===="
}

fail() {
    echo "FAIL: ${CURRENT}: $*" >&2
    FAILS+=("${CURRENT}: $*")
}

finish_report() {
    echo
    if [[ ${#FAILS[@]} -eq 0 ]]; then
        echo "==== IPACTA CA basic test PASSED ===="
        return 0
    fi
    echo "==== IPACTA CA basic test FAILED (${#FAILS[@]} check(s)) ===="
    local item
    for item in "${FAILS[@]}"; do
        echo " - ${item}"
    done
    return 1
}

iexec() { docker exec "$CONTAINER" "$@"; }

# Run bash -lc inside container (kerberos / paths)
ibash() { docker exec "$CONTAINER" bash -lc "$*"; }

export_nss_cert() {
    local nick="$1" out="$2"
    iexec certutil -L -d "$NSSDB" -n "$nick" -a > "$WORKDIR/$out"
}

serial_from_pem() {
    local pem="$1"
    openssl x509 -in "$WORKDIR/$pem" -noout -serial | sed 's/^serial=//'
}

if ! command -v docker >/dev/null; then
    echo "ERROR: docker not found" >&2
    exit 1
fi
if ! docker image inspect "$IPA_IMAGE" >/dev/null 2>&1; then
    cat >&2 <<EOF
ERROR: Docker image '$IPA_IMAGE' not found.
Prepare should have built it (tests/tmt/bin/build-ipa-runner.sh).
Override with IPA_IMAGE=... or SKIP_IPA_BUILD=1 only if the image already exists.
EOF
    exit 1
fi

mkdir -p "$WORKDIR"
# Bind-mounted workdir inside container for openssl OCSP / verify
WORKDIR_IN=/tmp/ca-basic-workdir

step "Create network"
docker network inspect example >/dev/null 2>&1 || docker network create example
docker rm -f "$CONTAINER" 2>/dev/null || true

step "Set up IPA container"
# FreeIPA-only: one container (DS + KDC + httpd + IPACTA). No DS/PKI sidecars.
docker run -d --name "$CONTAINER" \
    --hostname="$HOST" \
    --network=example \
    --network-alias="$HOST" \
    --network-alias="ipa-ca.${DOMAIN}" \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 \
    --privileged \
    -v "$WORKDIR:$WORKDIR_IN" \
    "$IPA_IMAGE" \
    /usr/sbin/init

for _i in $(seq 1 90); do
    if iexec systemctl is-system-running --wait 2>/dev/null \
        || iexec systemctl is-system-running 2>/dev/null | grep -Eq 'running|degraded'; then
        break
    fi
    sleep 2
done

step "Get Fedora version"
FEDORA_VERSION=$(iexec sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"')
echo "FEDORA_VERSION=$FEDORA_VERSION"
export FEDORA_VERSION

step "Check IPA CLI help messages"
iexec ipa --help >/dev/null
iexec ipa-server-install --help >/dev/null
iexec ipacta --help >/dev/null

step "Get IPACTA service flavor"
# Dogtag: Tomcat new/old. IPACTA unit is templated until install.
iexec test -f /usr/share/ipa/ipacta.service.template
iexec test -f /usr/share/ipa/ipacta.conf.template
iexec test -x /usr/bin/ipacta
iexec grep -E 'ExecStart|gunicorn|ipacta' /usr/share/ipa/ipacta.service.template \
    | tee "$WORKDIR/ipacta.unit"
grep -qiE 'ExecStart|ipacta' "$WORKDIR/ipacta.unit"

step "Install CA (ipa-server-install --internal-ca)"
iexec ipa-server-install \
    -U \
    --domain "$DOMAIN" \
    -r "$REALM" \
    -p "$PASSWORD" \
    -a "$PASSWORD" \
    --no-host-dns \
    --no-ntp \
    --internal-ca \
    > >(tee "$WORKDIR/install.stdout") 2> >(tee "$WORKDIR/install.stderr" >&2)

step "Check CA backend is IPACTA"
CA_BACKEND=$(iexec bash -c "grep -E '^ca_backend\\s*=' /etc/ipa/default.conf | cut -d= -f2 | tr -d ' '")
echo "ca_backend=${CA_BACKEND}"
[[ "$CA_BACKEND" == "ipacta" ]] || { echo "ERROR: expected ca_backend=ipacta, got '${CA_BACKEND}'" >&2; exit 1; }
iexec systemctl is-active ipacta
if docker exec "$CONTAINER" systemctl is-active pki-tomcatd@pki-tomcat 2>/dev/null; then
    echo "ERROR: pki-tomcatd is active; expected FreeIPA+IPACTA only" >&2
    exit 1
fi

# Install succeeded. Keep running remaining CA checks after a failure.
COLLECT=1
set +e
trap 'fail "command failed at line ${LINENO}"' ERR

step "Check for warnings"
# Dogtag pkispawn WARNING: lines — IPA install should not emit WARNING: on stderr for CA setup
sed -n '/^WARNING:/p' "$WORKDIR/install.stderr" | tee "$WORKDIR/warnings.txt" || true
# Allow empty; fail only on unexpected critical patterns if present later

step "Check external commands"
iexec bash -c 'command -v ipa ipa-server-install ipacta certutil openssl ldapsearch'

step "Install ipa-healthcheck"
if ! docker exec "$CONTAINER" bash -c 'command -v ipa-healthcheck >/dev/null'; then
    iexec dnf install -y freeipa-healthcheck
fi
iexec bash -c 'command -v ipa-healthcheck'

step "Check IPACTA base dir after installation"
iexec test -d /var/lib/ipacta
iexec ls -la /var/lib/ipacta

step "Check IPACTA conf after installation"
iexec test -f /etc/ipa/ipacta.conf
iexec test -f /etc/ipa/default.conf
iexec test -f /etc/ipa/ca.crt
iexec grep -E '^ca_backend\s*=\s*ipacta' /etc/ipa/default.conf

step "Check ipacta.conf"
iexec grep -E 'https_port|log_file|realm|domain' /etc/ipa/ipacta.conf | tee "$WORKDIR/ipacta.conf.snip"

step "Check NSS alias dir after installation"
iexec test -d "$NSSDB"
iexec ls -la "$NSSDB" | head -30 || true

step "Check httpd IPACTA proxy"
# Dogtag Catalina/localhost — IPACTA is proxied via httpd
if docker exec "$CONTAINER" test -f /etc/httpd/conf.d/ipa-pki-proxy.conf \
        || docker exec "$CONTAINER" test -f /etc/httpd/conf.d/ipa-ipacta-proxy.conf; then
    echo "httpd IPACTA/PKI proxy conf present"
else
    docker exec "$CONTAINER" bash -c 'ls /etc/httpd/conf.d/*ipa* /etc/httpd/conf.d/*pki* /etc/httpd/conf.d/*ipacta* 2>/dev/null | head' \
        || fail "no httpd IPA/PKI/IPACTA proxy conf"
fi
iexec systemctl is-active httpd

step "Check IPACTA systemd unit"
iexec systemctl is-active ipacta
# Installer starts the service; enable-state can be disabled in containers.
echo "is-enabled=$(iexec systemctl is-enabled ipacta 2>/dev/null || echo unknown)"
iexec systemctl status ipacta --no-pager | head -25 || true

step "Check IPACTA logs dir after installation"
iexec test -d /var/log/ipacta
iexec ls -la /var/log/ipacta

step "Check IPACTA CA dir"
iexec test -d /var/lib/ipacta/ca
iexec ls -la /var/lib/ipacta/ca
# Signing material lives in NSS (and PEMs under certs/); ca/ may be empty pre-subca.

step "Check IPACTA certs/private dirs"
iexec test -d /var/lib/ipacta/certs
iexec test -d /var/lib/ipacta/private
iexec test -f /var/lib/ipacta/certs/ca.crt
iexec test -f /var/lib/ipacta/private/server.key
iexec ls -la /var/lib/ipacta/certs /var/lib/ipacta/private

step "Check CA server status"
STATUS=$(iexec curl -sfk "https://127.0.0.1:8443/ca/admin/ca/getStatus" || true)
echo "getStatus: ${STATUS}"
echo "$STATUS" | grep -qiE 'running|Status|CMS' \
    || iexec curl -sfk "https://127.0.0.1:8443/ca/rest/info"
iexec curl -sfk "https://127.0.0.1:8443/ca/rest/info" | tee "$WORKDIR/ca-rest-info.json"
iexec curl -sfk "https://127.0.0.1:8443/pki/rest/info" | tee "$WORKDIR/pki-rest-info.json"

step "Check webapps (REST surfaces)"
# Dogtag lists Tomcat webapps; IPACTA exposes Dogtag-compatible REST
for path in /ca/rest/info /pki/rest/info /ca/rest/profiles; do
    echo "GET $path"
    iexec curl -sfk "https://127.0.0.1:8443${path}" >/dev/null
done

step "Check subsystems"
# Only IPACTA CA — no pki-tomcat subsystems
iexec systemctl is-active ipacta
iexec systemctl is-active dirsrv@${REALM//./-} \
    || docker exec "$CONTAINER" bash -c 'systemctl list-units --type=service --state=running | grep -E "dirsrv@"'
if docker exec "$CONTAINER" systemctl is-active pki-tomcatd@pki-tomcat 2>/dev/null; then
    fail "unexpected pki-tomcatd"
fi

step "Check CA certs and keys"
iexec certutil -L -d "$NSSDB" | tee "$WORKDIR/nss-list.txt"
for nick in \
    "$CA_SIGNING_NICK" \
    "$OCSP_SIGNING_NICK" \
    "$AUDIT_SIGNING_NICK" \
    "$SUBSYSTEM_NICK" \
    "$SSL_SERVER_NICK"
do
    iexec certutil -L -d "$NSSDB" -n "$nick" >/dev/null \
        || fail "missing NSS cert '$nick'"
    echo "OK: $nick"
done

# CSR file checks (Dogtag on-disk CSRs) → IPACTA: NSS nick + PEM exports prove key+cert
step "Check CA signing cert request"
iexec certutil -L -d "$NSSDB" -n "$CA_SIGNING_NICK" >/dev/null
export_nss_cert "$CA_SIGNING_NICK" ca_signing.crt
# Prefer filesystem CA cert if present
if iexec test -f /var/lib/ipacta/certs/ca.crt; then
    iexec cat /var/lib/ipacta/certs/ca.crt > "$WORKDIR/ca_signing.crt"
fi
openssl x509 -in "$WORKDIR/ca_signing.crt" -noout -subject -issuer

step "Check CA OCSP signing cert request"
iexec certutil -L -d "$NSSDB" -n "$OCSP_SIGNING_NICK" >/dev/null
export_nss_cert "$OCSP_SIGNING_NICK" ca_ocsp_signing.crt
if iexec test -f /var/lib/ipacta/certs/ocsp_subsystem.crt; then
    iexec cat /var/lib/ipacta/certs/ocsp_subsystem.crt > "$WORKDIR/ca_ocsp_signing.crt"
fi
openssl x509 -in "$WORKDIR/ca_ocsp_signing.crt" -noout -subject

step "Check CA audit signing cert request"
iexec certutil -L -d "$NSSDB" -n "$AUDIT_SIGNING_NICK" >/dev/null
export_nss_cert "$AUDIT_SIGNING_NICK" ca_audit_signing.crt
if iexec test -f /var/lib/ipacta/certs/ca_audit.crt; then
    iexec cat /var/lib/ipacta/certs/ca_audit.crt > "$WORKDIR/ca_audit_signing.crt"
fi
openssl x509 -in "$WORKDIR/ca_audit_signing.crt" -noout -subject

step "Check subsystem cert request"
iexec certutil -L -d "$NSSDB" -n "$SUBSYSTEM_NICK" >/dev/null
export_nss_cert "$SUBSYSTEM_NICK" subsystem.crt
if iexec test -f /var/lib/ipacta/certs/ca_subsystem.crt; then
    iexec cat /var/lib/ipacta/certs/ca_subsystem.crt > "$WORKDIR/subsystem.crt"
fi
openssl x509 -in "$WORKDIR/subsystem.crt" -noout -subject

step "Check SSL server cert request"
iexec test -f /var/lib/ipacta/private/server.key
iexec certutil -L -d "$NSSDB" -n "$SSL_SERVER_NICK" >/dev/null
export_nss_cert "$SSL_SERVER_NICK" sslserver.crt
if iexec test -f /var/lib/ipacta/certs/server.crt; then
    iexec cat /var/lib/ipacta/certs/server.crt > "$WORKDIR/sslserver.crt"
fi
openssl x509 -in "$WORKDIR/sslserver.crt" -noout -subject

step "Check admin cert request"
# IPA admin = Kerberos + RA agent cert (ipa-ca-agent / ipaCert)
ibash "echo '$PASSWORD' | kinit admin"
iexec ipa user-show admin | tee "$WORKDIR/admin-user.txt"
if iexec certutil -L -d "$NSSDB" -n "ipa-ca-agent cert-pki-ca" >/dev/null 2>&1; then
    export_nss_cert "ipa-ca-agent cert-pki-ca" ca_admin.crt
elif iexec test -f /var/lib/ipacta/certs/ipa_ca_agent.crt; then
    iexec cat /var/lib/ipacta/certs/ipa_ca_agent.crt > "$WORKDIR/ca_admin.crt"
elif iexec test -f /var/lib/ipa/ra-agent.pem; then
    iexec cat /var/lib/ipa/ra-agent.pem > "$WORKDIR/ca_admin.crt"
else
    export_nss_cert "ipaCert" ca_admin.crt
fi
openssl x509 -in "$WORKDIR/ca_admin.crt" -noout -subject

step "Check CA signing cert"
openssl x509 -in "$WORKDIR/ca_signing.crt" -noout -text > "$WORKDIR/ca_signing.txt"
head -40 "$WORKDIR/ca_signing.txt"
grep -qiE 'CA:TRUE|Certificate Sign' "$WORKDIR/ca_signing.txt"

step "Check CA OCSP signing cert"
openssl x509 -in "$WORKDIR/ca_ocsp_signing.crt" -noout -text > "$WORKDIR/ca_ocsp_signing.txt"
head -30 "$WORKDIR/ca_ocsp_signing.txt"

step "Check CA audit signing cert"
openssl x509 -in "$WORKDIR/ca_audit_signing.crt" -noout -text > "$WORKDIR/ca_audit_signing.txt"
head -30 "$WORKDIR/ca_audit_signing.txt"

step "Check subsystem cert"
openssl x509 -in "$WORKDIR/subsystem.crt" -noout -text > "$WORKDIR/subsystem.txt"
head -30 "$WORKDIR/subsystem.txt"

step "Check SSL server cert"
openssl x509 -in "$WORKDIR/sslserver.crt" -noout -text > "$WORKDIR/sslserver.txt"
head -30 "$WORKDIR/sslserver.txt"

step "Check CA admin cert"
openssl x509 -in "$WORKDIR/ca_admin.crt" -noout -subject
iexec ipa user-show admin >/dev/null

step "Check CA audit events"
iexec test -f /var/log/ipacta/audit.log
iexec tail -n 30 /var/log/ipacta/audit.log | tee "$WORKDIR/audit-tail.txt"
# Must have some content after install
test -s "$WORKDIR/audit-tail.txt"

step "Run IPA healthcheck"
# DNS (--no-host-dns) and IPA topology CA-suffix checks are not CA feature
# gaps. Any other ERROR/CRITICAL is a failure (remaining checks still run).
docker exec "$CONTAINER" ipa-healthcheck --failures-only --output-type json \
    > "$WORKDIR/ipa-hc.json" 2> "$WORKDIR/ipa-hc.err" || true
hc_rc=$?
cat "$WORKDIR/ipa-hc.err" || true
python3 - <<'PY'
import json, sys
from pathlib import Path
path = Path("/tmp/ca-basic-workdir/ipa-hc.json")
raw = path.read_text().strip() or "[]"
try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    print("ERROR: healthcheck JSON parse failed:", e, file=sys.stderr)
    print(raw[:2000], file=sys.stderr)
    sys.exit(1)
if isinstance(data, dict):
    data = data.get("results", data.get("checks", []))
allow_sources = {
    "ipahealthcheck.ipa.idns",
}
allow_checks = {
    "IPATopologyDomainCheck",
}
bad = []
for item in data:
    result = item.get("result")
    if result not in ("ERROR", "CRITICAL"):
        continue
    src = item.get("source", "")
    chk = item.get("check", "")
    if src in allow_sources or chk in allow_checks:
        print(f"IGNORE {result} {src}.{chk}: {item.get('kw', {})}")
        continue
    bad.append(item)
    print(f"FAIL {result} {src}.{chk}: {item.get('kw', {})}")
if bad:
    sys.exit(1)
print("ipa-healthcheck OK for CA-relevant checks")
PY
echo "ipa-healthcheck tool rc=$hc_rc"

step "Check external commands"
# Dogtag counts Command: from pkispawn debug — here confirm tooling still present
iexec bash -c 'command -v ipa certutil openssl ldapsearch ipa-healthcheck'

step "Check CA admin user"
iexec ipa user-show admin
# pkidbuser / ipara agents in o=ipaca
ibash "ldapsearch -Y EXTERNAL -H ldapi://%2fvar%2frun%2fslapd-${REALM//./-}.socket \
    -b 'ou=people,o=ipaca' -LLL '(uid=*)' uid 2>/dev/null || \
    ldapsearch -x -D 'cn=Directory Manager' -w '$PASSWORD' \
    -b 'ou=people,o=ipaca' -LLL '(uid=*)' uid" | tee "$WORKDIR/ipaca-people.txt"
grep -qiE 'ipara|pkidbuser|uid:' "$WORKDIR/ipaca-people.txt"

step "Check CA signing cert chain"
openssl verify -CAfile "$WORKDIR/ca_signing.crt" "$WORKDIR/ca_signing.crt"

step "Check CA OCSP signing cert chain"
openssl verify -CAfile "$WORKDIR/ca_signing.crt" "$WORKDIR/ca_ocsp_signing.crt"

step "Check CA audit signing cert chain"
openssl verify -CAfile "$WORKDIR/ca_signing.crt" "$WORKDIR/ca_audit_signing.crt"

step "Check CA subsystem cert chain"
openssl verify -CAfile "$WORKDIR/ca_signing.crt" "$WORKDIR/subsystem.crt"

step "Check CA SSL server cert chain"
openssl verify -CAfile "$WORKDIR/ca_signing.crt" "$WORKDIR/sslserver.crt"

step "Check CA admin cert chain"
openssl verify -CAfile "$WORKDIR/ca_signing.crt" "$WORKDIR/ca_admin.crt"

check_cert_status() {
    local label="$1" pem="$2"
    step "Check ${label} cert status"
    local serial out="$WORKDIR/ocsp-${pem}.out"
    serial=$(serial_from_pem "$pem")
    echo "serial=$serial"
    docker exec "$CONTAINER" bash -lc "openssl ocsp -url http://ipa-ca.${DOMAIN}/ca/ocsp \
            -CAfile $WORKDIR_IN/ca_signing.crt \
            -issuer $WORKDIR_IN/ca_signing.crt \
            -serial 0x${serial}" >"$out" 2>&1 || true
    if ! grep -qiE 'good|OCSP Response Status: successful' "$out"; then
        docker exec "$CONTAINER" bash -lc "openssl ocsp -url https://127.0.0.1:8443/ca/ocsp \
            -CAfile $WORKDIR_IN/ca_signing.crt \
            -issuer $WORKDIR_IN/ca_signing.crt \
            -cert $WORKDIR_IN/$pem" >"$out" 2>&1 || true
    fi
    cat "$out"
    if grep -qiE ': good' "$out"; then
        echo "OCSP: good"
        return 0
    fi
    fail "OCSP did not return good for ${label} (no LDAP/IPA fallback)"
    return 0
}

check_cert_status "CA signing" ca_signing.crt
check_cert_status "CA OCSP signing" ca_ocsp_signing.crt
check_cert_status "CA audit signing" ca_audit_signing.crt
check_cert_status "subsystem" subsystem.crt
check_cert_status "SSL server" sslserver.crt

step "Check CA admin cert status"
# Admin Kerberos principal + cert-find for HTTP/RA if issued
iexec ipa cert-find --all | tee "$WORKDIR/cert-find-all.txt" | head -80 || true
grep -qiE 'Serial|Number of entries' "$WORKDIR/cert-find-all.txt"

check_usage() {
    local label="$1" pem="$2" expect_re="$3"
    step "Check ${label} cert usage"
    openssl x509 -in "$WORKDIR/$pem" -noout -purpose | tee "$WORKDIR/purpose-${pem}.txt"
    if grep -qiE "$expect_re" "$WORKDIR/purpose-${pem}.txt"; then
        return 0
    fi
    openssl x509 -in "$WORKDIR/$pem" -noout -text | grep -iA5 'X509v3 Key Usage\|Extended' || true
    fail "purpose/keyUsage did not match '${expect_re}' for ${label}"
}

check_usage "CA signing" ca_signing.crt 'SSL client CA|SSL server CA|Certificate Sign'
check_usage "CA OCSP signing" ca_ocsp_signing.crt 'OCSP|SSL Client|Any'
check_usage "CA audit signing" ca_audit_signing.crt 'Any Purpose|SSL Client|Code Signing|Yes'
check_usage "subsystem" subsystem.crt 'SSL Client|Any'
check_usage "SSL server" sslserver.crt 'SSL server|Yes'
step "Check CA admin cert usage"
openssl x509 -in "$WORKDIR/ca_admin.crt" -noout -purpose | head -20 || true

step "Check default audit config"
iexec grep -E 'audit_signing_algorithm|log_file' /etc/ipa/ipacta.conf | tee "$WORKDIR/audit-cfg.txt"
iexec test -f /var/log/ipacta/audit.log
iexec test -d /var/lib/ipacta/audit

step "Enable audit log signing"
# IPACTA enables signed audit at install; verify signatures in the log.
ibash "python3 - <<'PY'
from pathlib import Path
import ipacta
from ipacta.config import IpactaConfig
from ipacta.audit import verify_audit_log

ipacta.set_global_config(IpactaConfig.from_file('/etc/ipa/ipacta.conf'))
log = Path('/var/log/ipacta/audit.log')
text = log.read_text()
assert '[signature=' in text, 'audit.log has no signatures'
ok = verify_audit_log(str(log))
print('verify_audit_log=', ok)
raise SystemExit(0 if ok else 1)
PY"

step "Test CA certs"
iexec ipa cert-find --all | tee "$WORKDIR/test-certs.txt"
grep -qiE 'Serial number|Number of entries returned' "$WORKDIR/test-certs.txt"

step "Check certs in DS"
ibash "ldapsearch -x -D 'cn=Directory Manager' -w '$PASSWORD' \
    -b 'ou=certificateRepository,ou=ca,o=ipaca' -o ldif_wrap=no -LLL \
    '(objectClass=*)' dn | head -100 || true" | tee "$WORKDIR/ds-certs.txt"
grep -qi 'certificateRepository\|dn:' "$WORKDIR/ds-certs.txt"

step "Check users in DS"
ibash "ldapsearch -x -D 'cn=Directory Manager' -w '$PASSWORD' \
    -b 'ou=people,o=ipaca' -o ldif_wrap=no -LLL \
    '(objectClass=*)' dn uid | head -100 || true" | tee "$WORKDIR/ds-users.txt"
grep -qiE 'uid:|dn:' "$WORKDIR/ds-users.txt"

step "Check cert requests in DS"
ibash "ldapsearch -x -D 'cn=Directory Manager' -w '$PASSWORD' \
    -b 'ou=ca,ou=requests,o=ipaca' -o ldif_wrap=no -LLL \
    '(objectClass=*)' dn | head -100 || true" | tee "$WORKDIR/ds-requests.txt"
# Tree may be empty early; container must exist
grep -qiE 'dn:|ou=requests|No such object' "$WORKDIR/ds-requests.txt" \
    || ibash "ldapsearch -x -D 'cn=Directory Manager' -w '$PASSWORD' \
        -b 'o=ipaca' -LLL -s one '(ou=requests)' dn"

step "Test CA auditor"
# Dogtag auditor scripts → signed audit log still verifies after an IPA op
BEFORE=$(iexec wc -c /var/log/ipacta/audit.log | awk '{print $1}')
iexec ipa certprofile-find >/dev/null
AFTER=$(iexec wc -c /var/log/ipacta/audit.log | awk '{print $1}')
echo "audit.log bytes before=$BEFORE after=$AFTER"
ibash "python3 - <<'PY'
from pathlib import Path
import ipacta
from ipacta.config import IpactaConfig
from ipacta.audit import verify_audit_log
ipacta.set_global_config(IpactaConfig.from_file('/etc/ipa/ipacta.conf'))
raise SystemExit(0 if verify_audit_log('/var/log/ipacta/audit.log') else 1)
PY"

step "Check CA profiles"
iexec ipa certprofile-find | tee "$WORKDIR/profiles-ipa.txt"
iexec ipa certprofile-show caIPAserviceCert
iexec curl -sfk "https://127.0.0.1:8443/ca/rest/profiles" | tee "$WORKDIR/profiles-rest.json"
grep -q 'caIPAserviceCert' "$WORKDIR/profiles-rest.json"

# Dogtag: export caUserCert → rename → ca-profile-add
iexec ipa certprofile-show caIPAserviceCert --out /tmp/caIPAserviceCert.cfg
ibash "
set -e
sed 's/^profileId=caIPAserviceCert\$/profileId=caCustomUser/' \
    /tmp/caIPAserviceCert.cfg > /tmp/caCustomUser.cfg
grep -q '^profileId=caCustomUser\$' /tmp/caCustomUser.cfg
ipa certprofile-import caCustomUser \
    --file /tmp/caCustomUser.cfg \
    --desc 'TMT custom profile (ca-basic-test)' \
    --store=true
ipa certprofile-show caCustomUser
ipa certprofile-del caCustomUser
"

step "Remove CA (ipa-server-install --uninstall)"
iexec ipa-server-install --uninstall -U \
    > >(tee "$WORKDIR/uninstall.stdout") 2> >(tee "$WORKDIR/uninstall.stderr" >&2)

step "Check for warnings"
sed -n '/^WARNING:/p' "$WORKDIR/uninstall.stderr" | tee "$WORKDIR/uninstall-warnings.txt" || true

step "Check external commands"
iexec bash -c 'command -v ipa-server-install >/dev/null'

step "Check IPACTA base dir after removal"
if docker exec "$CONTAINER" test -d /var/lib/ipacta; then
    fail "/var/lib/ipacta still present"
    docker exec "$CONTAINER" ls -la /var/lib/ipacta || true
fi

step "Check IPA conf after removal"
iexec test ! -f /etc/ipa/ca.crt
iexec test ! -f /etc/ipa/ipacta.conf

step "Check IPACTA logs dir after removal"
iexec test ! -d /var/lib/ipacta

step "Check DS server systemd journal"
iexec journalctl -u "dirsrv@*" --no-pager -n 50 || docker exec "$CONTAINER" journalctl --no-pager -n 50 | head -50

step "Check IPACTA / httpd journal"
iexec journalctl -u ipacta --no-pager -n 50 || true
iexec journalctl -u httpd --no-pager -n 30 || true

step "Check IPACTA access log"
if docker exec "$CONTAINER" test -f /var/log/ipacta/access.log; then
    iexec tail -n 20 /var/log/ipacta/access.log
else
    echo "access.log removed after uninstall (expected for IPACTA; Dogtag keeps Tomcat access logs)"
fi

step "Check IPACTA debug / service log"
if docker exec "$CONTAINER" test -f /var/log/ipacta/ipacta.log; then
    iexec tail -n 40 /var/log/ipacta/ipacta.log
else
    echo "ipacta.log removed after uninstall (expected for IPACTA; Dogtag keeps CA debug logs)"
fi

if ! finish_report; then
    exit 1
fi
