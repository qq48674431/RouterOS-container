#!/bin/bash
# ==================================================
# RouterOS v7.20.8 GitHub 一键重装脚本 (通用版)
# 源仓库: qq48674431/RouterOS-container
# ==================================================

# --- 1. 配置区 ---
GITHUB_REPO="qq48674431/RouterOS-container"
TAG="v-7.20.8"
VERSION="7.20.8"
ROS_PASSWORD="${ROS_PASSWORD:-admin}"

# --- 2. 环境检测与镜像匹配 ---
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="UEFI"
    IMG_NAME="chr-${VERSION}.img"
else
    BOOT_MODE="BIOS"
    IMG_NAME="chr-${VERSION}-legacy-bios.img"
fi

echo "环境检测: [$BOOT_MODE 模式]"
IMG_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${IMG_NAME}"

# --- 3. 下载镜像 ---
IMG_PATH="/tmp/chr.img"
echo "正在从 GitHub 下载: $IMG_URL ..."
wget "$IMG_URL" -O "$IMG_PATH"

if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络连接。"
    exit 1
fi

cd /tmp

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

echo "检测到网络: IP=$ADDRESS, GW=$GATEWAY, ETH=$ETH, Disk=$STORAGE"

# --- 5. 智能检测 DHCP ---
if ip route show default dev "$ETH" | grep -q "proto dhcp"; then
    IS_DHCP="yes"
    echo "网络模式检测: [DHCP 动态获取]"
else
    IS_DHCP="no"
    echo "网络模式检测: [Static 静态地址]"
fi

# --- 6. 注入配置 (offset=33571840 为官方 CHR 镜像 RW 分区偏移量) ---
echo "正在注入配置到镜像..."
mkdir -p /mnt

if mount -o loop,offset=33571840 "$IMG_PATH" /mnt; then
    mkdir -p /mnt/rw

    if [ "$IS_DHCP" = "yes" ]; then
        cat > /mnt/rw/autorun.scr <<EOF
/user set [find name=admin] password="$ROS_PASSWORD"
/interface ethernet set [ find default-name=ether1 ] disable-running-check=no
/ip dhcp-client add interface=ether1 disabled=no
/ip service set ftp disabled=yes
/ip service set telnet disabled=yes
/ip service set www disabled=yes
/ip service set api-ssl disabled=yes
/ip service set api port=12288
/ip service set ssh disabled=no port=22
/ip service set winbox port=18291
/system clock set time-zone-name=Asia/Shanghai
/system identity set name=$IMG_NAME
EOF
    else
        cat > /mnt/rw/autorun.scr <<EOF
/user set [find name=admin] password="$ROS_PASSWORD"
/interface ethernet set [ find default-name=ether1 ] disable-running-check=no
/ip address add address=$ADDRESS interface=ether1
/ip route add gateway=$GATEWAY
/ip service set ftp disabled=yes
/ip service set telnet disabled=yes
/ip service set www disabled=yes
/ip service set api-ssl disabled=yes
/ip service set api port=12288
/ip service set ssh disabled=no port=22
/ip service set winbox port=18291
/system clock set time-zone-name=Asia/Shanghai
/system identity set name=$IMG_NAME
EOF
    fi

    echo "注入脚本内容:"
    cat /mnt/rw/autorun.scr
    umount /mnt
    echo "配置注入成功！"
else
    echo "警告: 挂载镜像失败，可能是偏移量(offset)不匹配。跳过注入，尝试直接写入原镜像。"
fi

# --- 7. 执行写入 ---
echo "============================================="
echo "  目标硬盘: /dev/$STORAGE"
echo "  RouterOS: $VERSION ($BOOT_MODE)"
if [ "$IS_DHCP" = "yes" ]; then
    echo "  网络模式: DHCP 自动获取"
else
    echo "  网络模式: 静态 IP ($ADDRESS)"
fi
echo "  Winbox:   端口 18291"
echo "  SSH:      端口 22"
echo "  密码:     $ROS_PASSWORD"
echo "============================================="
echo "正在写入磁盘 /dev/$STORAGE ..."

dd if="$IMG_PATH" of=/dev/"$STORAGE" bs=4M oflag=sync status=progress

# --- 8. 重启 ---
echo "操作完成，系统即将重启..."
sleep 3
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger
