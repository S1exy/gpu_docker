FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PIP_INDEX_URL=https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
ENV PIP_TRUSTED_HOST=mirrors.tuna.tsinghua.edu.cn
ENV PIP_DEFAULT_TIMEOUT=120

WORKDIR /workspace

RUN if [ -f /etc/apt/sources.list ]; then \
    cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed -i -E \
    -e 's@https?://archive.ubuntu.com/ubuntu/?@https://mirrors.tuna.tsinghua.edu.cn/ubuntu/@g' \
    -e 's@https?://security.ubuntu.com/ubuntu/?@https://mirrors.tuna.tsinghua.edu.cn/ubuntu/@g' \
    -e 's@https?://[a-zA-Z0-9.-]+.archive.ubuntu.com/ubuntu/?@https://mirrors.tuna.tsinghua.edu.cn/ubuntu/@g' \
    /etc/apt/sources.list; \
    fi

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

RUN mkdir -p /etc/pip && \
    printf "[global]\nindex-url = https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple\ntimeout = 120\ntrusted-host = mirrors.tuna.tsinghua.edu.cn\n" > /etc/pip.conf

RUN printf "channels:\n  - defaults\nshow_channel_urls: true\ndefault_channels:\n  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main\n  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r\n  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2\ncustom_channels:\n  conda-forge: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud\n  pytorch: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud\n  pytorch-lts: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud\n" > /root/.condarc

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

COPY ./fonts/ /tmp/fonts/

RUN python -c "import pathlib, shutil, matplotlib; font_dir = pathlib.Path(matplotlib.get_data_path()) / 'fonts' / 'ttf'; src_dir = pathlib.Path('/tmp/fonts'); [shutil.copy(str(p), str(font_dir / p.name)) for p in src_dir.glob('*') if p.is_file()] if src_dir.exists() else None"

RUN sed -ri 's/^#?Port .*/Port 22/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config

RUN printf '#!/usr/bin/env bash\nset -e\nmkdir -p /var/run/sshd /root/.ssh\nchmod 700 /root/.ssh\nssh-keygen -A\nif [ -n "${SSH_PUBLIC_KEY:-}" ]; then\n  echo "${SSH_PUBLIC_KEY}" >> /root/.ssh/authorized_keys\n  chmod 600 /root/.ssh/authorized_keys\n  echo "SSH public key has been added."\nfi\nif [ -n "${SSH_PASSWORD:-}" ]; then\n  echo "root:${SSH_PASSWORD}" | chpasswd\n  echo "Root SSH password has been set from SSH_PASSWORD."\nelse\n  echo "WARNING: SSH_PASSWORD is not set. Password SSH login may not work."\nfi\n/usr/sbin/sshd\nexec "$@"\n' > /usr/local/bin/start-container.sh && \
    chmod +x /usr/local/bin/start-container.sh

RUN python -c "import torch, cv2, numpy, tqdm, PIL; print('torch:', torch.__version__); print('torch cuda:', torch.version.cuda); print('cv2:', cv2.__version__); print('numpy:', numpy.__version__); print('PIL:', PIL.__version__)"

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/start-container.sh"]

CMD ["/bin/bash", "-lc", "sleep infinity"]
