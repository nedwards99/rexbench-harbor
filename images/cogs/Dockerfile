# Specify base image from NVIDIA's CUDA container repository
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu20.04

# Specify which NVIDIA features container can use
ENV NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute

ENV DEBIAN_FRONTEND=noninteractive

# Specify paths for Hugging Face, Conda, CUDA
ENV HF_HOME=/opt/hf_cache
ENV CONDA_PKGS_DIRS=/conda_pkgs
ENV PATH=/opt/miniconda3/bin:/opt/miniconda3/condabin:$PATH
ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib:/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# Install base tools (remember to include git for applying patch), download and install miniconda
RUN apt-get update && apt-get install -y \
   git \
   curl \
   wget \
   ca-certificates && \
   wget --tries=3 --timeout=15 -v https://repo.anaconda.com/miniconda/Miniconda3-py312_24.1.2-0-Linux-x86_64.sh -O /tmp/miniconda.sh && \
   bash /tmp/miniconda.sh -b -p /opt/miniconda3 && \
   rm /tmp/miniconda.sh && \
   rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/miniconda3/bin:$PATH"

# Sets the working directory in the container to /stage/
WORKDIR /stage/
COPY base_repo/ /stage/

RUN conda env create --prefix /opt/task-env --file=/stage/environment.yml && \
    conda clean -afy
