#!/bin/bash
# ==================================================
# RouterOS v7.20.8 GitHub 一键重装脚本 (通用版)
# 源仓库: qq48674431/RouterOS-container
# ==================================================

# --- 1. 配置区 ---
GITHUB_REPO="qq48674431/RouterOS-container"
TAG="v-7.20.8"
VERSION="7.20.8"

# --- 2. 环境检测与镜像匹配 ---
if [ -d /sys/firmware/efi ]; then
    echo "环境检测: [UEFI 模式]"
    IMG_NAME="chr-${VERSION}.img"
else
    echo "环境检测: [BIOS 模式]"
    IMG_NAME="chr-${VERSION}-legacy-bios.img"
fi

IMG_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${IMG_NAME}"

# --- 3. 下载镜像 ---
IMG_PATH="/tmp/chr.img"
echo "正在从 GitHub 下载镜像..."
echo "下载地址: $IMG_URL"

wget "$IMG_URL" -O "$IMG_PATH"

if [ $? -ne 0 ]; then
    echo "Error: 下载失败！"
    echo "请检查服务器是否能访问 GitHub，或 DNS 配置。"
    exit 1
fi

echo "下载完成！"

# --- 4. 获取网络与磁盘信息 ---
STORAGE=$(lsblk | grep disk | awk '{print $1}' | head -n 1)
ETH=$(ip route show default | sed -n 's/.* dev \([^\ ]*\) .*/\1/p' | head -n 1)
ADDRESS=$(ip addr show "$ETH" | grep global | awk '{print $2}' | head -n 1)
GATEWAY=$(ip route list | grep default | awk '{print $3}' | head -n 1)

if [ -z "$ADDRESS" ] || [ -z "$GATEWAY" ]; then
    echo "Error: 无法自动获取 IP 或网关，脚本终止以防失联。"
    exit 1
fi

if [ -z "$STORAGE" ]; then
    echo "Error: 找不到物理硬盘"
    exit 1
fi

if ip route show default dev "$ETH" | grep -q "proto dhcp"; then
    IS_DHCP="yes"
    echo "网络检测: [DHCP 动态获取]"
    echo "  当前 IP=$ADDRESS | 网关=$GATEWAY | 接口=$ETH"
else
    IS_DHCP="no"
    echo "网络检测: [静态 IP]"
    echo "  IP=$ADDRESS | 网关=$GATEWAY | 接口=$ETH"
fi

# --- 5. 注入配置 (offset=33571840 为 CHR 镜像 RW 分区偏移量) ---
echo "正在注入配置到镜像..."
mkdir -p /mnt

if mount -o loop,offset=33571840 "$IMG_PATH" /mnt; then
    mkdir -p /mnt/rw

    if [ "$IS_DHCP" = "yes" ]; then
        cat > /mnt/rw/autorun.scr <<EOF
/ip dhcp-client add interface=ether1 disabled=no
/ip service set telnet disabled=yes
/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no
EOF
    else
        cat > /mnt/rw/autorun.scr <<EOF
/ip address add address=$ADDRESS interface=ether1
/ip route add gateway=$GATEWAY
/ip service set telnet disabled=yes
/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no
EOF
    fi

    echo "注入脚本内容:"
    cat /mnt/rw/autorun.scr
    umount /mnt
    echo "配置注入成功！"
else
    echo "Warning: 挂载镜像失败 (offset 可能不匹配)，跳过注入，继续写入原镜像。"
fi

# --- 6. 写入硬盘 ---
echo "============================================="
echo "  即将写入目标硬盘: /dev/$STORAGE"
echo "  RouterOS 版本:    $VERSION"
if [ "$IS_DHCP" = "yes" ]; then
    echo "  网络模式:         DHCP 自动获取"
else
    echo "  网络模式:         静态 IP ($ADDRESS)"
fi
echo "============================================="
echo "正在写入 (请勿断电)..."

dd if="$IMG_PATH" of=/dev/"$STORAGE" bs=4M oflag=sync status=progress

# --- 7. 重启 ---
echo "安装完成！3秒后重启系统..."
sleep 3
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger
