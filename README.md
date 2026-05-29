# Campus Network Proxy Toolkit

校园网环境下的代理配置与故障排查工具集。适用于需要通过代理访问外网、同时保持国内网络正常使用的场景。

> **用途声明**: 本项目仅供教育研究和授权的网络测试使用。使用者应遵守所在网络环境的使用规定和相关法律法规。

## 快速开始

如果你刚遇到"开了代理但上不了外网"的问题，先跑这个：

```powershell
# 1. 代理核心活着吗
netstat -ano | findstr "7897.*LISTENING"

# 2. 代理能翻吗
curl -x http://127.0.0.1:7897 https://www.google.com -o NUL -w "%{http_code}"

# 3. 系统代理生效了吗
powershell -File ./scripts/test-proxy.ps1
```

- 步骤 1 无输出 → 启动 Clash Verge
- 步骤 1 有输出、步骤 2 不是 200 → 节点挂了，换节点
- 步骤 1+2 OK 但浏览器不行 → 看 [故障排查手册](docs/troubleshooting.md)

## 项目结构

```
├── README.md
├── docs/
│   ├── guide.md              # 日常使用指南
│   └── troubleshooting.md    # 故障排查手册
├── scripts/
│   ├── test-proxy.ps1        # 一键诊断脚本
│   └── fix-system-proxy.ps1  # 系统代理修复脚本
├── config/
│   ├── clash-dns.yaml        # DNS 配置模板
│   └── clash-settings.yaml   # Clash Verge 设置参考
└── .gitignore
```

## 适用环境

- Windows 10/11 + 校园网（DR.COM / 深澜 / Web 认证 等）
- Clash Verge Rev (mihomo 内核)
- VLESS Reality / Hysteria2 协议

## 核心认知

**诊断要分层，不要一上来就改配置：**

| 层级 | 测试方法 | 通 → 问题在上层 / 不通 → 问题在本层 |
|------|----------|------|
| 1. 代理核心 | `curl -x http://127.0.0.1:7897 https://google.com` | 节点或 Clash 有问题 |
| 2. 系统代理 | `Get-NetTCPConnection -LocalPort 7897` | 注册表/服务有问题 |
| 3. 浏览器 | `https://google.com` | 浏览器缓存/扩展有问题 |

**80% 的"翻不了墙"不是节点问题，是系统代理层出了问题。**

## 已知问题

- **系统代理与游戏互斥**: 无畏契约/Valorant 的反作弊系统会检测系统代理。打游戏前关掉系统代理。
- **代理被自动恢复**: Clash Verge 服务（`clash_verge_service`）可能自动开启系统代理。管理员 cmd 执行 `sc config clash_verge_service start= demand` 解决。
- **.NET 程序的 SNI 问题**: 部分 .NET 程序通过系统代理时可能因 DNS 预解析导致 SNI 丢失。TUN 模式可根本解决。

## License

MIT
