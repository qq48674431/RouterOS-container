# RouterOS-container

MikroTik RouterOS CHR 一键安装脚本，支持 UEFI / Legacy BIOS 双模式。

---

## 版本信息

| 版本 | UEFI 镜像 | BIOS 镜像 |
|------|-----------|-----------|
| 7.20.8 | `chr-7.20.8.img` | `chr-7.20.8-legacy-bios.img` |

Release 里附带的是**精简 raw 镜像**（约 128MB 量级，适合一键 DD）。  
若把 VMware 整盘 `qemu-img convert` 成 raw，会得到约 **1GB+** 的文件，体积大、下载慢，本仓库**不采用**那种整盘包；密码与网络由安装脚本通过 `autorun.scr` 注入。

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

默认 admin 密码为 `admin`，如需自定义可在命令前加环境变量：

```bash
ROS_PASSWORD="你的密码" bash <(curl -Ls https://raw.githubusercontent.com/qq48674431/RouterOS-container/main/install.sh)
```

---

## 安装后连接

| 方式 | 默认端口 | 连接方式 |
|------|---------|---------|
| SSH | 22 | `ssh admin@服务器公网IP` |
| Winbox | 8291 | Winbox 客户端连接服务器公网 IP |
| WebFig | 80 | 浏览器访问 `http://服务器公网IP` |

默认用户名：`admin`，密码：`admin`（或安装时自定义的密码）。

> **云服务器注意**：需在安全组/防火墙放行以上端口（22、80、8291），否则无法远程连接。

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
- **维护者**：向 Release 上传镜像时请使用精简 **~128MB** 的 CHR raw，勿上传 VMware 整盘转换后的 **1GB+** img（脚本按精简镜像的 RW 偏移注入配置）
