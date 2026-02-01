#!/bin/bash

echo "Starting Apptainer container..."

apptainer exec --nv \
    --bind $(pwd):/stage \
    --bind /mnt/cache_volume/hf_cache/models/othello/gpt_synthetic.ckpt:/stage/ckpts/gpt_synthetic.ckpt \
    --bind /mnt/cache_volume/hf_cache/data/othello_championship:/stage/data/othello_championship \
    /mnt/cache_volume/apptainer-images/othello_image.sif \
    bash -c "cd /stage && source /opt/miniconda3/etc/profile.d/conda.sh && conda activate othello && git apply agent_patch.patch && \
    bash -e produce_probes.sh && echo 'de1ea76a963a2ccd2fae4a1983b4a5bb'"
