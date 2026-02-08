# dbox 基础镜像
FROM ubuntu:24.04

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    jq \
    moreutils \
    vim \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户，配置 PATH
RUN useradd -m -s /bin/bash devuser && \
    echo '' | tee -a /home/devuser/.bashrc >> /home/devuser/.profile && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' | tee -a /home/devuser/.bashrc >> /home/devuser/.profile && \
    echo '[[ -f /sandbox/env/global ]] && source /sandbox/env/global' | tee -a /home/devuser/.bashrc >> /home/devuser/.profile && \
    echo '[[ -f /sandbox/env/global.local ]] && source /sandbox/env/global.local' | tee -a /home/devuser/.bashrc >> /home/devuser/.profile && \
    echo '[[ -f /sandbox/env/tool ]] && source /sandbox/env/tool' | tee -a /home/devuser/.bashrc >> /home/devuser/.profile && \
    echo '[[ -f /sandbox/env/tool.local ]] && source /sandbox/env/tool.local' | tee -a /home/devuser/.bashrc >> /home/devuser/.profile && \
    echo '[[ -f /sandbox/env/profile ]] && source /sandbox/env/profile' | tee -a /home/devuser/.bashrc >> /home/devuser/.profile && \
    echo '[[ -f /sandbox/env/profile.local ]] && source /sandbox/env/profile.local' | tee -a /home/devuser/.bashrc >> /home/devuser/.profile

# 设置默认用户
USER devuser
