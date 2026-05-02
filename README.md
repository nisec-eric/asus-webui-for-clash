# Clash WebUI for ASUSWRT-Merlin

ASUSWRT-Merlin 原生风格的 Clash 管理界面，集成到路由器管理页面的 Tools 菜单下。

## 前置要求

- **路由器**: ASUS RT-AX86U (或其他 HND 平台机型)
- **固件**: asuswrt-merlin 384.15+ (支持 Addons API，即 `nvram get rc_support | grep am_addons` 有输出)
- **已有 Clash/Mihomo 环境**:
  ```
  /jffs/clash/
  ├── clash              # 二进制文件 (clash 或 mihomo)，需可执行
  └── config.yaml        # 配置文件，需包含 external-controller 和 secret 配置
  ```

## 文件说明

```
/jffs/clash/                         # 部署目标目录
├── clash                            # Clash/Mihomo 二进制 (你已有)
├── config.yaml                      # 配置文件 (你已有)
├── clash_service.sh                 # 服务管理 (start/stop/restart/status)
├── clash_config.sh                  # 配置管理 (list/switch/save/logs)
├── clash.asp                        # WebUI 页面
├── install.sh                       # 安装脚本
└── uninstall.sh                     # 卸载脚本
```

## 安装

```sh
# 1. 上传文件到路由器
scp clash_service.sh clash_config.sh install.sh uninstall.sh admin@ROUTER_IP:/jffs/clash/
scp www/clash.asp admin@ROUTER_IP:/jffs/clash/clash.asp

# 2. SSH 登录路由器
ssh admin@ROUTER_IP

# 3. 设置权限并安装
cd /jffs/clash
chmod +x clash_service.sh clash_config.sh install.sh uninstall.sh
sh install.sh
```

安装完成后，打开路由器管理页面 → **Tools → Clash**。

## 卸载

```sh
sh /jffs/clash/uninstall.sh
```

卸载不会删除 clash 二进制、config.yaml 和管理脚本，只移除 WebUI 集成。

## 功能

| 功能 | 说明 |
|------|------|
| 服务控制 | Start / Stop / Restart |
| 运行状态 | 实时显示 Running/Stopped + 代理模式，5 秒自动刷新 |
| 代理模式切换 | Rule-based / Global / Direct (直连 Clash REST API) |
| 配置管理 | 列表切换、在线编辑保存、上传新配置 |
| 日志查看 | 实时日志查看、清除、自动刷新 |
| Dashboard | iframe 嵌入 Yacd / MetaCubeXD |
| 开机自启 | 可选，重启后自动启动 Clash |

## 架构

```
浏览器 (ASP 页面)
├── 实时状态/模式 ──AJAX──→ Clash REST API (:9090)
├── 服务控制 ──form POST──→ start_apply.htm → service-event → clash_service.sh
├── 大文件写入 ──SystemCmd──→ base64 decode → 文件
├── 配置列表/日志 ──AJAX──→ /www/user/clash/*.html (后端脚本生成)
└── Dashboard ──iframe──→ Yacd/MetaCubeXD
```

## config.yaml 要求

确保你的 `config.yaml` 包含以下配置：

```yaml
external-controller: 0.0.0.0:9090
secret: 'your-secret-here'
```

- `external-controller`: WebUI 和 Dashboard 通过此端口访问 Clash API
- `secret`: API 认证密钥，安装时会自动读取并保存到 WebUI 设置中
