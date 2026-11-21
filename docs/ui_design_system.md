# Phosprite Unified Neo-Y2K Pixel UI Design System (v2)

This specification defines the shared visual tokens and layout rules for all Phosprite interfaces (Project Gallery, Editor UI1 / UI3 / UI4, dialogs, and popups) under the `Sunny Cream (Phosprite)` and `Twilight Berry (Phosprite)` themes (`Global.pixel_ui_unit = 2` default).

## 1. Spacing Scale (4px Base Grid)
| Token | Value | Usage |
|---|---|---|
| `SPACE_XXS` | `2px` | Tight metadata line spacing |
| `SPACE_XS` | `4px` | Icon-to-label gap inside compact chips, tight button pairs |
| `SPACE_SM` | `8px` | Action group button gaps, card internal section spacing |
| `SPACE_MD` | `12px` | Card body padding, panel internal padding, topbar vertical margin |
| `SPACE_LG` | `16px` | Grid column gap, separation between distinct toolbar groups |
| `SPACE_XL` | `24px` | Page horizontal safe margin, topbar horizontal margin |

## 2. Corner Radius Rules (Integer Pixel-Stepped)
- **`RADIUS_NONE` (0px — No Rounded Corners)**:
  - Full-width edge-docked bars (`TopBar`, docked `AnimationTimeline`, docked sidebars).
  - Fullscreen backgrounds and canvas viewports.
- **`TIER_S` (4px pixel-stepped)**:
  - Compact badges, status pills, card selection checkboxes, slider tracks, small chips.
- **`TIER_M` (6px pixel-stepped)**:
  - Standard interactive buttons (Import, Select, New, editor tool buttons), thumbnail frames, text inputs (`LineEdit`), menu item highlights.
- **`TIER_L` (8px pixel-stepped)**:
  - Standalone content cards (`ProjectGalleryCard`), floating workspace modules, modal dialogs, popups.

## 3. Typography Scale (Preserves Global CJK Fallback)
Never override `font` directly on individual controls so `NotoSansCJKsc-Regular.otf` fallback remains intact. Set only `font_size` and semantic `font_color`:
- `FONT_BRAND` (`20px`): App wordmark (`Phosprite`), empty-state hero title.
- `FONT_TITLE` (`15px`): Dialog/panel headers.
- `FONT_CARD_TITLE` (`14px`): Card project titles, primary CTA button labels.
- `FONT_BODY` (`13px`): Standard button labels, toolbar labels, body hints.
- `FONT_META` (`12px`): Card primary metadata (canvas dimensions `64 × 64 px`), selection count pills.
- `FONT_CAPTION` (`11px`): Timestamps (`2025-11-21 00:00`), build identity, micro-labels.

## 4. Stroke / Border Rules (No Triple-Nested Outlines)
- **Primary Ink Stroke (`outline_ink`, 2px @ unit=2)**: Standalone cards, solid interactive buttons, floating module shells, popups.
- **Accent Stroke (`accent_primary`, 2px)**: Selected cards, active/toggled controls, focused inputs.
- **Subtle Structural Border (`border_subtle`, 2px)**: Bottom divider on edge-docked bars (`TopBar`), inner media wells (`ThumbnailFrame`).
- **Borderless (0px)**: Inner card title strips, non-interactive grouping containers, nested `PanelContainer`s inside `WorkspaceModule` shells.

## 5. Hard Pixel Shadow Rules (4px @ unit=2)
Hard pixel shadows communicate clickable elevation and are never applied indiscriminately:
- **With Hard Shadow (`with_shadow = true`)**: Standalone clickable cards (normal/selected), standard buttons in normal/hover state, floating panels, popups.
- **No Shadow (`with_shadow = false`)**: Edge-docked bars (`TopBar`), elements nested inside cards/panels (title strip, thumbnail well, checkbox), pressed/disabled buttons, and locked-active toggle buttons (such as active `Exit Multi-Select` to convey a latched pressed state).

## 6. Icon-to-Control Size Ratio (~45%–56%)
- **Top Bar Height**: `60px` (Gallery) / `48px` (Editor).
- **Standard Action Button**: `38px` height (`36px` compact), `12px` horizontal padding, `6px` icon-text separation.
- **Icon Size inside Buttons**:
  - `36–40px` text+icon buttons: `16×16` exact 1x integer pixel icons (`PhospriteStage2Icons.icon_1x`), leaving generous breathing room around borders and hard shadows.
  - `28–32px` compact editor icon-only buttons: `16×16` exact 1x integer pixel icons centered cleanly with balanced padding.
