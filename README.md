# RouterOS-container

MikroTik RouterOS CHR 一键安装脚本，支持 UEFI / Legacy BIOS 双模式，自动识别 DHCP / 静态 IP。

---

## 版本信息

| 版本 | UEFI 镜像 | BIOS 镜像 |
|------|-----------|-----------|
| 7.20.8 | `chr-7.20.8.img` | `chr-7.20.8-legacy-bios.img` |

---

## 一键安装

SSH 登录服务器后，执行以下命令：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/qq48674431/RouterOS-container/main/install.sh)
```

自定义密码（默认 `admin`）：

```bash
ROS_PASSWORD="你的密码" bash <(curl -Ls https://raw.githubusercontent.com/qq48674431/RouterOS-container/main/install.sh)
```

### 脚本自动完成

- 检测 **UEFI / BIOS** 启动模式，选择对应镜像
- 检测 **DHCP / 静态 IP**，自动配置网络
- 注入 `autorun.scr` 配置（密码、网络、服务端口等）
- DD 写入硬盘并重启

---

## 安装后连接

| 方式 | 端口 | 连接方式 |
|------|------|---------|
| Winbox | **18291** | Winbox 客户端连接 `服务器公网IP:18291` |
| SSH | **22** | `ssh admin@服务器公网IP` |
| API | 12288 | API 接口 |

默认用户名：`admin`，密码：`admin`（或安装时自定义的密码）。

> **云服务器注意**：需在安全组/防火墙放行 **18291**（Winbox）、**22**（SSH）、**12288**（API）端口。

---

## 安装后默认配置

```
/ip service
  ftp       = 关闭
  telnet    = 关闭
  www       = 关闭
  api-ssl   = 关闭
  ssh       = 端口 22
  winbox    = 端口 18291
  api       = 端口 12288

/system clock   = Asia/Shanghai
/system identity = 镜像文件名
```

---

## 注意事项

- 此操作会**覆盖整个硬盘**，原系统数据将全部丢失
- 执行前请确认服务器可通过 VNC/IPMI 等方式救援，避免失联后无法恢复
- 国内服务器如果无法访问 GitHub，需先配置代理或使用加速镜像
