# Phosprite 项目上下文

## 技术栈与版本基线

| 项目 | 版本 | 说明 |
|:---|:---|:---|
| 底座 | Pixelorama v1.2 stable (`86d299c`) | Fork 自 Orama-Interactive/Pixelorama |
| 引擎 | Godot 4.6.3 stable | P0/P1 期间不得主动升级 |
| 许可证 | MIT | 保留 Pixelorama Credits |
| 产品名 | Phosprite | 独立品牌 |

## 仓库与远端

```text
origin    https://github.com/MoELuaNMaT/Phosprite.git      (自己的 fork)
upstream  https://github.com/Orama-Interactive/Pixelorama.git
```

注意:fork 最初叫 `MoELuaNMaT/Pixelorama`,后已重命名为 `MoELuaNMaT/Phosprite`。
GitHub 会重定向旧 URL,但 `origin` 已改为新地址。

## 环境配置

### Windows 主开发机

- Godot 二进制:`D:/_phosprite_tools/Godot_v4.6.3-stable_win64_console.exe`
- 导出模板:`%APPDATA%/Godot/export_templates/4.6.3.stable/`(含 `ios.zip`)
- 用途:日常代码、Godot Editor、UI/Logic 调试、Desktop Regression

### macOS 构建节点

**本地没有 Mac。** 所有 iOS 构建走 GitHub Actions `macos-latest`。

### iPad 真机(已接入)

- iPad(UDID `00008103-001948500AE9401E`)、iPadOS、Apple Pencil 2
- 侧载方式:AltStore 免费账号(Team ID `44MFR9W6NM`)
- **必须在纯 ASCII 用户会话中签名**:中文用户名会让 AltServer 的
  `ldid.dll` 崩在 `ldid.cpp(2609): _assert(): dir != NULL`。
  见 `findings.md` 的"Windows 侧载环境"一节。

### 纯 ASCII 签名环境(已建立)

因中文用户名的硬阻塞,单独建了一套隔离环境:

| 项 | 值 |
|:---|:---|
| 用户 | `dev`(本地管理员,无密码,`PasswordRequired=False`) |
| 工作区 | `C:\phosprite\`(`ipa/`、`build/`) |
| IPA 投放 | `C:\phosprite\ipa\Phosprite-unsigned.ipa` |
| 隔离原理 | 用户名/Profile/TEMP/工作区全 ASCII;Apple 组件栈在
  `C:\Users\dev\AppData\Local\AltServer\Apple\` 重新初始化 |

**不要**在 `乱码碳` 会话运行 AltServer:它会抢占设备通道与监听端口,
且加载的是中文路径下的 Apple 组件。

## 保存路径架构(P0-E 起)

iPadOS 没有用户可导航的文件系统,因此 iOS 上由 App 托管项目存储:

| 侧 | 落点 |
|:---|:---|
| 统一入口 | `Main.request_save(intent, target_project)`,intent 为 `SaveIntent { SAVE, SAVE_AS, QUIT_SAVE }` |
| 策略模块 | `src/PlatformServices/StoragePolicy.gd`(纯静态,无 autoload,禁止读 `Global`) |
| 托管目录 | `user://Projects`(iOS 上即沙箱 Documents/Projects,Files app 可见) |
| iOS 命名 | `make_initial_project_path()` 自动分配,冲突以文件系统为准递增 `_2`/`_3` |

**为什么需要 intent**:首次 Save、Save As、退出保存三条路径共用同一个入口,
无法用 `save_path == ""` 区分语义 —— 退出保存处理的是后台项目,
`target_project` 必须显式传参,不能读 `Global.current_project`。

iOS 行为:首次 Save 与退出保存直接落 `user://Projects`(不弹窗);
Save As 在 `ACCESS_USERDATA` + `user://Projects` 下开内部 chooser(不暴露 `/private`)。
其他平台分支与改动前逐条等价。

## 契约测试套件

入口:`tests/runner.gd`,headless 运行

```bash
godot --headless --path . --script res://tests/runner.gd -- --phosprite-test-runner
```

当前规模:**41 项**,0 failures。CI 门禁见 `.github/workflows/regression-tests.yml`。

**改动测试框架时注意**(P0-E 修复的三处假通过缺陷,见 `findings.md`):
- `runner.gd` 必须**无条件 `await`** 测试返回值 —— GDScript 协程返回
  `GDScriptFunctionState` 而非 `Signal`,`is Signal` 判断会截断所有含 await 的测试;
- `test_base.gd` 的 `assertions` 计数为 0 时判失败 —— 测试体在首个断言前
  因运行时错误中止时,返回值与通过时完全相同;
- 调整画布尺寸须走 `DrawingAlgos.resize_canvas()`,直接赋值 `project.size`
  会让 cel 图像尺寸与画布不一致(编辑器正常流程不会产生的状态)。

## 关键导出配置

`export_presets.cfg` 中 `[preset.9]` 为 iOS preset:

