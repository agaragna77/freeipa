# ca-cmc-shared-token-test (TMT / IPACTA)

Generated from Dogtag `tests/tmt/ca-cmc-shared-token-test` (GHA `ca-cmc-shared-token-test.yml`) for IDM-8254.

- Image: `freeipa-ipacta` via `tests/tmt/bin/build-ipa-runner.sh`
- Install: `ipa-server-install` (+ `ipa-kra-install` / `ipa-acme-manage enable` when the Dogtag test spawned KRA/ACME)
- Dogtag-only topology (DS sidecar, extra PKI hosts, HSM tokens) is **OMITTED**
- Remaining `pki` CLI / REST checks run in the IPA container and **FAIL** if IPACTA cannot do them

```bash
tmt --feeling-safe run -e SKIP_IPA_BUILD=1 plans --name /tests/tmt/plans/ca-cmc-shared-token-test
```
