# ============================================================
# 代理状态一键诊断脚本
# 用法: powershell -File test-proxy.ps1
# ============================================================

$ProxyPort = "7897"
$ProxyAddr = "127.0.0.1:`$ProxyPort"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      代理状态诊断" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. 注册表 ----
Write-Host "[1/6] 注册表系统代理:" -ForegroundColor Yellow
try {
    $pe = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable).ProxyEnable
    $ps = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer).ProxyServer
    Write-Host "  ProxyEnable: $pe"
    Write-Host "  ProxyServer: $ps"
} catch { Write-Host "  注册表项缺失" }

# ---- 2. DefaultConnectionSettings 标志 ----
Write-Host "[2/6] DefaultConnectionSettings 标志:" -ForegroundColor Yellow
try {
    $dcs = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections' -Name DefaultConnectionSettings).DefaultConnectionSettings
    $f = [BitConverter]::ToInt32($dcs, 4)
    Write-Host "  Bit0(proxy): $($f -band 1)  Bit1(PAC): $(($f -band 2)/2)  Bit2(auto): $(($f -band 4)/4)"
    if ($f -band 1) { Write-Host "  系统代理: 已开启" -ForegroundColor Green }
    else { Write-Host "  系统代理: 未开启" -ForegroundColor Red }
} catch { Write-Host "  读取失败" }

# ---- 3. 进程 ----
Write-Host "[3/6] Clash 进程:" -ForegroundColor Yellow
$m = Get-Process -Name "verge-mihomo" -ErrorAction SilentlyContinue
if ($m) { Write-Host "  verge-mihomo 运行中 (PID $($m.Id))" -ForegroundColor Green }
else { Write-Host "  verge-mihomo 未运行!" -ForegroundColor Red }

$port = netstat -ano 2>$null | Select-String "$ProxyPort.*LISTENING"
if ($port) { Write-Host "  端口 $ProxyPort 监听中" -ForegroundColor Green }
else { Write-Host "  端口 $ProxyPort 未监听!" -ForegroundColor Red }

# ---- 4. 国内直连 ----
Write-Host "[4/6] 国内直连:" -ForegroundColor Yellow
try {
    $r = Invoke-WebRequest -Uri "https://www.baidu.com" -TimeoutSec 5 -UseBasicParsing
    Write-Host "  百度: OK ($($r.StatusCode))" -ForegroundColor Green
} catch { Write-Host "  百度: FAIL — 网络可能不通" -ForegroundColor Red }

# ---- 5. 代理翻墙 ----
Write-Host "[5/6] 代理翻墙:" -ForegroundColor Yellow
try {
    $p = New-Object System.Net.WebProxy("http://127.0.0.1:$ProxyPort")
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = $p
    $wc.DownloadString('https://www.google.com') | Out-Null
    Write-Host "  Google (显式代理): OK" -ForegroundColor Green
} catch { Write-Host "  Google (显式代理): FAIL — 节点可能挂了" -ForegroundColor Red }

# ---- 6. 代理连接追踪 ----
Write-Host "[6/6] 哪些应用在走代理:" -ForegroundColor Yellow
$conns = Get-NetTCPConnection -LocalPort $ProxyPort -State Established -ErrorAction SilentlyContinue
if ($conns) {
    $conns | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        if ($proc) { Write-Host "  $($proc.ProcessName) (PID $($proc.Id))" }
    } | Sort-Object -Unique
} else { Write-Host "  无连接 — 系统代理可能未生效" }

# ---- 残留检查 ----
Write-Host ""
Write-Host "=== 残留检查 ===" -ForegroundColor Cyan
if (Test-Path 'HKCU:\Environment') {
    $hp = (Get-ItemProperty 'HKCU:\Environment' -Name HTTP_PROXY -EA SilentlyContinue).HTTP_PROXY
    $hs = (Get-ItemProperty 'HKCU:\Environment' -Name HTTPS_PROXY -EA SilentlyContinue).HTTPS_PROXY
    if ($hp) { Write-Host "  WARN: HTTP_PROXY 环境变量残留: $hp" -ForegroundColor Yellow }
    else { Write-Host "  OK: 无 HTTP_PROXY 残留" -ForegroundColor Green }
    if ($hs) { Write-Host "  WARN: HTTPS_PROXY 环境变量残留: $hs" -ForegroundColor Yellow }
    else { Write-Host "  OK: 无 HTTPS_PROXY 残留" -ForegroundColor Green }
}
$git = git config --global --get http.proxy 2>$null
if ($git) { Write-Host "  WARN: Git proxy 残留: $git" -ForegroundColor Yellow }
else { Write-Host "  OK: 无 Git proxy 残留" -ForegroundColor Green }
$npmProxy = npm config get proxy 2>$null
if ($npmProxy -match "7897") { Write-Host "  WARN: npm proxy 残留: $npmProxy" -ForegroundColor Yellow }
else { Write-Host "  OK: 无 npm proxy 残留" -ForegroundColor Green }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  诊断完成" -ForegroundColor Cyan
Write-Host "  如果 Google (显式代理) OK → 节点正常" -ForegroundColor Gray
Write-Host "  浏览器问题 → 重启浏览器再试" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
