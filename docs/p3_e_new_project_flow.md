# P3-E — iPad New Project Flow

P3-E makes the Project Gallery `New` entry functional on managed iPad storage.
It deliberately does not reuse or redesign the existing desktop
`CreateNewImage` dialog.

## 1. Platform boundary

The P3-E New Project panel is reachable only through the managed-storage
App Shell used on iOS.

Desktop and other non-managed platforms retain the existing
`src/UI/Dialogs/CreateNewImage.gd/.tscn` workflow without UI or behavior
changes.

The iPad panel is implemented independently under
`src/UI/ProjectGallery/NewProjectDialog.*`.

## 2. Default and presets

New Project opens at 64×64.

The managed New Project dialog exposes 18 built-in presets through a single ratio-aware dropdown.

### 1:1

- 16×16
- 32×32
- 64×64
- 128×128
- 256×256
- 512×512

### 4:3

- 21×16
- 43×32
- 85×64
- 171×128
- 341×256
- 683×512

### 16:9

- 28×16
- 57×32
- 114×64
- 228×128
- 455×256
- 910×512

The dialog uses a two-column layout:

- left: one preset dropdown plus 1:1 / 4:3 / 16:9 ratio tabs;
- right: authoritative Width and Height inputs under the Custom size heading.

Switching ratio tabs changes only the dropdown dataset. Selecting a dropdown item writes its exact
size into the Width and Height inputs. Manually editing Width or Height updates the project size
immediately and clears the dropdown selection when the resulting size no longer matches a preset.

A fourth Custom preset tab is visible but disabled as a reserved extension point for future
user-defined preset lists. There is currently no configuration entry for those presets.

The user can enter custom width and height values from 1 through 16384 px.

P3-E does not add fill-color, background, color-mode, clipboard-content, recent
template, aspect-lock, or project-name inputs to the iPad panel.

## 3. Blank project content

`ProjectFactory.create_blank_project()` creates a standard RGBA blank project
with:

- one PixelLayer;
- one frame;
- one empty transparent cel;
- the selected canvas dimensions.

The existing desktop Create New implementation is not refactored through this
factory in P3-E. The factory exists as a small construction seam for the new
managed-storage flow only.

## 4. Automatic name

P3-E does not ask for a project name.

At creation time the project receives:

`未命名_YYYY-MM-DD_HH-mm-ss`

using the device-local system date and time.

The corresponding managed PXO uses the same basename.

If that exact file already exists, collisions are resolved deterministically:

- first collision: `_1`
- second collision: `_2`
- and so on.

The allocation checks the filesystem directly so it cannot depend on stale
Gallery metadata.

## 5. Create → save → Editor transaction

The user must never enter Editor with a brand-new project that has not acquired a
formal managed PXO.

The App Shell therefore performs this sequence synchronously:

1. construct the hidden runtime project;
2. append it temporarily to the runtime project/tab model;
3. mark it dirty;
4. allocate a unique path under the managed Projects directory;
5. call the P3-B `ProjectSaveCoordinator` with that explicit initial target;
6. let P3-B perform staging → validation → recovery → formal PXO commit;
7. only after the commit succeeds, select the project tab and switch App Shell to
   Editor.

The existing P3-B save pipeline remains authoritative. P3-E does not implement a
second save format or bypass recovery validation.

## 6. Failed first save

If the initial managed save fails, P3-E must leave no half-created project visible
to the user.

The App Shell rolls back:

- the temporary project tab;
- the temporary runtime Project;
- the coordinator state for the new UUID;
- any staging/recovery entry for that UUID;
- any formal target that could only belong to this just-created transaction.

The previous current project remains selected and App Shell remains in Gallery.

The save coordinator continues to own error reporting.

## 7. Gallery integration

P3-D already freezes the Gallery `New` button as the
`new_project_requested` signal.

P3-E consumes that signal in `AppShellController`:

- managed iPad → open `NewProjectDialog`;
- non-managed platforms → no P3-E action.

Cancel closes the new-project flow without modifying projects or storage.

## 8. Acceptance

P3-E is complete when automated validation proves:

1. iPad New Project defaults to 64×64;
2. all 18 built-in presets are exact;
3. arbitrary custom width/height values are accepted within the supported range;
4. the iPad panel is independent from desktop `CreateNewImage`;
5. desktop Create New retains its existing content/fill workflow;
6. automatic names use `未命名_YYYY-MM-DD_HH-mm-ss`;
7. collisions use `_1`, `_2`, ...;
8. a new blank project contains one transparent PixelLayer/frame;
9. the first formal PXO is committed before App Shell enters Editor;
10. the formal PXO validates against the new project UUID;
11. successful first save clears the dirty state and leaves no recovery candidate;
12. failed first save removes the transient Project and tab;
13. failed first save leaves the previous project untouched and remains in Gallery;
14. all P0/P1/P2/P3-0/P3-A/P3-B/P3-C/P3-D regressions remain green;
15. unsigned iOS export remains green.

## 9. Deferred

P3-E does not implement:

- Import;
- rename;
- duplicate;
- delete;
- Gallery export/share;
- manual Save/Save As redesign;
- folders, stacks or tags;
- search;
- cloud/iCloud sync;
- recycle bin;
- version history;
- project-name display in Gallery;
- a Main Menu redesign.
