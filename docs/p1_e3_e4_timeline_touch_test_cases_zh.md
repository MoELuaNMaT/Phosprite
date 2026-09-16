# Phosprite P1-E3～E4 iPad 中文测试用例

目标：验证 P1-E3 顶部 Timeline 工具栏触控化与 P1-E4 高级 Timeline 能力的触控入口。E3 不单独要求人工实机 Gate；本文件用于 E4 完成后的合并真机验收，同时覆盖 E3 布局。

测试基线：iPad Air 5 / iPadOS 18.x；建议同时覆盖横屏与竖屏。

## 1. 顶部工具栏高频入口

操作：
- 打开至少包含 3 个 Frame 的工程。
- 依次点击 Add Frame、Delete Frame、Previous、Play Backwards、Play Forward、Next、Onion Skin、Loop。
- 调整 FPS。

预期：
- 这些高频入口保持直接可见，不需要打开 `…`。
- 点击区域明显比原来的 24 px 按钮更适合手指，目标高度约 44 pt。
- 图标本身不需要被强行放大。
- 每个操作仍执行原有 Pixelorama/Phosprite 行为，不发生双触发。

## 2. `…` 菜单中的 E3 低频操作

打开 Timeline 顶部 `…`。

确认至少存在：
- Duplicate frame；
- Move frame left；
- Move frame right；
- Jump to first frame；
- Jump to last frame；
- Timeline settings。

逐项执行可用操作。

预期：
- Duplicate / Move Left / Move Right 与原工具栏行为一致。
- First / Last 正确切到第一帧 / 最后一帧。
- Timeline settings 打开原有设置 Popup。
- Undo / Redo 行为与原实现一致。

## 3. `…` 菜单禁用状态

操作：
- 当前位于第一帧时打开 `…`。
- 当前位于最后一帧时打开 `…`。
- 创建 / 删除 Frame 后再次打开。

预期：
- 第一帧时 Jump to first frame 不可执行。
- 最后一帧时 Jump to last frame 不可执行。
- Move Left / Move Right、Duplicate 的状态遵循原工具栏按钮与当前工程状态。
- 禁用项目不能通过菜单绕过原限制。

## 4. Frame Properties / Duration

操作：
- 选择一个 Frame。
- 打开 `…` → Frame properties / duration。
- 修改该 Frame 的 Duration，并确认。
- 若原对话框支持多 Frame，使用 E1 Select 选中多个 Frame 后重复一次。
- Undo / Redo。

预期：
- 打开的仍是项目原有 Frame Properties 对话框。
- Duration 修改立即反映到动画播放时间。
- 多选语义与原桌面 Context Menu 一致。
- Undo / Redo 沿用原实现，不出现额外 transaction。

## 5. 新建 Tag 与 Tag 编辑

操作：
- 选择一个或多个 Frame。
- 打开 `…` → New tag，创建一个 Tag。
- 点击 Timeline 中 Tag 中央区域，再次打开 Tag Properties 并修改名称 / 颜色等已有属性。

预期：
- New tag 使用原有 Tag Properties 流程。
- Tag 中央点击仍打开原有编辑入口。
- E4 没有引入第二套 Tag 数据模型。

## 6. Tag 左边缘触控 Resize

准备：创建一个覆盖至少 4 个 Frame 的 Tag。

操作：
- 手指按在 Tag 左边缘附近（不需要精确压中原来的 8 px 小把手）。
- 左右拖动约 1～2 个 Frame 后释放。

预期：
- 左边界按 Frame 宽度吸附移动。
- 只能在合法范围内调整，不能越过 Tag 右边界。
- 释放后 Tag 起始 Frame 正确改变。
- 一次 Undo 完整恢复；Redo 再次恢复调整结果。

## 7. Tag 右边缘触控 Resize

操作同上，但拖动 Tag 右边缘。

预期：
- 右边界按 Frame 宽度吸附移动。
- 不能越过左边界，也不能超过工程最后一个 Frame。
- 释放后仍只产生原有一次 Resize Frame Tag Undo transaction。

## 8. 短 Tag / 两侧触控区重叠

准备：创建只有 1 个 Frame 或宽度很短的 Tag。

操作：
- 分别靠近左半侧与右半侧尝试拖动。

预期：
- 靠近左侧时调整起点，靠近右侧时调整终点。
- 不出现两侧同时抢占、跳变或 Tag 瞬间消失。
- 中央普通点击仍优先作为 Tag 编辑，不应被整个 Tag 区域错误当成 resize。

