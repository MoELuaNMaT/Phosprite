# Phosprite iPad-first 多平台像素编辑器执行方案（冻结版）

> 状态：执行方案冻结  
> 基线：Pixelorama v1.2 stable (`86d299c`) + Godot 4.6.3 stable  

### Git / Fork 基线规则

Phosprite 可以直接 Fork Pixelorama 官方仓库，但 **不得直接以当前 `master` 作为产品开发基线**。

冻结流程：

```bash
git clone https://github.com/<your-account>/Pixelorama.git Phosprite
cd Phosprite

git remote add upstream https://github.com/Orama-Interactive/Pixelorama.git
git fetch upstream --tags

git switch -c phosprite-main v1.2
```

基线关系：

```text
Pixelorama upstream/master
        │
        │ 仅在新的 stable release 发布后主动评估
        ▼
Pixelorama v1.2 tag / 86d299c
        │
        ▼
phosprite-main
        │
        ▼
Phosprite 产品开发
```

约束：

- 当前正式基线：**Pixelorama v1.2 stable (`86d299c`)**；
- 当前引擎基线：**Godot 4.6.3 stable**；
- 不跟随 `master` / `*-dev` 开发分支；
- 新的 Pixelorama stable release 发布后，只做一次收益/风险评估；
- 只有确认收益明确且迁移成本合理时，才选择性合并 upstream；
- P0 / P1 期间不得为了追上游版本而主动升级 Godot 或 Pixelorama。

> 许可证：MIT  
> 产品名：**Phosprite**
> 当前主目标：完成 iPadOS 移植与 iPad-first UX / UI 布局骨架  
> 当前非目标：功能补全、架构大重构、系统性性能优化、自定义产品增强

---

## 1. 项目定义

本项目基于 **Pixelorama** 的 MIT 开源代码进行选择性 Fork，在代码与开源说明中长期明确承认 Pixelorama 上游来源，并保留未来主动同步 upstream 的能力。

项目在产品层采用完全独立的身份，正式产品名为 **Phosprite**。

Phosprite 的命名取自 **phosphor（荧光体）+ sprite** 的组合意象：既呼应像素艺术、Sprite 与早期显示技术，也承载“接收已有的光，再继续发出光”的传承含义。该命名属于产品品牌表达，不改变项目对 Pixelorama 上游来源的明确承认。

产品身份要求：

- 正式产品名称：**Phosprite**；
- 独立图标；
- 独立 Bundle ID / App ID；
- 独立设置与产品文案；
- 独立发行渠道；
- 不让用户误认为 Phosprite 是 Pixelorama 官方版本；
- 保留 Pixelorama 原始 MIT License、版权声明与 Credits；
- 在 About / Credits / 开源说明中明确标注项目基于 Pixelorama。

本项目不是简单的 “Pixelorama iPad 版”，长期目标是形成一个独立的、iPad-first、同时可覆盖 Desktop / Android 的专业像素编辑器。但在当前阶段，**不得因为长期愿景提前引入大规模架构重构或功能扩张。**

---

# 2. 核心原则与硬边界

## 2.1 轻量级、快速迭代

项目优先验证真实产品工作流，而不是追求架构形式上的完美。

禁止在没有实际阻塞证据时主动进行：

- Core / UI 全量解耦；
- Clean Architecture 重构；
- 大规模目录移动或类重命名；
- 全面 Service 化；
- GDScript 全面 Native 化；
- GPU Pipeline 重写；
- 为未来假设需求设计复杂抽象。

原则：

> **只解决真实阻碍当前阶段目标的问题。**

---

## 2.2 选择性同步 Pixelorama upstream

项目保留与 Pixelorama upstream 的可合并性，但不被动追随上游。

策略：

1. 开发基线固定；
2. 不追踪 upstream HEAD；
3. 不要求始终保持最新版本；
4. Pixelorama 发布新的稳定版后，由项目主动评估；
5. 只有在新版本的功能、Bug Fix、兼容性或架构变化具有明确价值，并且合并成本合理时才同步；
6. 如果新版本当前无明显收益，则保持现有稳定基线；
7. 避免无意义地移动、重命名 Pixelorama 核心源码，以降低未来同步成本；
8. 但不为了方便同步 upstream 而限制我们的 iPad UX / UI 产品设计。

---

## 2.3 固定开发基线

P0 / P1 冻结：

- **Pixelorama：v1.2 stable (`86d299c`)**
- **Godot：4.6.3 stable**

在 P0 / P1 主链路稳定前：

- 不升级 Pixelorama；
- 不升级 Godot；
- 不跟随 Pixelorama master；
- 不因为“版本更新”主动引入额外变量；
- 只允许解决明确阻塞当前目标的依赖修复。

完成 iPad 主链路后，再单独评估后续 stable 版本。

---

## 2.4 许可证边界

项目主体继续采用 **MIT License**。

要求：

- 保留 Pixelorama 原 MIT License；
- 保留必要的版权声明；
- 我们新增代码继续采用 MIT；
- 新依赖优先选择 MIT / BSD / Apache-2.0 / CC0 等宽松许可证；
- 不引入会强制整个项目切换许可证的强 copyleft 依赖；
- 第三方依赖在正式发行前进行一次完整 License / Notice 核查。

---


## 2.5 产品命名与品牌边界

当前正式产品名冻结为：

> **Phosprite**

品牌与代码来源必须同时满足：

- 对外产品、App Store、Windows/macOS/Android 安装包使用 Phosprite 品牌；
- 仓库与 About 页面明确说明 Phosprite 基于 Pixelorama；
- 不使用 Pixelorama 的产品图标、商标或让用户误判为官方发行版的视觉资产；
- 不使用 Aseprite 的名称、商标、图标或造成官方关联误解的宣传方式；
- “Phosprite” 只定义产品身份，不改变底层继续选择性同步 Pixelorama upstream 的策略；
- 后续 Logo、视觉语言、主题系统属于 UI / Product Polish 阶段，不阻塞 P0 / P1。

---

# 3. 平台边界

## 3.1 当前正式目标

### 第一优先级

**iPadOS**

P0 / P1 所有正式 UX 验收均以真实 iPad 为主。

当前主测试设备：

- iPad Air（第 5 代）
- iPadOS 18.0
- Apple Pencil 2

该设备是当前开发测试基线，但 **不等于产品最低系统版本直接锁定 iPadOS 18**。

最低 deployment target 在 P0 搭建 Xcode / Godot iOS 环境后另行冻结。

---

## 3.2 未来平台

项目必须保留未来多平台能力：

- iPadOS
- Android Tablet
- iPhone / iOS
- Windows
- macOS
- 其他 Pixelorama / Godot 已支持平台

但当前优先级不同。

### 当前要求

- iPadOS：正式目标；
- Windows：保持可构建、可运行、核心功能不退化；
- Android：保持现有基础能力，不因为 iPad 改造被破坏；
- macOS：通过 Godot 多平台能力保留未来发行条件；
- iPhone：未来单独设计 Compact Layout，当前不进入 P1 验收。

---

## 3.3 横竖屏

P1 同时支持：

- iPad 横屏；
- iPad 竖屏；
- 系统自由旋转。

但：

> **当前只做旋转适应，不做横屏 / 竖屏两套专门 UI。**

要求：

- 同一套布局体系可在旋转后正常工作；
- UI 不越界；
- Canvas / Timeline / Panel 可继续操作；
- 不在当前阶段设计 Portrait 专用 Compact UI。

---

# 4. UI 与平台技术边界

## 4.1 主 UI 技术

项目主体继续使用：

- Godot；
- GDScript；
- Godot Control UI。

**不使用 SwiftUI / UIKit 重写整套应用 UI。**

---

## 4.2 Native iOS Bridge 的职责

原生层只处理 Godot 不适合或无法良好处理的平台能力，例如：

- UIDocumentPicker / iPadOS Files；
- Share Sheet；
- Photos；
- Apple Pencil 平台级事件；
- 后续 Pencil Hover / Double Tap 等能力；
- iOS lifecycle；
- security-scoped URL；
- 必要的签名 / 系统服务集成。

原生 Bridge 不承载：

- Timeline 主 UI；
- Layer Panel；
- Palette；
- Canvas UI；
- Tool UI；
- Settings 主 UI；
- 编辑器核心状态。

硬规则：

> **Native Bridge 解决平台能力，不建立第二套产品 UI 技术栈。**

---

# 5. Pixelorama 底座审查结论

## 5.1 审查裁决

**GO。Pixelorama 适合作为当前项目底座。**

