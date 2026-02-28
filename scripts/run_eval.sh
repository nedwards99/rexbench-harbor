#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

AGENT_NAME=${1:-"openhands_claude_4.5_sonnet"}
RESULT_DIR=${2:-"results"}
echo "Agent: ${AGENT_NAME}"
echo "Result folder: ${RESULT_DIR}"

# Activate a repo-local Python environment when available.
ENV_PATH=${EVAL_ENV_PATH:-"${REPO_ROOT}/.venv"}
if [ -d "${ENV_PATH}" ]; then
  # shellcheck disable=SC1091
  source "${ENV_PATH}/bin/activate"
else
  echo "No local env found at ${ENV_PATH}; using current python environment."
fi

SCRIPT_PATH="${SCRIPT_DIR}/calculate_success_rates.py"

python3 "${SCRIPT_PATH}" "${AGENT_NAME}" "${RESULT_DIR}"
