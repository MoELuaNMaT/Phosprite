# P1-E1 iPad 真机测试用例

目标：验证 Timeline 的选择交互已经从鼠标优先改造成可直接用手指操作，同时不提前进入 P1-E2 的长按拖动。

## 1. Cel 单击选择

准备一个至少 3 Frame、3 Layer 的工程。

操作：
- 用手指依次点击不同 Frame / Layer 交叉位置的 Cel。

预期：
- 每次普通单击只保留当前点击的一个 Cel。
- 当前 Frame 和当前 Layer 同步切换到该 Cel。
- Cel、Frame Header、Layer 行的选中高亮与当前选择一致。
- 不应出现一次触摸执行两次选择、选中后又被取消等 synthetic mouse 重复行为。

## 2. Frame Header 单击选择

操作：
- 当前处于任意 Layer。
- 点击不同的 Frame 编号。

预期：
- 切换到对应 Frame。
- 普通模式下只选择该 Frame × 当前 Layer 的一个 Cel。
- 当前 Layer 不应因为点击 Frame Header 而改变。

## 3. Cel 双击上下文菜单

操作：
- 先记录当前 Cel 多选集合和当前 Frame / Layer。
- 对同一个 Cel 快速双击。

预期：
- 第一击仍按普通单击即时响应。
- 第二击确认双击后，先恢复到第一击之前的 Cel 多选集合和当前 Frame / Layer，再打开现有 Cel PopupMenu。
- 因此双击结束后的选择状态应与双击开始前完全一致，不应额外加入或移除目标 Cel。
- 菜单仍包含该 Cel 类型原有的 Properties / Select pixels / Delete / Link / Unlink / Clone 等可用项目。
- 不增加新的 Cel 业务事务或 UndoRedo 记录。

## 4. Frame Header 双击上下文菜单

操作：
- 先记录当前 Cel 多选集合和当前 Frame / Layer。
- 对同一个 Frame 编号快速双击。

预期：
- 第一击仍按普通 Frame 单击即时响应。
- 第二击确认双击后，先恢复到第一击之前的 Cel 多选集合和当前 Frame / Layer，再打开现有 Frame PopupMenu。
- 因此双击结束后的选择状态应与双击开始前完全一致，不应额外选择或取消该整帧。
- Remove / Move Left / Move Right / Reverse 等菜单禁用状态应依据恢复后的真实选择状态刷新。
- 第一帧的 Move Left 不可用；最后一帧的 Move Right 不可用；只有一个 Frame 时 Remove 不可用。

## 5. 进入 / 退出 Timeline 多选模式

操作：
- 点击 Timeline 顶部新增的 Select 多选按钮。
- 再次点击关闭。

预期：
- 按钮有清晰的 Toggle 状态。
- 开启后进入多选；关闭后退出多选。
- 关闭多选时不强制清空已经形成的多选集合。
- 退出多选后的下一次普通 Cel / Frame 点击会恢复单选行为。

## 6. 多选模式下 Cel 增减选择

操作：
- 打开多选模式。
- 依次点击多个 Cel。
- 再点击其中一个已经选中的 Cel。

预期：
- 未选中的 Cel 被加入 `selected_cels`。
- 已选中的 Cel 再次点击会从选择中移除。
- 当前焦点切换和高亮同步正常。
- 当只剩最后一个 Cel 时，再点击它不会把选择变成空集合。

## 7. 多选模式下 Frame 整帧选择

操作：
- 打开多选模式。
- 点击某个 Frame Header。

预期：
- 该 Frame 在所有 Layer 上对应的 Cel 都进入选择。
- 再次点击已经完整选中的该 Frame，应从多选集合移除这一整帧。
- 如果这一整帧就是当前唯一选择，系统至少保留其中一个 Cel，不允许 `selected_cels` 为空。

## 8. 多选 + 双击菜单共存

操作：
- 打开多选模式并形成至少 3 个 Cel 的多选集合。
- 记录此时的完整多选集合与当前 Frame / Layer。
- 对“已选中的 Cel”和“未选中的 Cel”分别测试完整双击。
- 对“已完整选中的 Frame”和“未完整选中的 Frame”分别测试完整双击。

预期：
- 第一击可以产生即时单击反馈，但第二击确认双击时必须撤销第一击对选择造成的变化。
- 菜单打开后，`selected_cels`、current Frame、current Layer 与双击开始前一致。
- 已选 Cel 不应因双击被取消；未选 Cel 不应因双击被加入。
- 已选整帧不应因双击被取消；未选整帧不应因双击被加入。
- Cel 与 Frame Header 都复用原有 PopupMenu，不创建新的菜单事务。

## 9. Timeline 滚动不被 E1 抢占

操作：
- 手指从一个 Cel 上按下后立即横向拖动超过约 12 px。
- 在 Timeline 可纵向滚动时，也测试从 Cel 上直接纵向拖动。

预期：
- 拖动应属于现有 ScrollContainer，Timeline 正常滚动。
- 不发生 Cel 选择。
- 不出现拖动预览、Frame/Cel 重排或 Drop 高亮。
- E1 不应因为触摸选择而抢占 E2 尚未实现的拖动所有权。

## 10. iPad 外接鼠标 / 触控板回归

如有外接鼠标或触控板：

操作：
- 先用手指点击多个 Cel。
- 再使用真实鼠标 / 触控板点击 Cel、Frame。

预期：
- 物理 Pointer 到来后恢复原生按钮 mouse_filter。
- 鼠标左键、右键以及原有 Shift / Ctrl / Cmd 行为保持现有桌面语义。

## 11. 项目切换

操作：
- 打开多选模式。
- 在两个已打开工程之间切换。

预期：
- 多选模式按钮重置为关闭。
- 新工程使用自己的 `selected_cels`，不会继承上一个工程的触摸候选状态。
- 不出现失效 Control 引用或异常点击。

## 12. D4 Layer 回归

至少快速确认：
- Layer 单击选择。
- Layer 双击菜单。
- Layer Rename。
- Layer 长按重排。

预期：
- P1-E1 不影响 D4-A / D4-B / D4-C 已验收行为。

## 最小合并 Gate

如果只做快速真机验收，至少完成：

1. Cel 普通单击。
2. Frame Header 普通单击。
3. Cel 双击菜单，并确认双击前后选择集合不变。
4. Frame 双击菜单，并确认双击前后选择集合不变。
5. 开启多选后选择 3 个 Cel，再取消其中 1 个。
6. 多选模式点击一个 Frame，确认整帧选中。
7. 在多选模式下分别双击已选 / 未选 Cel 与 Frame，确认菜单打开但选择状态恢复。
8. 从 Cel 上直接拖动，确认是滚动而不是选择/重排。
9. 关闭多选，再点击 Cel，确认恢复单选。
10. 快速回归一次 Layer 长按重排。

全部通过即可判定 P1-E1 真机 Gate PASS。
