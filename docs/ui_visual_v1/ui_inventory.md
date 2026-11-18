# UI implementation inventory — pinned code audit

Audited code: `fix/p0-p2-audit-repairs-20261117` at `11c86c0`. **Static/source evidence only.** No in-app or iPad rendering was observed.

Legend: **confirmed** = explicit code/scene contract; **visual pending** = screenshot required; **candidate** = needs live reference and device confirmation.

| UI domain | Current scene/script owner | Confirmed baseline behavior | Design target / gap | Protect / regression contract |
|---|---|---|---|---|
| Global theme | `assets/theme.tres`; `src/Autoload/Themes.gd`; `src/UI/Workspace/WorkspaceVisualTheme.gd`; `WorkspaceThemeController.gd` | Base theme and many variants (System, Light, OLED, etc.); floating shell uses derived shades, 4px rounded corner and soft shadow | Unified tokens, R10/R6/R4 and hard offset; requires compatible theme bridge | Avoid changing canvas data, text fallback, custom themes and module identity |
| Project Gallery shell | `src/UI/ProjectGallery/ProjectGallery.tscn`, `.gd` | Dark BG; top bar 64 min height; import/new/multiselect; 6 landscape and 4 portrait columns; reflow logic | Cream background, chip topbar, coral New; adaptive grid in narrow width | New/import/selection/renaming/deleting/thumbnail status/scrolling/safe area must survive |
| Project Gallery card | `src/UI/ProjectGallery/ProjectGalleryCard.tscn`, `.gd` | Dark card R8, thumbnail frame R6, canvas dimensions and modified-time label, outline multi-select; no dedicated visible name header | R10 card with 28px name strip; conditional name / default title; visual selection | Existing gesture cancel and selected state; corrupted/unavailable thumbnail; project identity |
| iPad Top Menu | `src/UI/TopMenuContainer/TopMenuContainer.gd`, `.tscn` | Separate iOS icon buttons for Projects, Settings, Effects; live PopupMenu command paths; icon buttons currently 32×32; SVG Tabler | Two visual islands, 40 visual controls with verified usable hit target, 3-profile graphic segmented choice | Keep command dispatch, menu IDs, shortcuts and all non-iOS menu behavior |
| UI profile storage/switch | `src/UI/Workspace/WorkspaceUIProfileController.gd`; `WorkspaceLayoutStore.gd`; `WorkspaceEditorMigration.gd` | Three profile IDs 1, 3, 4, profile-scoped state snapshots; rejects removed UI2 | Friendly names/icons on same switching path | No second source of state; safe restoration across projects |
| Workspace floating system | `WorkspaceModule.gd`, `WorkspaceSurface.gd`, `WorkspaceDockHost.gd`, `WorkspaceVisualTheme.gd` | Floating panels, header and resize routes, reserved rectangles for UI3 strip | R10 floating chrome, hard pixel shadow, uniform header where safe | Keep float/dock boundary, Timeline-grip exception, exclusion/overlap and z-order |
| UI3 tool taskbar | `src/UI/Workspace/WorkspaceUIProfile3.gd` | Task buttons 38×38; grouped selection/shape representatives; actively excludes certain iOS-only tool proxies | Q icons, tighter two-island layout, tool-mode icon states | Preserve selection family tap toggle, tool selection and original source buttons |
| UI3 left quick strip | `WorkspaceUIProfile3.gd`; `WorkspaceSurface.gd` | Fixed strip `QUICK_BAR_WIDTH=100`, anchored x=8; pencil/eraser size and opacity via original Range controls; reserved from floating windows | 48px capsule, fine size mapping, opacity and sampled-color chip, temporary HUD | Keep original values and max range, fixed position, floating exclusion, Timeline clearance, no occlusion |
| UI3 color popup | `WorkspaceUIProfile3.gd`; `PaletteColorPanel.tscn`; `ColorPickers/ColorPicker.gd` | CurrentColor taskbar button toggles `UIProfile3PalettePopup`, nominal 320×460; separate color settings popup | Temporary vs tear-off persistent window, R4 dual color chip | No duplicate color model; no accidental long-press pick; close/restore behavior |
| Palette panel | `src/Palette/PalettePanel.tscn`, `.gd` | Palette select/edit/create; legacy add/delete/sort/lock nodes, some hidden by current iPad presentation | Compact color swatch chrome and updated icons *only for active controls* | Empty-swatch assign, project palette vs global file synchronization, color lock/sort semantics |
| Palette swatch | `src/Palette/PaletteGrid.gd`, `PaletteSwatch.gd` | Default 26×26, iOS 32×32; exact color equality selection; swatch drawing in `PaletteSwatch._draw()` draws black/white rect borders | R4 swatch 28×28 +4 spacing, selected halo; no color distortion | Exact primary/secondary match, transparency, reordering, touch suppression and tap handlers |
| Tool option inputs | `src/UI/Nodes/Sliders/ValueSlider.gd`; `src/UI/Nodes/ToolOptionModePicker.gd`; tool scenes | Tool-only vertical drag behavior; compact icon plus caption mode choices | Theme + pixel visuals without changing input direction | Existing min/max/step, double-tap text requirements, localization and icon labels |
| UI4 split panel | `WorkspaceUIProfile4.gd`, `WorkspaceDockHost.gd` | Existing draggable `UI4PaletteSplitHandle` with 18px grab band | Visual 3-dot handle on same draggable strip | Preserve width/height partitioning, gesture routing and saved layout |
| Timeline / cells | `src/UI/Timeline/AnimationTimeline.tscn`, `CelButton.tscn`, `SingleFrameLayerCard.gd`, layer scripts | `CelButton` 36×36; multiple selected states and touch multi-select; selection outlines separately drawn | R6 cell face, Q layer/playback icons, selected-state coherence | No phantom drags, preserve single-frame vs animation data, layer eye/lock and project state |
| Canvas / preview | `src/UI/Canvas/Canvas.tscn`; `CanvasPreview.tscn`; `WorkspaceBuiltinModules.gd` | Separate canvas and preview flows; live content must not be touched by decorative theme | Keep image colors exact; only theme surrounding chrome | Preview grayscale sync, pixel grid, no nearest-neighbor regression |
| Asset groups | `assets/graphics/tools`, `layers`, `timeline`, `mode_icons/mdi`, `ui/tabler`, `quick_access_panel` | Mixed PNG and SVG resource families; no `assets/graphics/q_icons` directory on baseline tree | New assets land under Q registry after source mapping is verified | Do not delete referenced SVG/PNG before replacing every live reference and updating tests |

