# P2-D — Workspace Layout Persistence & Presets

P2-D adds persistence on top of the P2-A through P2-C Workspace foundation. It does not migrate the live Pixelorama panels yet; that remains P2-G scope.

## Scope

- Capture the complete Workspace state for every registered module.
- Restore Docked, Floating, Collapsed, and None placements without recreating managed module instances.
- Preserve dock zone, dock order, dock size, floating rectangle, and collapsed restore target.
- Persist the current Workspace state in the existing `Global.config_cache` / `user://config.ini` configuration path.
- Coalesce Workspace placement changes into deferred autosaves.
- Save, list, load, overwrite, and delete named Workspace presets.
- Store Workspace presets under `user://layouts/workspace/` so they do not collide with the legacy `DockableLayout` `.tres` files already stored in `user://layouts`.
- Validate state before applying it and roll back to the previous Workspace snapshot if application fails.
- Ignore snapshot entries for currently unknown module IDs so extension removal or later module registration does not invalidate the rest of a layout.

## State format

The persisted state is a versioned dictionary. P2-D defines schema version `1`.

Each registered module has exactly one entry with a stable module ID and one placement:

- `none`: no visual placement.
- `docked`: dock zone name, insertion index, and requested size.
- `floating`: floating rectangle.
- `collapsed`: the previous dock or floating placement required by Restore.

Vectors and rectangles are serialized as numeric arrays so preset files do not depend on runtime object identity.

Unknown module IDs are tolerated and skipped. Known module entries are validated against the current `can_dock`, `can_float`, and `can_collapse` capability contracts before the existing layout is changed. Unsupported schema versions are rejected without mutation.

## Current layout

`WorkspaceLayoutStore` writes the current snapshot to:

- Config section: `workspace`
- Key: `layout_state`

The same existing `Global.config_cache` and `Global.CONFIG_PATH` used by Phosprite preferences are reused. Workspace changes are autosaved through a deferred/coalesced write rather than writing once for every intermediate signal emitted during a placement transition.

The UI bootstrap restores the saved Workspace state only after the Workspace manager, dock host, and surface have been initialized. The Workspace host remains hidden and mouse-inert until P2-G.

## Named presets

Named Workspace presets use `ConfigFile` files with the extension `.workspace.cfg` under `user://layouts/workspace/`.

Preset names are trimmed and reject path separators, traversal names, and filename characters that are invalid on the supported desktop platforms. Loading a preset also makes that state the current persisted Workspace layout.

The existing `Window > Layouts` menu and existing `DockableLayout` `.tres` files are intentionally untouched in P2-D. P2-G will migrate the live editor panels and can then switch that existing menu surface to the Workspace preset API without running two layout systems against the same panels.

## Acceptance contract

P2-D is complete when automated tests demonstrate that:

1. A mixed Docked / Floating / Collapsed / None Workspace snapshot round-trips with placement details intact.
2. The same managed `WorkspaceModule` instances survive snapshot restore.
3. A None entry clears a later placement without destroying the module instance.
4. Unknown module IDs are ignored while known state still restores.
5. The current layout survives a real `ConfigFile.save()` / reload cycle.
6. Named presets support save, list, load, overwrite, and delete behavior with safe name validation.
7. Future schema versions are rejected without mutating the current layout.
8. Existing P2-A, P2-B, and P2-C tests remain green.

## Explicitly out of scope

- Replacing the existing `Window > Layouts` / `DockableLayout` UI — P2-G.
- Migrating current editor panels into Workspace modules — P2-G.
- Workspace visual chrome and theme work — P2-E.
- Canvas visual and pixel-grid work — P2-F.
- Cloud sync or cross-device synchronization of presets.
