# ============================================================
# 系统代理修复脚本
# 用途: 清理代理注册表残留，重新建立干净的系统代理设置
# 用法: 管理员 PowerShell 运行 .\fix-system-proxy.ps1
# ============================================================

param(
    [int]$Port = 7897,
    [switch]$CleanOnly  # 仅清理不重新设置
)

$RegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$ConnPath = "$RegPath\Connections"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      系统代理修复" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================
# 第一步: 清理所有残留
# ============================================================
Write-Host ""
Write-Host "[1/4] 清理注册表残留..." -ForegroundColor Yellow

# 删除可能残留的代理键
@('ProxyEnable', 'ProxyServer', 'ProxyOverride', 'AutoConfigURL', 'AutoDetect') | ForEach-Object {
    Remove-ItemProperty -Path $RegPath -Name $_ -ErrorAction SilentlyContinue
    Write-Host "  删除 $_ (如果存在)"
}

# 清理 DefaultConnectionSettings 的所有代理标志位
try {
    $dcs = (Get-ItemProperty -Path $ConnPath -Name DefaultConnectionSettings).DefaultConnectionSettings
    $oldFlags = [BitConverter]::ToInt32($dcs, 4)
    # 清 Bit0(proxy) + Bit1(PAC) + Bit2(auto-detect)
    $dcs[4] = $dcs[4] -band -bnot 0x07
    Set-ItemProperty -Path $ConnPath -Name DefaultConnectionSettings -Value $dcs
    $newFlags = [BitConverter]::ToInt32($dcs, 4)
    Write-Host ("  DefaultConnectionSettings: 0x{0:X8} -> 0x{1:X8}" -f $oldFlags, $newFlags)
} catch { Write-Host "  DefaultConnectionSettings 修复失败: $_" -ForegroundColor Red }

# 同样处理 SavedLegacySettings
try {
    $sls = (Get-ItemProperty -Path $ConnPath -Name SavedLegacySettings -ErrorAction Stop).SavedLegacySettings
    $sls[4] = $sls[4] -band -bnot 0x07
    Set-ItemProperty -Path $ConnPath -Name SavedLegacySettings -Value $sls
    Write-Host "  SavedLegacySettings 已修复"
} catch { Write-Host "  SavedLegacySettings 跳过" }

# ============================================================
# 第二步: 清除环境变量
# ============================================================
Write-Host ""
Write-Host "[2/4] 清除环境变量残留..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable('HTTP_PROXY', $null, 'User')
[Environment]::SetEnvironmentVariable('HTTPS_PROXY', $null, 'User')
[Environment]::SetEnvironmentVariable('NO_PROXY', $null, 'User')
Write-Host "  已清除 HTTP_PROXY / HTTPS_PROXY / NO_PROXY"

# ============================================================
# 第三步: 通知系统刷新
# ============================================================
Write-Host ""
Write-Host "[3/4] 通知系统刷新..." -ForegroundColor Yellow
$sig = '[DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr h, int o, IntPtr b, int s);'
Add-Type -MemberDefinition $sig -Name WI -Namespace W32 -ErrorAction SilentlyContinue
[W32.WI]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null   # INTERNET_OPTION_SETTINGS_CHANGED
[W32.WI]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null   # INTERNET_OPTION_REFRESH
Write-Host "  已刷新系统代理设置"

# ============================================================
# 第四步: 重新设置 (除非 CleanOnly)
# ============================================================
if (-not $CleanOnly) {
    Write-Host ""
    Write-Host "[4/4] 重新设置系统代理 -> 127.0.0.1:$Port" -ForegroundColor Yellow
    Set-ItemProperty -Path $RegPath -Name ProxyEnable -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name ProxyServer -Value "127.0.0.1:`$Port" -Type String
    Set-ItemProperty -Path $RegPath -Name ProxyOverride -Value '<local>' -Type String

    # 更新 DefaultConnectionSettings Bit0=1
    try {
        $dcs = (Get-ItemProperty -Path $ConnPath -Name DefaultConnectionSettings).DefaultConnectionSettings
        $dcs[4] = $dcs[4] -bor 0x01
        Set-ItemProperty -Path $ConnPath -Name DefaultConnectionSettings -Value $dcs
        Write-Host "  系统代理已开启"
    } catch { Write-Host "  DefaultConnectionSettings 更新失败" -ForegroundColor Red }
} else {
    Write-Host ""
    Write-Host "[4/4] 仅清理模式 — 系统代理未重新开启" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  修复完成" -ForegroundColor Cyan
if (-not $CleanOnly) {
    Write-Host "  请重启浏览器后测试 https://google.com" -ForegroundColor Gray
}
Write-Host "========================================" -ForegroundColor Cyan
