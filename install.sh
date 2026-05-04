#!/bin/bash
# ==================================================
# RouterOS v7.20.8 GitHub 一键重装脚本
# 源仓库: qq48674431/RouterOS-container
# ==================================================

# --- 1. 检查启动方式 ---
if [ -d /sys/firmware/efi ]; then
    IMG_URL="https://github.com/qq48674431/RouterOS-container/releases/download/v-7.20.8/chr-7.20.8.img"
    echo "检测到 UEFI 启动方式"
else
    IMG_URL="https://github.com/qq48674431/RouterOS-container/releases/download/v-7.20.8/chr-7.20.8-legacy-bios.img"
    echo "检测到 BIOS 启动方式"
fi

# --- 2. 下载镜像 ---
IMG_PATH="/tmp/chr.img"
echo "正在从 GitHub 下载: $IMG_URL ..."
wget "$IMG_URL" -O "$IMG_PATH"

if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络连接。"
    exit 1
fi

cd /tmp

# --- 3. 获取网络与磁盘信息 ---
STORAGE=$(lsblk | grep disk | awk '{print $1}' | head -n 1)

# 获取默认路由网卡
ETH=$(ip route show default | sed -n 's/.* dev \([^\ ]*\) .*/\1/p' | head -n 1)

# 获取IP地址
ADDRESS=$(ip addr show "$ETH" | grep global | awk '{print $2}' | head -n 1)

# 获取网关
GATEWAY=$(ip route list | grep default | awk '{print $3}' | head -n 1)

echo "检测到网络: IP=$ADDRESS, GW=$GATEWAY, Device=$STORAGE"

# --- 4. 智能检测 DHCP ---
if ip route show default dev "$ETH" | grep -q "proto dhcp"; then
    IS_DHCP="yes"
    echo "网络模式检测: [DHCP 动态获取] (跳过配置注入)"
else
    IS_DHCP="no"
    echo "网络模式检测: [Static 静态地址] (准备注入配置)"
fi

# --- 5. 注入配置 ---
echo "正在注入配置..."
mkdir -p /mnt

if mount -o loop,offset=33571840 "$IMG_PATH" /mnt; then
    mkdir -p /mnt/rw

    if [ "$IS_DHCP" = "yes" ]; then
        cat > /mnt/rw/autorun.scr <<'ROSEOF'
/interface ethernet set [find where !disabled] name=ether1
/ip dhcp-client remove [find]
/ip dhcp-client add interface=ether1 disabled=no
ROSEOF
    else
        cat > /mnt/rw/autorun.scr <<EOF
/interface ethernet set [find where !disabled] name=ether1
/ip dhcp-client remove [find]
/ip address add address=$ADDRESS interface=ether1
/ip route add gateway=$GATEWAY
EOF
    fi

    echo "注入脚本内容:"
    cat /mnt/rw/autorun.scr

    umount /mnt
    echo "配置注入成功！"
else
    echo "警告: 挂载镜像失败，可能是偏移量(offset)不匹配。跳过注入。"
fi

# --- 6. 执行写入 ---
echo "正在写入磁盘 /dev/$STORAGE ..."
dd if="$IMG_PATH" of=/dev/"$STORAGE" bs=4M oflag=sync

# --- 7. 重启 ---
echo "操作完成，系统即将重启..."
sleep 3
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger
