# PhoSprite Design System Contract — Warm Cartridge (v3)

This file is the single source of truth for all PhoSprite iPad UI and dynamic UX implementation across **ProjectGallery**, **UI 1 (Classic Dual-Column)**, **UI 3 (Immersive Touch)**, and **UI 4 (U-Dock)**.

## 1. Locked Layout Architecture
- **ProjectGallery**, **UI 1**, **UI 3**, and **UI 4** remain independent, full-featured workspaces with bottom `AnimationTimeline`.
- Visual polish MUST preserve each profile's core spatial philosophy; never remove bottom timelines or re-enable unused right-click iPad tool options.

## 2. Pixel Stroke & 1U Grid Standard
- **Global Pixel Unit (`1U`)**: `2 dp` (`Global.pixel_ui_unit = 2`, 4 physical pixels on iPad Retina). Legacy `BAR_U = 4` and `FLOPPY_U = 5` are retired.
- **Single-Stroke Discipline** (adapted from `open-claude-ui`):
  - **Primary Ink Stroke (`1U = 2dp`)**: Clickable keycap buttons, floating popups, active gallery cards, primary panel edges.
  - **Physical Bottom Lip (`1U = 2dp`)**: Normal/Hover keycaps only; pressed/latched states shift down `2dp` and flatten the lip.
  - **Subtle Structural Divider (`0.5U = 1dp`)**: Internal panel dividers, palette swatch grid lines, timeline cel separators.
  - **Zero Stroke (`0dp`)**: Nested text strips, non-interactive grouping containers.

## 3. Four-Tier Micro-Contrast Surface Ladder (S0 → S3)
| Role | Warm Paper (Light) | Dark Cartridge (Dark) | Usage |
|---|---|---|---|
| `S0 · canvas_backdrop` | `#3D3B38` | `#171615` | Canvas & preview neutral backdrop |
| `S1 · well_surface` | `#E5E0D6` | `#1C1A18` | Top bar, recessed wells, slider tracks |
| `S2 · panel_surface` | `#F2EFE9` | `#242220` | Docked sidebars, timeline shell |
| `S3 · elevated_surface` | `#FCFBF7` | `#2C2926` | Tactile keycap buttons, popups, hover |
| `outline_ink` | `#2C2A29` | `#0E0D0C` | 2dp primary pixel borders |
| `border_subtle` | `#C9C2B6` | `#3A3632` | 1dp internal structural dividers |
| `text_primary` | `#242220` | `#EDE9E0` | Primary ink (dark de-dilation warm white) |
| `text_muted` | `#6E685F` | `#A39C92` | Captions, dimensions, timestamps |
| `accent_primary` | `#E85D3F` | `#F06D4F` | Active keycap, playhead, primary CTA |
| `accent_secondary` | `#3A6EA5` | `#5B93CC` | Lock indicators, secondary highlights |

## 4. Single-Source Open-Source Assets
- **Iconography**: 100% sourced from [`halfmage/pixelarticons`](https://github.com/halfmage/pixelarticons) (MIT License, 24×24 pixel grid, pure-white monochrome PNGs in `assets/graphics/q_icons/`, dynamically tinted via semantic tokens).
- **Typography**: [`TakWolf/fusion-pixel-font`](https://github.com/TakWolf/fusion-pixel-font) (`FusionPixel12pxProportional.ttf`, SIL OFL 1.1) paired with bundled `NotoSansCJKsc-Regular.otf` fallback for zero tofu across all 40+ locales.

## 5. Dynamic UX Interaction Physics (adapted from `open-claude-ui`)
- **Timing Constants**: `70ms` Haptic Snap (keycap press/tool switch), `120ms` Geometric Bite (toggles/segmented pills), `240ms` Damped Spring (popups/splitters).
- **4px Pointer Deadzone**: Suppresses accidental drags when tapping swatches, timeline cels, or gallery cards on iPad.
- **Double-Tap 54/46 Spring Snap**: Double-tapping UI 4's Preview/Palette split handle smoothly resets to default proportions.
- **TopBar Symmetry**: Editor top-left `Gallery`, `Settings`, and `Effects` buttons are strictly uniform `36×36` icon-only keycaps (`8px` spacing).
