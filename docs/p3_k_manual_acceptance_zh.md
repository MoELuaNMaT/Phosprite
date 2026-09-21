# Phosprite P3-K 中文人工验收用例

适用对象：P3-K 最终 IPA / 本轮 Debug 回归 IPA。

主要实机基线：iPad Air（第 5 代）、iPadOS 18.0、Apple Pencil 2。

结论规则：所有标记为“是”的必测项目均通过后，P3-K 才可标记为 REAL-DEVICE PASS。CI 已覆盖的事务微窗口会标为“自动化主验收”，不要求人工碰运气触发毫秒级中断。

## 一、测试准备

准备以下素材：

- 一个正常 .pxo 项目 A，至少 3 个图层、8 帧；
- 一个正常 .pxo 项目 B，尺寸与 A 不同；
- 一个故意损坏的 .pxo（普通文本文件改扩展名即可）；
- 一个 .ase 或 .aseprite 文件；
- PNG、JPG 各一张；
- Photos 中准备 PNG/JPG/HEIC 至少各一张；
- 一个 3 帧以上动画项目，用于 GIF/APNG 或 spritesheet 分享；
- Files 中准备一个与 Phosprite managed Projects 同名的外部文件，验证导入重名处理。

每个用例记录：PASS / FAIL / N/A、设备方向、是否 Pencil、失败截图或录屏、实际现象。

复选框规则：`[x]` = 你已在真机确认通过；`[ ]` = 本轮仍需执行或复测。当前仅预勾你已确认通过的 A01–A06、A08。

---

## A. 安装、冷启动与 App Shell

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [x] | A01 | 是 | 对最终 IPA 完成签名/侧载并首次启动 | App 可正常启动，无崩溃、黑屏、永久 loading |
| [x] | A02 | 是 | 清除应用数据后冷启动 | 直接进入 Project Gallery，不进入 Editor |
| [x] | A03 | 是 | 冷启动观察启动过程 | 不出现旧 Splash |
| [x] | A04 | 是 | 冷启动且没有任何 recovery | 不出现全局“上次异常退出/恢复”弹窗 |
| [x] | A05 | 是 | 杀掉 App 后再次普通启动 | 仍先进入 Gallery，不自动打开上次项目 |
| [x] | A06 | 是 | Gallery 横屏启动 | 顶栏、项目区、Import/New 均在安全区内，无裁切 |
| [ ] | A07 | 是 | Gallery 竖屏启动 | 同上，无控件越界 |
| [x] | A08 | 是 | Gallery 前后台切换 3 次 | 不闪退、不重复初始化、不出现重复弹窗 |
| [ ] | A09 | 是 | 从 Editor 返回 Gallery 后再次进 Editor | AppShell 往返稳定，没有残留半透明或偏移 |
| [ ] | A10 | 是 | 连续 Gallery↔Editor 往返 10 次 | 无卡死、模式错乱、项目丢失 |

## A-R. 本轮 Debug 定向回归

| 状态 | ID | 操作 | 预期 |
|---|---|---|---|
| [ ] | AR01 | 准备至少 5 个项目，竖屏冷启动 Gallery | 固定 4 列；左右边缘全部位于屏幕安全区内，不横向溢出 |
| [ ] | AR02 | 至少 5 个项目时横屏→竖屏→横屏各 3 次 | 6↔4 列稳定切换；不溢出、不乱序、不残留旧列宽 |
| [ ] | AR03 | 分别在卡片“缩略图区域”执行单击、双击、长按 | 与卡片文字区域行为完全一致：打开 / 菜单 / 多选均可触发 |
| [ ] | AR04 | Gallery → New 创建项目并进入 Editor | 只存在新建的时间戳“未命名_…”项目；不再出现额外纯“未命名”项目 |
| [ ] | AR05 | 进入 Editor 观察顶部并放大 Canvas 到顶部区域 | 项目 Tabs 完全移除；Canvas 紧接顶部编辑区，原 Tabs 下方约 3–5 行死区消失 |
| [ ] | AR06 | 用画笔、橡皮、直线工具分别点击 Canvas 最顶部 1–5 像素行 | 工具与跟手图标均可进入并生效，不存在不可点击条带 |
| [ ] | AR07 | 点击左侧 Projects/Home，再重复往返 Editor↔Gallery 10 次 | 按钮不被 iPadOS 顶部三个点遮挡；每次均可点击且模式切换稳定 |