## 9. Tag Resize 取消 / 非法拖动

操作：
- 开始拖动 Tag 边缘后触发系统取消（如可稳定复现），或快速返回原位置释放。

预期：
- Cancel 不写入新的 Tag 边界。
- 回到原边界释放不产生实际变化。
- UI Preview 能恢复到正式 Tag 状态。

## 10. Linked Cel：Link

准备：同一 Pixel Layer 上选择至少 2 个 Cel。

操作：
- 使用 E1 Select 建立多选。
- 保持其中一个 Cel 为当前 Cel。
- 打开 `…` → Link selected cels。
- 在其中任意一个 Linked Cel 上绘制内容。
- Undo / Redo Link 操作与后续绘制（按原项目能力验证）。

预期：
- Link 使用原有 CelButton Link transaction。
- 同 Layer 的选中 Cel 正确进入同一 link set。
- Linked Cel 的视觉标记与联动编辑行为与桌面一致。

## 11. Linked Cel：Unlink

操作：
- 在已 Linked 的当前 Pixel Cel 上打开 `…` → Unlink selected cels。
- 修改其中一个 Cel 内容。
- Undo / Redo。

预期：
- Unlink 使用原有 CelButton transaction。
- 解链后的 Cel 内容能够独立变化。
- Undo 后正确恢复链接关系与内容状态。

## 12. 非 Pixel Cel 的 Link/Unlink 限制

操作：
- 切到 Group / Audio 等非 Pixel Cel（按项目可创建类型测试）。
- 打开 `…`。

预期：
- Link selected cels / Unlink selected cels 不应成为可执行的非法入口。
- 不发生错误 transaction 或崩溃。

## 13. Onion Skin

操作：
- 直接点击 Onion Skin 开关。
- 打开 `…` → Timeline settings，调整 Past / Future、Opacity、Blue/Red 等现有 Onion Skin 设置。
- 在多个 Frame 间切换观察画布。

预期：
- Onion Skin 开关仍是直接 44 pt 触控入口。
- 设置仍走原 Timeline Settings。
- 显示算法、颜色、前后帧逻辑与 E4 前一致，本阶段只改变可达性和命中面积。

## 14. 工具栏横向空间与旋转

操作：
- 横屏打开 Timeline，滚动 / 操作顶部工具区。
- 切到竖屏，再重复。

预期：
- 高频按钮、Select、`…`、FPS 均可到达。
- 工具栏可以沿用已有 ScrollContainer 处理空间不足，不出现控件永久被截断。
- Canvas / Timeline 主区域仍可操作。

## 15. P1-E1 回归

快速确认：
- Cel 单击单选；
- Frame Header 单击；
- Select 多选 Cel；
- Select 整 Frame 多选；
- Cel 双击打开原菜单；
- Frame Header 双击打开原菜单。

预期：E3/E4 不改变 E1 已验收的选择与菜单语义。

## 16. P1-E2 回归

快速确认：
- Cel / Frame 立即拖动仍优先 Timeline 滚动；
- 长按约 0.45 秒后拖动仍进入 reorder；
- 多选 Cel / Frame 长按拖动仍保持多选集合；
- 边缘自动滚动正常；
- 一次 reorder 仍对应一次 Undo。

预期：E3/E4 没有接管 E2 的 reorder gesture owner。

## 17. Layer / Desktop 快速回归

iPad：
- D4 Layer 选择、长按 reorder、Group reparent、Layer `…` 菜单快速验证一次。

如有桌面构建：
- 原完整 Frame toolbar、鼠标右键菜单、鼠标拖放、快捷键保持不变。

预期：E3/E4 的布局适配只在 iOS 生效。

## 最小人工 Gate

如果只做快速真机验收，至少完成：
1. 顶部直接按钮 + `…` 能正常操作；
2. Frame Properties / Duration 可修改；
3. Tag 左 / 右边缘各 resize 一次，并验证 Undo；
4. 两个 Pixel Cel 完成 Link → Unlink，并验证 Undo；
5. Onion Skin 直接开关 + Settings 可达；
6. E1 单击 / 多选与 E2 长按 reorder 各快速回归一次；
7. 横屏、竖屏各确认一次工具栏无不可达控件。

以上通过即可作为 P1-E3～E4 合并 Gate。E3 不需要再额外单独做一轮人工真机测试。
