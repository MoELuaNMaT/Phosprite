# Tool Options 图标与模式菜单统一审查（2026-11-09）

## 目标与适用范围
- 覆盖 `src/Tools` 下 29 个工具场景配置，所有 UI Profile 共用相同工具状态。
- 用图标代替“即时命令”的文字按钮。保留需要明确表达持久开关状态的复选框标签。
- 互斥的多个选项统一显示为一个当前模式图标。单击图标打开菜单，选中后关闭；再次单击图标可以关闭。
- 不改变画布编辑语义、快捷键、项目文件格式或已有配置字段。

## 调整清单

| 工具／选项 | 原显示 | 新显示 | 资源／说明 |
| --- | --- | --- | --- |
| 选区模式：Replace/Add/Subtract/Intersect | 4 个竖直的图标按钮 | 当前图标 + 4 图标弹出菜单 | 沿用已有 MDI 图标 |
| 选区操作：Select all/Clear/Reselect/Invert/Select cel area | 5 个文字按钮 | 5 个按状态显示的图标按钮 | MDI select-all、selection-off、backup-restore、select-inverse、grid |
| 选区修改：Expand/Shrink/Border/Center | 4 个文字按钮 | Modify 图标展开，内部 4 个图标 | MDI border-color、arrow-expand-all、arrow-collapse-all、border-all、image-filter-center-focus |
| 油漆桶填充区域：Similar area/colors/Whole selection | 3 个竖直图标按钮 | 当前图标 + 3 图标弹出菜单 | 沿用已有图标 |
| 油漆桶填充内容：Selected color/Pattern | 2 个文字按钮 | 当前图标 + 2 图标弹出菜单 | MDI palette-swatch、checkerboard |
| 取色器：Top Color/Current Layer | 2 个竖直图标按钮 | 当前图标 + 2 图标弹出菜单 | 沿用已有图标 |
| 曲线工具：Chained/Single | 2 个文字按钮 | 当前图标 + 2 图标弹出菜单 | MDI vector-polyline、vector-bezier |
| 缩放：Fit to frame/100% Zoom | 2 个文字按钮 | 2 个独立图标动作 | MDI fit-to-screen-outline、image-size-select-actual |
| 裁剪：Apply | 文字按钮 | 单个图标动作 | MDI check |
| 画笔：Pressure settings | 文字“…”按钮 | 单个设置图标 | MDI tune-variant |
| 渐变形状、抖动、重复和区域 | 已是单图标菜单 | 保留 | 现有 `Gradient.gd` 为参考实现 |
| Pixel Perfect、Fill Shape、Across Layers、Wrap Strokes 等 | 状态复选框 | 保留标签 | 独立开关，不应混进互斥模式菜单 |
| 一般参数、选项列表和数值滑块 | 参数输入 | 不修改 | 不是文字动作按钮 |

## 状态机

| 场景 | Select all | Select cel area | Clear | Invert | Reselect | Modify |
| --- | --- | --- | --- | --- | --- | --- |
| 无当前选区、无历史选区 | 显示 | 显示 | 隐藏 | 隐藏 | 隐藏 | 隐藏 |
| 无当前选区、有历史选区 | 显示 | 显示 | 隐藏 | 隐藏 | 显示 | 隐藏 |
| 有当前选区 | 显示 | 显示 | 显示 | 显示 | 隐藏 | 显示 |

项目切换后重新连接到当前项目的 `selection_changed` 信号；撤销和恢复选区也通过该信号更新。模式状态继续由工具原来的 `get_config`、`set_config`、`save_config` 管理。通用 `ToolOptionModePicker` 只管理显示和点击，不保存新的状态副本。

## 人工验收用例

- [ ] 新建空项目，打开选区工具：只显示全选与选择帧格区域的操作图标。
- [ ] 点击全选：取消、反选和修改入口出现，重新选择不显示。
- [ ] 点击取消：选区消失，重新选择入口出现。
- [ ] 点击重新选择：选区恢复，重新选择入口消失。
- [ ] 使用框选、套索、魔棒、颜色选择等切换选区：图标与动作状态一致。
- [ ] 对现有选区使用反选、扩展、收缩、边框和居中：确认原有功能未变化。
- [ ] 对空项目执行选择帧格区域；确认按帧格内容执行，必要时选区状态正确。
- [ ] 选区模式图标单击展开；选择任意模式后只显示所选图标；再次点击可关闭菜单。
- [ ] 油漆桶的区域模式和颜色／图案模式各自独立；选为图案时显示图案偏移参数，选为颜色时隐藏。
- [ ] 取色器在顶部合成和当前图层模式间切换，取色结果正确且当前图层预览不残留。
- [ ] 曲线工具在 Chained/Single 模式间切换，绘制与启动诊断正常。
- [ ] 各工具切换、工程切换、关闭再进入后，模式图标与保存状态一致。
- [ ] UI1、UI2、UI3、UI4 检查窄栏和悬浮设置：弹出菜单不遮挡主要操作、不超出屏幕。
- [ ] 用触控执行单击、再次单击、点空白处关闭；无重复触发、误长按或点击穿透。
- [ ] 缩放、裁剪和画笔设置图标具有正确的动作和工具提示。

## 素材许可

新增素材来自 [Pictogrammers / Material Design Icons](https://github.com/Templarian/MaterialDesign-SVG)，Apache License 2.0；与原项目中采用的 MDI SVG 风格保持一致。具体文件已更新 `assets/graphics/mode_icons/mdi/NOTICE.md`。

## 风险与验证

主要风险为：模式按钮和持久化配置不同步、工具场景内的 `PopupPanel` 生命周期、UI3 悬浮窗口的边界定位、无选区／历史选区状态混淆、以及 Godot SVG 导入。为降低风险，保留原始信号回调和配置字段；新增图标在 UI 初始化时加载；使用既有 CI 的资源导入、编辑器入口、UI3 冒烟和全量自动回归测试。