## B. Gallery 布局、缩略图与动效

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | B01 | 是 | 横屏进入 Gallery | 固定 6 列 |
| [ ] | B02 | 是 | 竖屏进入 Gallery | 固定 4 列 |
| [ ] | B03 | 是 | 横屏→竖屏 | 卡片平滑 reflow，不瞬移到错误位置 |
| [ ] | B04 | 是 | 竖屏→横屏 | 同上 |
| [ ] | B05 | 是 | 快速连续旋转 5 次 | 不崩溃、不出现卡片重叠/重复/乱序 |
| [ ] | B06 | 是 | 在 reflow 尚未结束时快速点卡片 | 不应误打开视觉上另一张卡片 |
| [ ] | B07 | 是 | 滚动到中下部后旋转 | 项目顺序保持，不随机换位 |
| [ ] | B08 | 是 | 从 Editor 点 Projects/Home 返回 | Gallery 回到顶部 |
| [ ] | B09 | 是 | Gallery 有大量项目时快速上下滚动 | 滚动顺畅；可视范围外缩略图不要求提前加载 |
| [ ] | B10 | 是 | 新进入 Gallery 观察尚未解码的健康卡片 | 可看到 Loading preview… 状态 |
| [ ] | B11 | 是 | 使用无 preview 的健康 PXO | 显示 Preview unavailable，项目仍可存在 |
| [ ] | B12 | 是 | 放入损坏 PXO | 显示 Corrupted/不可读状态，不导致 Gallery 崩溃 |
| [ ] | B13 | 是 | 检查透明缩略图 | Gallery 缩略图透明区域不显示棋盘格 |
| [ ] | B14 | 是 | 查看缩略图比例 | 图片保持比例居中，不裁切、不拉伸 |
| [ ] | B15 | 是 | 空项目库启动 | 显示“无项目”标题及 New/Import 引导 |

## C. Project Gallery 手势与多选

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | C01 | 是 | 单击健康项目 | 约 300ms 判定后打开项目 |
| [ ] | C02 | 是 | 双击健康项目 | 打开项目操作菜单，不同时进入 Editor |
| [ ] | C03 | 是 | 两次点击间隔接近 300ms | 边界仍能稳定识别双击 |
| [ ] | C04 | 是 | 长按 1 秒 | 进入多选并选中该项目 |
| [ ] | C05 | 是 | 长按后松手 | 不再泄漏一次单击打开 |
| [ ] | C06 | 是 | 按住卡片拖动超过约 12px 后松手 | 当作滚动/拖动，不误触打开 |
| [ ] | C07 | 是 | 多选态单击多个项目 | 分别切换选中状态 |
| [ ] | C08 | 是 | 观察选中视觉 | 有明显描边和右上角勾选，整页不整体变暗 |
| [ ] | C09 | 是 | 多选 A/B/C 后双击 A | 批量菜单作用于 A/B/C |
| [ ] | C10 | 是 | 多选 A/B/C 后双击未选 D | D 不应被临时加入选择集 |
| [ ] | C11 | 是 | 点击 Exit Multi-Select | 清空多选并回普通态 |
| [ ] | C12 | 是 | 双击卡片后滚动少量 | Popover 跟随原卡片锚点 |
| [ ] | C13 | 是 | Popover 打开后将卡片滚出可视区 | Popover 自动关闭 |
| [ ] | C14 | 是 | Popover 打开时旋转屏幕 | 菜单不漂到无关卡片上；必要时安全关闭 |

