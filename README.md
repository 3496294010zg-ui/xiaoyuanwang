# 校园网代理工具箱

校园网翻墙配置与故障排查，从零到能用。

> 适用：Windows 10/11 + 校园网 | 需要：Clash Verge + 机场订阅

---

## 这个项目解决什么问题

校园网用代理翻墙时经常遇到：明明开了 Clash，系统代理也勾了，浏览器就是打不开 Google。或者关掉代理后游戏还报"检测到代理"。

80% 的情况不是节点问题，是 **Windows 系统代理层出了 bug**。本项目提供一键诊断脚本 + 修复脚本 + 从零搭建指南。

---

## 从零开始（新手 10 分钟搞定）

### 第一步：下载 Clash Verge

去 [clash-verge-rev 发布页](https://github.com/clash-verge-rev/clash-verge-rev/releases) 下载最新版 `Clash.Verge_x64-setup.exe`，安装。

### 第二步：获取机场订阅

你需要一个机场（代理服务商）提供节点。选机场的几个标准：

- 支持 **VLESS Reality** 或 **Hysteria2** 协议（校园网 DPI 识别不了这两个）
- 有日韩/香港节点（延迟低）
- 支持按量付费（不要一上来买年卡）

拿到订阅链接后，Clash Verge → 配置 → 新建 → 粘贴订阅 URL → 下载。

### 第三步：确认端口

打开 Clash Verge → 设置 → 端口设置，记下混合端口号。默认是 **7897**（不是 7890）。

本项目的脚本和文档默认端口是 7897，如果你的不是，用的时候把端口号改成你的。

### 第四步：日常使用

```
需要翻墙时:
  1. 右键 Clash 托盘 → 系统代理 (勾选)
  2. 重启浏览器 (必须！)

不需要时:
  右键 Clash 托盘 → 系统代理 (取消勾选)
  默认保持关闭
```

---

## 遇到问题了？

### 快速诊断（复制粘贴到 PowerShell）

```powershell
# 先跑这个，30 秒定位问题
powershell -File ./scripts/test-proxy.ps1
```

或者手动跑：

```powershell
# 1. Clash 在运行吗
netstat -ano | findstr "7897.*LISTENING"

# 2. 代理核心能翻吗
curl -x http://127.0.0.1:7897 https://www.google.com -o NUL -w "%{http_code}"

# 3. 谁在用代理
powershell "Get-NetTCPConnection -LocalPort 7897 -EA SilentlyContinue | % { Get-Process -Id `$_.OwningProcess -EA SilentlyContinue | select ProcessName, Id }"
```

根据结果判断：

| 步骤 1 | 步骤 2 | 步骤 3 | 问题在哪 |
|--------|--------|--------|----------|
| 无输出 | — | — | Clash 没启动 |
| 有输出 | 000/超时 | — | 节点挂了，换节点 |
| 有输出 | 200 | 无进程连接 | 系统代理没生效 → 跑修复脚本 |
| 有输出 | 200 | 有连接 | 代理正常 → 重启浏览器 |

### 系统代理修复

关掉代理但关不掉、或开了代理但不生效：

```powershell
# 管理员 PowerShell 运行
powershell -File ./scripts/fix-system-proxy.ps1
```

- 不带参数：清理残留 + 重新设置系统代理
- `-CleanOnly`：只清理残留，不重新设置（游戏前用）
- `-Port 7897`：指定端口号

### 详细排查

看 [docs/troubleshooting.md](docs/troubleshooting.md)，覆盖了节点层、系统代理层、DNS 层、SNI 问题的完整排查。

---

## 常见场景

### "开了代理但浏览器打不开外网"

```powershell
# 三步走
1. 检查 Clash 是不是真的在运行 → netstat -ano | findstr "7897.*LISTENING"
2. 测试代理核心能不能翻 → curl -x http://127.0.0.1:7897 https://google.com
3. 如果 1 和 2 都 OK → 托盘右键关代理 → 等 3 秒 → 再开 → 重启浏览器
```

### "打游戏（无畏契约/LOL）报检测到代理"

```powershell
# 关掉系统代理
右键 Clash 托盘 → 系统代理 (取消勾选)

# 如果关了还不行，以管理员运行：
powershell -File ./scripts/fix-system-proxy.ps1 -CleanOnly
```

### "国内网站也变慢了"

检查 Clash 是不是切到了全局模式，改回**规则模式**。如果 DNS 配置被改过，用 [config/clash-dns.yaml](config/clash-dns.yaml) 参考恢复。

### "命令行工具（git/npm/curl）代理不生效"

不要设全局环境变量（会绑架所有流量）。用的时候临时加：

```bash
# 终端里的临时做法（关终端就没了）
export HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897

# git 单次代理
git clone -c http.proxy=http://127.0.0.1:7897 https://github.com/xxx/yyy

# npm 单次代理
npm install --proxy http://127.0.0.1:7897
```

---

## 项目文件说明

```
├── README.md                     ← 你在看的这个
├── docs/
│   ├── guide.md                  ← 日常使用参考
│   └── troubleshooting.md        ← 完整排查手册
├── scripts/
│   ├── test-proxy.ps1            ← 一键诊断 (6项检查+残留扫描)
│   └── fix-system-proxy.ps1      ← 注册表清理+代理重置
├── config/
│   ├── clash-dns.yaml            ← DNS 配置参考
│   └── clash-settings.yaml       ← Clash Verge 设置参考
└── .gitignore
```

---

## 核心原理

Windows 代理有三层，互不统属，这就是为什么"明明开了代理却没用"：

```
浏览器 ← WinINET API → 注册表 Internet Settings (你能看到的)
浏览器 ← WinHTTP API → netsh 设置 (独立的，需管理员)
.NET程序← .NET WebProxy → 自己的封装 (行为可能不同)
```

而且注册表里 `ProxyEnable=1` 不算数，Windows 底层读的是一个二进制 blob（`DefaultConnectionSettings`），那个 blob 的标志位才是真的。本项目脚本会直接修这个 blob。

---

## License

MIT — 随便用，改了不用通知我。
