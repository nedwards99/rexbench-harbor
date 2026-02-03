#!/bin/bash
set -euo pipefail

EVAL_REPO="${1:-/stage}"
RESULTS_PATH="${EVAL_REPO}/"

# Download private assets into /root/private
mkdir -p /root/private

# GDrive folder URLs
OTHELLO_CKPT_URL="https://drive.google.com/drive/folders/1OhEicPy302z_eE_NSKqVDjaP8tm-cVhT"
OTHELLO_DATA_URL="https://drive.google.com/drive/folders/1GweUZmhcv548RZAz_yY0AYw-UOKLIYWY"

gdown --folder "$OTHELLO_CKPT_URL" -O /root/private
gdown --folder "$OTHELLO_DATA_URL" -O /root/private

# Unzip data
unzip -q /root/private/data/othello_championship.zip -d /root/private/data/

# Target paths expected by your code
mkdir -p /stage/ckpts
mkdir -p /stage/data

cp -f /root/private/model/gpt_synthetic.ckpt /stage/ckpts/gpt_synthetic.ckpt
cp -r /root/private/data/othello_championship /stage/data/othello_championship

cd "$EVAL_REPO"

# Run experiment
bash -e produce_probes.sh
