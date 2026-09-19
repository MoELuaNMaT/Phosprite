# P2-G — Live Workspace Migration

P2-G moves the real editor UI from the legacy `DockableContainer` layout into the Workspace system built during P2-A through P2-F. This is the first stage where Workspace becomes the live editor layout instead of a hidden parallel implementation.

The migration deliberately preserves existing editor `Control` instances. Panels are adopted into `WorkspaceModule` wrappers rather than re-instantiated, so their runtime state, signal connections, and child-node identities survive docking, floating, collapsing, and restoring.

## 1. Live panel ownership

`WorkspaceBuiltinModules` assigns stable module IDs to the current editor panels, including Tools, contextual tool options, Canvas Preview, Palette, Color Picker, Timeline, Tiles, and the 3D Object Tree. Global Tool Options is no longer a standalone Workspace module: its existing controls are embedded directly in Animation Timeline's `AnimationButtons` toolbar so they move with Timeline without becoming Timeline body content.

`Main Canvas` is not a Workspace Module. It remains the central editing surface and is promoted out of the legacy `DockableContainer` during migration. Occupied Workspace docks reserve space around it; empty docks reserve no permanent space.

The old `DockableContainer` remains available only as a startup fallback. If live migration cannot complete transactionally, the editor keeps the legacy layout instead of entering a partially migrated state.

## 2. Adopted-content lifecycle

P2-G extends the P2-A lifecycle with an existing-content path:

- `WorkspaceModule.configure_existing()` adopts a live `Control`;
- `WorkspaceModuleManager.adopt_module()` registers that exact instance;
- `mount_module()` reuses adopted modules instead of creating duplicates;
- release/rollback can return adopted content to its original parent if startup migration fails.

Scene-backed creation remains supported for Preview/Palette and tests. The new adoption path does not replace the original factory path.

## 3. Dock and Canvas geometry

The live `WorkspaceDockHost` is input-through outside actual panel content.

Empty Top/Left/Right/Bottom docks have zero layout extent, so they do not reduce the Canvas viewport. Drag resolution still receives a narrow edge snap band, allowing a floating/docked panel to target an otherwise empty edge.

When a dock becomes occupied, its configured extent is subtracted from the central Canvas rectangle. Geometry changes propagate to the promoted `Main Canvas` immediately.

## 4. Live panel interactions

Workspace chrome owns panel manipulation; panel content remains responsible for its existing internal input.

Desktop behavior:

- left-drag a module header to move a panel;
- move into an edge snap target to dock;
- move away from dock targets to float;
- use the header collapse target to collapse;
- resize floating panels from the lower-right resize target.

Touch/iPad behavior:

- panel movement begins only after a short header long-press;
- ordinary taps on a header do not relocate the layout;
- collapse remains an explicit header control;
- floating resize is available through the resize target;
- active move/resize gestures are captured until release, even after the pointer leaves the original header/handle.

Collapse is always in-place. Both docked and floating modules keep the same WorkspaceModule instance, parent, and screen location while their body content is parked/hidden and only the title bar remains visible. The legacy bottom `WorkspaceCollapsedTray` is not used by P2-G live collapse. Pressing the same title-bar collapse control restores the body directly in place; restore does not unmount/remount the panel or pass through the top-left origin.

## 5. Layout persistence and contextual panels

P2-D remains the authoritative persistence layer. P2-G restores the current Workspace snapshot only after all live editor panels have been adopted.

Contextual visibility changes are intentionally transient:

- Tiles visibility follows tile-map editing context;
- 3D Object Tree visibility follows 3D cel context;
- Right Tool Options follows single-tool mode.

Those temporary changes use the LayoutStore transient-update guard and therefore do not overwrite the user’s saved Workspace layout.

Named Workspace layouts continue to use `user://layouts/workspace/*.workspace.cfg`.

## 6. Window menu migration

