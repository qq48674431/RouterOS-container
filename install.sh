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
echo "正在从 GitHub 下载镜像..."
echo "下载地址: $IMG_URL"

if ! curl -L -f -o /tmp/chr.img "$IMG_URL" --connect-timeout 20 --retry 3; then
    echo "Error: 下载失败！"
    echo "请检查服务器是否能访问 GitHub，或 DNS 配置。"
    exit 1
fi

echo "下载完成！"

# --- 4. 备份当前网络信息 & 检测静态/DHCP ---
ETH=$(ip route show default | sed -n 's/.* dev \([^\ ]*\) .*/\1/p' | head -n 1)
ADDRESS=$(ip addr show "$ETH" | grep global | awk '{print $2}' | head -n 1)
GATEWAY=$(ip route list | grep default | awk '{print $3}' | head -n 1)

if [ -z "$ADDRESS" ] || [ -z "$GATEWAY" ]; then
    echo "Error: 无法自动获取 IP 或网关，脚本终止以防失联。"
    exit 1
fi

IS_DHCP=false

if pgrep -a dhclient 2>/dev/null | grep -q "$ETH" 2>/dev/null; then
    IS_DHCP=true
elif pgrep -a dhcpcd 2>/dev/null | grep -q "$ETH" 2>/dev/null; then
    IS_DHCP=true
elif pgrep -a udhcpc 2>/dev/null | grep -q "$ETH" 2>/dev/null; then
    IS_DHCP=true
elif [ -f "/var/lib/dhcp/dhclient.${ETH}.leases" ] || [ -f "/var/lib/dhclient/dhclient-${ETH}.leases" ]; then
    IS_DHCP=true
elif [ -d /etc/netplan ] && grep -rql "dhcp4.*true\|dhcp4.*yes" /etc/netplan/ 2>/dev/null; then
    IS_DHCP=true
elif [ -f /etc/network/interfaces ] && grep -A5 "$ETH" /etc/network/interfaces 2>/dev/null | grep -q "dhcp"; then
    IS_DHCP=true
elif [ -d /etc/NetworkManager/system-connections ] && nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep -q "$ETH" && \
     nmcli -t -f ipv4.method con show "$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep "$ETH" | cut -d: -f1)" 2>/dev/null | grep -q "auto"; then
    IS_DHCP=true
fi

if [ "$IS_DHCP" = true ]; then
    echo "网络检测: [DHCP 动态获取]"
    echo "  当前 IP=$ADDRESS | 网关=$GATEWAY | 接口=$ETH"
    echo "  RouterOS 将配置为 DHCP Client 自动获取地址"
else
    echo "网络检测: [静态 IP]"
    echo "  IP=$ADDRESS | 网关=$GATEWAY | 接口=$ETH"
fi

# --- 5. 离线注入配置 (losetup 方式) ---
echo "正在注入配置到镜像..."
mkdir -p /mnt/ros_tmp

LOOPDEV=$(losetup -f --show -P /tmp/chr.img)
if [ -z "$LOOPDEV" ]; then
    echo "Error: losetup 挂载失败 (可能是内核版本过低不支持 -P 参数)"
    exit 1
fi
sleep 1

FOUND_PART=""
for part in "${LOOPDEV}"p{1..5} "${LOOPDEV}"{1..5}; do
    [ -e "$part" ] || continue
    if mount "$part" /mnt/ros_tmp 2>/dev/null; then
        if [ -d /mnt/ros_tmp/rw ]; then
            FOUND_PART="$part"
            break
        else
            umount /mnt/ros_tmp 2>/dev/null || true
        fi
    fi
done

if [ -z "$FOUND_PART" ]; then
    echo "Error: 无法在镜像中找到 rw 配置目录，注入失败。"
    losetup -d "$LOOPDEV"
    exit 1
fi

if [ "$IS_DHCP" = true ]; then
    cat > /mnt/ros_tmp/rw/autorun.scr <<EOF
/interface ethernet set [ find default-name=ether1 ] name=wan
/ip dhcp-client add interface=wan disabled=no
/ip service set telnet disabled=yes
/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no
EOF
else
    cat > /mnt/ros_tmp/rw/autorun.scr <<EOF
/interface ethernet set [ find default-name=ether1 ] name=wan
/ip address add address=$ADDRESS interface=wan
/ip route add gateway=$GATEWAY
/ip service set telnet disabled=yes
/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no
EOF
fi

echo "配置注入成功！(挂载分区: $FOUND_PART)"
sync
umount /mnt/ros_tmp
losetup -d "$LOOPDEV"

# --- 6. 写入硬盘 ---
STORAGE=$(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1; exit}')
if [ -z "$STORAGE" ]; then
    echo "Error: 找不到物理硬盘"
    exit 1
fi

echo "============================================="
echo "  即将写入目标硬盘: /dev/$STORAGE"
echo "  RouterOS 版本:    $VERSION"
if [ "$IS_DHCP" = true ]; then
    echo "  网络模式:         DHCP 自动获取"
else
    echo "  网络模式:         静态 IP ($ADDRESS)"
fi
echo "  密码:             已内置于镜像"
echo "============================================="
echo "正在写入 (请勿断电)..."

dd if=/tmp/chr.img of=/dev/"$STORAGE" bs=4M oflag=sync status=progress

# --- 7. 重启 ---
echo "安装完成！3秒后重启系统..."
sleep 3
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger
