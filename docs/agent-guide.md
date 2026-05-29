# AI Agent 代理操作指引

本项目配套了诊断脚本和修复脚本，但如果你在用 **Claude Code**或其他 AI 编程助手，可以直接让 Agent 帮你排查和修复代理问题，不用手动跑命令。

---

## 给 Agent 的提示词

把下面这段话直接发给 Claude Code 就行：

### 场景 1：代理翻不了墙

```
帮我检查代理问题。先跑一遍完整诊断，告诉我问题在哪一层，然后帮我修好。

要求：
1. 不要改 Clash 的 DNS 配置（会影响国内网站）
2. 修好后确认系统代理是关闭的（不要常开，会影响游戏）
3. 如果有环境变量残留（HTTP_PROXY 等）帮我清掉
4. 修复过程中不要影响正常网络
```

Agent 会执行的操作：
1. 检查 Clash 进程 + 端口
2. `curl -x` 测试代理核心
3. 检查 DefaultConnectionSettings 标志位
4. 扫描 HTTP_PROXY/Git/npm 残留
5. 如果系统代理有问题→修注册表 blob
6. 如果有残留→清理
7. 输出最终状态报告

### 场景 2：游戏报"检测到代理"

```
帮我彻底关掉系统代理，确保游戏（无畏契约）不会检测到。

要求：
1. 清理所有代理注册表键
2. 修复 DefaultConnectionSettings 二进制 blob
3. 清除所有环境变量/工具代理残留
4. 确认 Clash 服务不会自动恢复代理
5. 不要影响 Clash 核心运行（只要系统代理关了就行）
```

### 场景 3：日常诊断（不改配置）

```
帮我检查一下代理状态，只看不修。
```

### 场景 4：Github/Git 操作需要走代理

```
我要 push 代码到 GitHub，校园网直连不了，帮我走代理。
用完记得清理 git proxy 配置，不要残留。
```

---

## Agent 会用到哪些能力

| 能力 | 用途 |
|------|------|
| Bash (PowerShell) | 跑诊断命令、修改注册表 |
| Read | 读 Clash 配置文件 |
| Edit/Write | 修注册表、改配置 |
| Grep | 搜索残留项 |

Agent 不需要管理员权限就能做大部分操作。只有两个需要管理员：
- 设置 WinHTTP 代理（`netsh winhttp`）
- 停用 Clash 服务（`sc stop clash_verge_service`）

---

## 排查知识（Agent 决策树）

Agent 应该按这个顺序思考，这跟 [troubleshooting.md](troubleshooting.md) 对应：

```
收到"代理有问题"报告
  │
  ├─ 检查 Clash 进程 + 端口 7897
  │   └─ 不存活 → "先启动 Clash Verge"
  │
  ├─ curl -x 测试代理核心
  │   └─ 超时 → "节点挂了，换节点" (Agent 到此为止)
  │
  ├─ Get-NetTCPConnection 看谁在用代理
  │   └─ 无连接 → 系统代理层问题
  │       ├─ 检查 DefaultConnectionSettings blob 标志位
  │       ├─ 检查 AutoConfigURL/PAC 残留
  │       ├─ 修复 blob → 刷新 WinINET
  │       └─ 提示"重启浏览器"
  │
  ├─ 检查环境变量残留
  │   ├─ HTTP_PROXY/HTTPS_PROXY → 删除
  │   ├─ git http.proxy → 删除
  │   └─ npm proxy → 删除
  │
  └─ 输出最终报告
```

---

## 关键约束（Agent 必须遵守）

1. **不要改 Clash DNS 配置** — `respect-rules`、`use-hosts`、`use-system-hosts` 三个参数改动会导致国内网站 DNS 异常
2. **不要设全局 HTTP_PROXY** — 绑架所有 CLI 工具流量，且 Claude Code 不需要（Anthropic API 直连可达）
3. **修完关掉系统代理** — 游戏（Valorant）反作弊会检测
4. **git/npm 代理用完就删** — `--unset` / `delete`，不残留
5. **开关代理后提醒重启浏览器** — 浏览器缓存旧状态

---

## Agent 常用命令速查

```powershell
# 诊断
tasklist | findstr "verge-mihomo"
netstat -ano | findstr "7897.*LISTENING"
curl -x http://127.0.0.1:7897 https://www.google.com -o NUL -w "%{http_code}"

# DefaultConnectionSettings 标志位 (Agent 最常用)
$dcs = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections' DefaultConnectionSettings).DefaultConnectionSettings
$f = [BitConverter]::ToInt32($dcs, 4)
# Bit0=proxy Bit1=PAC Bit2=auto-detect

# 清理残留
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' AutoConfigURL -EA SilentlyContinue
[Environment]::SetEnvironmentVariable('HTTP_PROXY', $null, 'User')
git config --global --unset http.proxy
npm config delete proxy

# 刷新系统代理
Add-Type -MemberDefinition '[DllImport("wininet.dll")]public static extern bool InternetSetOption(IntPtr h,int o,IntPtr b,int s);' -Name W -Namespace W32
[W32.W]::InternetSetOption([IntPtr]::Zero,39,[IntPtr]::Zero,0)
```