`WorkspaceWindowMenuBridge` reuses the existing `Window`, `Panels`, and `Layouts` menu UI while switching its data source to Workspace.

When live migration succeeds it disconnects the legacy DockableContainer handlers, including the old startup layout callback and old `.tres` add/delete handlers. This prevents one user action from mutating both layout systems.

In Workspace mode:

- `Window > Panels` toggles Workspace module visibility;
- `Window > Layouts > Default` applies the P2-G default Workspace layout;
- named entries load P2-D Workspace presets;
- Add/Delete/Reset operate on Workspace presets;
- Moveable Panels is always enabled because Workspace panels are inherently movable;
- Zen Mode hides Workspace chrome while leaving the central Canvas available.

If live migration fails, none of this bridge behavior is installed and the existing legacy menu path remains available.

## 7. Automated acceptance

`tests/unit/test_p2_g_live_workspace_migration.gd` covers the P2-G integration contract, including:

- adoption of existing editor panel controls;
- preservation of module/content identity;
- promotion of `Main Canvas` out of the legacy container;
- hidden legacy container after successful migration;
- empty-dock input passthrough and zero reserved extent;
- occupied-dock Canvas geometry;
- docked and floating collapse preserving the adopted instance, parent, and title-bar position;
- collapse never creating the legacy bottom text-button tray;
- direct in-place restore without remount/top-left flash;
- Workspace header/collapse/resize hit targets;
- Window menu bridge source contract.

The pre-existing P2-A through P2-F tests remain part of the same regression suite and therefore protect the lower-level lifecycle, docking, floating/collapse, persistence, theme, and Canvas contracts.

## 8. Final iPad real-device gate

P2-G is the full Workspace interaction gate. Automated CI is necessary but cannot prove touch ergonomics or real-device input coexistence.

On physical iPad hardware, verify:

1. Launch the editor and confirm the live UI uses Workspace chrome with the central Canvas unobstructed.
2. Draw with Apple Pencil before manipulating any panel. Pencil drawing must behave exactly as before P2-G.
3. Touch the Canvas and pan/zoom. Empty Workspace regions must not consume Canvas gestures.
4. Long-press a panel header, then drag it to Left, Right, Top, and Bottom edges. Snap preview and final placement must agree.
5. Drag a panel away from every edge and release it as a floating panel. The original panel content/state must remain intact.
6. Resize the floating panel from its lower-right handle. Minimum/maximum size constraints must hold and the Canvas must remain responsive.
7. Collapse both a docked and a floating panel. Each must remain exactly where it was as a title-bar-only strip; no bottom text-button Tray may appear.
8. Expand each collapsed title bar using the same header control. The panel must reopen directly at the same dock/rect with no one-frame jump or flash at the top-left corner.
9. Open `Window > Panels`, hide/show several modules, and confirm the check states follow the Workspace state.
10. Save a named layout, move several panels, reload that layout, then relaunch the app and confirm current-layout persistence.
11. Switch between ordinary cel, tile-map cel, and 3D cel where available. Context panels must appear/disappear without losing their remembered placement.
12. Toggle single-tool mode and confirm Right Tool Options follows the mode without changing the persisted layout.
13. Toggle Zen Mode and return from Zen Mode. The Workspace layout must remain unchanged.
14. Rotate between portrait and landscape with docked and floating panels present. No panel should become permanently unreachable and Canvas bounds must update.
15. Repeat Pencil drawing and touch navigation after panel drag/float/collapse/layout restore operations to confirm Workspace capture state cannot leak into Canvas input.

The P2-G real-device gate passes only after these checks are performed on physical hardware. A green CI result means the branch is ready for this gate; it does not substitute for the gate.

## 9. Out of scope

P2-G does not redesign the internal content of individual panels, change drawing/tool semantics, change P2-F Canvas visuals, or replace existing project/document formats. Its responsibility is live editor panel ownership, manipulation, persistence integration, and menu migration.
