# UI Visual System — Stage 3 pilot implementation

Status: **functional implementation on feature branch; iPad visual and touch acceptance pending**.

**Base:** Stage 2 feature HEAD `4d1c93269433ddce201ead5fa68c684fcb0c6371`, including Stage 1 1/2/3px visual thickness, bundled CJK font and Timeline header font bridge. Do not start from older `master`.

## Implemented

| Visual element | Stage 3 change | Existing behavior protected |
|---|---|---|
| UI3 Pencil/Eraser strip | 48px opt-in R10 pixel capsule, 14px vertical tracks, overlapping two actual color swatches | Left strip is **fixed** at original safe-bound anchor. Workspace floating exclusions still reserve its rectangle; timeline stays clear |
| Brush size | 1–16px within first 55% of travel; ease toward each real brush's maximum over last 45% | Underlying `Brush/BrushSize` remains authoritative. Larger 256px ranges, %/image brushes and source updates remain available. Legacy themes keep original sliders |
| Opacity | 0–100% native source slider mirrored into capsule | No duplicated settings state; existing source `Range` owns values |
| HUD | Noninteractive, token-themed preview beside capsule, 20px numeric label, 180ms release-to-hide | Only visible during a slider drag. Native tool preview pixels are not painted on the artwork |
| Color shortcuts | Swatches show actual left/right colors; tapping invokes original `Tools.swap_color()` | Global color synchronization and assigned tool slots remain intact |
| Palette & Color popup | Optional 36px grip, 24px drag-to-pin threshold, movable and clamped to root canvas area, Q close icon | **Same** existing Palette scene and live colors; no duplicate palette or project settings. Temporary popup closes from blank canvas; pinned popup remains open until closed |
| UI3 topbar | New right R10 pixel tool island; narrow viewport scrolls horizontally instead of hiding tools; 40px touch buttons | Same source Tool buttons, families, existing shortcut/command handlers and layout profile; no clipboard action deletion |
| Presets | New treatment only with Sunny Cream / Twilight Berry and all 1/2/3px settings; legacy UI3 reuses original 100px controls | Switching theme removes overrides, hides the pinned color card and HUD and restores ordinary tool presentation |

## Design boundary and conscious departures

- The production visual specification proposes a default Procreate strip curve that ends at 128px. This implementation intentionally targets the **real source brush maximum**: silently capping 256px brushes would break established tool settings. The curve is only used for whole-pixel size sliders.
- The fixed strip is not made movable and does not yield to a Preview drag. The earlier user-approved collision rule takes precedence over the generic floating-window proposal.
- Existing selection clipboard actions and context menus are **not deleted** in Stage 3 without a verified replacement path. The new top island preserves the commands and scrolls if there is insufficient split-view width.
- The existing global long-press color sampler remains untouched. Starting that gesture directly from a color swatch is **not** in this pilot, because it would require an explicit handoff from GUI pointer capture to the canvas sampler and is risky without touch hardware evidence.
- Color swatches themselves are not altered by the UI shell color budget. Only pixel chrome uses semantic tokens. Do not apply `NEAREST` sampling to text.

## Automated verification

- `tests/unit/test_ui_visual_stage3.gd` checks curve round-trip, source maxima, 24px tear-off, viewport clamping, overlay input pass-through and fixed Workspace exclusion.
- The full existing tests also cover UI3 quick source sync, floating Preview exclusion, Timeline height changes, Pencil/Eraser configuration, compact tool options and color menu states.
- CI static checks and Godot regression suite are required to be green on final commit.

## iPad test scenarios

- [ ] Switch UI3 and back to UI1/UI4. Verify the preexisting source brush value, opacity and profile layout heights survive.
- [ ] In both new themes at thickness 1/2/3px, compare actual 48px strip corners/track widths/HUD/contrast. Test a 1px, 16px, 128px and larger brush.
- [ ] Drag Preview and Tool Options directly toward the left capsule. Neither may cover it or force it to move to the right.
- [ ] Tap vs drag the Palette header (0, 23, 24 and 40px drags); check the close icon, pinned state and re-entry after theme switching.
- [ ] Sample colors using the existing canvas long-press gesture and verify the capsule and popup show the same primary/secondary colors.
- [ ] Open/close tool settings via top-right tool icon and tap empty canvas: no accidental stroke.
- [ ] Rotate, resize Timeline and test 590pt split-screen. Right tool island may scroll but must never clip/hide actions.
- [ ] Check Simplified Chinese/English/number glyphs on iPad; no tofu squares.
- [ ] Confirm App start and project open do not crash; do not mark the pilot production-ready based solely on CI.

## Not in Stage 3

Stage 4 owns general PaletteGrid candy swatches, UI1/UI4 panel skins and all Timeline visual states. General 78-icon replacement beyond this pilot remains separately tracked in `icon_registry.csv`.
