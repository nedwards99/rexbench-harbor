#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

TASKS_ZIP="${REPO_ROOT}/tasks.zip"
PATCHES_ZIP="${REPO_ROOT}/patches.zip"
TASKS_DIR="${REPO_ROOT}/tasks"
PATCHES_DIR="${REPO_ROOT}/patches"
VENV_DIR="${REPO_ROOT}/.venv"
REQUIREMENTS_FILE="${REPO_ROOT}/requirements-eval.txt"

if [ ! -f "$TASKS_ZIP" ]; then
  echo "Error: missing tasks zip: $TASKS_ZIP"
  exit 1
fi

if [ ! -f "$PATCHES_ZIP" ]; then
  echo "Error: missing patches zip: $PATCHES_ZIP"
  exit 1
fi

if [ ! -f "$REQUIREMENTS_FILE" ]; then
  echo "Error: missing requirements file: $REQUIREMENTS_FILE"
  exit 1
fi

if [ ! -d "$TASKS_DIR" ]; then
  echo "Extracting $TASKS_ZIP..."
  unzip -q "$TASKS_ZIP" -d "$REPO_ROOT"
else
  echo "Tasks directory already exists at $TASKS_DIR; skipping unzip."
fi

if [ ! -d "$PATCHES_DIR" ]; then
  echo "Extracting $PATCHES_ZIP..."
  unzip -q "$PATCHES_ZIP" -d "$REPO_ROOT"
else
  echo "Patches directory already exists at $PATCHES_DIR; skipping unzip."
fi

if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment at $VENV_DIR..."
  python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "Installing Python dependencies from $REQUIREMENTS_FILE..."
pip install -r "$REQUIREMENTS_FILE"

echo "Setup complete."
