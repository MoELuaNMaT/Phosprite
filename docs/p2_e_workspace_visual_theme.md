# P2-E — Workspace Visual Theme

## Goal

Give the P2 Workspace foundation a theme-aware visual language without migrating the live Pixelorama editor panels yet.

P2-E adds presentation only. The P2-A module lifecycle, P2-B dock model, P2-C placement semantics, and P2-D persistence format remain unchanged.

## Theme source

Workspace visuals derive from Pixelorama's active application Theme and the existing theme preferences:

- active Panel / PanelContainer surface color
- Label font color
- current base color
- current accent color
- current contrast value
- active default font and font size

`Themes.theme_switched` triggers a Workspace refresh, so Dark, Light, OLED, System, custom colors, and extension-provided themes are not treated as separate hard-coded Workspace skins.

## Semantic Workspace palette

`WorkspaceVisualTheme` exposes semantic values instead of application-specific hard-coded colors:

- surface
- elevated surface
- header
- border
- accent
- primary and muted text
- snap preview
- floating shadow

The semantic palette then builds module and header StyleBox resources for these states:

- `none`
- `docked`
- `floating`
- `collapsed`
- `peek`

Floating and Peek use a stronger accent/elevation treatment than docked modules. The same accent-derived preview color is used by both Dock and Floating snap previews.

## Module chrome

`WorkspaceModule` keeps the same runtime identity and lifecycle contract, but can now render Workspace chrome:

- panel surface and border
- compact title header
- title text from the module definition
- content padding below the title bar
- placement-dependent visual state

Adding chrome does not replace or recreate the module's content root. `get_content()` continues to return the exact content instance created by the P2-A module factory.

## Runtime controller

`WorkspaceThemeController` connects presentation to the existing runtime model:

- themes newly created modules immediately
- tracks Docked / Floating / Collapsed / Peek transitions
- reapplies styles when the application theme changes
- synchronizes both snap preview colors

The controller does not own placement and does not write persistence state.

## UI bootstrap boundary

`UI.gd` creates the controller after `WorkspaceSurface` and before the layout store restore. It applies the current application Theme immediately and listens to `Themes.theme_switched` for later updates.

`WorkspaceDockHost` remains hidden and mouse-inert in the current editor. P2-E therefore does not visually replace the shipping editor layout yet.

## Compatibility boundaries

P2-E intentionally does not:

- migrate current Pixelorama panels into Workspace Modules (P2-G)
- replace `Window > Layouts` (P2-G)
- add or change layout persistence schema (P2-D)
- change dock/floating/collapse placement semantics (P2-B/P2-C)
- redesign Canvas checkerboard, background, pixel-grid rendering, blur, noise, or atmosphere (P2-F)
- introduce final branded PNG icon/button/banner art assets

Final art assets can be layered on the semantic chrome later without changing Workspace lifecycle or placement APIs.

## Acceptance

P2-E is complete when:

1. Workspace chrome follows the active Pixelorama Theme rather than fixed colors.
2. Docked, Floating, Collapsed, and Peek states resolve deterministic semantic styles.
3. Theme changes update already-created modules and future modules.
4. Dock and Floating snap previews share the active accent treatment.
5. Applying chrome preserves the managed `WorkspaceModule` instance and its content instance.
6. Existing live editor panels remain untouched until P2-G.
7. Static checks and regression tests pass on the final P2-E HEAD.
