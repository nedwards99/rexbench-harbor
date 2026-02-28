#!/bin/bash

REPO_NAME=$1
TASK_NAME=$2
RUN=$3

CURR_DIR=$(pwd)

export LLM_MODEL="anthropic/claude-sonnet-4-5"

export LLM_API_KEY="$ANTHROPIC_KEY"

# Add costs per token based on LLM used
export LLM_INPUT_TOKEN_COST="0.000003"
export LLM_OUTPUT_TOKEN_COST="0.000015"
export AGENT_NAME="openhands_claude_4.5_sonnet"

OPENHANDS_PATH=/home/ubuntu/OpenHands
REPOS_ROOT=/home/ubuntu/rexbench-repos
PATCHES_ROOT=/home/ubuntu/patches/${AGENT_NAME}

if [ ! -d "$OPENHANDS_PATH" ]; then
  echo "Error: OPENHANDS_PATH does not exist: $OPENHANDS_PATH"
  exit 1
fi

mkdir -p "$REPOS_ROOT"

echo "Creating PATCHES DIR $PATCHES_ROOT..."
mkdir -p $PATCHES_ROOT

export REPO_PATH=${REPOS_ROOT}/${REPO_NAME}

mkdir -p ${PATCHES_ROOT}/${TASK_NAME}

export WORKSPACE_BASE=$REPO_PATH

# Install command for OpenHands
export INSTALL_COMMAND="if [ ! -x /opt/openhands-venv/bin/python ]; then
      apt-get update && apt-get install -y curl git build-essential tmux
      curl -LsSf https://astral.sh/uv/install.sh | sh
      export PATH=\"\$HOME/.local/bin:\$PATH\"
      uv python install 3.13
      uv venv /opt/openhands-venv --python 3.13
      uv pip install --python /opt/openhands-venv/bin/python openhands-ai==1.4.0
    fi"

# Run command with instruction for OpenHands agent
export RUN_COMMAND="/opt/openhands-venv/bin/python -m openhands.core.main \
      -t \"Read the instructions in instructions.md and carry out the specified task.\""

# map tasks to image name local, mount paths to image name on volume/local

case "$TASK_NAME" in
    "othello")
        export TASK_IMAGE="othello_image:latest"
        export CONTAINER_WORKSPACE="/stage"
        ;;
    "cogs")
        export TASK_IMAGE="cogs_image:latest"
        export CONTAINER_WORKSPACE="/stage"
        ;;
    *)
        echo "Warning: Task $TASK_NAME not found in router."
        ;;
esac


for level in default
do

cd $REPOS_ROOT
if [ ! -d "$REPOS_ROOT/${REPO_NAME}" ]; then
  cp -r /home/ubuntu/tasks/${REPO_NAME} $REPO_PATH
fi


cd $REPO_PATH

mkdir -p ${REPO_PATH}/trajectories/

cd $OPENHANDS_PATH
echo "Running agent..."
docker run -it --rm \
 --gpus all \
 -e DEBUG=false \
 -e RUNTIME="local" \
 -e SANDBOX_USER_ID=$(id -u) \
 -e WORKSPACE_MOUNT_PATH="$CONTAINER_WORKSPACE" \
 -e LLM_API_KEY=$LLM_API_KEY \
 -e SAVE_TRAJECTORY_PATH="$CONTAINER_WORKSPACE/trajectories" \
 -e LLM_MODEL=$LLM_MODEL \
 -e LLM_INPUT_TOKEN_COST=$LLM_INPUT_TOKEN_COST \
 -e LLM_OUTPUT_TOKEN_COST=$LLM_OUTPUT_TOKEN_COST \
 -e LOG_ALL_EVENTS=true \
 -e SANDBOX_VOLUMES="$CONTAINER_WORKSPACE:/workspace:rw" \
 -e SANDBOX_TIMEOUT=240 \
 -v $WORKSPACE_BASE:$CONTAINER_WORKSPACE \
 -v /var/run/docker.sock:/var/run/docker.sock \
 -v ~/.openhands-state:/.openhands-state \
 --add-host host.docker.internal:host-gateway \
 --name openhands-app-$(date +%Y%m%d%H%M%S) \
 -e AGENT_ENABLE_PROMPT_EXTENSIONS="false" \
 -e AGENT_ENABLE_BROWSING="false" \
 -e ENABLE_BROWSER="false" \
 -e SANDBOX_ENABLE_AUTO_LINT="true" \
 -e SKIP_DEPENDENCY_CHECK="1" \
 -e RUN_AS_OPENHANDS="false" \
 $TASK_IMAGE \
 bash -lc "$INSTALL_COMMAND && $RUN_COMMAND"

sudo chown -R ubuntu:ubuntu "$REPO_PATH"
sudo chmod -R u+rwX "$REPO_PATH"

echo "Creating patch at ${PATCHES_ROOT}/${TASK_NAME}/${level}/${AGENT_NAME}_${level}_run${RUN}.patch..."
cd $REPO_PATH
mkdir -p ${PATCHES_ROOT}/${TASK_NAME}/${level}
mv trajectories/*.json  ${PATCHES_ROOT}/${TASK_NAME}/${level}/${AGENT_NAME}_${level}_run${RUN}.json

git add .
git diff 'main' > ${PATCHES_ROOT}/${TASK_NAME}/${level}/${AGENT_NAME}_${level}_run${RUN}.patch
git restore --staged .
git restore .
git clean -f

# Remove "/workspace" from any paths (shouldn't be any here, but just in case)
sed -i "s|/workspace/|./|g" ${PATCHES_ROOT}/${TASK_NAME}/${level}/${AGENT_NAME}_${level}_run${RUN}.patch

cd $CURR_DIR

echo "Deleting ${REPO_PATH}"
rm -rf $REPO_PATH

done
