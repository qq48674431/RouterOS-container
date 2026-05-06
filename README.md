# RouterOS CHR 一键重装

MikroTik RouterOS CHR v7.20.8 一键安装脚本，支持 UEFI / Legacy BIOS 双模式，自动识别 DHCP / 静态 IP。

---

## 一键安装命令

### 国内 VPS（走本地服务器，速度快）

```bash
bash <(curl -Ls http://124.221.155.16:8888/vps-RouterOS-container/install.sh)
```

### 海外 VPS（走 GitHub）

```bash
bash <(curl -Ls https://raw.githubusercontent.com/qq48674431/RouterOS-container/main/install.sh)
```

---

## 脚本自动完成

- 检测 **UEFI / BIOS** 启动模式，选择对应镜像
- 国内版优先从 VPS 本地下载，海外版直接走 GitHub
- 检测 **DHCP / 静态 IP**，自动配置网络
- 注入 `autorun.scr`（重命名网卡为 ether1，静态 IP 模式注入地址和网关）
- DD 写入硬盘并重启

---

## 安装后连接

| 方式 | 端口 | 连接方式 |
|------|------|---------|
| Winbox | **18291** | Winbox 客户端连接 `服务器公网IP:18291` |
| SSH | **22** | `ssh admin@服务器公网IP` |
| API | 12288 | API 接口 |

默认用户名：`admin`，密码：`admin`。

> **云服务器注意**：需在安全组/防火墙放行 **18291**（Winbox）、**22**（SSH）、**12288**（API）端口。

---

## 注意事项

- 此操作会**覆盖整个硬盘**，原系统数据将全部丢失
- 执行前请确认服务器可通过 VNC/IPMI 等方式救援
- 国内服务器推荐使用本地源命令，无需担心 GitHub 被墙
