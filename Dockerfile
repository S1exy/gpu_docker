FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIP_INDEX_URL=https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple \
    PIP_TRUSTED_HOST=mirrors.tuna.tsinghua.edu.cn \
    PIP_DEFAULT_TIMEOUT=120

WORKDIR /workspace

# 1. 尝试将 Ubuntu apt 源替换为清华源
# PyTorch 官方镜像一般是 Ubuntu 系列；这里做成兼容写法
RUN if [ -f /etc/apt/sources.list ]; then \
        cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
        sed -i -E \
        -e 's@https?://archive.ubuntu.com/ubuntu/?@https://mirrors.tuna.tsinghua.edu.cn/ubuntu/@g' \
        -e 's@https?://security.ubuntu.com/ubuntu/?@https://mirrors.tuna.tsinghua.edu.cn/ubuntu/@g' \
        -e 's@https?://[a-zA-Z0-9.-]+.archive.ubuntu.com/ubuntu/?@https://mirrors.tuna.tsinghua.edu.cn/ubuntu/@g' \
        /etc/apt/sources.list; \
    fi

# 2. 安装 SSH、编译工具、CV 常用系统库
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    passwd \
    git \
    git-lfs \
    curl \
    wget \
    vim \
    nano \
    tmux \
    htop \
    rsync \
    unzip \
    zip \
    psmisc \
    iproute2 \
    ca-certificates \
    tzdata \
    locales \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    && locale-gen C.UTF-8 || true \
    && mkdir -p /var/run/sshd /root/.ssh \
    && rm -rf /var/lib/apt/lists/*

# 3. 配置 pip 默认使用清华源
RUN mkdir -p /etc/pip && \
    printf "[global]\nindex-url = https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple\ntimeout = 120\ntrusted-host = mirrors.tuna.tsinghua.edu.cn\n" > /etc/pip.conf

# 4. 配置 conda 默认使用清华源
RUN cat > /root/.condarc <<'EOF'
channels:
  - defaults
show_channel_urls: true
default_channels:
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2
custom_channels:
  conda-forge: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
  pytorch: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
  pytorch-lts: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
EOF

# 5. 安装常见 CV / 深度学习 / 实验管理 Python 包
# 注意：这里不要重新 pip install torch，否则可能破坏基础镜像里的 torch + cuda 版本
RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install --no-cache-dir \
    numpy \
    scipy \
    pandas \
    scikit-learn \
    scikit-image \
    opencv-python-headless \
    pillow \
    imageio \
    imageio-ffmpeg \
    matplotlib \
    seaborn \
    tqdm \
    rich \
    loguru \
    tabulate \
    yacs \
    omegaconf \
    hydra-core \
    tensorboard \
    jupyterlab \
    ipykernel \
    albumentations \
    pycocotools \
    einops \
    timm \
    torchmetrics \
    requests \
    pyyaml \
    h5py \
    wandb

# 6. 复制你仓库里的字体，解决 matplotlib 中文显示问题
COPY ./fonts/ /tmp/fonts/
RUN python - <<'PY'
import pathlib
import shutil

try:
    import matplotlib
    font_dir = pathlib.Path(matplotlib.get_data_path()) / "fonts" / "ttf"
    src_dir = pathlib.Path("/tmp/fonts")
    if src_dir.exists():
        for p in src_dir.glob("*"):
            if p.is_file():
                shutil.copy(str(p), str(font_dir / p.name))
        print("Fonts copied to:", font_dir)
except Exception as e:
    print("Skip font copy:", e)
PY

# 7. 配置 SSH
# 不建议把密码写死在 Dockerfile 里；后面通过环境变量 SSH_PASSWORD 设置
RUN sed -ri 's/^#?Port .*/Port 22/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config

# 8. 容器启动脚本：启动 sshd，并支持密码或公钥登录
RUN cat > /usr/local/bin/start-container.sh <<'EOF'
#!/usr/bin/env bash
set -e

mkdir -p /var/run/sshd /root/.ssh
chmod 700 /root/.ssh

ssh-keygen -A

if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
    echo "${SSH_PUBLIC_KEY}" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "SSH public key has been added."
fi

if [ -n "${SSH_PASSWORD:-}" ]; then
    echo "root:${SSH_PASSWORD}" | chpasswd
    echo "Root SSH password has been set from SSH_PASSWORD."
else
    echo "WARNING: SSH_PASSWORD is not set. Password SSH login may not work."
fi

/usr/sbin/sshd

exec "$@"
EOF

RUN chmod +x /usr/local/bin/start-container.sh

# 9. 构建时简单检查关键包
RUN python - <<'PY'
import torch
import cv2
import numpy
import tqdm
import PIL

print("torch:", torch.__version__)
print("torch cuda:", torch.version.cuda)
print("cv2:", cv2.__version__)
print("numpy:", numpy.__version__)
print("PIL:", PIL.__version__)
PY

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/start-container.sh"]

CMD ["/bin/bash", "-lc", "sleep infinity"]