## D. 新建项目

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | D01 | 是 | Gallery → New | 默认尺寸 64×64 |
| [ ] | D02 | 是 | 逐一浏览 21 个预设 | 21 个预设均存在，尺寸和方向正确 |
| [ ] | D03 | 是 | 分别创建一个 1:1、4:3、16:9 预设 | Canvas 尺寸与所选预设一致 |
| [ ] | D04 | 是 | 自定义 1×1 | 可创建 |
| [ ] | D05 | 是 | 自定义 16384×16384 | 输入范围允许；若内存不足必须明确失败而不是生成损坏项目 |
| [ ] | D06 | 是 | 输入 0、负数、>16384 | 不允许生成非法尺寸 |
| [ ] | D07 | 是 | 连续新建两个同秒项目 | 自动名称不冲突，必要时追加后缀 |
| [ ] | D08 | 是 | 创建项目后立刻返回 Gallery | 项目已先写入 managed PXO，不是只存在内存 |
| [ ] | D09 | 是 | 新建后杀 App，再启动 | 已成功进入 Editor 的项目仍在 Gallery |
| [ ] | D10 | 是 | 新建失败场景（可用空间不足时验证） | 不留下半成品项目卡片；若无法稳定制造则记 N/A |

## E. Managed Save、Home 与后台持久化

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | E01 | 是 | 编辑后停止操作并等待 >2 秒 | 项目自动持久化 |
| [ ] | E02 | 是 | 连续编辑约 35 秒不停笔/频繁改动 | 最长约 30 秒仍会触发保存，不会无限拖延 |
| [ ] | E03 | 是 | 编辑后立即点 Projects/Home | 返回前强制保存 |
| [ ] | E04 | 是 | 修改项目 A 后立即切项目 B | A 在切换前强制保存 |
| [ ] | E05 | 是 | 编辑后立即切到后台 | 后台边界执行强制保存 |
| [ ] | E06 | 是 | 编辑后锁屏/系统挂起，再恢复 | 不出现项目损坏；已完成的强制保存内容保留 |
| [ ] | E07 | 是 | 修改后等待 >2 秒，再从任务管理器杀 App | 重启后修改仍存在 |
| [ ] | E08 | 是 | 修改后 <2 秒立即强杀 App | 正式 PXO 必须仍可打开；最近未到 debounce 的改动可能丢失，此项不以“必须保留最后一笔”为标准 |
| [ ] | E09 | 是 | 重复 E07 10 次 | 不出现一次性 ZIP 损坏或项目消失 |
| [ ] | E10 | 是 | 保存完成后检查 Gallery | 不应无缘无故出现 recovery 提示 |
| [ ] | E11 | 是 | Home 返回期间快速连续点击 | 不出现 Editor/Gallery 双重可交互状态 |

## F. Recovery / 异常退出

F01–F03 的“事务中断精确微窗口”由 P3-K 自动测试主验收；人工无需反复碰运气卡毫秒级窗口。F04 起为真机可观察行为。

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | F01 | 自动化主验收 | 中断在 staging 写完、尚未 install recovery | 正式 PXO 不变且有效；staging 不冒充 recovery |
| [ ] | F02 | 自动化主验收 | 中断在 recovery install 后、formal commit 前 | 正式 PXO 仍有效；新 recovery 保留 |
| [ ] | F03 | 自动化主验收 | 模拟重新启动后重新扫描 | 对应项目显示 pending recovery |
| [ ] | F04 | 条件必测 | 真机出现 recovery 项目时冷启动 | App 先进入 Gallery，不弹全局恢复 |
| [ ] | F05 | 条件必测 | 在 Gallery 打开有 recovery 的项目 | 只对该项目弹恢复询问 |
| [ ] | F06 | 条件必测 | recovery 弹窗选择 Cancel | 留在 Gallery；recovery 不被消费 |
| [ ] | F07 | 条件必测 | Cancel 后再次打开同项目 | 再次询问 recovery |
| [ ] | F08 | 条件必测 | recovery 弹窗显示时直接杀 App | 再启动后 recovery 仍存在；再次打开仍询问 |
| [ ] | F09 | 条件必测 | 选择 Restore | 恢复版本成为正式项目并进入 Editor；之后不再提示同一 recovery |
| [ ] | F10 | 条件必测 | 新的 recovery 选择 Discard | 丢弃 recovery，打开正式版本；之后不再提示该 recovery |
| [ ] | F11 | 是 | Gallery 中有别的正常项目时触发 recovery 流程 | recovery 不影响其他项目打开 |
| [ ] | F12 | 是 | 损坏 PXO 与 recovery 项目同时存在 | 两种异常状态互不混淆，Gallery 不崩溃 |

