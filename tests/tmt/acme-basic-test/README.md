# acme-basic-test (TMT / IPACTA)

Hand-ported from Dogtag `tests/tmt/acme-basic-test` (GHA `acme-basic-test.yml`) for IDM-8254.

## Model

- Image: `freeipa-ipacta` via `tests/tmt/bin/build-ipa-runner.sh`
- Install: `ipa-server-install` + packaged forge IPACTA
- ACME: `ipa-acme-manage enable` → `https://ipa-ca.$DOMAIN/acme/directory`
- Client: certbot inside the IPA container (HTTP-01 standalone; httpd stopped during challenge), following `ipatests/test_integration/test_acme.py`

## Coverage vs Dogtag

| Dogtag intent | IPACTA |
|---|---|
| Install CA / ACME | `ipa-server-install` + `ipa-acme-manage enable` |
| `pki acme` CLI help | `ipa-acme-manage --help` |
| certbot register / enroll / renew / revoke | same, `--server https://ipa-ca…/acme/directory` |
| account update / unregister | certbot `update_account` / `unregister` |
| Tomcat ACME layout, DS sidecar, caddy | **omitted** |

Failures are collected; the script exits non-zero at the end if any check failed.

```bash
tmt --feeling-safe run -e SKIP_IPA_BUILD=1 plans --name /tests/tmt/plans/acme-basic-test
```
