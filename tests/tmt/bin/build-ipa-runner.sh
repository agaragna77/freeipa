#!/bin/bash
# Build freeipa-ipacta the same way Azure IPA tests do: makerpms →
# ipatests/azure/Dockerfiles/Dockerfile.build.fedora → tagged runner.
#
# A clean Testing Farm guest only needs Docker (and network). Set
# SKIP_IPA_BUILD=1 to reuse an existing image locally.
set -euo pipefail

REPO_ROOT="${1:-${TMT_TREE:-}}"
if [[ -z "$REPO_ROOT" || ! -f "$REPO_ROOT/freeipa.spec.in" ]]; then
    REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
fi
cd "$REPO_ROOT"

IPA_IMAGE="${IPA_IMAGE:-freeipa-ipacta:latest}"
BASE_IMAGE="${BASE_IMAGE:-registry.fedoraproject.org/fedora-toolbox:44}"
DOCKERFILE="${IPA_DOCKERFILE:-${REPO_ROOT}/ipatests/azure/Dockerfiles/Dockerfile.build.fedora}"
COPR_REPO="${COPR_REPO:-@freeipa/freeipa-master}"

if [[ "${SKIP_IPA_BUILD:-0}" == "1" ]]; then
    echo "SKIP_IPA_BUILD=1 — not building (image must already exist)"
    docker image inspect "$IPA_IMAGE" >/dev/null
    exit 0
fi

command -v docker >/dev/null \
    || { echo "ERROR: docker required to build ${IPA_IMAGE}" >&2; exit 1; }
[[ -f "$DOCKERFILE" ]] \
    || { echo "ERROR: missing Dockerfile ${DOCKERFILE}" >&2; exit 1; }

echo "==== Building IPA image (Azure Dockerfile.build.fedora equivalent) ===="
echo "IPA_IMAGE=${IPA_IMAGE}"
echo "BASE_IMAGE=${BASE_IMAGE}"
echo "COPR_REPO=${COPR_REPO:-<none>}"
echo "DOCKERFILE=${DOCKERFILE}"
echo "workdir=${REPO_ROOT}"

if [[ "${SKIP_IPA_RPMS:-0}" != "1" ]] && [[ ! -d "$REPO_ROOT/.git" ]]; then
    if compgen -G "$REPO_ROOT/dist/rpms/*.rpm" >/dev/null; then
        echo "TMT_TREE has no .git — skipping makerpms, using existing dist/rpms"
        SKIP_IPA_RPMS=1
    else
        echo "ERROR: TMT_TREE is not a git checkout and dist/rpms is empty." >&2
        echo "makerpms.sh needs git submodules. Re-run from a git tree, or set SKIP_IPA_BUILD=1." >&2
        exit 1
    fi
fi

if [[ "${SKIP_IPA_RPMS:-0}" == "1" ]]; then
    echo "SKIP_IPA_RPMS=1 — using existing dist/rpms"
else
    echo "==== Building FreeIPA RPMs (makerpms.sh) ===="
    docker pull "$BASE_IMAGE"
    docker run --rm \
        --network host \
        --security-opt label=disable \
        -v "$REPO_ROOT:/freeipa" \
        -w /freeipa \
        -e HOST_UID="$(id -u)" \
        -e HOST_GID="$(id -g)" \
        -e COPR_REPO="$COPR_REPO" \
        "$BASE_IMAGE" \
        bash -ce '
            set -euo pipefail
            git config --global --add safe.directory /freeipa
            dnf install -y dnf-plugins-core rpm-build make autoconf automake \
                libtool gettext-devel git gdb-minimal
            if [[ -n "${COPR_REPO}" ]]; then
                dnf copr enable -y "${COPR_REPO}" || true
            fi
            dnf builddep -y -D "with_wheels 1" -D "with_lint 1" -D "with_doc 1" \
                --spec freeipa.spec.in --best --allowerasing \
                --setopt=install_weak_deps=False
            ./makerpms.sh
            chown -R "${HOST_UID}:${HOST_GID}" /freeipa/dist
        '
fi

shopt -s nullglob
rpms=(dist/rpms/*.rpm)
if [[ ${#rpms[@]} -eq 0 ]]; then
    echo "ERROR: no RPMs in ${REPO_ROOT}/dist/rpms (makerpms failed or SKIP_IPA_RPMS=1 with empty dist)" >&2
    exit 1
fi
echo "RPMs: ${#rpms[@]} under dist/rpms"

echo "==== docker build ${IPA_IMAGE} ===="
docker pull "$BASE_IMAGE"
CTX=$(mktemp -d)
trap 'rm -rf "$CTX"' EXIT
cp "$DOCKERFILE" "$CTX/Dockerfile"
cp -a "$REPO_ROOT/dist" "$CTX/dist"
docker build --network host -t "$IPA_IMAGE" -t "${IPA_IMAGE%%:*}:latest" "$CTX"

echo "==== Installing freeipa-healthcheck into image ===="
bake="ipa-hc-bake-$$"
docker rm -f "$bake" >/dev/null 2>&1 || true
docker run -d --name "$bake" --entrypoint sleep "$IPA_IMAGE" 7200
docker exec "$bake" dnf install -y freeipa-healthcheck
docker commit "$bake" "$IPA_IMAGE"
docker rm -f "$bake" >/dev/null 2>&1 || true

docker image inspect "$IPA_IMAGE" >/dev/null
echo "==== ${IPA_IMAGE} ready ===="
docker images "$IPA_IMAGE"