主要原因：

- MIT 许可证干净；
- 已具备成熟 Pixel Editing Core；
- 已具备 Animation / Layer / Cel / Frame；
- 已具备 Group Layer；
- 已具备 Palette / Indexed Mode；
- 已具备 Selection / Transform；
- 已具备 Tilemap / Tileset / Autotiling；
- 已具备 Undo / Redo；
- 已具备 PNG / GIF / APNG / Sprite Sheet 等导出能力；
- 已具备 Reference Image；
- 已具备 `.ase/.aseprite` 导入；
- 已有 Android / Mobile 适配工作；
- Godot 本身具备 iOS / Windows / Android / macOS 多平台基础。

---

## 5.2 主要架构风险

Pixelorama 不是一个：

> “Headless Editor SDK + 可替换前端”。

它是一个完整 Godot 应用。

目前可以看到：

- `Project.gd` 会直接操作部分 UI；
- `Global.gd` 同时保存应用状态与大量 UI Node 引用；
- Canvas / Timeline / Project / Undo 之间存在直接耦合；
- Tool 系统历史上仍明显围绕 Left Mouse / Right Mouse；
- Open / Save 包含 Desktop / Android 特定路径行为；
- Extension 可以接触 UI / Global。

因此：

> **当前不尝试先把 Pixelorama Core 完全抽离。**

正确策略是保持现有 Contract，在真正阻碍 iPad UX 的边界逐步建立 Adapter。

---

# 6. 当前允许优先建立的薄抽象

只优先建立三个边界。

## 6.1 Input Adapter

目标：

把物理输入设备转换成编辑器意图。

不要让业务逻辑继续直接绑定：

- Left Mouse；
- Right Mouse；
- Apple Pencil；
- Finger。

建议形成：

- Primary Content Action；
- Secondary Content Action；
- Navigation Gesture；
- UI Interaction；
- Modifier。

现有 Tool 算法尽量不改。

---

## 6.2 Document Storage

保留：

- `.pxo` 格式；
- Project serialize / deserialize；
- OpenSave 主要业务逻辑。

替换 / 适配：

- iPadOS Files；
- UIDocumentPicker；
- security-scoped URL；
- overwrite；
- Save As；
- atomic / safe save；
- iCloud / Files Provider。

---

## 6.3 Platform Services

统一承载：

- Files；
- Share；
- Photos；
- Pencil platform features；
- iOS lifecycle；
- 后续必要原生能力。

除此之外，不提前大规模 Service 化。

---

# 7. 文件格式边界

## 7.1 不创建自有工程格式

当前不设计新的私有项目格式。

### 原生项目格式

继续使用：

**`.pxo`**

原因：

- Pixelorama 已有成熟保存 / 加载；
- 已支持完整 Project / Layer / Cel / Frame 等数据；
- 避免引入迁移系统；
- 避免制造新的用户锁定；
- 降低 upstream merge 成本。

---

## 7.2 Aseprite 兼容

Aseprite 兼容是长期重点需求。

### 当前阶段要求

重点保证：

> **`.ase/.aseprite → 本项目` 高质量读取。**

当前目标：

- 能从 Files 直接选择 `.ase/.aseprite`；
- 正确读取 Pixelorama 当前已经支持的数据；
- 把 Aseprite 导入兼容加入回归测试；
- 编辑后保存为 `.pxo`。

### 当前阶段明确不要求

> `.aseprite` 原格式完整写回。

完整 writer / round-trip 属于未来计划，不能阻塞 iPad 移植。

---

# 8. 输入职责冻结

## 8.1 输入类型分层

输入必须区分三类：

### Content Input
会改变作品内容，例如：

- Pencil；
- Eraser；
- Fill；
- Selection Drag；
- Transform。

### Navigation Gesture

例如：

- Pan；
- Zoom；
- 后续其他画布导航手势。

### UI Interaction

例如：

- 点击按钮；
- Timeline；
- Palette；
- Layer Panel；
- Settings。

---

## 8.2 Finger 画布输入策略

设置中提供三档配置。

### 模式 A：不限制

Finger 与 Pencil 都可以执行画布内容编辑。

### 模式 B：Finger 禁止画布内容编辑

Finger：

- 不执行绘制；
- 不执行 Fill；
- 不执行 Selection Content Drag；
- 不执行其他内容修改。

