# P2-A Workspace Foundation

P2-A establishes a layout-neutral module contract. It does **not** replace the
current `DockableContainer` layout yet; that belongs to P2-B/P2-G.

## Contract

Every `WorkspaceModuleDefinition` has:

- a stable lowercase `module_id`;
- one existing or new `Control` scene as its content;
- minimum, preferred, and optional maximum size constraints;
- explicit `can_dock`, `can_float`, and `can_collapse` capabilities.

A maximum size of `0` on an axis means that axis is unbounded.

`WorkspaceModule` is a visual-policy-free wrapper around the content scene.
Content may optionally implement these hooks without inheriting a new base class:

- `workspace_module_initialized(module, context)`
- `workspace_module_mounted(module, host)`
- `workspace_module_activated(module)`
- `workspace_module_deactivated(module)`
- `workspace_module_unmounting(module, host)`
- `workspace_module_disposed(module)`

The lifecycle is:

`CREATED -> INITIALIZED -> MOUNTED -> ACTIVE`

and reverses to `MOUNTED -> INITIALIZED` before `DISPOSED`.

`WorkspaceModuleManager` owns definition registration, one managed instance per
module ID, module creation, mounting, activation, unmounting, and disposal.
Modules remain detached until explicitly mounted, so P2-A does not change the
current editor layout.

## Built-in seed modules

P2-A registers two existing editor panels as proof that legacy UI can enter the
new system without a rewrite:

| Module ID | Existing content scene | Dock | Float | Collapse |
| --- | --- | --- | --- | --- |
| `preview` | `CanvasPreviewContainer.tscn` | yes | yes | yes |
| `palette` | `PalettePanel.tscn` | yes | yes | yes |

`UI.gd` creates the manager and registers these definitions at editor startup.
It intentionally does not create duplicate live panels; the currently visible
Preview/Palette nodes continue running in the old layout until P2-G migration.

## P2-A boundary

Not implemented here: dock zones, drag/drop ordering, floating windows, resize
handles, edge snapping, collapsed tray/peek, presets, persistence, theme tokens,
canvas checkerboard changes, or migration of the current editor tree. Those are
owned by P2-B through P2-H and should build on this contract rather than bypass it.
