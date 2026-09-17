# P2-B Dock Layout System

P2-B adds the deterministic docking layer on top of the P2-A Workspace Module contract. It intentionally stops before floating panels, collapsing, persistence, visual reskinning, or migration of the legacy editor panels.

## Four dock zones

`WorkspaceDockLayout` owns four explicit zones: `TOP`, `LEFT`, `RIGHT`, and `BOTTOM`. A Workspace Module can be placed only when its P2-A definition declares `can_dock = true`.

For every docked module the model stores:

- current dock zone;
- stable order inside that zone;
- requested dock size, clamped through the module's P2-A minimum/maximum size contract.

Moving a module removes it from the previous zone before insertion in the new position, so a module cannot exist in two dock zones at once.

## Runtime dock host

`WorkspaceDockHost` provides one container per dock zone and keeps rendered child order synchronized with `WorkspaceDockLayout`. Dock moves preserve the existing `WorkspaceModule` instance and drive the P2-A lifecycle through deactivate, unmount, mount, and activate as required.

Dock moves are transactional. If a reparent/mount operation fails, the layout model and previous host are restored instead of leaving model and scene-tree state divergent.

The main editor now creates one `WorkspaceDockHost` beside `WorkspaceManager`, but keeps it hidden and mouse-inert. This makes the P2-B runtime available without replacing the current Pixelorama `DockableContainer`; actual editor panel migration remains P2-G scope.

## Drag and snap preview

`WorkspaceDockDragResolver` is a pure target resolver. Given a pointer position, the four dock rectangles, current module rectangles, and the dock layout, it returns:

- whether the target is valid;
- target dock zone;
- insertion index;
- snap-preview rectangle.

`WorkspaceDockHost` exposes drag as `begin_module_drag()`, `update_module_drag()`, `commit_module_drag()`, and `cancel_module_drag()`. This keeps drag policy separate from touch gesture policy, which is refined later in P2-H.

A pointer outside all four dock zones is invalid in P2-B. It does not create a floating panel; floating starts in P2-C.

## P2-B acceptance boundary

P2-B is complete when automated coverage verifies that Workspace Modules can:

1. enter any of the four dock zones;
2. move between zones without creating a replacement instance;
3. reorder within a zone;
4. obey module size constraints;
5. resolve and display a dock snap preview during drag;
6. commit a drag into a new dock zone;
7. keep the live editor unchanged until module migration in P2-G.

Not included in this stage: floating windows, edge snapping for floating panels, collapse/peek/restore, layout presets or persistence, visual theme work, checkerboard changes, or migration of existing editor panels.