# 日常使用指南

## 环境概述

| 组件 | 说明 |
|------|------|
| 代理客户端 | Clash Verge Rev (>= 2.x) |
| 内核 | mihomo (verge-mihomo) |
| 默认混合端口 | 7897 |
| DNS 模式 | Fake-IP |
| 推荐协议 | VLESS Reality / Hysteria2 |

## 开关代理

```
开启: 托盘右键 → 系统代理 (勾选) → 重启浏览器
关闭: 托盘右键 → 系统代理 (取消勾选)
默认: 保持关闭，按需开启
```

**开关后必须重启浏览器**，浏览器缓存旧的代理状态，只刷新无效。

## 节点管理

- Clash Verge 主界面 → 代理标签 → 选择/切换节点
- 配置 → 订阅旁刷新按钮 → 更新节点列表
- 亚洲节点（JP/HK/SG）通常延迟更低

## 游戏冲突

无畏契约/Valorant 等游戏的反作弊系统（Vanguard）会扫描 Windows 系统代理设置，检测到则报网络错误。

- **打游戏前**: 关掉系统代理
- **打完需要翻墙**: 重新开启 → 重启浏览器

如果代理关了仍被检测，管理员 cmd 运行:

```cmd
sc stop clash_verge_service
sc config clash_verge_service start= demand
```

## 命令行工具

不设全局环境变量，需要时临时开：

```bash
# 终端临时 (关终端即失效)
export HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897

# Git 单次
git clone -c http.proxy=http://127.0.0.1:7897 https://github.com/xxx/yyy

# npm 单次
npm install --proxy http://127.0.0.1:7897
```

用完就删，不留残留：

```bash
git config --global --unset http.proxy
git config --global --unset https.proxy
npm config delete proxy
npm config delete https-proxy
```

## TUN 模式 (可选)

TUN 模式创建虚拟网卡接管所有流量，不依赖系统代理，最稳定但需要管理员权限。

1. 退出 Clash Verge
2. 右键 → 以管理员身份运行
3. 设置 → 开启 TUN 模式
4. 验证: `config.yaml` 中 `tun.enable: true`