但仍然允许：

- Pan；
- Zoom；
- 导航手势；
- UI Interaction。

### 模式 C：Pencil 输入时抑制 Finger 内容编辑

平时：

- Finger 可以编辑画布。

检测到 Pencil 正在进行内容输入时：

- 暂时禁止 Finger 修改画布内容。

但仍然保留：

- Pan；
- Zoom；
- 导航；
- UI Interaction。

---

## 8.3 Apple Pencil

当前 P0 / P1 硬件基线：

**Apple Pencil 2**

当前必须支持：

- 基础绘制；
- Pencil / Finger 区分；
- 与 Pan / Zoom 共存；
- 可用的压力 / 倾斜信息（以 Godot / 平台实际提供能力为准）。

高级能力：

- Hover；
- Pencil Double Tap；
- Pencil Pro Squeeze；
- Barrel Roll。

采用 capability detection。

其中 Pencil Pro 能力不属于当前测试机硬验收项。

---

# 9. 测试策略

## 9.1 测试边界

P0 不为 Pixelorama 建立完整 QA 工程。

测试目标：

> **为 iPad / UI 改造提供最小行为护栏。**

不追求：

- 代码覆盖率指标；
- 100% 单元测试；
- 全模块完整自动化；
- 为测试而测试。

测试投入必须设上限。

禁止：

> 因为“先把测试全部补完整”而推迟 iPad 主线。

---

## 9.2 P0 最小 Contract Regression Suite

优先覆盖：

1. 新建 Project；
2. `.pxo` Save；
3. `.pxo` Reload；
4. `.pxo` Round-trip；
5. Draw → Undo → Redo；
6. Layer Create / Delete；
7. Group Layer；
8. Frame Create / Delete / Reorder；
9. Cel Create / Move；
10. Linked Cel；
11. Selection；
12. Transform；
13. Palette；
14. PNG Export；
15. Sprite Sheet 基础 Export；
16. Tilemap 基础创建 / 读写；
17. Timeline 关键状态变化；
18. Project 切换；
19. `.ase/.aseprite` 基础导入；
20. 后续追加 iOS Files Storage Contract。

建议测试数量维持在：

> **十几到几十条关键用户路径，而非追求覆盖率。**

---

# 10. P0：前期准备与底座验证

P0 是所有正式 UX 工作之前的硬 Gate。

## 10.1 P0-A：仓库与依赖

任务：

1. Fork / Clone Pixelorama v1.2 stable (`86d299c`)；
2. 配置 `upstream` 指向 Pixelorama 官方仓库；
3. 固定 Godot 4.6.3 stable；
4. 建立独立产品仓库；
5. 配置 **Phosprite** 产品名、独立 Bundle ID / App ID 与 Branding 占位；
6. 保留 Pixelorama MIT / Credits；
7. 安装并验证所有 Addons；
8. 在 Windows 上运行现有 Pixelorama；
9. 确认当前 baseline 无本地修改时行为正常；
10. 建立基线 Commit / Tag。

---

## 10.2 P0-B：开发环境准备

### Windows 主开发机

负责：

- 日常代码；
- Godot Editor；
- Git；
- 大部分 UI / Logic 调试；
- Desktop Regression。

### iPad

现有设备：

- iPad Air 5；
- iPadOS 18.0；
- Apple Pencil 2。

作为 P0 / P1 主真机。

### macOS 构建节点

当前没有 Mac。

P0 必须准备：

- Mac / Mac mini，或可持续使用的 macOS 构建节点；
- Xcode；
- 对应 iOS SDK；
- Godot iOS export templates；
- 开发签名环境；
- Apple ID；
- 后续正式发行所需 Apple Developer Program。

原则：

> Windows 继续作为主开发机，Mac 只承担无法在 Windows 完成的 iOS build / signing / Xcode / App Store 工作。

---

## 10.3 P0-C：补测试

完成第 9 节定义的最小 Contract Regression Suite。

不扩展为完整测试重构项目。

---

## 10.4 P0-D：iOS Boot Spike

首要目标：

> **未经 UI 重构的 Pixelorama 首先真实跑到 iPad 上。**

验证：

1. Godot iOS Export；
2. Xcode build；
3. 真机安装；
4. App 启动；
5. Shader / Canvas 正常；
6. Touch Event 到达；
7. Pencil Event 到达；
8. 基础 Tool 可运行；
9. 无明显 platform-only crash。

---

## 10.5 P0-E：Storage Spike

验证：

- Files Picker；
- `.pxo` Open；
- `.pxo` Save；
- Save As；
- 重新打开；
- PNG Export；
- overwrite；
- Files Provider；
- App background / foreground 后文件状态。

先证明业务闭环，不要求最终 UI。

---

# 11. P0 Gate

只有在真实 iPad 上完成以下完整闭环后，才允许进入大规模 iPad UX / UI 重构：

> **启动应用 → 新建项目 → 绘制 → Undo / Redo → 新建 Layer → 新建 Frame → 播放简单动画 → 保存 `.pxo` → 完全关闭 App → 重新启动 → 打开该项目 → 数据正确 → 导出 PNG 到 iPad Files。**

这条链路必须证明：

- Render；
- Input；
- Editor State；
- Timeline；
- Save；
- Load；
- Export；

均已穿过真实 iPadOS 环境。

P0 Gate 未通过：

> **禁止进入大规模 UI 重构。**

---

# 12. P1：iPad 核心移植与 UX / UI 布局

P1 是当前项目的主要开发阶段。

目标不是“最终美术完成”，而是：

> **让 Pixelorama 的专业核心功能在 iPad 上真正达到日常可用，并建立长期可演进的 iPad-first UX / UI 布局骨架。**

---

## 12.1 P1-A：Desktop Compatibility iPad Mode

先保留现有 UI 与行为。

要求：

- UI 在 iPad 上可完整操作；
- 所有核心工作流可达；
- 即便体验仍然偏 Desktop，也必须先证明功能完整；
- 不先删除旧 UI；
- 不先大规模重构 Timeline；
- 不先追求视觉美术。

目的：

> 将“iOS 移植问题”和“新 UX 问题”分开。

---

## 12.2 P1-B：Input Adapter

建立输入意图层。

优先支持：

- Pencil Content Input；
- Finger Content Input；
- Finger Navigation Gesture；
- UI Interaction；
- Mouse / Trackpad；
- Keyboard；
- Primary / Secondary Action；
- Modifier。

实现三档 Finger 画布策略。

禁止：

> 在各个 Tool / UI 中散落大量 `if iOS` / `if Pencil` / `if Finger` 特殊判断。

---

## 12.3 P1-C：Canvas UX

优先完成：

- Pencil 绘制；
- Finger / Pencil 分流；
- Pan；
- Pinch Zoom；
- 基础 Navigation Gesture；
- Tool Primary / Secondary Action；
- 取色交互；
- Selection；
- Transform；
- Undo / Redo 高频入口；
- Pointer / Pencil 与 Canvas 坐标一致性。

P1 中：

> UX 优先于视觉效果。

---

## 12.4 P1-D：Tools / Palette / Layer UI

目标：

- 适合触控的命中区域；
- 高频操作无需依赖鼠标右键；
- Tool Options 可在 iPad 快速访问；
- Palette 可顺畅选择；
- Layer / Group 可完整操作；
- 不因为 UI 重构减少核心能力。

视觉：

- 先保证布局；
- 后续再统一美术。

---

## 12.5 P1-E：Timeline

Timeline 是当前风险最高的 UI 模块。

要求：

- 不优先删除旧 Timeline；
- 先梳理其与 Project / Global / Undo / Cel / Frame 的现有 Contract；
- 新 Timeline 第一阶段尽量兼容旧接口 / Signal；
- 逐步替换，不一次切断全部旧依赖。

最终 P1 要达到：

- Frame / Cel / Layer 可选择；
- 可拖动；
- 可多选；
- 可调整 Frame；
- 可管理 Tags；
- 可操作 Onion Skin；
- Linked Cel 等核心能力可达；
- 触控目标合理。

具体高级手势在 UX 阶段逐项冻结，不在当前方案预定义死。

---

## 12.6 P1-F：Files / Export UX

与 Canvas / Timeline 同级优先。

必须完成：

### Open
- iPad Files；
- `.pxo`；
- `.ase/.aseprite`。

### Save
- Save；
- Save As；
- `.pxo`；
- Files Provider；
- 正确 overwrite。

### Export
接入 Pixelorama 已有核心 exporter：

