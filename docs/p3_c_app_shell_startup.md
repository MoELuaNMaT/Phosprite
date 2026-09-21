# P3-C — iPad App Shell and Startup Routing

P3-C introduces the iPad application shell that separates Project Gallery from
the existing Editor. It also moves crash recovery presentation from application
startup to the affected project-open action.

This stage intentionally stops before the full Project Gallery UI. P3-D owns the
visual grid, project cards, thumbnail layout, metadata presentation and corrupted
card visuals.

## 1. App Shell states

`AppShellController` owns exactly two runtime states:

- `GALLERY`;
- `EDITOR`.

The existing `MenuAndUI` subtree is the Editor root. A sibling
`ProjectGalleryRoot` is the Gallery root.

Only one of those roots is visible at a time. Dialog infrastructure remains
outside both roots so a project-specific recovery dialog can be presented while
the Gallery is active.

## 2. Platform boundary

The new shell startup routing is enabled only when
`StoragePolicy.uses_managed_project_storage()` is true, currently iOS.

Desktop, Web and Android retain the existing Editor-first startup behavior.

The P3-C additions are present in the shared scene, but on non-managed platforms:

- Editor stays visible;
- Gallery stays hidden;
- the new return-to-Projects button stays hidden;
- legacy splash behavior remains;
- legacy `open_last_project` startup behavior remains;
- legacy global session-recovery startup behavior remains.

## 3. iPad cold start

On managed iPad storage, Main configures App Shell before the first awaited
process frame. The Editor root is hidden and the Gallery root is made active
immediately.

Managed startup does not:

- show the legacy Splash dialog;
- automatically open `Global.open_last_project`;
- show the legacy global crash/session recovery confirmation.

After window/safe-area setup, App Shell performs the initial Project Library
refresh and resets the Gallery scroll contract.

## 4. Project Gallery shell API

P3-C adds `ProjectGallery.gd/.tscn` as a navigation/data shell only.

It exposes:

- `refresh()` — rescan through P3-A `ProjectLibrary`;
- `find_entry(path)`;
- `request_open(path)`;
- `project_open_requested(path)`;
- `reset_scroll_position()`.

The last method is intentionally a P3-C contract hook. P3-D will bind it to the
real Gallery ScrollContainer.

P3-C does not add:

- project cards;
- grid columns;
- thumbnail rendering;
- project size/mtime labels;
- corrupted-card visuals;
- Gallery top bar;
- visual polish.

## 5. Editor → Gallery

The Editor top bar gains a minimal `Projects` control.

It is hidden by default and made visible only for managed iPad storage.

Pressing it calls `AppShellController.return_home()`.

The transition is allowed only when P3-B
`ProjectSaveCoordinator.flush_before_leaving_editor()` succeeds.

On success:

1. Project Library is rescanned;
2. Gallery scroll contract is reset;
3. Editor root is hidden;
4. Gallery root is shown.

On save failure the shell remains in Editor.

Open projects remain alive in memory while Gallery is shown. Reopening an
already-open project selects the existing Project instead of creating a duplicate
tab.

## 6. Project-specific recovery prompt

P3-B already exposes `ProjectLibraryEntry.has_pending_recovery`.

P3-C consumes that state only when a user requests opening the corresponding
project.

For a healthy entry without recovery, the formal PXO opens normally.

For an entry with pending recovery:

1. App Shell remains in Gallery;
2. no Project is opened yet;
3. `ProjectRecoveryDialog` is shown;
4. the dialog binds the selected UUID and formal project path.

The recovery prompt is therefore project-scoped rather than application-scoped.

## 7. Recovery decisions

The recovery dialog supports three outcomes.

### Restore

`ProjectRecoveryStore.restore_to_project(uuid, path)` atomically promotes the
validated recovery candidate over the formal project.

Only after that succeeds does App Shell open the formal path and enter Editor.

If restore fails, the recovery candidate remains and the shell stays in Gallery.

### Discard

Discard explicitly deletes only that UUID's recovery slot, then opens the formal
project.

Failure to discard leaves the recovery candidate intact and does not enter the
Editor.

### Cancel / close

Cancel is intentionally non-destructive.

It clears only the transient dialog selection. The recovery file remains in its
single project slot, so opening the same project later asks again.

This also preserves the previously agreed chained-crash behavior: if the
application terminates while the recovery decision is unresolved, no new stack
of recovery files is created and the same unresolved candidate remains.

## 8. Corrupted project boundary

If a selected Project Library entry is already marked `CORRUPTED`, App Shell
does not call the full PXO loader.

The current P3-C shell reports the open failure. P3-D will supply the final
corrupted-card presentation.

## 9. Safe area

Both App Shell roots share the existing mobile safe-area calculation.

This prevents switching to Gallery from re-exposing content under iPad display
cutouts or system areas while preserving the existing Editor behavior.

## 10. P3-0 baseline test migration

P3-0 originally froze the P2-G startup flow as evidence.

P3-C is the planned stage that intentionally changes that flow, so the P3-0
startup test now verifies the historical behavior from
`docs/p3_0_baseline_freeze.md` rather than requiring current `Main.gd` to keep
the obsolete iPad startup popup.

Other P3-0/P3-A/P3-B contracts remain active.

## 11. Acceptance

P3-C is complete when automated tests prove:

1. non-managed desktop runtime still starts in Editor;
2. managed startup path enters Gallery;
3. managed startup skips Splash, automatic last-project open and global recovery
   popup;
4. desktop source path still retains those legacy behaviors;
5. Home transition runs the P3-B flush gate before leaving Editor;
6. successful Home transition refreshes Project Library and resets Gallery scroll;
7. Gallery/Editor roots remain mutually exclusive;
8. already-open projects are reused rather than duplicated;
9. recovery prompt binds only to the selected project's UUID/path;
10. showing or canceling the recovery prompt does not consume recovery;
11. Restore and Discard are wired to the selected UUID;
12. Editor exposes the iPad-only return-to-Projects entry;
13. existing P0/P1/P2/P3-0/P3-A/P3-B regressions remain green;
14. unsigned iOS export still succeeds.

## 12. Deferred to P3-D

P3-C does not implement the full Project Gallery presentation.

P3-D remains responsible for:

- dark Gallery visual composition;
- Gallery Top Bar;
- square project thumbnail cards;
- canvas size and modified-time labels;
- newest-first visual ordering;
- lazy thumbnail/card loading;
- fixed six-column landscape / four-column portrait layout;
- corrupted-project card visuals;
- final card interaction surface.
