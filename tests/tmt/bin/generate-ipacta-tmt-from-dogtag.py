#!/usr/bin/env python3
"""Generate IPACTA TMT plans/tests from Dogtag tests/tmt/{ca,kra,acme}-*.

Does not overwrite the hand-ported ca-basic-test/test.sh (or its README/main.fmf).
Plans for ca-basic-test are left as-is.

Usage:
  python3 tests/tmt/bin/generate-ipacta-tmt-from-dogtag.py [--force]
"""
from __future__ import annotations

import argparse
import os
import re
import stat
import sys


OMIT_NAME_RE = re.compile(
    r"(?i)("
    r"clone repository"
    r"|retrieve .* images"
    r"|set up .* ds container"
    r"|set up ds container"
    r"|check ds container logs"
    r"|create softhsm"
    r"|remove softhsm"
    r"|create pqc softhsm"
    r"|softhsm token"
    r"|install dependencies"
    r"|nuxwdog"
    r"|set up (primary|secondary|clone) ds"
    r"|set up .* hsm"
    r"|create .*hsm"
    r"|postgresql"
    r")"
)

LOAD_IMAGES_RE = re.compile(r"(?i)load .* images")
PKI_CONTAINER_RE = re.compile(
    r"(?i)set up (pki|primary pki|secondary pki|clone pki).*container"
    r"|set up pki container"
    r"|create pki server"
)
INSTALL_CA_RE = re.compile(r"(?i)^install ca( in .*)?$|install ca in primary")
INSTALL_KRA_RE = re.compile(r"(?i)^install kra|install kra in")
INSTALL_ACME_RE = re.compile(r"(?i)install acme")
REMOVE_CA_RE = re.compile(r"(?i)^remove ca|pkidestroy|uninstall")
NETWORK_RE = re.compile(r"(?i)^create network$")
FEDORA_RE = re.compile(r"(?i)^get fedora version$")
TOMCAT_RE = re.compile(r"(?i)get tomcat flavor")
CLIENT_RE = re.compile(r"(?i)set up client container")
REPLICA_RE = re.compile(
    r"(?i)secondary|replica|clone pki|clone ca|clone kra|clone acme"
)

DOCKER_EXEC_PKI = re.compile(
    r"docker\s+exec\s+((?:-[a-zA-Z]+(?:\s+\S+)?\s+)*)(pki|ds|primary|secondary)\b"
)
RUNNER_INIT = re.compile(r".*runner-init\.sh.*", re.M)
DS_CREATE = re.compile(r".*ds-create\.sh.*", re.M)


def repo_root():
    d = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(d, "..", "..", ".."))


def parse_steps(text: str) -> list[tuple[str, str]]:
    """Return [(name, body_including_gha_wrapper), ...]."""
    parts = re.split(r'^step "', text, flags=re.M)
    steps = []
    for part in parts[1:]:
        name, _, rest = part.partition('"')
        steps.append((name, rest))
    return steps


def rewrite_body(body: str) -> str:
    body = DOCKER_EXEC_PKI.sub(r'docker exec \1"$CONTAINER"', body)
    body = re.sub(
        r"docker\s+exec\s+((?:-[a-zA-Z]+(?:\s+\S+)?\s+)*)\"\$CONTAINER\"",
        r'docker exec \1"$CONTAINER"',
        body,
    )
    body = RUNNER_INIT.sub(
        'echo "runner-init skipped; IPA container already running"', body
    )
    body = DS_CREATE.sub('echo "ds-create skipped; IPA DS is in-container"', body)
    # Process substitutions inside ( ) subshells break bash -n (inherited from
    # some Dogtag generated tests). Split stdout/stderr to files instead.
    body = body.replace("> >(tee stdout) 2> >(tee stderr >&2)", "> stdout 2> stderr")
    body = body.replace("> >(tee stdout)", "> stdout")
    body = body.replace("2> >(tee stderr >&2)", "2> stderr")
    # Dogtag generated tests indent heredoc closers (`    EOF`) which never
    # terminate << EOF; unindent so bash parses.
    body = re.sub(r"^[ \t]+EOF[ \t]*$", "EOF", body, flags=re.M)
    body = body.replace("pki-runner", "freeipa-ipacta")
    body = body.replace("${PKI_IMAGE:-pki-runner}", "${IPA_IMAGE:-freeipa-ipacta:latest}")
    body = body.replace("PKI_IMAGE", "IPA_IMAGE")
    # Drop pki tests/bin paths that do not exist in freeipa
    body = re.sub(
        r"^.*tests/bin/.*$",
        'echo "OMITTED: Dogtag tests/bin helper (not in FreeIPA tree)"',
        body,
        flags=re.M,
    )
    return body


