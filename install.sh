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

# --- 5. 写入硬盘 ---
echo "============================================="
echo "  即将写入目标硬盘: /dev/$STORAGE"
echo "  RouterOS 版本:    $VERSION"
if [ "$IS_DHCP" = "yes" ]; then
    echo "  网络模式:         DHCP 自动获取"
else
    echo "  网络模式:         静态 IP ($ADDRESS)"
fi
echo "  admin 密码:       $ROS_PASSWORD"
echo "============================================="
echo "正在写入 (请勿断电)..."

dd if="$IMG_PATH" of=/dev/"$STORAGE" bs=4M oflag=sync status=progress

echo "DD 写入完成！"

# --- 6. DD 后在硬盘上注入配置 ---
echo "正在扫描硬盘分区并注入配置..."
sleep 1
partprobe /dev/"$STORAGE" 2>/dev/null || true
sleep 1

mkdir -p /mnt/ros_tmp
INJECT_OK="no"

# 尝试自动发现 RW 分区
for part in /dev/"${STORAGE}"{p1,p2,p3,p4,p5,1,2,3,4,5}; do
    [ -e "$part" ] || continue
    if mount "$part" /mnt/ros_tmp 2>/dev/null; then
        if [ -d /mnt/ros_tmp/rw ]; then
            echo "找到 RW 分区: $part"

            if [ "$IS_DHCP" = "yes" ]; then
                cat > /mnt/ros_tmp/rw/autorun.scr <<EOF
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
                cat > /mnt/ros_tmp/rw/autorun.scr <<EOF
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
            cat /mnt/ros_tmp/rw/autorun.scr
            sync
            umount /mnt/ros_tmp
            INJECT_OK="yes"
            break
        else
            umount /mnt/ros_tmp 2>/dev/null || true
        fi
    fi
done

if [ "$INJECT_OK" = "no" ]; then
    echo "Warning: 未找到 RW 分区，尝试使用 offset 方式注入..."

    # 尝试多个常见 offset
    for offset in 33571840 33554432 67108864 8388608; do
        if mount -o loop,offset=$offset /dev/"$STORAGE" /mnt/ros_tmp 2>/dev/null; then
            if [ -d /mnt/ros_tmp/rw ]; then
                echo "找到 RW 分区 (offset=$offset)"

                if [ "$IS_DHCP" = "yes" ]; then
                    cat > /mnt/ros_tmp/rw/autorun.scr <<EOF
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
                    cat > /mnt/ros_tmp/rw/autorun.scr <<EOF
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
                cat /mnt/ros_tmp/rw/autorun.scr
                sync
                umount /mnt/ros_tmp
                INJECT_OK="yes"
                break
            else
                umount /mnt/ros_tmp 2>/dev/null || true
            fi
        fi
    done
fi

if [ "$INJECT_OK" = "yes" ]; then
    echo "配置注入成功！"
else
    echo "Warning: 配置注入失败，RouterOS 启动后请手动配置网络。"
fi

# --- 7. 重启 ---
echo "安装完成！3秒后重启系统..."
sleep 3
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger
