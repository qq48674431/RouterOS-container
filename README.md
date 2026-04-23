# RouterOS-container

MikroTik RouterOS CHR 一键安装脚本，支持 UEFI / Legacy BIOS 双模式。

---

## 版本信息

| 版本 | UEFI 镜像 | BIOS 镜像 |
|------|-----------|-----------|
| 7.20.8 | `chr-7.20.8.img` | `chr-7.20.8-legacy-bios.img` |

---

## 安装步骤

### 前置要求

- 一台 Linux VPS（Debian / Ubuntu / CentOS 等均可）
- root 权限
- 服务器能访问 GitHub（国外网络）

### 方法一：一键脚本安装（推荐）

脚本全自动处理，无需手动操作：
- 自动检测 **UEFI / BIOS** 启动模式，选择对应镜像
- 自动识别 **DHCP / 静态 IP**，DHCP 服务器配置 DHCP Client，静态服务器保留原 IP

SSH 登录服务器后，执行以下命令：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/qq48674431/RouterOS-container/main/install.sh)
```

---

## 安装后连接

| 方式 | 地址 |
|------|------|
| SSH | `ssh admin@你的服务器IP` |
| Winbox | 使用 Winbox 客户端连接服务器 IP |
| WebFig | 浏览器访问 `http://你的服务器IP` |

默认用户名：`admin`，密码已内置于镜像中。

---

## 脚本工作流程

```
检测启动模式 (UEFI/BIOS) → 选择对应镜像
        ↓
从 GitHub 下载镜像
        ↓
检测网络模式 (DHCP/静态)
  ├─ DHCP  → 配置 DHCP Client 自动获取
  └─ 静态  → 保留当前 IP/网关写入配置
        ↓
挂载镜像 → 注入 autorun.scr
        ↓
dd 写入物理硬盘
        ↓
自动重启 → RouterOS 启动并应用配置
```

---

## 注意事项

- 此操作会**覆盖整个硬盘**，原系统数据将全部丢失
- 执行前请确认服务器可通过 VNC/IPMI 等方式救援，避免失联后无法恢复
- 国内服务器如果无法访问 GitHub，需先配置代理或使用加速镜像