def classify(name: str, stem: str) -> str:
    n = name.strip()
    if OMIT_NAME_RE.search(n):
        return "omit"
    if LOAD_IMAGES_RE.search(n):
        return "load"
    if NETWORK_RE.search(n):
        return "network"
    if PKI_CONTAINER_RE.search(n):
        return "pki-container"
    if INSTALL_CA_RE.search(n):
        return "install-ca"
    if INSTALL_KRA_RE.search(n):
        return "install-kra"
    if INSTALL_ACME_RE.search(n):
        return "install-acme"
    if REMOVE_CA_RE.search(n) and "softhsm" not in n.lower():
        return "remove-ca"
    if FEDORA_RE.search(n):
        return "fedora"
    if TOMCAT_RE.search(n):
        return "tomcat"
    if CLIENT_RE.search(n):
        return "client"
    if any(
        x in stem
        for x in (
            "clone",
            "hsm",
            "softhsm",
            "kryoptic",
            "container",
            "nuxwdog",
            "postgresql",
            "separate",
            "migration",
        )
    ) and REPLICA_RE.search(n):
        return "omit-gap"
    return "keep"


def emit_guarded(name: str, inner_lines: list[str]) -> list[str]:
    lines = [f'step "{name}"']
    lines.append('if [[ "$GHA_FAILED" -eq 0 ]]; then')
    lines.append("set +e")
    lines.append("(")
    lines.append("set -euo pipefail")
    lines.extend(inner_lines)
    lines.append(")")
    lines.append("_rc=$?")
    lines.append("set -euo pipefail")
    lines.append("if [[ $_rc -ne 0 ]]; then")
    lines.append(f'    echo "FAIL: {name} (rc=$_rc)" >&2')
    lines.append("    GHA_FAILED=$_rc")
    lines.append("fi")
    lines.append("fi")
    lines.append("")
    return lines


def extract_inner(wrapper: str) -> str:
    """Best-effort inner body from Dogtag GHA_FAILED wrapper."""
    m = re.search(
        r"set -euo pipefail\n(.*?)\)\n_rc=\$\?",
        wrapper,
        flags=re.S,
    )
    if m:
        return m.group(1).rstrip() + "\n"
    return wrapper.strip() + "\n"


def generate_test_sh(stem: str, dogtag_sh: str) -> str:
    steps = parse_steps(dogtag_sh)
    lines = [
        "#!/bin/bash",
        f"# Generated IPACTA TMT port of Dogtag tests/tmt/{stem}",
        "# (GHA .github/workflows/" + stem + ".yml). Packaged forge IPACTA.",
        "# Dogtag-only layout (DS sidecar, HSM, extra PKI containers) is OMITTED.",
        "# Remaining pki CLI / REST steps run against the IPA container and FAIL",
        "# if IPACTA does not cover them.",
        "set -euo pipefail",
        "",
        'REPO_ROOT="${TMT_TREE:-}"',
        'if [[ -z "$REPO_ROOT" || ! -f "$REPO_ROOT/tests/tmt/bin/ipacta-tmt-common.sh" ]]; then',
        '    REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)',
        "fi",
        'source "$REPO_ROOT/tests/tmt/bin/ipacta-tmt-common.sh"',
        'export GITHUB_WORKSPACE="$REPO_ROOT"',
        'export SHARED="${SHARED:-/tmp/workdir/pki}"',
        'export GITHUB_ENV="${TMPDIR:-/tmp}/gha-env-$$"',
        'touch "$GITHUB_ENV"',
        "source_gha_env() { set -a; source \"$GITHUB_ENV\" 2>/dev/null || true; set +a; }",
        'mkdir -p "$GITHUB_WORKSPACE"',
        "export LC_ALL=C",
        "trap ipacta_cleanup EXIT",
        "GHA_FAILED=0",
        "ipacta_start_container",
        "",
    ]

    ca_done = False
    for name, wrapper in steps:
        kind = classify(name, stem)
        if kind == "omit":
            lines.extend(
                emit_guarded(
                    name,
                    [f'omit "{name}"'],
                )
            )
        elif kind == "omit-gap":
            lines.extend(
                emit_guarded(
                    name,
                    [
                        f'omit "parity gap for {stem}: {name}"',
                    ],
                )
            )
        elif kind == "load":
            lines.extend(
                emit_guarded(
                    name,
                    [
                        'docker image inspect "$IPA_IMAGE" >/dev/null',
                    ],
                )
            )
        elif kind == "network":
            lines.extend(
                emit_guarded(name, ['echo "network example already created"'])
            )
        elif kind == "pki-container":
            lines.extend(
                emit_guarded(
                    name,
                    ['echo "IPA container already running as $CONTAINER"'],
                )
            )
        elif kind == "fedora":
            lines.extend(
                emit_guarded(
                    name,
                    [
                        'FEDORA_VERSION=$(iexec sed -n \'s/^VERSION_ID=//p\' /etc/os-release | tr -d \'"\')',
                        'echo "FEDORA_VERSION=$FEDORA_VERSION"',
                    ],
                )
            )
        elif kind == "tomcat":
            lines.extend(
                emit_guarded(
                    name,
                    [
                        'iexec systemctl cat "$IPACTA_UNIT" | head -20 || true',
                    ],
                )
            )
        elif kind == "install-ca":
            if ca_done:
                lines.extend(
                    emit_guarded(
                        name,
                        [
                            'omit "second CA instance / clone install not mapped (use ipa-replica-install)"',
                        ],
                    )
                )
            else:
                lines.extend(emit_guarded(name, ["ipacta_install_ca"]))
                ca_done = True
        elif kind == "install-kra":
            lines.extend(emit_guarded(name, ["ipacta_install_kra"]))
        elif kind == "install-acme":
            lines.extend(emit_guarded(name, ["ipacta_install_acme"]))
        elif kind == "remove-ca":
            lines.extend(emit_guarded(name, ["ipacta_uninstall"]))
        elif kind == "client":
            lines.extend(
                emit_guarded(
                    name,
                    [
                        'omit "extra client container; run ACME client in IPA container if needed"',
                    ],
                )
            )
        else:
            rewritten = rewrite_body(wrapper.lstrip("\n"))
            lines.append(f'step "{name}"')
            lines.append(rewritten.rstrip())
            lines.append("")

    lines.extend(
        [
            'if [[ "$GHA_FAILED" -ne 0 ]]; then',
            f'    echo "==== IPACTA {stem} FAILED (GHA_FAILED=$GHA_FAILED) ====" >&2',
            "    exit \"$GHA_FAILED\"",
            "fi",
            f'echo "==== IPACTA {stem} PASSED ===="',
            "",
        ]
    )
    return "\n".join(lines) + "\n"


PLAN_FMF = """\
summary: {summary} — IPACTA
description: |
  IPACTA/FreeIPA TMT port of Dogtag tests/tmt/{stem}
  (GHA {stem}.yml). Guest prepare builds freeipa-ipacta from
  Fedora 46 packages. See tests/tmt/{stem}/README.md
discover:
    how: fmf
    test:
        - /tests/tmt/{stem}
provision:
    how: local
prepare:
    - name: require-docker
      how: shell
      script:
        - |
          set -euo pipefail
          if ! command -v docker >/dev/null 2>&1; then
            echo "==== Installing Docker (moby-engine) ===="
            dnf install -y moby-engine containerd
          fi
          systemctl enable docker 2>/dev/null || true
          systemctl start docker 2>/dev/null || true
          docker info >/dev/null
          echo "==== Docker ready ===="
    - name: build-ipa-runner
      how: shell
      script:
        - |
          "${{TMT_TREE}}/tests/tmt/bin/build-ipa-runner.sh" "${{TMT_TREE}}"
execute:
    how: tmt
finish:
    how: shell
    script:
      - |
        docker rm -f ipa client 2>/dev/null || true
        docker network rm example 2>/dev/null || true
tag:
    - {family}
    - ipacta
    - idm-8254
link:
    - verifies: https://redhat.atlassian.net/browse/IDM-8254
    - relates: https://github.com/dogtagpki/pki/blob/master/.github/workflows/{stem}.yml
"""

