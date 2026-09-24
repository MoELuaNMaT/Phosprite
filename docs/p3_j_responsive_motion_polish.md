# P3-J — Responsive Motion & Polish

P3-J is the final implementation stage of the P3 Project Library plan. It adds motion and state polish to the already-complete P3-D through P3-I behavior. It does not add a new project feature or replace any existing persistence/import/export business logic.

## 1. Responsive 6 ↔ 4 Gallery reflow

The Gallery keeps the fixed P3-D layout contract:

- landscape: 6 columns;
- portrait: 4 columns.

When the orientation crosses that boundary, ProjectGallery records every existing card's global rect before changing GridContainer columns and card width.

Each ProjectGalleryCard owns a non-interactive `VisualRoot`. After Godot lays out the new grid, the card computes the old-to-new translation and scale on VisualRoot and tweens both back to identity over 0.18 seconds.

The GridContainer itself always owns the final logical geometry. No animated card position is written back into the container layout.

This is a FLIP-style visual transform: card identity and child order never change during rotation.

## 2. Touch stability during motion

ProjectGallery has named interaction locks.

The `reflow` lock is held from the orientation boundary change until the VisualRoot tweens complete. The gesture resolver is reset when the lock activates, and card/top-bar input stays disabled until the reflow finishes.

AppShell also uses a `mode_transition` lock while Gallery is entering.

This prevents a visible card that is still interpolating from accepting a touch at a different logical GridContainer position.

## 3. Anchored action popovers

A double tap still opens the P3-H action menu, but P3-J stores:

- the tapped project path;
- the tap point as a normalized position inside that card.

The popup is then recomputed from the card's current global rect after scroll or resize. It remains anchored to the same card while the card moves.

If the anchor card scrolls outside the visible Gallery area or disappears after a refresh/action, the popup closes rather than floating over unrelated content.

## 4. Scroll contract

Every explicit Gallery refresh/return keeps the approved P3 behavior:

1. rescan the managed project library;
2. rebuild/sort cards;
3. request scroll-to-top;
4. re-assert scroll position after container layout.

The deferred second write avoids a ScrollContainer layout pass restoring a stale non-zero scroll value.

Orientation-only reflow does not rescan or reorder the project list.

## 5. Gallery ↔ Editor transition

AppShell mode changes expose the destination root immediately so state remains synchronous for callers and tests.

The destination root then enters with a short 0.16-second fade plus a 10 px vertical settle. The underlying mode, visibility and current Project are already final before the tween starts.

Gallery input remains locked until its entry tween completes.

No transition owns project persistence or navigation decisions; AppShellController remains the single routing layer.

## 6. Empty, loading and error feedback

Gallery empty state now includes a title and direct next-step hint instead of a bare “No projects yet” label.

Healthy cards begin with `Loading preview…` while their lazy thumbnail has not resolved.

A missing/invalid preview becomes `Preview unavailable`; corrupted PXO state remains explicitly `Corrupted`.

Gallery project actions also have an inline transient feedback banner for successful rename/duplicate/delete operations and operation failures. Existing error dialogs are retained for destructive/action failures.

## 7. Acceptance

P3-J is complete when:

1. landscape still uses 6 columns and portrait still uses 4;
2. crossing 6 ↔ 4 records old card rects and visually interpolates to the new layout;
3. card order is unchanged across orientation reflow;
4. card visual transforms end at position zero / scale one;
5. touch is disabled throughout reflow and restored after it;
6. double-tap menus remain anchored to the tapped card during scroll/resize;
7. an off-screen/deleted anchor closes its popup;
8. Editor → Gallery continues to rescan and deterministically land at scroll top;
9. Gallery/Editor destination roots use the bounded entry transition without changing routing semantics;
10. empty Gallery, thumbnail loading, missing preview and corrupted project states are distinguishable;
11. prior P3-H gesture semantics and P3-I export/share behavior remain unchanged;
12. static checks, full regression tests and unsigned iOS build pass at the final commit.

## 8. Deferred to P3-K

P3-K remains the Final Integration Gate only:

- full regression on the final P3 implementation;
- stress / kill-process recovery scenarios;
- iPad real-device orientation, touch, Files, Photos and Share Sheet checks;
- final IPA;
- Chinese manual acceptance cases.

P3-K does not introduce new product behavior unless final validation finds a blocking defect.
