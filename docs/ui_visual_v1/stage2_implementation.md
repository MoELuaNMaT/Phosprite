# UI Visual System — Stage 2 implementation

Status: **implemented on opt-in branch, awaiting real iPad visual acceptance**.

Base: Stage 1 + bundled CJK font + Timeline header fix `f3bc8eac4b1b7a399076fe2898d5d6a76c1ca2ff`. This branch does not modify `master` or merge Stage 1 PRs.

## What changed

| Area | Theme-scoped changes | Functional owner preserved |
|---|---|---|
| Gallery shell | Semantic `gallery_ground` and R10 pixel top-bar; exact 2× brand logo | Existing project scan and screen rotation |
| Gallery actions | Import and Multi-Select left group; coral independent New CTA; new 32px Q icon assets | Existing button signals, long-press menus, multi-select transactions |
| Project cards | Pixel R10 surface and R6 thumbnail well, selected accent label strip, title derived by Gallery, 1/2/3px borders | Thumbnail contents, project paths, P3 interaction logic, original 6/4 columns |
| Editor top bar | Pixel shell, 40px Projects/Settings/Effects buttons with Q icons | Original PopupMenu command IDs, shortcuts and dialogs |
| UI1/UI3/UI4 | 3-state visual option in iPad Workspace Settings and in Settings popup | **One** `WorkspaceUIProfileController` and existing WorkspaceLayoutStore |
| Shared resources | Nine 20×20 Q PNGs, cropped to central 16×16 and cached at true integer 2× (32×32); reusable pixel Button chrome | Existing font and color selection, no Canvas or pixel-art mutation |

Active only for built-in **Sunny Cream** or **Twilight Berry**, detected through semantic tokens. All older themes and custom themes keep existing UI; changes are reversible without changing project data or layout slots. The pixel setting **1/2/3px** continues to control borders/corner steps/shadow. There is no global DPI change and no global nearest filter.

The project filename is displayed in the new themed title strip only. The older Gallery does **not** show filenames. A default `untitled_*` project receives a localized “Untitled N” caption in the new strip.

## Affected files

- `src/UI/DesignSystem/PhospriteStage2Chrome.gd` and `PhospriteStage2Icons.gd`
- `assets/graphics/q_icons/top/`, `gallery/`, and `layout/` (nine icon PNGs)
- `src/UI/ProjectGallery/ProjectGallery.gd`, `ProjectGalleryCard.gd`, `ProjectGalleryCard.tscn`
- `src/UI/TopMenuContainer/TopMenuContainer.gd`
- `src/Preferences/PreferencesDialog.gd`
- Three translation catalogs and `tests/unit/test_ui_visual_stage2.gd`

## Acceptance checks (on device)

- [ ] Sunny Cream and Twilight Berry: compare 1/2/3px. Inspect R10 corners, hard shadows, icon pixels and text CJK fallback.
- [ ] Rotate Gallery between landscape 6-column and portrait 4-column states; make sure thumbnails never crop.
- [ ] Open 3+ projects, rename/duplicate/delete and multi-select with one finger. Verify no ghost presses or state resets.
- [ ] Toggle themed/legacy presets repeatedly. Gallery background, title strip and original top-bar icon dimensions must fully revert.
- [ ] UI1/UI3/UI4 switch from both the new Settings popup entries and the traditional UI profile source. Check independent saved layout sizes and project data.
- [ ] Check top bar and Gallery on narrow iPad split view, including menu overflow and no clipped text/targets.
- [ ] In Chinese and English, verify titles and tooltips. New typography must inherit the bundled iOS CJK fallback.
- [ ] Verify undo history and Timeline header still work after profile switches and Gallery reopen.

**Device confirmation remains pending until someone actually installs a built IPA.** Passing static/Godot regression tests does not prove iPad color, nearest-filter quality, touch regions, or narrow viewport fit.

## Scope intentionally excluded

UI3 fixed tool strip, color popovers and HUD belong to Stage 3; palette and timeline visual skin to Stage 4. Stage 2 does not replace the entire 78-icon manifest. Later asset batches will cover missing icons such as export/share, delete, undo and redo after corresponding live controls are identified.
