apptainer overlay create --size 1624 overlay_image.img
apptainer exec --nv \
    --overlay overlay_image.img \
    --bind $(pwd):/stage/repo/ \
    /mnt/cache_volume/apptainer-images/cogs_image.sif bash -c "source /opt/miniconda3/etc/profile.d/conda.sh && conda activate /stage/cogs/env/ && \
    conda info --envs && which python && python --version && \
    cd /stage/repo/ && \
    git apply agent_patch.patch && { [ -s run_final.sh ] || (echo 'Error: run_final.sh is empty or missing'; exit 1); } && bash -e run_final.sh | tee /stage/repo/cogs_result_agent_apptainer.txt; RUN_EXIT=\${PIPESTATUS[0]}; if [ \$RUN_EXIT -eq 0 ]; then echo 'de1ea76a963a2ccd2fae4a1983b4a5bb'; else exit \$RUN_EXIT; fi"