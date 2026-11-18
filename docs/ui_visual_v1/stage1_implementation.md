# UI Visual System v1.0 — Stage 1 Implementation and Verification

Branch: `feat/ui-visual-system-stage1-20261118`  
Based on: `docs/ui-visual-system-stage0-20261118` (draft PR #130).  
Status: **opt-in implementation / visual preview**; full device sign-off pending.

## Goals completed in source

1. **Semantic palette:** `PhospriteTokens.gd` contains exact Sunny Cream and Twilight Berry visual values from the production spec, including canvas/gallery targets not yet applied.
2. **Independent renderer:** `PhospritePixelStyle.gd` creates reusable R10 / R6 / R4 `ImageTexture` + `StyleBoxTexture` resources from integer pixel masks, using 24×24 / 20×20 / 16×16 nine-slice sources, margins 10 / 7 / 5 and content margins 8 / 4 / 2.
3. **Hard shadow:** the optional 2px offset is rasterized directly into the texture; no `StyleBoxFlat.shadow_size` is used for opt-in floating chrome.
4. **Button-ready state resources:** R6 `normal`, `hover`, `pressed`, `disabled` and `focus` resources are available as a helper Theme. These are not globally installed on existing Buttons in stage 1.
5. **Theme compatibility:** `Themes.gd` appends **Sunny Cream (Phosprite)** and **Twilight Berry (Phosprite)** behind all previous presets. Default and saved theme indices remain unchanged; custom and non-Phosprite themes continue using legacy style generation.
6. **Real pilot:** `WorkspaceVisualTheme.gd` + `WorkspaceModule.gd` use the pixel style for **floating, peeking and collapsed Workspace module chrome** only when one of the new presets is selected. Docked and bottom Timeline geometry, plus all touch/drag/resize code, remain unchanged.
7. **Automated test suite:** `tests/unit/test_p1_ui_visual_design_system.gd` verifies tokens, corner transparency, exact fill, 2px shadow, stylebox margins, button states, theme detection, legacy fallback and font preservation.

## Deliberate compatibility boundaries

- **Do not touch the user's canvas texture:** UI color budget only applies to shell chrome. No canvas or palette data changes in this stage.
- **Do not change font objects or font sizes:** the current theme font and translation fallback are passed through. The arbitrary font-size budget in the concept spec is **not** enforced until iPad Chinese/English screenshots confirm safe text rendering.
- **Do not change every widget yet:** gallery, topbar, toolbars, palette, UI1/UI3/UI4 layouts and CelButton are separate planned stages. A global StyleBox replacement now would silently change existing interactions.
- **Do not touch existing theme indices:** both new presets were appended at the end.
- **Do not change hit regions:** none of the WorkspaceModule header, floating resize, exclusion or UI3 touch logic was modified.
- **Do not assert texture sampling is proven:** nine-slice source pixels are exact, but real iPad rendering/filter scaling must still be checked before a production-wide switch.

## Test and inspection plan

Automated CI on each source push:
```
godot --headless --path . --import
godot --headless --path . --quit-after 120
godot --headless --path . --script res://tests/runner.gd -- --phosprite-test-runner
gdformat --diff .
gdlint .
```

CI is expected to run through the repository's normal regression and static workflows. Record actual GitHub run outcomes before marking the stage validated.

Required manual preview on iPad before merging:
- [ ] Switch from existing Dark to Sunny Cream, observe a floating Preview and Palette window.
- [ ] Check R10 corner stair-stepping at native and 2× UI zoom, without blurry edge pixels.
- [ ] Check the blue (+2,+2) hard-shadow shape does not clip or show irregular seams when resized.
- [ ] Switch to Twilight Berry, confirm label readability and no unexpected transparent layer.
- [ ] Switch back to existing Dark/Light and to a custom theme: original chrome and font remain.
- [ ] Drag and resize Preview toward UI3 quick bar; no overlap and no bar movement.
- [ ] Open projects repeatedly and test Chinese text, English text and numbers.
- [ ] Verify exact paint colors and Canvas/Preview grayscale remain unchanged.
- [ ] Validate actual iPad touch target size separately; the source spec's `40+4=44` premise is not sufficient.

## Next adoption rule

Only after the pilot passes on iPad should stage 2 start replacing Gallery buttons and topbar assets. Use the R6 button state helper **without replacing Godot font resources**; add localized labels and physical hit-area verification per component. If nine-slice scaling causes edge blur, keep the token/geometry contracts and switch the shell rendering technique; do not add an overall nearest filter to the user's canvas/ColorPicker hierarchy as a workaround.
