# 使用带有 CUDA 12.1 的基础镜像
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# 安装系统依赖项
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    ffmpeg \
    libgl1 \
    python3.10 \
    python3.10-dev \
    python3.10-venv \
    python3-pip \
    python3-tk \
    && rm -rf /var/lib/apt/lists/*

# 创建并激活 Python 虚拟环境
RUN python3.10 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 安装 Python 依赖项
COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip && \
    pip install -r /tmp/requirements.txt

# 复制项目文件到容器中
COPY . /workspace
WORKDIR /workspace

# 设置脚本可执行权限
RUN chmod +x /workspace/fastapp_inference.sh

ENV HF_HUB_DOWNLOAD_TIMEOUT=600

# 下载模型权重
# RUN huggingface-cli download ByteDance/LatentSync --local-dir checkpoints --exclude "*.git*" "README.md"

RUN retries=5 && \
    while [ $retries -gt 0 ]; do \
        huggingface-cli download ByteDance/LatentSync --local-dir checkpoints --exclude "*.git*" "README.md" && break; \
        retries=$((retries-1)); \
        echo "Download failed, retrying in 10 seconds... ($retries retries left)"; \
        sleep 10; \
    done && \
    [ $retries -gt 0 ] || { echo "Download failed after multiple retries"; exit 1; }

# 创建软链接
RUN mkdir -p ~/.cache/torch/hub/checkpoints && \
    ln -s $(pwd)/checkpoints/auxiliary/2DFAN4-cd938726ad.zip ~/.cache/torch/hub/checkpoints/2DFAN4-cd938726ad.zip && \
    ln -s $(pwd)/checkpoints/auxiliary/s3fd-619a316812.pth ~/.cache/torch/hub/checkpoints/s3fd-619a316812.pth && \
    ln -s $(pwd)/checkpoints/auxiliary/vgg16-397923af.pth ~/.cache/torch/hub/checkpoints/vgg16-397923af.pth

# 设置默认命令
CMD ["python", "fastapp.py"]