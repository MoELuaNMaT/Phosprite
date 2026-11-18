# Phosprite UI Visual System v1.0 — Stage 0 Baseline

Status: **stage 0 static inventory recorded; device captures still pending**.  
Recorded: **2026-11-18**.  
Scope: **documentation and audit only**; no UI logic, source asset, Godot scene, or build-setting changes.

## Source of truth

- GitHub repository: [MoELuaNMaT/Phosprite](https://github.com/MoELuaNMaT/Phosprite).
- **Frozen implementation baseline:** `fix/p0-p2-audit-repairs-20261117` at commit `11c86c04471ff1094122b4a83fca5f59890271b4`.
- Default `master` reference: `6280c5bab99049ed5b57803324bc3bb7d5443be8` (2026-11-09).
- GitHub comparison at stage-0 audit: implementation baseline **ahead by 23 commits; behind by 0**. Do **not** start the UI redesign from `master` alone or discard those fixes.
- Primary visual specification: [Phosprite Ui Production Spec.md](https://drive.google.com/file/d/1VegR1KFmgFJ3TBp7Z0U5Wfe1z09fjTxi/view?usp=drivesdk).
- Icon specification: [Phosprite Q Icon Manifest.md](https://drive.google.com/file/d/1pslp5NqcfWLgea-mvuWWKbzUqXfBrQCQ/view?usp=drivesdk).

The two source specifications are external design inputs. This stage **does not overwrite them**. Any contradictions with current code or earlier accepted interaction decisions are tracked in [spec_errata.md](spec_errata.md). Corrected requirements should be agreed upon before implementation.

## Recorded deliverables

| Artifact | Contents |
|---|---|
| [ui_inventory.md](ui_inventory.md) | Actual UI modules, scene/script owners, existing features, gaps, regression contracts |
| [icon_registry.csv](icon_registry.csv) | All 78 design IDs, verified manifest priority, proposed destination paths, existing asset candidates and unresolved mappings |
| [spec_errata.md](spec_errata.md) | Specification inconsistencies, conflicting product assumptions, implementation constraints |
| [acceptance_baseline.md](acceptance_baseline.md) | Required screenshots and test baselines, current verification status, stage-1 entry criteria |

## Scope and non-goals

Stage 0 **does**: pin implementation commit and source documents; map scene ownership; identify existing icons and missing mappings; make specification conflicts explicit; capture a reproducible acceptance checklist.

Stage 0 **does not**: change UI colors, replace icons, alter gestures, create or update IPA, change defaults, refactor Theme, alter master or the 2026-11-17 repair branch, or claim device tests without running them.

## Boundary for stages 1–5

1. **Stage 1:** token palette, pixel StyleBoxes, theme compatibility, text/font and crisp-raster checks. First validate on a limited sample without replacing every UI.
2. **Stage 2:** Project Gallery, top bars, profile switcher, and high-frequency assets.
3. **Stage 3:** UI3 quick strip, color tear-off and HUD; preserve floating exclusions and original tool values.
4. **Stage 4:** palette swatches, UI1, UI4, Timeline and layer controls; preserve selection and touch semantics.
5. **Stage 5:** remaining icons, removal of obsolete visual references after usages are migrated, device regression.

Priority labels in the **icon** spec are illustration batches, not code defect priorities. The true item counts are **P0 42, P1 27, P2 9** (78 total). These must not be conflated with the unrelated 2026-11-17 repair priority labels.

## Rule for implementation follow-up

Use the pinned branch SHA as the comparison anchor. Before an implementation branch starts, recheck whether the 2026-11-17 repair branch advanced. If it did, inspect the delta and rebase/merge **deliberately**. Do not silently branch from default `master`.

The icon registry marks existing **asset candidates**, not necessarily live UI references. A candidate is confirmed by filename/path presence; live node usage must be traced before replacement. No runtime screenshot has been captured during Stage 0.
