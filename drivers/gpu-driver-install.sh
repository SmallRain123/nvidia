#!/bin/bash

# ===================== 日志函数定义 =====================
# 功能：统一输出带时间戳的信息日志
log_info() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[INFO] [${timestamp}] $1"
}

# 功能：统一输出带时间戳的错误日志（标准错误输出）
log_error() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[ERROR] [${timestamp}] $1" >&2
}

# ===================== 核心配置 =====================
# 定义 nouveau 黑名单配置文件路径
nouveau_file="/etc/modprobe.d/blacklist-nouveau.conf"
# 标记是否已经执行过驱动安装（避免重复安装）
install_flag="/tmp/gpu_driver_installed.tmp"

# ===================== 权限检查 =====================
if [ "$(id -u)" -ne 0 ]; then
    log_error "此脚本需要以 root 权限运行，请使用 sudo 执行！"
    exit 1
fi

# ===================== 核心逻辑 =====================
# 第一步：检测配置文件是否存在（即是否已完成禁用 nouveau 步骤）
if [ -f "${nouveau_file}" ]; then
    # 检查是否已经安装过驱动，避免重复执行
    if [ -f "${install_flag}" ]; then
        log_info "检测到驱动已安装完成，无需重复操作，脚本退出。"
        exit 0
    fi

    log_info "检测到 ${nouveau_file} 文件存在（已禁用 nouveau），直接执行驱动安装..."
    # 执行自动驱动安装
    log_info "开始执行 ubuntu-drivers autoinstall 命令..."
    if ubuntu-drivers autoinstall; then
        log_info "驱动安装完成！"
        # 创建安装完成标记，避免重复安装
        touch "${install_flag}"
        log_info "建议执行以下命令更新内核并重启系统："
        log_info "  sudo update-initramfs -u && sudo reboot"
    else
        log_error "驱动安装失败，请检查网络或系统状态后重试！"
        exit 1
    fi
    exit 0
fi

# 第二步：配置文件不存在，执行 nouveau 禁用流程
log_info "未检测到 ${nouveau_file} 文件，开始创建禁用配置..."
tee ${nouveau_file} <<EOF
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF

# 验证文件创建结果
if [ ! -f "${nouveau_file}" ]; then
    log_error "${nouveau_file} 文件创建失败，请检查权限后重试！"
    exit 1
fi

log_info "${nouveau_file} 文件创建成功，更新 grub 配置..."
update-grub

# 确认重启（重启后再次执行脚本会自动安装驱动）
read -p "$(log_info "已完成 nouveau 禁用配置，需要重启系统使配置生效。重启后再次执行此脚本会自动安装驱动，是否立即重启？(y/N) " 2>&1)" confirm
if [[ "${confirm}" =~ ^[Yy]$ ]]; then
    log_info "系统将在 5 秒后重启..."
    sleep 5
    reboot
else
    log_info "已取消重启，你可稍后手动执行 sudo reboot 重启系统，再重新运行此脚本安装驱动。"
fi