- PNG；
- GIF；
- APNG；
- Sprite Sheet；
- PNG Sequence；
- WebP 等实际可在 iOS 运行的格式。

### Destination
按能力实现：

- Files；
- Share Sheet；
- Photos。

原则：

> **Save 与 Export 明确分开。**

并且：

> **不得增加导出次数、分辨率、格式限制。**

Quick Export / Export Preset 当前只预留产品位置，不强制进入 P1。

---

# 13. P1 核心功能范围

P1 要求：

> **核心编辑能力零缩水。**

必须保持可用：

- Canvas Drawing；
- Palette / Color；
- Selection；
- Transform；
- Layer；
- Group；
- Frame；
- Cel；
- Timeline；
- Onion Skin；
- Tags；
- Tilemap 基础能力；
- Reference Image；
- Undo / Redo；
- Open；
- Save；
- Export；
- Project 切换；
- 基础 Settings。

允许暂时隐藏或关闭：

- Extension Explorer；
- CLI；
- External FFmpeg Video Workflow；
- Desktop 多窗口高级能力；
- 明显 Desktop-only 且低频的入口。

原则：

> **边缘能力可以后置，核心工作流不能缩水。**

---

# 14. P1 UI 完成标准

P1 不要求最终视觉设计完成。

阶段顺序：

1. UX Interaction；
2. UI Layout；
3. 真机使用；
4. 后续 UI Art / Polish。

P1 必须完成：

- iPad-first 输入职责；
- 可长期使用的 Canvas；
- 可长期使用的 Timeline；
- 可长期使用的 Files / Export；
- 可长期使用的主要面板；
- 横竖屏旋转不破坏布局；
- Settings 中完成 Finger 三档策略；
- 用户可以真正拿它长期画像素画。

P1 当前不要求完成：

- 最终主题；
- 最终视觉语言；
- 完整动效；
- 最终图标风格；
- 所有 UI 美术细节。

但是：

> P1 设计时必须预留未来主题、尺寸、布局、组件替换空间，不能把临时 UI 完全写死。

---

# 15. 当前明确后置的事项

以下内容只在 Roadmap 中占位。

当前不定义完整需求，不进入 P0 / P1 主线。

---

## 15.1 功能补全

未来阶段。

当前不定义：

- “Aseprite 功能 parity”；
- Slice / 9-slice；
- Color Profile；
- `.aseprite` Writer；
- 高级 Export；
- Lua / CLI parity。

这些只能在 P1 稳定后重新进行需求调研。

硬规则：

> **不得在 P0 / P1 期间因为发现 Aseprite 有某个功能就顺手补功能。**

---

## 15.2 自定义产品功能

未来阶段。

当前只允许记录想法，不执行。

---

## 15.3 Core / UI 解耦

后置。

只有当现有耦合明确阻碍当前功能或维护时，才局部处理。

---

## 15.4 项目架构重构

排期很后。

不作为当前目标。

---

## 15.5 Extension

现有架构暂时保留。

iOS 移植完成前：

- 不开发 Extension；
- Extension Explorer 可以关闭；
- 不把在线下载 `.pck` 作为 App Store 首发功能。

后续单独评估 App Store policy。

---

## 15.6 视频 / FFmpeg

Pixelorama 当前部分视频能力依赖外部 FFmpeg executable。

iPad 第一版不要求支持。

当前：

- 保留 Desktop 能力；
- iOS 可暂时关闭；
- 后续再评估 AVFoundation / embedded codec。

---

# 16. 性能边界

性能不是 P0 / P1 的主动优化目标。

当前不做：

- 大规模 profiling；
- 全面多线程；
- WorkerThreadPool 改造；
- GDExtension C++ 重写；
- GPU Pipeline 重写；
- 大型项目极限性能专项。

但是：

> **阻塞基本使用的性能问题属于 P0 / P1 Bug，允许并要求局部修复。**

例如：

- Pencil latency 已影响绘画；
- 普通项目 Canvas 明显掉帧；
- Save / Load 无法接受；
- iPad 普通项目频繁 OOM；
- 某算法在 iOS 上不可用；
- App 因内存压力在基础工作流被系统杀死。

处理顺序：

1. 复现；
2. 定位；
3. 局部修复；
4. 不顺手扩展成系统性性能重构。

---

# 17. Desktop / Android 保持原则

