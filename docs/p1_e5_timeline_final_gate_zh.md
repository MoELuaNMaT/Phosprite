# Phosprite P1-E5 Timeline Final Gate（iPad）

目标：对 P1-E1～E4 已完成的 Timeline 触控改造做一次连续真实工作流验收。E5 不新增 Timeline 功能；只允许修复阻碍本 Gate 的最小问题。

基线：iPad Air 5 / iPadOS 18.x。建议使用至少 3 个 Layer、8 个 Frame 的测试工程，并分别覆盖横屏、竖屏。

## 通过原则

- E1～E4 的行为必须能连续组合使用，不能只在孤立测试中成立。
- Touch adapter 继续复用 Pixelorama/Phosprite 原有 selection、drop、UndoRedo、Tag、Linked Cel、Onion Skin 业务逻辑。
- 一次用户操作只产生一次业务 transaction。
- 不允许因为 E5 重新设计 selected_cels、Tag 数据模型、Linked Cel、Onion Skin 或 Timeline reorder。
- 发现无关问题只记录，不扩张本阶段范围。

## Final Gate 连续流程

### 1. 建立测试工程

创建至少 3 个 Pixel Layer、8 个 Frame，并在不同 Frame 中绘制可辨认内容。

预期：Timeline、Canvas、Layer 面板正常，无启动异常。

### 2. E1 单选 / 多选

- 普通点击 Cel，确认单选。
- 点击 Frame Header，确认当前 Layer 的对应 Cel 成为当前 Cel。
- 打开 Select，跨 Frame / Layer 多选多个 Cel。
- 用 Frame Header 做整 Frame 多选。
- 双击 Cel / Frame Header，确认仍打开原有 Context Menu。

预期：选择不丢失、不产生空 selection，不发生 synthetic mouse 双触发。

### 3. E2 长按 reorder

在上一节的多选状态继续操作：

- 短距离立即拖动，确认优先滚动 Timeline。
- 长按约 0.45 秒后拖动单个 Cel。
- 多选多个 Cel 后长按 reorder，确认集合一起移动。
- 多选 Frame 后长按 reorder。
- 靠近 Timeline 左右边缘停留，确认水平自动滚动；Cel reorder 同时确认必要的垂直自动滚动。
- 对一次 reorder 执行一次 Undo / Redo。

预期：一次 reorder 只有一次 Undo transaction；源 selection 与目标结果正确。

### 4. E3 顶部 Timeline 工具栏

连续执行：Add Frame、Delete Frame、Previous、Play Backwards、Play Forward、Next、Onion Skin、Loop、FPS 调整。

再打开 `…`，执行 Duplicate、Move Left / Right、First / Last、Timeline Settings。

预期：高频入口直接可达，低频入口集中在 `…`；禁用状态遵循原逻辑；不出现双触发。

### 5. Frame Duration

选择一个 Frame，打开 `…` → Frame properties / duration，修改 Duration。

播放动画后执行 Undo / Redo。

预期：播放时间按新 Duration 生效，Undo / Redo 完整恢复；没有第二套 transaction。

### 6. Tag resize

创建 Tag A、Tag B，各覆盖至少 2 个 Frame。

分别执行：

- Tag 左边缘 resize；
- Tag 右边缘 resize；
- 短 Tag 左 / 右边缘 resize；
- 中央点击编辑 Tag；
- 每次 resize 后执行 Undo / Redo。

预期：只修改当前正在操作的 Tag；边界按 Frame 吸附；中央点击不被 resize 抢占。

### 7. 近邻 / 重叠 Tag

这是 E5 的强制回归项。

- 让 Tag A 与 Tag B 本体不重叠，但两者边缘距离小于约 44 pt；分别拖 A 右边缘、B 左边缘。
- 再建立允许的数据状态：Tag A 与 Tag B 本体发生范围重叠；分别尝试操作各自可见边缘。

预期：

- 操作 B 时 A 的 from / to 不得变化，反之亦然。
- 不允许出现整段 Tag 突然跳到另一个 Tag 附近。
- 不允许邻居 Tag 的某一侧被错误吸到当前手指位置。
- 若两个可操作边缘视觉上完全重合，行为至少必须稳定、可重复，不得随机修改不同 Tag。

任一项失败均视为 E5 blocker，不允许合并。

### 8. Linked Cel：Link → Unlink

使用 Select 在同一 Pixel Layer 选择至少两个 Cel。

执行 `…` → Link selected cels，在其中一个 Cel 绘制；随后执行 Unlink，再独立修改其中一个 Cel。

对 Link、Unlink 与后续编辑执行 Undo / Redo。

预期：链接与解链语义与桌面原实现一致；非 Pixel Cel 不允许非法 Link / Unlink。

### 9. Onion Skin

直接切换 Onion Skin，再通过 Timeline Settings 调整 Past / Future、Opacity、Blue / Red 等已有设置。

在多个 Frame 间切换并播放动画。

预期：E4 只改变触控可达性；Onion Skin 的显示算法与设置语义保持不变。

### 10. 连续 Undo / Redo 压力回归

依次完成：多选 → reorder → Duration → Tag resize → Link → Unlink，然后连续 Undo 回退这些操作，再连续 Redo。

预期：每一步按原操作粒度恢复，没有多一次或少一次 transaction，没有跨功能状态串扰。

### 11. 横屏 / 竖屏

在横屏完整检查 Timeline 顶部按钮、Select、`…`、FPS、Tag、Cel；旋转到竖屏后再次快速检查。

预期：控件均可到达；Timeline 可滚动；Canvas 与 Layer 面板仍可操作；旋转不破坏当前工程状态。

### 12. Desktop 快速回归

如有桌面构建，快速确认鼠标单选、多选、右键菜单、Frame/Cel 原生 drag、Tag 原鼠标 resize、快捷键与完整 Timeline toolbar。

预期：iOS touch adapter 不改变桌面行为。

## 自动化 Gate

必须全部通过：

- Static Checks；
- Regression Tests；
- Development desktop builds；
- iOS build (unsigned)。

其中 Regression 必须包含 E1、E2、E3/E4、E4 stale Tag guard 与 E5 组合契约测试。

## E5 PASS 条件

只有同时满足以下条件才判定 P1-E 完成：

1. 四项自动化 Gate 全绿；
2. 上述 target-iPad 连续工作流通过；
3. 近邻 / 重叠 Tag 强制回归通过；
4. 不存在会导致 selection、reorder、Tag、Linked Cel、Onion Skin 数据损坏的 blocker；
5. 横屏、竖屏均无 Timeline 不可达问题。

E5 PASS 后停止 P1-E，不自动进入 P1-F。
