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

| # | 验收项 | 状态 | 依据 |
|---|---|---|---|
| 1 | AltServer 重签 `Phosprite-unsigned.ipa` | ✅ 通过 | AltServer 完成重签并推送 |
| 2 | 真机安装成功(嵌套 framework 未触发重签失败) | ✅ 通过 | 用户确认装到 iPad |
| 3 | App 启动 | ✅ 通过 | 用户确认可启动 |
| 4 | Shader / Canvas 正常 | ✅ 通过 | 用户确认界面显示正常 |
| 5 | Touch Event 到达 | ✅ 通过 | 用户确认能绘制(触摸绘制成立) |
| 6 | Pencil Event 到达(Apple Pencil 2) | ⬜ 待验证 | 需 Pencil 专测 |
| 7 | 基础 Tool 可运行 | ✅ 通过 | 用户确认能绘制 |
| 8 | 无 platform-only crash | ✅ 通过 | 用户确认无崩溃 |
| 9 | 是否 OOM(免费账号无 increased_memory_limit) | ⬜ 待验证 | 需较大项目压力测试 |

### 已排除的风险

- **嵌套 framework 重签**:`libswift_Concurrency.dylib` / MoltenVK
  未导致重签失败或启动即崩。
- **iOS 版 Shader 兼容**:渲染正常,无平台专有图形问题。
- **基础输入链路**:触摸事件到达并驱动绘制。

### 已完成的验证(用户实测)

- 内存压力测试:1024×1024 画布 / 5 帧,**无 OOM**。免费签名下
  该规模可用,`increased_memory_limit` 缺失在 P0 规模暂未构成阻塞。
- P0 Gate 闭环:新建 → 绘制 → 保存 `.pxo` → 重启 App → 打开 → 导出 PNG,
  **业务链路全部走通**。

### 仍待验证

- **Apple Pencil 2 输入**:厂商 Pencil 事件与手指事件是否都被正确接收、
  是否存在指针类型识别问题(方案 §6.1 Input Adapter 的直接依据)。

### 验证环境

- 设备:iPad(UDID `00008103-001948500AE9401E`)
- 签名:AltStore 免费账号,Team ID `44MFR9W6NM`
- 产物:`C:\phosprite\ipa\Phosprite-unsigned.ipa`
  (SHA256 `c3628e83d0fac5631fe4ea98e1c7735354117692fa99926b23436d26f2c1bc6f`)

---

## P0-E Storage:三个实测缺陷(阻塞 P0 Gate)

用户在真机上走通保存/打开/导出后报告三个问题,均已定位根因:

### 缺陷 1:默认导出/保存目录在 iOS 上无效

```gdscript
# src/Classes/Project.gd:166-171
if OS.get_name() == "Web":
    export_directory_path = "user://"
else:
    export_directory_path = Global.config_cache.get_value(
        "data", "current_dir", OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
    )
```

`OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)` 在 iOS 上不返回沙箱 Documents,
而是空串/无效路径 → 用户看到"默认目录是 iOS private 目录,无写入权限"。

同一错误默认值在 `src/UI/Dialogs/ExportDialog.gd:318` 重复出现。

### 缺陷 2:`user://` 在 iPad Files app 中不可见

```ini
# export_presets.cfg (preset.9 / iOS)
user_data/accessible_from_files_app=false
user_data/accessible_from_itunes_sharing=false
```

iOS 上 `user://` 映射到 App 沙箱 `Documents/`。上述两项为 `false` 时,
该目录既不出现在 Files app,也不通过 iTunes 共享暴露 →
用户看到"导出的图片没有在相册/Files 中显示"。

### 缺陷 3:文件名输入框在切换窗口后被清空

`ExportDialog.gd` 的 `path_line_edit.text` 每次 `show_tab()` 时按
`export_directory_path.path_join(project.file_name)` 重建,
而 `export_directory_path` 变更后未持有用户已输入的 `project.file_name`,
切回窗口即回退为默认值。

### 相关既有事实(调研结论)

- `src/` 下 GDScript **无任何 iOS 分支**;`OS.get_name()` 判断只有
  `"Web"`、`"Android"`(以及 `OS.has_feature("mobile")` 间接覆盖)。
- 方案 §10.2 要求的 `UIDocumentPicker` / security-scoped URL /
  atomic safe save **均未实现**,属于 P0 尚未交付项。
- `Mobile` 平台唯一命中点是 `Global.gd:903-904`:
  `if OS.is_sandboxed() or OS.has_feature("mobile"): use_native_file_dialogs = true`。

### P0 Gate 判定

方案 §11 原文要求闭环终点为"**导出 PNG 到 iPad Files**"。
当前导出落在沙箱、Files/相册不可见 → **P0 Gate 判定未通过**。
需先完成最小 storage 修复(默认目录 + Files 可见性)再复验。

### 修复策略(用户已确认:最小修复优先)

先做不引入 Native Bridge 的最小修复并验证文件可见性,
完整 `UIDocumentPicker` + security-scoped URL 视验证结果再定。

### 修复进展(GPT-006 审查后)

上述三个缺陷已修复并通过 GPT 审查:
**GPT-006 裁决 `VERDICT: PASS` / `S1 PASS` / `CLOSE: NO`**。

唯一阻塞项是 **iPad 真机复验**:iOS 分支在 Windows 开发机上不可执行,
目前只有源码断言 + 策略函数直调证据,不能把 "iOS build success"
当作 "iOS storage behavior validated"。

复验产物与六项最小 Gate 见会话内交接单
`phosprite-p0e-device-verification-handoff.md`。

---

## 契约测试框架的三处假通过缺陷(已修复)

P0-E 实现期发现,**套件绿灯不可信**,是 P0 Gate 复验的前置阻塞:

### 1. 协程测试被截断(`tests/runner.gd`)

```gdscript
if result is Signal:
    await result
```

GDScript 协程返回 **`GDScriptFunctionState`,不是 `Signal`**。
因此每个含 `await` 的测试都在第一个 `await` 处被截断,
**其后的断言从不执行,套件仍报 ok**。

修复:无条件 `await`(`await` 普通值原样返回)。

### 2. 中途崩溃的测试被报成通过(`tests/test_base.gd`)

测试体若在首个断言前因运行时错误中止,返回值与通过时**完全相同**,无法区分。

修复:新增 `assertions` 计数,每个 check 递增;`runner.gd` 在计数为 0 时判失败。

### 3. pxo 往返测试的 fixture 自相矛盾(`tests/integration/test_pxo_round_trip.gd`)

直接赋值 `project.size` 调整画布,但 **cel 图像尺寸不随之改变** ——
编辑器正常流程不会产生这种状态,存档因此自相矛盾。

修复:改走 `DrawingAlgos.resize_canvas()`,并按真实结构
`reopened.frames[0].cels[0]` 读回。

### 影响

修复前套件 29 项"全绿"但含假通过;修复后 41 项 0 failures,
**本次绿灯是首次可信绿灯**。

**边界**:GPT 已裁决此次测试框架修改为 `ACCEPTED` 的
verification-enabling amendment,但明确记录——
今后不得以"改善测试"为由普遍扩大测试框架范围;
本次成立是因为发现了能使当前 Gate 假通过的具体缺陷。
