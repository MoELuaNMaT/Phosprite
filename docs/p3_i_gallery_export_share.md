# P3-I — Gallery Export / Share Redesign

P3-I connects the P3-H Export actions to the existing Pixelorama export stack. It does not introduce a second exporter.

## 1. Single-project Gallery export

Gallery Export explicitly binds the existing ExportDialog to the selected Project through:

`ExportDialog.configure_for_project(project)`

The dialog keeps the same format, frame/layer, crop, scaling, interpolation, quality and spritesheet controls used by Editor export. Rendering and encoding remain owned by `Export.gd`.

The configured project can differ from `Global.current_project`; Gallery export therefore does not need to enter Editor.

## 2. ExportProfile

For multi-selection, the dialog is shown once for the first selected project. Confirming the dialog snapshots the current export controls into one `ExportProfile`.

The profile contains export format and the existing Export.gd options. It deliberately does not preserve the first project's basename as a batch filename.

Each project uses its own managed PXO filename as the export basename.

## 3. ProjectExportCoordinator

`ProjectExportCoordinator` owns batch orchestration.

For each selected path, in selection/library order:

1. acquire the already-open Project or transiently load the PXO;
2. apply the same ExportProfile;
3. set the basename from that project's managed filename;
4. clear `Export.processed_images` and `Export.blended_frames`;
5. rebuild that project's export cache;
6. await that project's export before continuing;
7. release transient Projects;
8. clear global export caches again.

No project export runs in parallel because Export.gd owns global processed/blended caches.

## 4. Transient PXO loading

`OpenSave.open_pxo_file(..., transient := true)` reuses the existing PXO parser while suppressing user-visible open side effects.

Transient loads:

- never replace an empty Editor project;
- do not switch the active tab;
- do not change window title;
- do not update current/last project configuration;
- do not enter Recent Projects;
- are released after export.

This avoids a second PXO parser while keeping Gallery export invisible to the Editor session.

## 5. iOS Share Sheet

Single-project export retains the P0 Share Export behavior.

For a Gallery batch, every project is still required to produce one shareable artifact. Multi-file-per-project configurations remain rejected on iOS; an animated format or spritesheet can be used instead.

The pinned Share plugin exposes `share_completed`, `share_canceled` and `share_failed`. P3-I waits for one Share Sheet result before starting the next project. This prevents multiple native Share Sheets from being presented concurrently.

Cancel/failure stops the remaining iOS batch. Desktop/non-share batch export continues through the selected projects and writes them to the configured directory.

## 6. Editor export compatibility

Editor Export continues to use the same ExportDialog and Export.gd entry points. When no Gallery project is configured, ExportDialog falls back to `Global.current_project`.

Gallery completion restores the Editor File menu state after temporary project exports.

## 7. Acceptance

P3-I is complete when:

1. Gallery single-project Export opens the existing ExportDialog for that project;
2. the dialog no longer assumes Global.current_project while explicitly configured;
3. batch configuration occurs once and produces one ExportProfile;
4. every project receives the same profile but keeps its own basename;
5. unopened projects are transiently loaded through the existing PXO parser;
6. transient loading does not enter Editor, Recent Projects or last-project state;
7. batch execution is strictly serial;
8. processed_images / blended_frames are cleared and rebuilt per project;
9. two projects with different dimensions/content export correctly without cache bleed;
10. iOS waits for native share completion/cancel/failure before advancing;
11. single-artifact Share Export behavior remains compatible with P0;
12. existing Editor export behavior and all prior P0/P1/P2/P3 regressions remain green;
13. unsigned iOS export remains green.

## 8. Deferred

P3-I does not implement P3-J transition/motion/polish, folder/Stack organization, search, cloud sync, Trash, or the P3-K real-device final acceptance matrix.
