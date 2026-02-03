# Base image with CUDA 12.2
FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

# Set environment variables
ENV PATH="/opt/miniconda3/bin:${PATH}" \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

ARG MINICONDA_VERSION=py38_4.10.3
ARG MINICONDA_URL=https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh

# Set work directory
WORKDIR /stage/

# Install dependencies and Miniconda
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    ca-certificates \
    unzip \
    && wget -q ${MINICONDA_URL} -O /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/miniconda3 \
    && rm /tmp/miniconda.sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/miniconda3/bin:$PATH"

WORKDIR /stage/
COPY base_repo/ /stage/

# Create env, clean conda cache, clean pip cache
RUN conda env create --prefix /stage/env --file=/stage/environment.yml && \
    conda clean -afy && \
    rm -rf /root/.cache/pip

RUN /opt/miniconda3/bin/pip install --no-cache-dir gdown

# Create required directories
RUN mkdir -p /stage/ckpts/battery_othello

# Default shell
ENV PATH="/stage/env/bin:$PATH"