MAIN_FMF = """\
summary: {summary} (IPACTA / {stem})
description: |
  IPACTA port of Dogtag TMT {stem} / GHA {stem}.yml.
  Single IPA container + packaged forge IPACTA.
test: ./test.sh
framework: shell
require: []
duration: {duration}
tag:
    - {family}
    - ipacta
    - idm-8254
link:
    - verifies: https://redhat.atlassian.net/browse/IDM-8254
    - relates: https://github.com/dogtagpki/pki/blob/master/.github/workflows/{stem}.yml
"""

README = """\
# {stem} (TMT / IPACTA)

Generated from Dogtag `tests/tmt/{stem}` (GHA `{stem}.yml`) for IDM-8254.

- Image: `freeipa-ipacta` via `tests/tmt/bin/build-ipa-runner.sh`
- Install: `ipa-server-install` (+ `ipa-kra-install` / `ipa-acme-manage enable` when the Dogtag test spawned KRA/ACME)
- Dogtag-only topology (DS sidecar, extra PKI hosts, HSM tokens) is **OMITTED**
- Remaining `pki` CLI / REST checks run in the IPA container and **FAIL** if IPACTA cannot do them

```bash
tmt --feeling-safe run -e SKIP_IPA_BUILD=1 plans --name /tests/tmt/plans/{stem}
```
"""


def family_of(stem: str) -> str:
    if stem.startswith("kra-"):
        return "kra"
    if stem.startswith("acme-"):
        return "acme"
    return "ca"


def duration_of(stem: str) -> str:
    if any(x in stem for x in ("clone", "ssnv", "container", "migration")):
        return "180m"
    return "90m"


def summary_of(stem: str, dogtag_main: str | None) -> str:
    return (stem + " (IPACTA)")[:50]


def chmod_x(path: str) -> None:
    mode = os.stat(path).st_mode
    os.chmod(path, mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--dogtag-root",
        default=os.environ.get("DOGTAG_ROOT", "/home/agaragna/Projects/pki"),
    )
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    ipa_root = repo_root()
    dog_tmt = os.path.join(args.dogtag_root, "tests", "tmt")
    if not os.path.isdir(dog_tmt):
        print(f"ERROR: no Dogtag TMT at {dog_tmt}", file=sys.stderr)
        return 1

    stems = sorted(
        d
        for d in os.listdir(dog_tmt)
        if os.path.isdir(os.path.join(dog_tmt, d))
        and re.match(r"^(ca|kra|acme)-.+-test$", d)
        and os.path.isfile(os.path.join(dog_tmt, d, "test.sh"))
    )

    written = 0
    skipped = 0
    for stem in stems:
        src_sh = os.path.join(dog_tmt, stem, "test.sh")
        src_main = os.path.join(dog_tmt, stem, "main.fmf")
        dst_dir = os.path.join(ipa_root, "tests", "tmt", stem)
        dst_sh = os.path.join(dst_dir, "test.sh")
        dst_plan = os.path.join(ipa_root, "tests", "tmt", "plans", f"{stem}.fmf")
        os.makedirs(dst_dir, exist_ok=True)
        os.makedirs(os.path.join(ipa_root, "tests", "tmt", "plans"), exist_ok=True)

        dog_main = ""
        if os.path.isfile(src_main):
            with open(src_main, encoding="utf-8") as f:
                dog_main = f.read()
        summary = summary_of(stem, dog_main)
        fam = family_of(stem)
        dur = duration_of(stem)

        if stem == "ca-basic-test" and not args.force:
            skipped += 1
            print(f"keep hand-port  {stem}")
            continue

        with open(dst_plan, "w", encoding="utf-8") as f:
            f.write(
                PLAN_FMF.format(
                    summary=stem,
                    stem=stem,
                    family=fam,
                )
            )
        with open(os.path.join(dst_dir, "main.fmf"), "w", encoding="utf-8") as f:
            f.write(
                MAIN_FMF.format(
                    summary=summary,
                    stem=stem,
                    duration=dur,
                    family=fam,
                )
            )
        with open(os.path.join(dst_dir, "README.md"), "w", encoding="utf-8") as f:
            f.write(README.format(stem=stem))

        with open(src_sh, encoding="utf-8") as f:
            dog_sh = f.read()
        with open(dst_sh, "w", encoding="utf-8") as f:
            f.write(generate_test_sh(stem, dog_sh))
        chmod_x(dst_sh)
        written += 1
        print(f"wrote {stem}")

    print(f"done: wrote {written} test.sh, kept {skipped} hand-ports, {len(stems)} stems")
    return 0


if __name__ == "__main__":
    sys.exit(main())
