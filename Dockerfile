# ##################################################################################
# Create PyTorch Docker Layer
# We do this seperately since else we need to keep rebuilding
# ##################################################################################
FROM ubuntu:22.04 as downloader-pytorch
#FROM ubuntu:18.04 as downloader-pytorch

# Configuration Arguments
# https://github.com/pytorch/pytorch
ARG V_PYTORCH=v1.12.1

# Install Git Tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends software-properties-common apt-utils git \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Accept default answers for everything
ENV DEBIAN_FRONTEND=noninteractive

# Clone Source
RUN git clone --recursive --branch ${V_PYTORCH} http://github.com/pytorch/pytorch

# ##################################################################################
# Build PyTorch
# ##################################################################################
FROM ubuntu:22.04 as builder

# Configuration Arguments
ARG V_PYTHON_MAJOR=3
ARG V_PYTHON_MINOR=9

ENV V_PYTHON=${V_PYTHON_MAJOR}.${V_PYTHON_MINOR}

# Accept default answers for everything
ENV DEBIAN_FRONTEND=noninteractive

# Download Common Software
RUN apt-get update \
    && apt-get install -y clang build-essential bash ca-certificates git wget cmake curl software-properties-common ffmpeg libsm6 libxext6 libffi-dev libssl-dev xz-utils zlib1g-dev liblzma-dev

# Setting up Python 3.9
WORKDIR /install

RUN add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y python${V_PYTHON} python${V_PYTHON}-dev python${V_PYTHON}-venv python${V_PYTHON_MAJOR}-tk \
    && rm -f /usr/bin/python \
    && rm -f /usr/bin/python${V_PYTHON_MAJOR} \
    && ln -s $(which python${V_PYTHON}) /usr/bin/python \
    && ln -s $(which python${V_PYTHON}) /usr/bin/python${V_PYTHON_MAJOR} \
    && curl --silent --show-error https://bootstrap.pypa.io/get-pip.py | python

# PyTorch - Build - Source Code Setup 
# copy everything from the downloader-pytorch layer /torch to /torch on this one
COPY --from=downloader-pytorch /pytorch /pytorch
WORKDIR /pytorch

# PyTorch - Build - Prerequisites
# Set clang as compiler
# clang supports the ARM NEON registers
# GNU GCC will give "no expression error"
ARG CC=clang
ARG CXX=clang++

# Set path to ccache
ARG PATH=/usr/lib/ccache:$PATH

# Other arguments
ARG USE_CUDA=OFF
ARG BUILD_CAFFE2_OPS=0
ARG USE_FBGEMM=0
ARG USE_FAKELOWP=0
ARG BUILD_TEST=0
ARG USE_MKLDNN=0
ARG USE_NNPACK=0
ARG USE_XNNPACK=0
ARG USE_QNNPACK=0
ARG USE_PYTORCH_QNNPACK=0
ARG USE_NCCL=0
ARG USE_SYSTEM_NCCL=0
ARG USE_OPENCV=0
ARG USE_DISTRIBUTED=0

ARG BUILD_SHARED_LIBS=0
ARG BUILD_EXAMPLES=0
ARG BUILD_PYTHON=0
ARG BUILD_ONNX_PYTHON=0

# Build
RUN cd /pytorch \
    && rm build/CMakeCache.txt || : \
    && sed -i -e "/^if(DEFINED GLIBCXX_USE_CXX11_ABI)/i set(GLIBCXX_USE_CXX11_ABI 1)" CMakeLists.txt \
    && pip install -r requirements.txt \
    && python setup.py build \
    && cd ..

# ##################################################################################
# Prepare Artifact
# ##################################################################################
#FROM scratch as artifact
#COPY --from=builder /pytorch/build/* /
CMD ["/bin/bash"]
