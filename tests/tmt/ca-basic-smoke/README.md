# ca-basic-smoke (TMT / IPACTA)

Parity plan for [IDM-8254](https://redhat.atlassian.net/browse/IDM-8254) against
dogtagpki/pki `plans/ca-basic-smoke.fmf` (GHA `ca-basic-test.yml` smoke).

## Backend

- **IPACTA** via `ipa-server-install --internal-ca` (this branch / IPAthinCA)
- Not Dogtag/`pkispawn` (that baseline lives in the pki repo)

## Checks (aligned intent)

| This plan | Dogtag TMT / GHA |
|-----------|------------------|
| `ipa-server-install --internal-ca` | `pkispawn -s CA` |
| `ipa ping` + `ipa cert-find` / `certprofile-find` | `pki -n caadmin ca-cert-find` / `ca-profile-find` |
| `ipa-server-install --uninstall` | `pkidestroy -s CA` |

## Prerequisites

- Docker
- `IPA_IMAGE` env var pointing at an image with this FreeIPA+IPACTA build

## Run locally

```bash
export IPA_IMAGE=freeipa-ipacta:latest   # override if needed
tmt lint /plans/ca-basic-smoke /tests/tmt/ca-basic-smoke
tmt --feeling-safe run -vvv plan --name ca-basic-smoke
```
