# 已知风险与待办

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

## 待验证(需要真机)

以下 P0-D 验收项**均未验证**,因为手上没有可用的 iPad 连接:

1. AltStore 能否成功重签 `Phosprite-unsigned.ipa`
2. 真机安装是否成功(嵌套 framework 是否触发重签失败)
3. App 是否启动
4. Shader / Canvas 是否正常
5. Touch Event 是否到达
6. Pencil Event 是否到达(Apple Pencil 2)
7. 基础 Tool 是否可运行
8. 是否无 platform-only crash
9. 是否 OOM

## P0-E Storage Spike(未开始)

需验证:Files Picker、`.pxo` Open/Save/Save As、重新打开、PNG Export、
overwrite、Files Provider、App background/foreground 后文件状态。

前置:先通过 P0-D。
