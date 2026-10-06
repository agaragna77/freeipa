# ca-basic-test (TMT / IPACTA)

Same functional coverage as Dogtag [`tests/tmt/ca-basic-test`](https://github.com/dogtagpki/pki)
/ [`.github/workflows/ca-basic-test.yml`](https://github.com/dogtagpki/pki/blob/master/.github/workflows/ca-basic-test.yml)
([IDM-8254](https://redhat.atlassian.net/browse/IDM-8254)), against a **FreeIPA-only**
install with packaged forge IPACTA (Dogtag drop-in).

## Model

- One IPA container (Directory Server + KDC + httpd + IPACTA). No DS/PKI sidecars.
- Stock `ipa-server-install` (no `--internal-ca`). `ipacta` Provides `pki-ca` so
  FreeIPA uses forge IPACTA instead of Dogtag.
- Unit is `pki-tomcatd@pki-tomcat` running `python -m ipacta.server` (not Java).
- After install, every CA check still runs if an earlier check fails; the test
  fails at the end if any **CA** check failed. Standalone Dogtag CSR/DS-sidecar
  steps are omitted (not FAILs).
- Surfaces: IPA CLI, NSS `/etc/pki/pki-tomcat/alias`, IPACTA paths
  (`/var/lib/ipacta`, `/var/log/ipacta`, `/etc/pki/pki-tomcat/ipacta.conf`),
  `/ca/rest/*` + OCSP, LDAP `o=ipaca`, `ipa-healthcheck`, uninstall.

## Layout

| Path | Role |
|------|------|
| `tests/tmt/plans/ca-basic-test.fmf` | Plan (prepare builds runner, then execute) |
| `tests/tmt/bin/build-ipa-runner.sh` | Fedora 46 + packaged IPACTA → `freeipa-ipacta` |
| `tests/tmt/ca-basic-test/` | Test (`main.fmf` + `test.sh`) |

## Prepare (Fedora 46 packages)

Prepare runs `build-ipa-runner.sh`: pull `registry.fedoraproject.org/fedora:46`,
`dnf install freeipa-server ipacta freeipa-healthcheck` (+ systemd/sshd bits),
tag `freeipa-ipacta:latest`. Naming **`ipacta`** selects IPACTA over Dogtag.

Official IPACTA packaging lives at
[forge.fedoraproject.org/freeipa/ipacta](https://forge.fedoraproject.org/freeipa/ipacta)
and ships as Fedora packages (`ipacta`, `python3-ipacta`, `python3-ipacta-pki`).
This path does **not** build FreeIPA from git / makerpms.

Optional local skip: `SKIP_IPA_BUILD=1` if `freeipa-ipacta:latest` already
exists, or `SKIP_IPA_BUILD=1 IPA_IMAGE=quay.io/…` to pull a prebuilt tag.
Override: `BASE_IMAGE=…` `IPACTA_PKGS=…`.

## Prerequisites

- Docker
- Network to `registry.fedoraproject.org` and Fedora 46 repos
- Local run: `tmt --feeling-safe …`

## Run locally

```bash
tmt lint /tests/tmt/plans/ca-basic-test /tests/tmt/ca-basic-test
tmt --feeling-safe run -vvv plans --name /tests/tmt/plans/ca-basic-test
```

## Testing Farm

```bash
# Guest prepare builds from F46 packages (default compose: Fedora-Rawhide)
tests/tmt/bin/tf-quay-pilot.sh --wait

# Optional: prebuild and pull from Quay
tests/tmt/bin/tf-quay-pilot.sh --quay --wait
```
