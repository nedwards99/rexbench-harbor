# Specify base image from NVIDIA's CUDA container repository
ARG CUDA=11.8.0
ARG DIST=ubuntu20.04
ARG TARGET=cudnn8-devel
FROM nvidia/cuda:${CUDA}-${TARGET}-${DIST}


# Avoids prompts during package installations
ARG DEBIAN_FRONTEND="noninteractive"
ARG MINICONDA_VERSION=py312_24.1.2-0
ARG MINICONDA_URL=https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh

# Specify which NVIDIA features container can use
ENV NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute


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
   wget -q ${MINICONDA_URL} -O /tmp/miniconda.sh && \
   bash /tmp/miniconda.sh -b -p /opt/miniconda3 && \
   rm /tmp/miniconda.sh && \
   rm -rf /var/lib/apt/lists/*

# ARG MINICONDA_VER=py312_24.11.1-0
# ARG MINICONDA_SH=Miniconda3-${MINICONDA_VER}-Linux-x86_64.sh
# wget -q https://repo.anaconda.com/miniconda/${MINICONDA_SH} -O /tmp/miniconda.sh && \
# wget -q https://repo.anaconda.com/miniconda/${MINICONDA_SH}.sha256 -O /tmp/miniconda.sha256 && \
# sed -i 's#Miniconda3-.*-Linux-x86_64.sh#/tmp/miniconda.sh#' /tmp/miniconda.sha256 && \
# sha256sum -c /tmp/miniconda.sha256 && \
# bash /tmp/miniconda.sh -b -p /opt/miniconda3 && \
# && wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
# echo "636b209b00b6673471f846581829d4b96b9c3378679925a59a584257c3fef5a3  miniconda.sh" | sha256sum --check && \

ENV PATH="/opt/miniconda3/bin:$PATH"

# Sets the working directory in the container to /stage/
WORKDIR /stage/
COPY base_repo/ /stage/
COPY base_repo/ /root/base_repo/

RUN conda env create --prefix /stage/env --file=/stage/environment.yml && \
    conda clean -afy

ENV PATH="/stage/env/bin:$PATH"
# # installs packages inside conda environment
# RUN conda init bash && \
#    . ~/.bashrc && \
#    conda env create -p /stage/env/ python=3.12 --file=/stage/environment.yml
