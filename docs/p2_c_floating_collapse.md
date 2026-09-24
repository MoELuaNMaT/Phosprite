# P2-C Floating & Collapse

## Scope

P2-C extends the P2-B workspace foundation with runtime presentation states while preserving the existing four-zone dock model.

Implemented behavior:

- Docked modules can transition to a floating surface without recreating the managed `WorkspaceModule` instance.
- Floating modules keep constrained bounds and can be moved/resized within the workspace surface.
- Dragging a floating module near a P2-B dock zone produces the existing deterministic dock snap candidate and can commit back into Top / Left / Right / Bottom.
- Modules that declare `can_collapse` can enter a collapsed state.
- Collapsed modules remember the placement they came from and support `peek` plus `restore` without destroying the module instance.
- Capability flags (`can_float`, `can_collapse`, `can_dock`) are enforced before state transitions.
- The new workspace surface remains hidden and mouse-inert in the current editor. Existing editor panels are not migrated until P2-G.

## State model

P2-C treats docking, floating, and collapsing as presentation/layout state, not as module lifecycle state. `WorkspaceModuleManager` still owns the single module instance and its lifecycle.

A module can be in one of these presentation states:

- `DOCKED`: placement is owned by `WorkspaceDockLayout` and rendered by `WorkspaceDockHost`.
- `FLOATING`: placement is owned by the P2-C surface as a constrained `Rect2`.
- `COLLAPSED`: the module is hidden from its normal placement while the surface retains a restore snapshot.

`peek` temporarily reveals a collapsed module without replacing its restore snapshot. `restore` returns it to the saved dock or floating placement.

## Dragging and edge snapping

P2-C reuses the P2-B dock resolver for edge snapping. This keeps dock zone ordering and preview geometry deterministic and avoids a second competing docking algorithm.

- A floating drag that resolves to a valid P2-B dock candidate can commit into that zone/index.
- A floating drag that does not resolve to a dock candidate remains floating at the requested position.
- Dock-to-float transitions preserve the same managed module instance.

## Explicitly out of scope

- Persisting layout state across sessions or named layout presets (P2-D).
- Theme, chrome, animation, or final panel visuals (P2-E).
- Canvas visual changes (P2-F).
- Migration of existing Pixelorama editor panels from `DockableContainer` to workspace modules (P2-G).
- Real-device acceptance testing; the first formal iPad gate remains P2-F, with the full interaction gate at P2-G.

## Acceptance criteria

P2-C is complete when automated tests demonstrate that:

1. A module can move Dock -> Float while preserving object identity.
2. A floating module can snap back Float -> Dock through the existing four-zone resolver.
3. Floating bounds respect module minimum/maximum size constraints.
4. Collapse -> Peek -> Restore returns to the recorded dock or floating placement.
5. Capability flags reject invalid float/collapse/dock transitions.
6. The current editor UI remains unchanged because the workspace surface is still hidden until P2-G.