## G. Files 导入与 Open In

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | G01 | 是 | Gallery → Import → 文件 | 打开原生 UIDocumentPicker |
| [ ] | G02 | 是 | Document Picker 取消 | 不创建项目、不留下半成品 |
| [ ] | G03 | 是 | 从 Files 选择单个 PXO | 导入为 managed PXO，外部原文件不被修改 |
| [ ] | G04 | 是 | 导入同名 PXO | managed 目标自动生成唯一文件名，不覆盖已有项目 |
| [ ] | G05 | 是 | 导入复制出来、UUID 与现有项目相同的 PXO | 只修导入副本 UUID，原项目身份不变 |
| [ ] | G06 | 是 | 选择 .ase | 成功转换并纳入 managed Project Library |
| [ ] | G07 | 是 | 选择 .aseprite | 同上 |
| [ ] | G08 | 是 | Files 选择 PNG/JPG | 进入图片导入流程 |
| [ ] | G09 | 是 | Files 一次多选 PXO/ASE/图片 | 按序串行处理，不同时弹多个决策框 |
| [ ] | G10 | 是 | 多选中间某张图片取消导入 | 清理该项临时文件，后续项仍可继续 |
| [ ] | G11 | 是 | 多选批次尚未结束 | 中间成功项不提前把界面切进 Editor |
| [ ] | G12 | 是 | 多选批次最后一个成功 | 最终进入 Editor |
| [ ] | G13 | 是 | Files 长按外部 PXO → 用 Phosprite 打开（App 已运行） | warm open-in 进入同一 P3-F managed import 流程 |
| [ ] | G14 | 是 | 杀掉 App 后从 Files 用 Phosprite 打开 PXO | cold open-in 可完成；startup Gallery 不覆盖导入结果 |
| [ ] | G15 | 是 | 从 Files Open In 图片 | 不把外部 URL 当项目保存位置，而是 copy-in/import |
| [ ] | G16 | 是 | 导入完成后回 Files 检查源文件 | 源文件时间/内容未被 Phosprite 修改 |
| [ ] | G17 | 是 | Gallery 项目菜单 → Reveal in Files | Files 打开并定位/展示对应 managed 文件 |
| [ ] | G18 | 是 | iPad Files 中查看 Phosprite Documents | managed Projects/*.pxo 可见 |

## H. Photos 导入

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | H01 | 是 | Gallery → Import → 照片 | 打开原生 PHPicker，不要求全量照片库权限 |
| [ ] | H02 | 是 | PHPicker 取消 | 不创建项目 |
| [ ] | H03 | 是 | 单选 JPG | 进入图片导入模式选择 |
| [ ] | H04 | 是 | 单选 HEIC | 能以规范化临时 PNG 进入同一图片业务流程 |
| [ ] | H05 | 是 | 多选 3 张照片 | 串行进入处理，不重叠弹窗 |
| [ ] | H06 | 是 | 第一张选“作为图层” | 进入 Canvas size 决策并正确创建 |
| [ ] | H07 | 是 | 图片选“作为参考图” | 保留源像素，以统一缩放 fit 到画布 |
| [ ] | H08 | 是 | 作为图层且图片大于画布 | 最近邻 downfit、居中，不产生模糊插值 |
| [ ] | H09 | 是 | 某一项取消模式/尺寸选择 | 当前项失败退出，下一项仍继续 |
| [ ] | H10 | 是 | 批次完成后再次打开 Photos | 上一批临时状态不残留 |

## I. Rename / Duplicate / Delete

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | I01 | 是 | 健康项目双击 → Rename | 能修改 managed 文件名 |
| [ ] | I02 | 是 | Rename 后关闭/重开 App | 项目 UUID/内容保持，名称保持 |
| [ ] | I03 | 是 | Rename 到已存在名称 | 明确报冲突，不自动改成另一个名字 |
| [ ] | I04 | 是 | Rename 已在 Editor 加载的项目 | save_path、file_name、tab title 同步 |
| [ ] | I05 | 是 | Duplicate foo.pxo | 得到 foo_1.pxo |
| [ ] | I06 | 是 | 再 Duplicate 原 foo.pxo | 得到 foo_2.pxo |
| [ ] | I07 | 是 | Duplicate foo_1.pxo | 得到 foo_1_1.pxo |
| [ ] | I08 | 是 | 打开原件和副本 | 内容相同，但 UUID 不同 |
| [ ] | I09 | 是 | 单项目 Delete | 只确认一次，确认后永久删除 |
| [ ] | I10 | 是 | 多选 3 项 Delete | 只确认一次，确认后批量删除 |
| [ ] | I11 | 是 | Delete 弹窗取消 | 不删除任何文件 |
| [ ] | I12 | 是 | 删除当前已加载项目 | runtime tab/Project 同步移除，Editor 不引用已删除对象 |
| [ ] | I13 | 是 | 删除带 recovery 的项目 | 对应 recovery/staging 一并清理 |
| [ ] | I14 | 是 | 双击 Corrupted 项目 | 菜单仅提供 Delete / Reveal，不出现 Rename/Duplicate/Export |
| [ ] | I15 | 是 | Rename/Duplicate/Delete 成功 | Gallery 顶部/内容区出现短暂 inline feedback |

## J. Export 与 Share Sheet

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | J01 | 是 | 单项目 Export | 复用现有 ExportDialog，配置项完整 |
| [ ] | J02 | 是 | 单项目导出 PNG | Share Sheet 只针对最终产物弹一次 |
| [ ] | J03 | 是 | 单项目导出 spritesheet | 输出尺寸/排列与 Editor 导出逻辑一致 |
| [ ] | J04 | 是 | 单项目动画导出 GIF/APNG | 等待动画文件真正生成后再弹 Share Sheet |
| [ ] | J05 | 是 | Share Sheet 取消 | App 不崩溃，Gallery 可继续操作 |
| [ ] | J06 | 是 | Share 到 Files | 文件可在目标位置打开 |
| [ ] | J07 | 是 | 多选 2 个项目 Export | 只配置一次 ExportProfile |
| [ ] | J08 | 是 | 批量导出 | 严格串行，一个 Share Sheet 结束后才出现下一个 |
| [ ] | J09 | 是 | 批量项目尺寸不同 | 每个产物内容/尺寸对应自己的项目，无 cache 串图 |
| [ ] | J10 | 是 | 批量项目文件名不同 | 每个产物使用自己的项目 basename |
| [ ] | J11 | 是 | 第二个 Share Sheet 取消 | 后续批次按既定取消语义停止，不出现并发 Share Sheet |
| [ ] | J12 | 是 | 批量导出结束后回 Editor | 原 Editor 当前项目未被 transient export 改掉 |
| [ ] | J13 | 是 | 导出前后查看 Recent/last project | transient PXO 不写入最近项目、不修改 last project |
| [ ] | J14 | 是 | 导出后立即再次导出另一项目 | 不继承上一项目 processed_images/blended_frames |

## K. P2 Workspace / 触控 / 绘制回归

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | K01 | 是 | Canvas 上 Apple Pencil 连续绘制 | 轨迹稳定，坐标正确，无明显断笔 |
| [ ] | K02 | 是 | Pencil 绘制、手指平移/缩放交替 | Content input 与 navigation 不串行为 |
| [ ] | K03 | 是 | 双指 pinch zoom Canvas | 缩放中心/速度自然，不误绘制 |
| [ ] | K04 | 是 | Preview 双指缩放 | Preview 可缩放，不影响 Canvas |
| [ ] | K05 | 是 | 画笔→橡皮→画笔 | 工具切换正确 |
| [ ] | K06 | 是 | 直线/曲线/矩形/椭圆/等距框各画一次 | 不崩溃，结果与工具预期一致 |
| [ ] | K07 | 是 | 长按图形工具入口选择子工具 | 折叠工具菜单可用，右下角子工具标识正常 |
| [ ] | K08 | 是 | 取色器点击画布颜色 | 正确取色，无旧“左/右键颜色模式”残留 |
| [ ] | K09 | 是 | 从 Canvas 外开始拖选区并进入 Canvas | 选区按既定规则生效 |
| [ ] | K10 | 是 | 选区移动/缩放/旋转、Undo/Redo | 结果可逆且坐标稳定 |
| [ ] | K11 | 是 | ≥3 Layer / 8 Frame 工程操作 | Layer/Frame 选择、增删、切换稳定 |
| [ ] | K12 | 是 | Timeline 调整帧 duration 并播放 | 播放节奏与 duration 一致 |
| [ ] | K13 | 是 | Timeline Tag resize，覆盖相邻/重叠场景 | Tag 边界正确，无 stale target |
| [ ] | K14 | 是 | Link/Unlink cel 后分别编辑 | Unlink 后彻底隔离，不串改 |
| [ ] | K15 | 是 | Onion Skin 开关与多帧编辑 | 显示正确，无残影状态泄漏 |
| [ ] | K16 | 是 | Animation Timeline 拖到下方 dock 后上下调高度 | 高度可调整，内容不被永久遮挡 |
| [ ] | K17 | 是 | Preview/Palette/Tools 等窗口浮动、折叠、恢复 | 位置稳定，折叠后标题栏留在原位 |
| [ ] | K18 | 是 | 重启 App | Workspace 不堆回左上角，Preview 不出现旧空白问题 |
| [ ] | K19 | 是 | Canvas 棋盘格放大检查 | Canvas 背景按既定 2×2 像素格表现 |
| [ ] | K20 | 是 | Preview 棋盘格检查 | Preview 按既定 8×8 表现 |
| [ ] | K21 | 是 | 标尺检查 | 标尺紧贴 Canvas，范围不超 Canvas，终点标注正确 |
| [ ] | K22 | 是 | 横竖屏各操作一次 Workspace | 所有悬浮窗/Timeline/Canvas 仍可操作且不越界 |
| [ ] | K23 | 建议 | 接鼠标/触控板 | 主按钮、滚轮/缩放、上下文行为无明显回归 |
| [ ] | K24 | 建议 | 接键盘 | 常用快捷键、Undo/Redo 与文本输入无明显回归 |

## L. Project Library 压力与长期操作

| 状态 | ID | 必测 | 操作 | 预期 |
|---|---|---|---|---|
| [ ] | L01 | 是 | 准备至少 100 个 managed 项目 | Gallery 可进入，不因数量直接卡死/崩溃 |
| [ ] | L02 | 是 | 100+ 项目快速滚动 | 卡片按需加载缩略图，不出现全量同时解码造成长时间冻结 |
| [ ] | L03 | 是 | 外部在 Files 新增一个 managed PXO 后回 App/刷新 | 新项目出现 |
| [ ] | L04 | 是 | 外部删除一个 managed PXO 后回 App/刷新 | 项目消失 |
| [ ] | L05 | 是 | 外部替换一个 PXO 后回 App/刷新 | 尺寸/mtime 等 metadata 更新 |
| [ ] | L06 | 是 | 放入多个同 UUID 的物理副本 | 所有文件都保留，非 canonical 副本获得新身份 |
| [ ] | L07 | 是 | 重启后再次查看上述 duplicate 项目 | UUID 修复稳定，不会每次启动都继续变化 |
| [ ] | L08 | 是 | 100+ 项目横竖屏切换 | 6↔4 reflow 正常，不乱序 |
| [ ] | L09 | 是 | 100+ 项目多选 20 项后退出多选 | 选择视觉和状态能完全清空 |
| [ ] | L10 | 是 | 连续 Rename/Duplicate/Delete 各 10 次 | Gallery 与磁盘状态一致，无幽灵卡片 |
| [ ] | L11 | 是 | 连续导入 10 个 Files 项目 | 每项纳管成功或明确失败，不互相覆盖 |
| [ ] | L12 | 是 | 长时间编辑一个项目并反复 Home/打开 20 次 | 不产生重复 runtime Project/tab，不出现逐次变慢的明显异常 |

## M. 最终退出标准

最终记录以下结果：

- Static Checks：PASS；
- Regression Tests：PASS，0 failures；
- iOS unsigned build：PASS；
- 最终 IPA 已获取；
- A～L 所有标记为“是”的项目：PASS；
- F04～F10 若没有 recovery 候选可稳定制造，可标记 N/A（自动化事务 Gate 已 PASS），但至少应完成一次真实“杀 App → 冷启动 → Gallery”流程；
- 所有 FAIL 都附截图/录屏和最短复现步骤。

只有自动化全绿且本表必测项通过后，P3-K 才标记为 REAL-DEVICE PASS / CLOSED。
