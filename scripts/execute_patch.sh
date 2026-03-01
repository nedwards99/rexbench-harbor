#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

AGENT_NAME=${1:?Usage: bash scripts/execute_patch.sh <agent_name> <task_name> <run_number> [patch_root]}
TASK_NAME=${2:?Usage: bash scripts/execute_patch.sh <agent_name> <task_name> <run_number> [patch_root]}
RUN_NUMBER=${3:?Usage: bash scripts/execute_patch.sh <agent_name> <task_name> <run_number> [patch_root]}
PATCH_ROOT=${4:-"${REPO_ROOT}/patches"}
LEVEL="default"

case "$TASK_NAME" in
  cogs)
    TASK_IMAGE="cogs_image:latest"
    ;;
  othello)
    TASK_IMAGE="othello_image:latest"
    ;;
  *)
    echo "Error: unsupported task '$TASK_NAME'. Expected one of: cogs, othello"
    exit 1
    ;;
esac

PATCH_PATH="${PATCH_ROOT}/${AGENT_NAME}/${TASK_NAME}/${LEVEL}/${AGENT_NAME}_${LEVEL}_run${RUN_NUMBER}.patch"
SOURCE_REPO="${REPO_ROOT}/tasks/${TASK_NAME}"
TESTS_DIR="${REPO_ROOT}/eval_scripts/${TASK_NAME}"
RUN_DIR="${REPO_ROOT}/evaluation/${AGENT_NAME}/${TASK_NAME}/${LEVEL}/run${RUN_NUMBER}"
LOG_PATH="${RUN_DIR}/${TASK_NAME}-${AGENT_NAME}-${LEVEL}-docker.log"
WORK_ROOT="${REPO_ROOT}/run_logs"

if [ ! -f "$PATCH_PATH" ]; then
  echo "Error: patch not found: $PATCH_PATH"
  exit 1
fi

if [ ! -d "$SOURCE_REPO" ]; then
  echo "Error: source task repo not found: $SOURCE_REPO"
  exit 1
fi

if [ ! -d "$TESTS_DIR" ]; then
  echo "Error: eval script directory not found: $TESTS_DIR"
  exit 1
fi

if [ -e "$RUN_DIR" ]; then
  echo "Error: run directory already exists: $RUN_DIR"
  echo "Remove it first if you want to rerun this patch."
  exit 1
fi

mkdir -p "$RUN_DIR"
mkdir -p "$WORK_ROOT"
WORK_DIR=$(mktemp -d "${WORK_ROOT}/${TASK_NAME}_${AGENT_NAME}_${RUN_NUMBER}_XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT

cp -R "${SOURCE_REPO}/." "$WORK_DIR"/

echo "Task image: $TASK_IMAGE"
echo "Patch: $PATCH_PATH"
echo "Run directory: $RUN_DIR"
echo "Working directory: $WORK_DIR"

timeout 12h docker run --rm \
  --gpus all \
  -v "$WORK_DIR:/stage" \
  -v "$TESTS_DIR:/tests:ro" \
  -v "$PATCH_PATH:/patches/agent.patch:ro" \
  "$TASK_IMAGE" \
  bash -lc '
    set -euo pipefail

    PATCH_PATH="/patches/agent.patch"

    if [ ! -f "$PATCH_PATH" ]; then
      echo "Error: patch not found in container: $PATCH_PATH"
      exit 1
    fi

    cd /stage

    if command -v git >/dev/null 2>&1 && git apply --verbose "$PATCH_PATH"; then
      :
    elif command -v patch >/dev/null 2>&1; then
      patch -p1 < "$PATCH_PATH"
    else
      echo "Error: failed to apply patch and no fallback patch command is installed"
      exit 1
    fi

    bash /tests/run_docker.sh /stage
  ' | tee "$LOG_PATH"

case "$TASK_NAME" in
  cogs)
    RESULT_FILE="${WORK_DIR}/eval_results.txt"
    if [ ! -f "$RESULT_FILE" ]; then
      echo "Error: expected cogs result file not found: $RESULT_FILE"
      exit 1
    fi
    cp "$RESULT_FILE" "$RUN_DIR"/
    ;;
  othello)
    RESULT_DIR="${WORK_DIR}/ckpts/battery_othello"
    if [ ! -d "$RESULT_DIR" ]; then
      echo "Error: expected othello result directory not found: $RESULT_DIR"
      exit 1
    fi
    mkdir -p "$RUN_DIR/ckpts"
    cp -R "$RESULT_DIR" "$RUN_DIR/ckpts/"
    ;;
esac

echo "Completed patch eval. Results are in $RUN_DIR"
