# 故障排查手册

## 优先流程 (30 秒定位)

```
1. 代理核心活着？
   tasklist | findstr "verge-mihomo"
   netstat -ano | findstr "7897.*LISTENING"
   → 无输出 = Clash 没运行

2. 核心能翻吗？(绕过系统设置)
   curl -x http://127.0.0.1:7897 https://www.google.com -o NUL -w "%{http_code}"
   → 200 = 核心正常 | 000/超时 = 节点问题

3. 系统代理生效吗？
   powershell "Get-NetTCPConnection -LocalPort 7897 -EA SilentlyContinue | %{ Get-Process -Id $_.OwningProcess -EA SilentlyContinue | select ProcessName,Id }"
   → 有进程连接 = 系统代理正常 | 无连接 = 系统代理层问题

4. 浏览器不行？
   → 完全关闭浏览器 → 重新打开
   → 托盘 → 系统代理 → 关 → 等3秒 → 开
```

**核心原则**: `curl -x` 能翻 = 代理核心没问题，问题一定在系统代理层或浏览器层。

---

## 症状速查

| 现象 | 章节 |
|------|------|
| curl -x Google 超时 | [节点层](#节点层) |
| curl -x 能翻但浏览器不行 | [系统代理层](#系统代理层) |
| 代理关了又自动开 | [自动恢复](#代理被自动恢复) |
| 国内网站出问题 | [DNS 层](#dns-层) |
| .NET/PowerShell 翻不了 | [SNI 问题](#sni-问题) |

---

## 节点层

```powershell
# 逐个测试外网
curl -x http://127.0.0.1:7897 https://www.google.com -o NUL -w "Google: %{http_code}\n"
curl -x http://127.0.0.1:7897 https://www.youtube.com -o NUL -w "YouTube: %{http_code}\n"
curl -x http://127.0.0.1:7897 https://www.github.com -o NUL -w "GitHub: %{http_code}\n"
# 全挂 → 换节点或检查机场
```

## 系统代理层

### 诊断

```powershell
# 注册表
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable

# DefaultConnectionSettings 标志位 (比注册表更权威)
$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections'
$dcs = (Get-ItemProperty $path DefaultConnectionSettings).DefaultConnectionSettings
$f = [BitConverter]::ToInt32($dcs, 4)
"Bit0(proxy): $($f -band 1)  Bit1(PAC): $(($f -band 2)/2)  Bit2(auto): $(($f -band 4)/4)"
# 正常开启状态: Bit0=1, Bit1=0, Bit2=0

# 谁真的在用代理 (最可靠)
Get-NetTCPConnection -LocalPort 7897 -EA SilentlyContinue | % {
    Get-Process -Id $_.OwningProcess -EA SilentlyContinue | select ProcessName, Id
}
```

### 常见故障

**Bit1=1 (PAC 标志残留)**: Windows 尝试用 PAC 但文件不存在 → 全部回退直连。

```powershell
$dcs = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections' DefaultConnectionSettings).DefaultConnectionSettings
$dcs[4] = $dcs[4] -band -bnot 0x06
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections' DefaultConnectionSettings $dcs
```

### 修复流程

1. Clash 托盘 → 系统代理 → 关 → 等 3 秒 → 开
2. 重启浏览器
3. 还不行 → 清除注册表残留 (见 [fix-system-proxy.ps1](../scripts/fix-system-proxy.ps1))

### 浏览器特殊处理

如果 `Get-NetTCPConnection` 显示 Steam/OneDrive 在走代理但浏览器不行：
- 任务管理器杀掉所有浏览器进程 → 重新打开
- `chrome://net-internals/#dns` → Clear host cache
- 禁用 VPN/代理类浏览器扩展

### 代理被自动恢复

**原因**: `clash_verge_service` 服务以 SYSTEM 权限运行，自行恢复系统代理。

**修复** (管理员 cmd):
```cmd
sc stop clash_verge_service
sc config clash_verge_service start= demand
```

确认 `verge.yaml` 中:
- `enable_system_proxy: false`
- `enable_proxy_guard: false`

---

## DNS 层

不要随意改以下参数，否则国内 DNS 解析异常：
- `respect-rules`
- `use-hosts`
- `use-system-hosts`

如已改动，恢复默认: `respect-rules: false`, `use-hosts: false`, `use-system-hosts: false`

---

## SNI 问题

**症状**: `curl -x` 域名通但 .NET/PowerShell 程序不通。

**原因**: 程序先解析 DNS 得 IP → 用 IP 发 CONNECT → Windows Schannel 对 IP 不发 SNI → Google CDN 拒绝。

```powershell
# 验证
curl -x http://127.0.0.1:7897 https://www.google.com     # 应 200
curl -x http://127.0.0.1:7897 https://157.240.7.20/     # 应超时 (无 SNI)
```

**修复**: TUN 模式 (需管理员) 或浏览器用 SwitchyOmega 扩展。

---

## Windows 代理架构

```
应用层
  ├─ WinINET API  → 注册表 Internet Settings
  ├─ WinHTTP API  → netsh 设置 (需管理员，独立于 WinINET)
  └─ .NET WebProxyWrapper → 有自己的封装，行为可能不同
```

- **DefaultConnectionSettings 二进制 blob** 是权威来源，注册表 `ProxyEnable` 只是 UI 值
- PAC/AutoConfigURL 未清理是常见故障源
- 开关系统代理后必须重启浏览器
