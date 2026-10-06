#!/bin/bash
# Submit IDM-8254 IPACTA ca-basic-test to Testing Farm.
#
# Default: guest prepare builds freeipa-ipacta from Fedora 46 packages
# (no Quay). Optional --quay path keeps build→push→pull for faster
# re-runs or offline guests.
#
# Defaults (override via env or flags):
#   compose=Fedora-Rawhide  parallel-limit=1  timeout=180
#
# Auth (Quay path only): QUAY_USER + QUAY_PASSWORD from
# ~/.config/quay-pki-tmt.env, else existing docker login.
# TF: TESTING_FARM_API_TOKEN must be set. Public Quay → no TF pull secrets.
#
# Usage:
#   tests/tmt/bin/tf-quay-pilot.sh
#   tests/tmt/bin/tf-quay-pilot.sh --wait
#   tests/tmt/bin/tf-quay-pilot.sh --quay --skip-build-if-present
#   tests/tmt/bin/tf-quay-pilot.sh --git-ref my-branch
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../../.." && pwd)
cd "$REPO_ROOT"

# Optional local Quay robot env (not in git): ~/.config/quay-pki-tmt.env
# Preserve caller QUAY_IMAGE — the robot file may set QUAY_IMAGE=pki-runner.
_CALLER_QUAY_IMAGE="${QUAY_IMAGE:-}"
if [[ -f "${HOME}/.config/quay-pki-tmt.env" ]]; then
    # shellcheck source=/dev/null
    . "${HOME}/.config/quay-pki-tmt.env"
fi

QUAY_IMAGE="${_CALLER_QUAY_IMAGE:-quay.io/agaragna77/freeipa-ipacta}"
# Public ranch has no Fedora-46 yet; Rawhide tracks F46. Guest only needs Docker.
COMPOSE="${TF_COMPOSE:-Fedora-Rawhide}"
PARALLEL_LIMIT="${TF_PARALLEL_LIMIT:-1}"
TIMEOUT_MIN="${TF_TIMEOUT:-180}"
GIT_URL="${TF_GIT_URL:-}"
GIT_REF=""
USE_QUAY=0
SKIP_BUILD_IF_PRESENT=0
DO_WAIT=0
DO_PUSH=1
DO_BUILD=1

usage() {
    cat <<'EOF'
Usage: tf-quay-pilot.sh [options]

  (default)                TF guest builds freeipa-ipacta from F46 packages
  --quay                   Build/push Quay image; TF pulls via SKIP_IPA_BUILD
  --skip-build-if-present  With --quay: skip build+push if Quay tag exists
  --skip-build             Alias for --skip-build-if-present
  --no-push                With --quay: build locally but do not push
  --no-build               With --quay: do not run build-ipa-runner.sh
  --wait                   Wait for Testing Farm request completion
  --git-ref REF            Git ref/branch for TF (default: current branch)
  --git-url URL            Git URL for TF (default: origin → https)
  --compose NAME           TF compose (default: Fedora-Rawhide)
  --parallel-limit N       Max parallel plans (default: 1)
  --timeout MIN            TF timeout minutes (default: 180)
  --quay-image IMAGE       Quay repository (default: $QUAY_IMAGE or
                           quay.io/agaragna77/freeipa-ipacta)
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --quay)
            USE_QUAY=1
            shift
            ;;
        --skip-build-if-present|--skip-build)
            SKIP_BUILD_IF_PRESENT=1
            shift
            ;;
        --no-push)
            DO_PUSH=0
            shift
            ;;
        --no-build)
            DO_BUILD=0
            shift
            ;;
        --wait)
            DO_WAIT=1
            shift
            ;;
        --git-ref)
            GIT_REF="$2"
            shift 2
            ;;
        --git-url)
            GIT_URL="$2"
            shift 2
            ;;
        --compose)
            COMPOSE="$2"
            shift 2
            ;;
        --parallel-limit)
            PARALLEL_LIMIT="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_MIN="$2"
            shift 2
            ;;
        --quay-image)
            QUAY_IMAGE="$2"
            USE_QUAY=1
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

command -v testing-farm >/dev/null \
    || { echo "ERROR: testing-farm CLI required (pipx install tft-cli)" >&2; exit 1; }
[[ -n "${TESTING_FARM_API_TOKEN:-}" ]] \
    || { echo "ERROR: TESTING_FARM_API_TOKEN is not set" >&2; exit 1; }

BRANCH_RAW=$(git rev-parse --abbrev-ref HEAD)
SHORT_SHA=$(git rev-parse --short HEAD)
BRANCH_TAG=$(printf '%s' "$BRANCH_RAW" | tr '/' '-')
TAG="${BRANCH_TAG}-${SHORT_SHA}"
FULL_IMAGE="${QUAY_IMAGE}:${TAG}"

