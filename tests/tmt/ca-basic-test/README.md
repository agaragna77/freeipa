# ca-basic-test (TMT / IPACTA)

Same functional coverage as Dogtag [`tests/tmt/ca-basic-test`](https://github.com/dogtagpki/pki)
/ [`.github/workflows/ca-basic-test.yml`](https://github.com/dogtagpki/pki/blob/master/.github/workflows/ca-basic-test.yml)
([IDM-8254](https://redhat.atlassian.net/browse/IDM-8254)), against a **FreeIPA-only**
install with IPACTA (`ipa-server-install --internal-ca`).

## Model

- One IPA container (Directory Server + KDC + httpd + IPACTA). No DS/PKI sidecars.
- No `pkispawn` / `pki-tomcatd` as the CA.
- After install, every CA check still runs if an earlier check fails; the test
  fails at the end if any **CA** check failed. Dogtag-only Tomcat/`pki` CLI/CSR
  file/DS-sidecar steps are omitted (not FAILs).
- Dogtag surfaces map to IPA CLI, NSS nicknames under `/etc/pki/pki-tomcat/alias`,
  IPACTA paths (`/var/lib/ipacta`, `/var/log/ipacta`, `/etc/ipa/ipacta.conf`),
  `/ca/rest/*` + OCSP, LDAP `o=ipaca`, `ipa-healthcheck`, and
  `ipa-server-install --uninstall`.

## Layout

| Path | Role |
|------|------|
| `tests/tmt/plans/ca-basic-test.fmf` | Plan (prepare builds runner, then execute) |
| `tests/tmt/bin/build-ipa-runner.sh` | Azure-equivalent RPM + `freeipa-ipacta` image build |
| `tests/tmt/ca-basic-test/` | Test (`main.fmf` + `test.sh`) |

## Build dependency (like Azure IPA tests)

Prepare runs `build-ipa-runner.sh`: `makerpms.sh` inside `fedora-toolbox:44`
(COPR `@freeipa/freeipa-master`), then `docker build` of
`ipatests/azure/Dockerfiles/Dockerfile.build.fedora`, then installs
`freeipa-healthcheck` into the image. A clean host / Testing Farm guest
does not need a preloaded image.

Optional local skip (not for TF): `SKIP_IPA_BUILD=1` if `freeipa-ipacta:latest`
already exists. `SKIP_IPA_RPMS=1` rebuilds the image from existing `dist/rpms`.
Override: `IPA_IMAGE=…` `BASE_IMAGE=…` `COPR_REPO=…`.

## Prerequisites

- Docker
- Network to pull the toolbox/base image and COPR
- Local run: `tmt --feeling-safe …`

## Run locally

```bash
tmt lint /tests/tmt/plans/ca-basic-test /tests/tmt/ca-basic-test
tmt --feeling-safe run -vvv plans --name /tests/tmt/plans/ca-basic-test
```
