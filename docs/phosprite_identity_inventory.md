# Phosprite 身份分类清单(P0-A)

> 依据:`phosprite_ipad_multiplatform_execution_plan.md` 冻结决策 + `PHOSPRITE_P0_CONTRACT_V3`
> 目的:把「必须保留的上游兼容标识」与「必须改为 Phosprite 的产品标识」分开,避免重构时误伤 `.pxo` / GPL / 扩展 API 的兼容性。

---

## A. 兼容标识(禁止改动 — 冻结)

这些字符串是 **跨产品数据契约**,一旦改动,用户已有的 `.pxo` 项目、GPL 调色板、第三方扩展会失效。

| 标识 | 位置 | 作用 | 冻结原因 |
|:---|:---|:---|:---|
| `pixelorama_version` | `src/Classes/Project.gd:319` | `.pxo` JSON 顶层键 | 上游 `.pxo` 读写双方都依赖此键名 |
| `pxo_version` | `src/Classes/Project.gd:320,361` | `.pxo` 格式版本 | 决定反序列化兼容分支 |
| `Pxo_Version=7` | `project.godot:31` | 当前 `.pxo` 格式版本值 | 改动会改变写出格式 |
| `application/x-pixelorama` | `src/Autoload/OpenSave.gd:514` | `.pxo` zip 内 mimetype 条目 | 上游按此名读取归档 |
| `PixeloramaEmptySlot` | `src/Autoload/Palettes.gd:616,664` | GPL 调色板空槽标记 | 写入与读取必须是同一字面量 |
| `pixelorama_data` | `src/Autoload/Global.gd:152` | 随程序分发的默认资源目录 | 打包路径与 `export_presets.cfg` 一致 |
| `get_pixelorama_version()` | `src/Autoload/ExtensionsApi.gd:127` | 扩展 API 方法名 | 第三方扩展调用此名 |
| `signal_pixelorama_opened` | `src/Autoload/ExtensionsApi.gd:1023` | 扩展 API 信号包装 | 同上 |
| `signal_pixelorama_about_to_close` | `src/Autoload/ExtensionsApi.gd:1028` | 扩展 API 信号包装 | 同上 |
| `pixelorama_opened` / `pixelorama_about_to_close` | `src/Autoload/Global.gd:10,12` | Global 信号 | 被 ExtensionsApi 转发 |
| `supported_api_versions` | `src/HandleExtensions.gd:158` | 扩展清单键名 | 扩展安装校验依赖 |

> 这些标识由 `tests/unit/test_compatibility_identifiers.gd` 逐条守护。

---

## B. 产品标识(必须为 Phosprite)

| 项 | 位置 | 值 |
|:---|:---|:---|
| 应用名 | `project.godot:13` | `Phosprite` |
| 应用描述 | `project.godot:14` | 含上游 MIT 归属说明 |
| 自定义用户目录开关 | `project.godot:18` | `true` |
| 用户数据 namespace | `project.godot:19` | `phosprite` |
| 运行时产品名常量 | `src/Autoload/Global.gd:148` | `PRODUCT_NAME := "Phosprite"` |
| 可写用户目录名 | `src/Autoload/Global.gd:150` | `HOME_SUBDIR_NAME := "phosprite"` |
| CI 导出名 | `.github/workflows/*.yml` | `EXPORT_NAME: Phosprite` |

**用户数据落点**:`OS.get_data_dir()/phosprite`(Windows 为 `%APPDATA%\phosprite`)。
**上游归属**:`project.godot:14` 的 description 明确保留 Pixelorama / Orama Interactive 的 MIT 归属。

> 这些项由 `tests/unit/test_product_identity.gd` 逐条守护。

---

## C. 已停用(可保留代码,不进入运行路径)

| 项 | 处理 |
|:---|:---|
| Steam 集成 | `project.godot` 删除 `[steam]` 段;`Main.tscn` 不再实例化 `SteamManager`。`src/Classes/SteamManager.gd` 文件保留但无引用,便于将来评估。 |
| Ubuntu Touch (Clickable) | `.github/workflows/dev-clickable-builds.yml` 改为 `workflow_dispatch` 手动触发,不绑定分支,不会成为产品分支的门禁。 |
| Extension 系统 | 代码保留(P1 范围),iOS 上暂停使用。 |

---

## D. 判定规则

改动任何 `pixelorama` 字面量前,先问:

1. 它是 **A 区**的跨产品数据契约吗?→ 不允许改。
2. 它只是 C 区已停用路径的内部命名吗?→ 可以留待 P1 处理。
3. 它是 **B 区**的产品可见标识吗?→ 必须是 Phosprite。

模糊时按 **A > B > C** 优先级保守处理:宁可保留上游命名,也不破坏兼容性。
