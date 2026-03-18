# =============================================================================
# Base Image and Build Arguments
#  - Docker container must match jetpack version installed on Jetson
#    - Image list: https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-base/tags
#  - ROS2 Humble is used for Jetson Orin OpenCV and Python version compatibility
#  - For native builds: ARM64/Jetson uses l4t-jetpack, AMD64 uses Ubuntu 22.04
# =============================================================================

# Build arguments
ARG ros_distro=humble
ARG gid
ARG uid
ARG username
ARG install_cuda=false
ARG is_jetson=false
ARG BASE_STAGE_NAME=base_amd64

# =============================================================================
# Stage 1: Platform-Specific Base Images
# =============================================================================
# For Robot (ARM64/Jetson): Use NVIDIA JetPack base image
# Note: Stage name uses "arm64" to match Docker's TARGETARCH variable
ARG BASE_IMAGE_ARM64=nvcr.io/nvidia/l4t-jetpack:r36.4.0
FROM ${BASE_IMAGE_ARM64} AS base_arm64
# JetPack container: includes CUDA, cuDNN, TensorRT, VPI, Jetson Multimedia, and so on
# Alternative ML container with PyTorch, TensorFlow pre-installed:
# FROM nvcr.io/nvidia/l4t-ml:r36.2.0-py3 AS base-arm64

ARG is_jetson
ARG install_cuda

# NOTE that while the package repositories are not enabled inside the container, jetpack is already installed.
# To get a list of all packages, check the host by running:
# cat /var/lib/apt/lists/repo.download.nvidia.com_jetson_common_dists_r36.4_main_binary-arm64_Packages |grep cudnn
# Install the jetson package repository (only on actual Jetson devices)
RUN if [ "$is_jetson" = "true" ]; then \
        apt-key adv --fetch-key https://repo.download.nvidia.com/jetson/jetson-ota-public.asc && \
        echo "deb https://repo.download.nvidia.com/jetson/common r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
        echo "deb https://repo.download.nvidia.com/jetson/t234 r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
        echo "deb https://repo.download.nvidia.com/jetson/ffmpeg r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list; \
    fi

# Install cuDNN (only when CUDA is available, required for PyTorch)
# NOTE cudnn8 is not compatible with latest PyTorch on Jetson, so we install cudnn9
RUN if [ "$install_cuda" = "true" ]; then \
        apt-get update && apt-get install -y \
        libcudnn9 \
        libcudnn9-dev \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# For Desktop (AMD64/x86_64): Use Ubuntu 22.04 with optional CUDA
# Note: Stage name uses "amd64" to match Docker's TARGETARCH variable
FROM ubuntu:22.04 AS base_amd64

ARG install_cuda

# Install CUDA toolkit for Desktop only if install_cuda is true
# This provides GPU support on Desktop machines with NVIDIA GPUs
COPY scripts/detect_gpu_setup.sh /tmp/detect_gpu_setup.sh
RUN if [ "$install_cuda" = "true" ]; then \
        . /tmp/detect_gpu_setup.sh && \
        apt-get update && apt-get install -y \
            wget \
            gnupg2 \
            && rm -rf /var/lib/apt/lists/* && \
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
        dpkg -i cuda-keyring_1.1-1_all.deb && \
        rm cuda-keyring_1.1-1_all.deb && \
        apt-get update && apt-get install -y \
            ${CUDA_TOOLKIT_PKG} \
            libcudnn8 \
            libcudnn8-dev \
            && rm -rf /var/lib/apt/lists/*; \
    fi

# =============================================================================
# Stage 2: Select Base - Auto-detects platform during native build
# =============================================================================
# When building natively on Robot (ARM64), this will pull from base-arm64
# When building natively on Desktop (AMD64), this will pull from base-amd64
ARG BASE_STAGE_NAME
FROM $BASE_STAGE_NAME AS base-selected

ARG ros_distro=humble
ARG gid
ARG uid
ARG username

# =============================================================================
# Stage 3: Base Setup - Locale and Essential Tools
# =============================================================================
FROM base-selected AS base-setup

# Set non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Setup Locale
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install base dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    gnupg2 \
    lsb-release \
    iproute2 \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 4: ROS2 Installation
# =============================================================================
FROM base-setup AS ros2-install

ARG ros_distro
ARG is_jetson

# Setup Isaac ROS2 APT repository (ARM64 only, will fail gracefully on AMD64)
RUN if [ "$is_jetson" = "true" ]; then \
  wget -qO - https://isaac.download.nvidia.com/isaac-ros/repos.key | apt-key add - && \
  grep -qxF "deb https://isaac.download.nvidia.com/isaac-ros/release-3 $(lsb_release -cs) release-3.0" /etc/apt/sources.list || \
  echo "deb https://isaac.download.nvidia.com/isaac-ros/release-3 $(lsb_release -cs) release-3.0" | tee -a /etc/apt/sources.list || true; \
fi

# Setup Official ROS2 APT repository
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install Core ROS 2 Humble packages
RUN apt-get update && apt-get install -y \
    ros-${ros_distro}-desktop-full \
    ros-${ros_distro}-rmw-cyclonedds-cpp \
    ros-dev-tools \
    && rm -rf /var/lib/apt/lists/*

# Install Isaac ROS common dependencies and VPI (ARM64 only, skip on AMD64)
# Note: VPI libraries are also part of the Jetson host system and will be mounted.
# This ensures any additional dependencies are met inside the container.
RUN if [ "$is_jetson" = "true" ]; then \
    apt-get update && \
    (apt-get install -y ros-${ros_distro}-isaac-ros-common || echo "Isaac ROS not available on this platform") && \
    rm -rf /var/lib/apt/lists/*; \
fi

# Initialize rosdep
RUN rosdep init && \
    rosdep update

# Install PCL & Eigen & essential libraries
RUN apt-get update && apt-get install -y cmake libatlas-base-dev libeigen3-dev libpcl-dev libgoogle-glog-dev libsuitesparse-dev libglew-dev wget unzip git python3-pip
RUN apt-get install -y ros-humble-tf2 ros-humble-cv-bridge ros-humble-pcl-conversions ros-humble-xacro ros-humble-robot-state-publisher \
    ros-humble-rviz2 ros-humble-image-transport ros-humble-image-transport-plugins ros-humble-pcl-ros \
    ros-humble-ament-cmake-auto

# Install matplotlib
RUN apt-get update && apt-get install -y libtbb-dev python-tk && pip install matplotlib 

# Install ceres-solver
WORKDIR /root/thirdParty
RUN wget https://github.com/ceres-solver/ceres-solver/archive/refs/tags/2.1.0.tar.gz
RUN tar zxf 2.1.0.tar.gz
WORKDIR /root/thirdParty/ceres-solver-2.1.0
RUN mkdir build
WORKDIR /root/thirdParty/ceres-solver-2.1.0/build
RUN cmake -DCMAKE_BUILD_TYPE=Release .. && make -j4 && make install

# Install livox SDK
WORKDIR /root/
RUN git clone https://github.com/Livox-SDK/Livox-SDK2.git
WORKDIR /root/Livox-SDK2
RUN mkdir build
WORKDIR /root/Livox-SDK2/build
RUN cmake .. && make -j2 && make install

# Install livox ros driver
WORKDIR /root/ros2_livox_ws/src
RUN git clone https://github.com/Livox-SDK/livox_ros_driver2.git
WORKDIR /root/ros2_livox_ws/src/livox_ros_driver2


WORKDIR /root/ros2_ws

# Load ROS environment at each run
COPY docker/ros_entrypoint.sh /
RUN chmod 755 /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]

CMD ["bash"]