if [[ -z "$GIT_REF" ]]; then
    GIT_REF="$BRANCH_RAW"
fi

if [[ -z "$GIT_URL" ]]; then
    ORIGIN=$(git remote get-url origin 2>/dev/null || true)
    if [[ -z "$ORIGIN" ]]; then
        echo "ERROR: cannot detect origin; pass --git-url" >&2
        exit 1
    fi
    GIT_URL=$(printf '%s' "$ORIGIN" \
        | sed -E 's#^git@([^:]+):#https://\1/#; s#\.git$##')
fi

PLAN_REGEX='^/tests/tmt/plans/ca-basic-test$'

echo "==== TF IPACTA pilot ===="
echo "MODE=$([ "$USE_QUAY" -eq 1 ] && echo quay || echo guest-f46-packages)"
echo "GIT_URL=${GIT_URL}"
echo "GIT_REF=${GIT_REF}"
echo "COMPOSE=${COMPOSE}"
echo "PARALLEL_LIMIT=${PARALLEL_LIMIT}"
echo "TIMEOUT_MIN=${TIMEOUT_MIN}"
if [[ "$USE_QUAY" -eq 1 ]]; then
    echo "QUAY_IMAGE=${QUAY_IMAGE}"
    echo "TAG=${TAG}"
    echo "FULL_IMAGE=${FULL_IMAGE}"
fi

quay_tag_exists() {
    local url="https://quay.io/v2/${QUAY_IMAGE#quay.io/}/manifests/${TAG}"
    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -H 'Accept: application/vnd.docker.distribution.v2+json' \
        "$url" || true)
    [[ "$code" == "200" ]]
}

ensure_quay_login() {
    if [[ -n "${QUAY_USER:-}" && -n "${QUAY_PASSWORD:-}" ]]; then
        echo "==== docker login quay.io (QUAY_USER) ===="
        printf '%s' "$QUAY_PASSWORD" \
            | docker login quay.io -u "$QUAY_USER" --password-stdin
        return 0
    fi
    if docker system info 2>/dev/null | grep -q 'quay.io'; then
        echo "==== using existing docker credentials for quay.io ===="
        return 0
    fi
    echo "NOTE: QUAY_USER/QUAY_PASSWORD unset; relying on existing docker login"
}

if [[ "$USE_QUAY" -eq 1 ]]; then
    command -v docker >/dev/null \
        || { echo "ERROR: docker required for --quay" >&2; exit 1; }

    if [[ "$SKIP_BUILD_IF_PRESENT" -eq 1 ]] && quay_tag_exists; then
        echo "==== Quay tag already present; skipping build+push ===="
        DO_BUILD=0
        DO_PUSH=0
    fi

    if [[ "$DO_BUILD" -eq 1 ]]; then
        echo "==== Building freeipa-ipacta locally (F46 packages) ===="
        unset SKIP_IPA_BUILD
        # Keep IPA_IMAGE for tagging if set; default freeipa-ipacta:latest.
        "${SCRIPT_DIR}/build-ipa-runner.sh" "$REPO_ROOT"
    fi

    if [[ "$DO_PUSH" -eq 1 ]]; then
        docker image inspect freeipa-ipacta >/dev/null \
            || { echo "ERROR: local freeipa-ipacta missing; build first" >&2; exit 1; }
        ensure_quay_login
        echo "==== Pushing ${FULL_IMAGE} ===="
        docker tag freeipa-ipacta:latest "$FULL_IMAGE"
        if ! docker push "$FULL_IMAGE"; then
            echo "ERROR: docker push failed; aborting (no TF request)" >&2
            exit 1
        fi
    fi

    echo "==== Verifying Quay tag is pullable ===="
    if ! quay_tag_exists; then
        echo "ERROR: ${FULL_IMAGE} not found on Quay after push; aborting" >&2
        exit 1
    fi
fi

TF_ARGS=(
    request
    --git-url "$GIT_URL"
    --git-ref "$GIT_REF"
    --compose "$COMPOSE"
    --plan "$PLAN_REGEX"
    --parallel-limit "$PARALLEL_LIMIT"
    --timeout "$TIMEOUT_MIN"
)

if [[ "$USE_QUAY" -eq 1 ]]; then
    TF_ARGS+=(-e "SKIP_IPA_BUILD=1 IPA_IMAGE=${FULL_IMAGE}")
fi

if [[ "$DO_WAIT" -eq 0 ]]; then
    TF_ARGS+=(--no-wait)
fi

echo "==== Submitting Testing Farm request ===="
echo "testing-farm ${TF_ARGS[*]}"
testing-farm "${TF_ARGS[@]}"
if [[ "$USE_QUAY" -eq 1 ]]; then
    echo "==== Submitted (image ${FULL_IMAGE}) ===="
else
    echo "==== Submitted (guest prepare builds F46 packaged IPACTA) ===="
fi
