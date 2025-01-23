# 使用带有 CUDA 12.1 的基础镜像
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04 AS builder

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
    && rm -rf /var/lib/apt/lists/*

# 复制项目文件到容器中
COPY . /workspace
WORKDIR /workspace

# 将 Windows 格式的换行符转换为 Unix 格式
RUN sed -i 's/\r$//' fastapp_inference.sh

# 安装 Python 依赖项
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install -r requirements.txt

# 设置脚本可执行权限
RUN chmod +x /workspace/fastapp_inference.sh

## 下载模型权重
#RUN retries=5 && \
#    while [ $retries -gt 0 ]; do \
#        huggingface-cli download ByteDance/LatentSync --local-dir checkpoints --exclude "*.git*" "README.md" && break; \
#        retries=$((retries-1)); \
#        echo "Download failed, retrying in 10 seconds... ($retries retries left)"; \
#        sleep 10; \
#    done && \
#    [ $retries -gt 0 ] || { echo "Download failed after multiple retries"; exit 1; }

# 安装 modelscope
RUN pip install modelscope

# 下载模型权重
RUN retries=10 && \
    while [ $retries -gt 0 ]; do \
        modelscope download --model ByteDance/LatentSync --local_dir checkpoints && break; \
        retries=$((retries-1)); \
        echo "Download failed, retrying in 30 seconds... ($retries retries left)"; \
        sleep 30; \
    done && \
    [ $retries -gt 0 ] || { echo "Download failed after multiple retries"; exit 1; }

# 创建软链接
RUN mkdir -p ~/.cache/torch/hub/checkpoints && \
    ln -s $(pwd)/checkpoints/auxiliary/2DFAN4-cd938726ad.zip ~/.cache/torch/hub/checkpoints/2DFAN4-cd938726ad.zip && \
    ln -s $(pwd)/checkpoints/auxiliary/s3fd-619a316812.pth ~/.cache/torch/hub/checkpoints/s3fd-619a316812.pth && \
    ln -s $(pwd)/checkpoints/auxiliary/vgg16-397923af.pth ~/.cache/torch/hub/checkpoints/vgg16-397923af.pth

# 第二阶段构建，只复制必要的文件
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

# 设置环境变量
ENV PYTHONUNBUFFERED=1

# 安装系统依赖项
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libgl1 \
    python3.10 \
    python3-tk \
    && rm -rf /var/lib/apt/lists/*

# 复制必要的文件
COPY --from=builder /workspace /workspace

# 设置工作目录
WORKDIR /workspace

# 设置默认命令
CMD ["uvicorn", "fastapp:app", "--host", "0.0.0.0", "--port", "8000"]