iPad 是当前主目标。

但 iPad 改造不能通过删除其他平台能力完成。

### Desktop

允许：

- 暂时继续旧 UI；
- 暂时不获得 iPad 新布局。

必须：

- 可构建；
- 可运行；
- 核心功能不退化；
- Mouse / Keyboard 继续有效。

### Android

允许：

- 暂时继续 Pixelorama 现有 Mobile 行为。

必须：

- 不因 iPad 改动彻底破坏；
- 保留未来复用 Touch Profile 的条件。

---

# 18. Upstream 合并保护策略

为了保持未来选择性同步：

建议新增代码尽量集中在：

- `Platform/iOS`；
- `PlatformServices`；
- `InputAdapter`；
- `UI/Touch`；
- `Product`；
- 独立 Branding / Settings 区域。

避免：

- 无意义重命名原 Core 文件；
- 无意义搬动 Pixelorama 目录；
- 给所有 Core class 做统一格式重构；
- 同时修改大量与当前目标无关的上游代码。

每次同步 stable 前：

1. Review upstream release notes；
2. 识别对我们的收益；
3. 做 merge impact assessment；
4. 在单独 integration branch 合并；
5. 运行 Contract Suite；
6. 再决定是否进入主线。

---

# 19. 风险自问自答

## Q1：Pixelorama 是否已经被正式锁死为唯一底座？

**A：不是。**

当前裁决是：

> 通过静态底座审查，可以进入 iOS Prototype。

真正最终锁定条件是 P0 Gate。

如果 Pixelorama 在真实 iPad 上出现不可接受的平台硬阻塞，可以重新评估。

---

## Q2：Godot 支持 iOS，是否等于 Pixelorama 已支持 iOS？

**A：不是。**

Pixelorama 当前有 Android / Desktop 实际路径，但当前基线没有经过我们的 iPad 真机验证。

所以 P0 Boot Spike 是硬任务。

---

## Q3：是否应该在 iPad 移植前把 Core / UI 解耦？

**A：不应该。**

现有耦合真实存在，但大重构会严重拖慢项目。

只在 Input / Storage / Platform Service 等真实边界渐进解耦。

---

## Q4：最危险的 UI 模块是什么？

**A：Timeline。**

它同时关系：

- Project；
- Frame；
- Cel；
- Layer；
- Selection；
- Undo；
- Drag；
- Tag；
- Animation。

因此不能把它当成普通 View 一次删除重写。

---

## Q5：最适合第一批重构的模块是什么？

**A：Canvas Input。**

输入边界最容易定义，并且用户价值最高。

---

## Q6：Apple Pencil 是否意味着要重写所有 Tool？

**A：不应该。**

目标是：

> Physical Input → Editor Intent → Existing Tool。

而不是重写 Pencil / Eraser / Line / Fill 算法。

---

## Q7：Finger 是否固定不能画画？

**A：不是。**

用户拥有三档设置：

1. 不限制；
2. Finger 不编辑画布；
3. Pencil 输入时抑制 Finger 编辑。

无论哪一档：

> UI 与导航手势不受禁止画布编辑影响。

---

## Q8：`.pxo` 是否要替换成自己的格式？

**A：不。**

当前没有足够收益。

---

## Q9：`.aseprite` 是否必须第一版无损写回？

**A：不。**

当前重点是可靠读取。

Writer 后置。

---

## Q10：测试是不是要先补到很完善再移植？

**A：不。**

只补核心行为 Contract。

测试不能成为新的主项目。

---

## Q11：Pixelorama 性能会不会因为 Godot / GDScript 不够？

**A：目前没有证据支持这个结论。**

性能必须基于真实 iPad / 真实项目规模测量。

只有基础可用性受到影响时才在 P0 / P1 局部优化。

---

## Q12：最大的性能风险是不是 CPU？

**A：不确定，内存同样值得警惕。**

Frame × Layer × Cel × Image × Texture × Undo 可能在 iPad 上形成明显 Memory Pressure。

当前只记录风险，不提前优化。

---

## Q13：现有 `.pxo` 保存是否可以直接搬到 iOS？

**A：格式可以，Storage 语义不能直接假定。**

必须验证：

- Files；
- security-scoped URL；
- overwrite；
- atomic save；
- background；
- iCloud / File Provider。

---