## Explicit source observations

- `ProjectGallery.gd`: `LANDSCAPE_COLUMNS=6`, `PORTRAIT_COLUMNS=4`; source UI spec's static 4-column premise conflicts.
- `ProjectGalleryCard.tscn`: R8 normal card, R6 thumbnail panel, `CanvasSize` / `ModifiedTime` labels; a name header does **not** currently exist.
- `WorkspaceVisualTheme.gd`: `CORNER_RADIUS=4` and `StyleBoxFlat.shadow_size=3` on floating modules.
- `WorkspaceUIProfile3.gd`: `TASK_BUTTON_SIZE=38`, `QUICK_BAR_WIDTH=100`, `PALETTE_POPUP_SIZE=320×460`; UI3 quick controls proxy original Range nodes.
- `WorkspaceSurface.gd`: `set_floating_exclusion_rect()` enforces nonoverlap with UI3 quick strip.
- `PaletteGrid.gd`: iOS default swatch 32×32; selection based on exact Color match. `PaletteSwatch.gd`: actual `_draw()` uses `draw_rect`.
- `TopMenuContainer.gd`: Projects/Settings/Effects point at Tabler SVG and use 32×32 iPad button target.
- `WorkspaceUIProfileController.gd`: menu IDs are 1/3/4; no UI2 reactivation.
- `CelButton.tscn`: 36×36 already meets requested visual dimensions; corner/style rendering remains to be migrated.

## Baseline tests to retain and extend

| Behavior | Existing test anchor | Next stage addition |
|---|---|---|
| UI3 quick strip and floating exclusion | `tests/unit/test_ui3_safe_layout.gd`; `test_p2_c_workspace_surface_constraints.gd` | 48px size and HUD state without overlap regression |
| Workspace theme changes | `tests/unit/test_p2_e_workspace_visual_theme.gd` | Golden token/9-slice tests for Sunny Cream and Twilight Berry |
| iOS menu / profile commands | `tests/unit/test_editor_ipad_unified_settings.gd`; `test_ui_profile_3_procreate.gd` | 3-segment selector calls the same profile controller |
| Tool mode icon semantics | `tests/unit/test_mode_button_icons.gd` | Replace explicit old MDI asset assertions when Q assets are integrated |
| Palette selection | `tests/unit/test_palette_model.gd`; earlier palette touch tests in `docs/p1_d3_palette_touch_test_cases.md` | Swatch contrast, exact color and transparent pixel test |
| iOS touch protection | `tests/unit/test_ios_touch_ui_behavior.gd`; touch-selection test docs | Drag/pick/switch priority after capsule + color tear-off |
| Runtime project entry | `tests/integration/test_p3_c_app_shell_runtime.gd` | Ensure new theme initialization does not break iPad opening |

## Verification gaps

This stage used repository and cloud-document reads. It did **not** run Godot tests, generate a device IPA, capture actual light/dark/device screenshots, visually prove occlusion, or measure hit target sizes at physical iPad scale. Those are tracked in [acceptance_baseline.md](acceptance_baseline.md). All proposed visual outcomes remain unverified until rendered.