- `application/bundle_identifier="com.phosprite.app"`
- `application/targeted_device_family=1` → **iPad-only**
  (Godot 枚举为 `0=iPhone, 1=iPad, 2=iPhone & iPad`,注意与 Xcode 的
  `TARGETED_DEVICE_FAMILY` 编码不同)。实测产物 `UIDeviceFamily=[2]`。
  与方案 §23"iPadOS 第一优先 / iPhone 后置"一致。
- `application/export_project_only=true` → Godot **只产出 Xcode 工程,不调用 xcodebuild,不签名**
- `application/app_store_team_id="0000000000"` → **占位值**。Godot 导出校验强制要求非空;
  该值只写入工程文件,真实签名在 CI 由 xcodebuild 参数覆盖
- 横竖屏 4 方向全开(方案 §12:只做旋转适应)
- `user_data/accessible_from_files_app=true` + 显式注入
  `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace`
  → 让 `user://`(= 沙箱 Documents)出现在 Files app
- `entitlements/increased_memory_limit=false`(免费账号拿不到)
- `UIRequiresFullScreen=true` 来自 Godot 模板默认值,未显式配置。
  代价:不支持 iPad Split View / Slide Over。P0 保持现状,待 P1 评估。

## iOS 构建链路

`.github/workflows/ios-build.yml`,触发于 `main` / `phosprite-main` 的 push 与 PR。

```text
macos-latest
  ├─ 装 Godot 4.6.3 + export templates(注意:必须用 ${HOME},env 里的 ~ 不会展开)
  ├─ Godot --export-release "iOS" → Xcode 工程(不签名)
  ├─ xcodebuild archive CODE_SIGNING_ALLOWED=NO → 未签名 .xcarchive
  └─ 从 .xcarchive 取 .app 重打包 → Phosprite-unsigned.ipa(清除 _CodeSignature)
```

**不能**用 `xcodebuild -exportArchive`:它强制要求可用的签名身份与 provisioning profile。

产物:artifact `Phosprite-ios-unsigned`,约 27 MB。

## AltStore 侧载环境(Windows 主开发机)

| 组件 | 版本 | 安装位置 |
|:---|:---|:---|
| AltServer | **1.7.5** | `C:\Program Files (x86)\AltServer\` |
| iCloud(直装版) | 7.21.0.23 | `Common Files\Apple\Internet Services\` |
| Apple Mobile Device Support | 20.0.0.35 | `Common Files\Apple\Mobile Device Support\` |
| Bonjour | 3.1.0.1 | `C:\Program Files (x86)\Bonjour\` |
| iTunes | 12.13.11.1 | `C:\Program Files\iTunes\` |

服务:`Apple Mobile Device Service`、`Bonjour Service`,均 Running / Automatic。

**重要陷阱**:`winget install Apple.iTunes` 只装了 `iTunes64.msi`,**跳过了内嵌的
`AppleMobileDeviceSupport64.msi`**,导致 AltServer 无法识别设备
(见 microsoft/winget-pkgs#18433)。正确做法是用官方 `iTunes64Setup.exe -layout`
解出全部 MSI 后单独补装 AMDS。

**必须用 Apple 官网直装版 iTunes/iCloud,不能用 Microsoft Store 版** ——
Store 版做了混淆,缺少 AltServer 生成 Anisette 数据所需的文件访问能力。

## CI 已知问题(非 P0 阻塞)

`Development Web build` 在同一仓库上持续失败:

```text
remote: Permission to MoELuaNMaT/Phosprite.git denied to github-actions[bot].
fatal: unable to access '...': The requested URL returned error: 403
```

根因是 fork 的 `GITHUB_TOKEN` 默认只读,无法向 `gh-pages` 强推。
需要在仓库 Settings → Actions → General → Workflow permissions 改为
"Read and write",或在 fork 上禁用 Pages 部署步骤。与 iOS 链路无关。

## 提交历史

| commit | 内容 |
|:---|:---|
| `a75c390` | P0:项目初始化、身份隔离与 Contract Regression Suite |
| `22ccf5b` | P0-D:新增 iOS 导出配置与未签名 IPA 构建流水线 |
| `89ca784` | P0-D:修复 iOS CI 导出模板路径未展开导致构建失败 |
| `76f6566` | docs: 项目记忆(技术栈基线、iOS 构建链路、AltStore 侧载环境) |
| `656a471` | docs: 记录 Windows 侧载中文用户名阻塞的根因与修复 |
| `a07538b` | docs: P0-D 真机验收进展(启动/渲染/触摸绘制/crash 通过) |
| `0780c62` | P0-E: 修复沙箱平台的导出路径与 Files app 可见性 |
| `caf8cf0` | style: 修正空行以满足 gdformat |
| `159be75` | fix: 修正 iOS 平台判定,导出/保存默认目录改回 user:// |
| `c9db137` | test: 修正测试框架的假通过缺陷 |
| `f3bbb7d` | feat: P0-E 保存路径统一入口(iPadOS 托管存储) |