## Q14：Extension 为什么暂时关闭？

**A：因为它不是 iPad 核心需求，并可能增加 App Store 审核复杂度。**

保留架构，不阻塞首发。

---

## Q15：External FFmpeg 为什么后置？

**A：因为 Desktop executable 调用模式不适合作为 iPad 首发依赖。**

视频不是当前核心像素编辑闭环。

---

## Q16：为什么不一次重做最终 UI？

**A：因为会同时叠加平台移植风险、功能回归风险和产品设计风险。**

正确顺序：

> 先可运行 → 再 UX → 再布局 → 再视觉。

---

## Q17：为什么不先补 Aseprite 缺失功能？

**A：因为当前目标不是 parity，而是建立可靠 iPad 产品基础。**

功能补全属于未来重新立项的阶段。

---

## Q18：未来 Windows / macOS 是否可以从同一项目发行？

**A：可以。**

Core 与大多数 Godot UI 继续共享。

平台特定部分集中在：

- Input；
- Files；
- Share；
- Pencil；
- Window / Lifecycle。

但当前不把 Desktop 新产品发行作为 P1 目标。

---

# 20. 阶段 Roadmap

```text
P0
环境 + 基线 + 测试 + iPad Boot + Storage
│
│ Gate：真实 iPad 完整 Open/Edit/Save/Reload/Export 闭环
▼
P1-A
现有 Pixelorama UI 在 iPad 可完整操作
│
▼
P1-B
Input Adapter / Pencil / Finger
│
▼
P1-C
Canvas UX
│
▼
P1-D
Tools / Palette / Layer
│
▼
P1-E
Timeline
│
▼
P1-F
Files / Export UX
│
│ Gate：可以长期用于真实像素绘画
▼
P2
UI Visual Polish / Productization
│
▼
Future
功能补全
架构专项
性能专项
Extension
自定义产品能力
多平台产品化
```

---

# 21. 当前执行优先级

## 立即执行

1. 准备仓库；
2. 锁 Pixelorama 1.2 stable (`86d299c`)；
3. 锁 Godot 4.6.3；
4. 创建独立产品 identity；
5. 补最小 Contract Tests；
6. 准备 Mac / Xcode / iOS 构建环境；
7. 真机 Boot Spike；
8. 真机 Storage Spike；
9. 完成 P0 Gate。

## P0 通过后

开始：

1. Desktop Compatibility iPad Mode；
2. Input Adapter；
3. Canvas UX；
4. 逐步 UI 布局重构；
5. Timeline；
6. Files / Export；
7. P1 Gate。

---

# 22. 成功定义

当前版本项目成功，不是：

> “功能比 Aseprite 多。”

也不是：

> “架构比 Pixelorama 漂亮。”

而是：

> **Pixelorama 的成熟编辑核心在真实 iPad 上可靠运行；Apple Pencil、Finger、Files、Timeline、Export 等关键交互已经变成真正适合 iPad 的工作流；同时项目仍保持 Windows / Android / 未来 macOS 等多平台演进条件，没有因为短期移植制造大规模技术债。**

---

# 23. 冻结结论

当前方案正式冻结以下决策：

- Pixelorama v1.2 stable (`86d299c`)；
- Godot 4.6.3；
- MIT；
- 选择性 upstream；
- 独立产品品牌：**Phosprite**；
- `.pxo` 原生格式；
- `.aseprite` 读取为重点；
- `.aseprite` writer 后置；
- Godot UI + Native iOS Bridge；
- iPadOS 第一优先；
- Windows / Android 不退化；
- iPhone 后置；
- 横竖屏只做旋转适应；
- Finger 三档 Canvas Input Policy；
- Apple Pencil 2 为当前硬件基线；
- P0 最小 Contract Tests；
- P0 必须真实 iPad 完整闭环；
- P1 核心功能零缩水；
- UX 优先、布局其次、UI 美术后置；
- Files / Export 属于 P1 核心；
- Extension iOS 暂停；
- External FFmpeg iOS 后置；
- Core/UI 全解耦后置；
- 架构重构后置；
- 系统性性能优化后置；
- 可用性阻塞性能问题允许局部修复；
- 功能补全与自定义能力均为未来计划。

该冻结版之后的开发，除非发现 P0 硬阻塞或出现新的明确需求，不重新打开上述已冻结决策。
