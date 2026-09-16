# P1-E2 iPad 真机测试用例

目标：验证 Timeline 的 Cel / Frame 已能通过“长按后拖动”安全重排，同时普通滑动仍然属于 Timeline 滚动；E1 的单击、双击、多选不能回归。

## 1. Cel 普通滑动仍然滚动

操作：
- 手指按在任意 Cel 上后立即横向拖动，明显超过约 12 px。
- Timeline 可纵向滚动时，再从 Cel 上立即纵向拖动。

预期：
- Timeline 正常滚动。
- 不出现 reorder preview、虚线 source marker 或 drop highlight。
- 不移动 Cel。
- 不产生 Undo 记录。

## 2. 单个 Cel 长按拖动

操作：
- 选择一个 Cel。
- 按住约 0.45 秒后开始左右拖动。
- 拖到同一 Layer 的另一个 Frame 左半区 / 右半区并释放。

预期：
- 长按后开始移动时取得 reorder ownership。
- 出现 floating preview、source outline 和现有 Timeline drop highlight。
- 左 / 右半区决定插入方向。
- 释放后调用现有 Cel Move 行为。
- 一次 Undo 完整撤销；一次 Redo 完整恢复。

## 3. 未选 Cel 作为拖动源

操作：
- 当前已有其他 Cel 选择。
- 长按一个未选中的 Cel 并拖动。

预期：
- 取得 drag ownership 时，选择集合先收敛为这个源 Cel。
- 只拖这个 Cel，不把此前无关的选择一起带走。

## 4. 多选 Cel 一起拖动

操作：
- 使用 E1 Select 模式选择多个 Cel。
- 长按其中一个已选 Cel，再拖动。

预期：
- 已有多选保持，不因长按源 Cel 被压缩成单选。
- 拖动 payload 使用当前 `selected_cels`。
- 同 Layer 可按原生规则一起 Move。
- 一次 Undo 撤销整次多 Cel Move。

## 5. Cel 跨 Layer

操作：
- 长按 Cel，将其拖向另一个兼容 Layer 的 Cel。

预期：
- 继续沿用项目现有的跨 Layer Swap 规则。
- 不新增 Touch 专用的第二套 Swap 逻辑。
- 不兼容 Layer 类型的目标仍应判定无效。
- Linked Cel 限制与桌面原有行为一致。

## 6. 单个 Frame 长按重排

操作：
- 长按 Frame Header 约 0.45 秒后左右拖动。
- 分别在目标 Frame 左半区和右半区释放。

预期：
- Frame 进入 reorder ownership。
- Drop highlight 正确显示插入侧。
- Frame 顺序正确改变。
- 一次 Undo / Redo 对应一次完整 Frame reorder。

## 7. 未选 Frame 作为拖动源

操作：
- 当前选择包含其他 Frame。
- 长按一个不属于当前选择集合的 Frame Header。

预期：
- 取得 ownership 时选择收敛到该 Frame × 当前 Layer。
- 只拖这个 Frame。

## 8. 多 Frame 一起拖动

操作：
- 在 E1 多选模式下形成跨多个 Frame 的选择。
- 长按其中一个已包含在当前选择中的 Frame Header。
- 拖动到新位置。

预期：
- Frame 集合继续从现有 `selected_cels` 推导，不出现新的 selected_frames 状态。
- 多 Frame 按原生 Frame reorder 行为一起移动。
- 一次 Undo 恢复整个 Frame 集合。

## 9. Frame reorder 与 Tag

准备：
- 创建覆盖若干 Frame 的 Animation Tag。

操作：
- 长按拖动 Tag 范围内或范围外的 Frame。

预期：
- Tag 范围跟随原有 Frame `_drop_data()` 的重算规则变化。
- Undo / Redo 后 Frame 与 Tag 都恢复正确。

## 10. 横向边缘自动滚动

操作：
- 创建足够多 Frame，使 Timeline 需要横向滚动。
- Cel 或 Frame 进入 reorder ownership 后，将手指拖到可视区域左 / 右边缘之外并停住。

预期：
- Timeline 持续横向自动滚动。
- 手指不继续移动时也会滚动。
- 越过边缘越远，滚动速度逐步增加。
- 回到可视区后停止自动滚动。

## 11. Cel 纵向边缘自动滚动

操作：
- 创建足够多 Layer，使 Timeline 需要纵向滚动。
- Cel 进入 reorder ownership 后，将手指拖到可视区域上 / 下边缘之外并停住。

预期：
- Timeline 持续纵向自动滚动。
- 手指静止时仍滚动。
- Frame Header drag 不应触发纵向自动滚动。

## 12. 无效目标与取消

分别测试：
- 拖到 Timeline 外无效区域释放。
- 拖到不兼容的 Cel / Frame 目标释放。
- 系统触发 touch cancel（如能稳定复现）。

预期：
- 不调用原生 `_drop_data()`。
- 不产生 Undo transaction。
- preview、source outline、drop highlight 全部清理。
- 原数据顺序不变。

## 13. 外接 Ctrl / Cmd 不污染 Finger drag

如有外接键盘：
- 按住 Ctrl / Cmd。
- 用手指拖动同 Layer Cel 或 Frame。

预期：
- Finger drag 仍按 Touch Move 语义执行，不因为修饰键突然变成桌面强制 Swap。
- 跨 Layer Cel 仍可按原生规则 Swap。

随后用鼠标 / 触控板测试 Ctrl / Cmd drag。

预期：
- 桌面原有 Ctrl / Cmd Swap 行为保持不变。

## 14. P1-E1 回归

快速确认：
- Cel 单击单选。
- Frame Header 单击。
- Select 多选 Cel。
- Select 整 Frame 多选。
- Cel 双击菜单且选择状态回滚正确。
- Frame Header 双击菜单且选择状态回滚正确。

预期：
- E2 不改变 E1 已验收语义。

## 15. D4 Layer 回归

快速测试：
- Layer 普通滚动。
- Layer 长按重排。
- Group 拖入 / 拖出。
- Layer 边缘自动滚动。

预期：
- P1-E2 不影响 D4-B Layer reorder。

## 最小人工 Gate

如果只做快速真机验收，至少完成：

1. Cel 上立即滑动，确认是滚动。
2. Cel 长按后同 Layer Move + Undo。
3. 多选 3 个 Cel，长按其中一个一起 Move + Undo。
4. Cel 跨 Layer，确认沿用原生 Swap / 类型限制。
5. Frame 单个长按重排 + Undo。
6. 多 Frame 长按重排 + Undo。
7. 横向边缘停住，确认持续自动滚动。
8. Cel 纵向边缘停住，确认持续自动滚动。
9. 无效区域释放，确认 no-op。
10. Cel / Frame 双击菜单各测试一次，确认 E1 不回归。

以上全部通过即可判定 P1-E2 真机 Gate PASS。
