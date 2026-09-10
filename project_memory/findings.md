# 已知风险与待办

---

# Windows 侧载环境:中文用户名是硬阻塞(已解决)

## 现象

AltServer 1.7.5 登录成功,但推送 IPA 时崩在:

```
ldid.cpp(2609): _assert(): dir != NULL
```

Sideloadly v0.60 则报 `Login failed (-22410)`。

## 根因

**不是 Apple 封禁,也不是网络问题,是中文用户名。**

- 用户名 `乱码碳` → `C:\Users\乱码碳\`
- AltServer 的 Apple 组件栈与 `ldid.dll`(POSIX 风格 `opendir`/`realpath`)
  在中文路径下编码转换失败,`opendir` 返回 NULL。
- 证据:AltServer 崩溃前生成 `C:\ProgramData\AltServer\anisette-debug.txt`,
  内含实际使用的库路径 `C:\Users\乱码碳\AppData\Local\AltServer\Apple\...`。

系统 Locale 为 `zh-CN`(LCID 2052),`ACP`/`OEMCP`/`MACCP` 均为 `65001`(UTF-8),
但 MSYS 兼容层仍按 ANSI 处理 → 路径丢字符。

### 排查中被排除的干扰项

- `198.18.0.x` fake-IP:代理(0dcloud / Tailscale 双 TUN)接管默认路由所致,
  关闭后 DNS 恢复真实 Apple IP。
- 证书链 `Verify return code: 19 (self-signed certificate in certificate chain)`:
  本机信任库缺 Apple Root CA,非 MITM(实测拿到的是真 Apple 证书链)。
- `-22410` 是登录阶段错误,与安装阶段错误 `ldid.cpp` 是**不同故障点**。

## 修复

1. 新建纯 ASCII 本地管理员用户 `dev`(无密码,`PasswordRequired=False`)。
2. 建独立工作区 `C:\phosprite\`(`ipa/`、`build/`),授权 dev 完全控制。
3. IPA 移入 `C:\phosprite\ipa\Phosprite-unsigned.ipa`(全 ASCII 路径)。
4. 在 **dev 会话**中运行 AltServer(`C:\Users\dev\AppData\Local\AltServer\Apple\`
   于 21:18 成功生成完整 Apple 组件栈)。
5. 同时清理乱码碳会话残留的 AltServer 实例(会抢占 2775 端口与设备通道)。

结果:**AltServer 成功推送 IPA 到 iPad**,`ldid.cpp` 断言消失。

## 环境事实(供后续 CI/脚本引用)

- `dev` 用户 / 工作区 `C:\phosprite\`
- AltServer 1.7.5.0(x86)位于 `C:\Program Files (x86)\AltServer\`
- 证书:`C:\ProgramData\AltServer\Certificates\44MFR9W6NM.p12`(Team ID `44MFR9W6NM`)
- ADI:`C:\ProgramData\Apple Computer\iTunes\adi\`(系统级共享,删后可重新生成)
- AltServer RPC 端口每次启动随机(实测乱码碳会话 2775、dev 会话 14031/10839)
- Apple DLL 与 AltServer 均为 **32 位**;检查脚本需用 32 位 Python

---

## AltStore 免费账号侧载的代价(用户已确认接受)

用户选择 AltStore 免费账号路线而非方案 §10.2 原本的付费开发者账号路线。
以下代价将在 P0-D / P0-E 真机验证时实际撞上:

### 1. 7 天重签周期

免费账号签发的证书 7 天失效,需在 iPad 上通过 AltStore 重新签名。
P0-D 是"未经 UI 重构的 Pixelorama 真实跑到 iPad 上"的 spike,需要反复重装,
这个周期会明显拖慢迭代。

### 2. 无 increased_memory_limit entitlement

免费账号拿不到内存豁免。Pixelorama 是完整编辑器,很容易撞内存墙。
方案 §16 明确把"iPad 普通项目频繁 OOM"列为 P0 级阻塞 bug ——
若 P0 Gate 的完整闭环(新建项目→绘制→多图层→多帧→播放动画→保存)
在免费签名下 OOM,则 AltStore 路线在 P0 阶段即不可行。

### 3. 嵌套 framework 重签风险

Godot iOS 产物含嵌套动态库:

- `Phosprite.app/Frameworks/libswift_Concurrency.dylib`
- `MoltenVK.xcframework`(在导出的 Xcode 工程内)

AltStore 重签时若处理不当,会出现签名校验失败或启动即崩。
此点尚未在真机验证。

### 4. 侧载本身需要额外条件

- iPad 需开启开发者模式
- Windows 与 iPad 需在同一局域网(或 USB 连接)
- AltStore 首次安装需要用 AltServer 通过 USB 装进去

---

## P0-D 真机验收(进行中)

淘汰项说明:第 1、2 项已通过(见本文档顶部"中文用户名"一节)。

| # | 验收项 | 状态 |
|---|---|---|
| 1 | AltServer 重签 `Phosprite-unsigned.ipa` | ✅ 通过 |
| 2 | 真机安装成功(嵌套 framework 未触发重签失败) | ✅ 通过 |
| 3 | App 启动 | ⬜ 待验证 |
| 4 | Shader / Canvas 正常 | ⬜ 待验证 |
| 5 | Touch Event 到达 | ⬜ 待验证 |
| 6 | Pencil Event 到达(Apple Pencil 2) | ⬜ 待验证 |
| 7 | 基础 Tool 可运行 | ⬜ 待验证 |
| 8 | 无 platform-only crash | ⬜ 待验证 |
| 9 | 是否 OOM(免费账号无 increased_memory_limit) | ⬜ 待验证 |

第 1、2 项通过的证据:

- AltServer 在 dev 会话生成完整 Apple 组件栈
  (`C:\Users\dev\AppData\Local\AltServer\Apple\`,21:18);
- 用户确认 AltStore 安装成功、开发者模式已开、IPA 推送成功;
- `ldid.cpp(2609)` 断言不再出现。

第 2 项的意义:嵌套 framework(`libswift_Concurrency.dylib` / MoltenVK)
**未**导致重签失败 —— 该风险已排除。

---

## P0-E Storage Spike(未开始)

需验证:Files Picker、`.pxo` Open/Save/Save As、重新打开、PNG Export、
overwrite、Files Provider、App background/foreground 后文件状态。

前置:先通过 P0-D。
