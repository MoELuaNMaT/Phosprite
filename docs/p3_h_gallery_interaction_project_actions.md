# P3-H — Gallery Touch Interaction & Project Actions

P3-H turns the read-only Project Gallery cards into the iPad project-management surface. It owns gesture disambiguation, multi-selection, Rename / Duplicate / Delete, the Reveal in Files hook from P3-G, and the Export action entry that P3-I will implement.

## 1. Gesture contract

Normal card interaction uses an explicit resolver instead of the Button `pressed` signal:

- Touch Down starts the 1,000 ms long-press timer.
- Touch Up schedules a single tap, but the single tap is not emitted until the 300 ms double-tap window closes.
- A second Down on the same card within that 300 ms window cancels the pending single and emits a double tap.
- Holding the original Down for 1,000 ms emits long press and consumes the later release.
- Dragging more than the card gesture threshold cancels the card press so Gallery scrolling does not accidentally open/select a project.

The exact 300 ms boundary belongs to the double tap: a second Down at the deadline still resolves as double tap.

## 2. Normal state

- delayed single tap opens the project;
- double tap opens the single-project action menu near the tapped card;
- long press enters multi-select and selects the held project.

Healthy project menu: Rename, Duplicate, Delete, Export, Reveal in Files.

Corrupted project menu is intentionally limited to Delete and Reveal in Files.

## 3. Multi-select state

Long press enters multi-select. Selected cards use a prominent outline plus an upper-right checkmark. The rest of the Gallery is not dimmed.

While multi-select is active:

- delayed single tap toggles that card's selection;
- double tap opens the batch action menu for the selection set that already existed before the double tap;
- therefore double-tapping an unselected card D while A/B/C are selected does not add D;
- Exit Multi-Select clears the selection and returns to normal card behavior.

Batch actions are Duplicate and Export when every selected entry is healthy, plus Delete for healthy or corrupted entries.

## 4. Rename

Rename changes the managed `.pxo` filename and preserves the project's UUID. A conflicting target name is rejected; P3-H does not silently append `_1` during rename.

If that project is currently loaded, AppShell synchronizes its runtime `save_path`, `file_name`, name and tab title with the new managed path.

## 5. Duplicate

Duplicate copies the formal managed PXO and then rewrites only the copied project's identity metadata to a newly generated UUID.

Naming is deterministic: `foo.pxo → foo_1.pxo → foo_2.pxo`; duplicating `foo_1.pxo` creates `foo_1_1.pxo`. The original project and UUID are never mutated.

## 6. Delete

Single delete and batch delete each use one explicit confirmation dialog. Confirmed deletion permanently removes the managed `.pxo`; P3 v1 does not add an app Trash layer.

Per-project staging/recovery data is discarded for a valid UUID. If the deleted project is currently loaded, AppShell removes that runtime Project/tab as well. Corrupted PXO files remain deletable because deletion does not require parsing the project body.

## 7. Reveal in Files

P3-H emits the selected managed path through the Gallery action signal. On iOS, Main routes that signal into the P3-G `IOSDocumentBridge.reveal_in_files()` native capability. The Gallery does not duplicate native Files logic.

## 8. Export boundary

P3-H exposes Export in the healthy single-project and healthy batch menus, then emits `export_projects_requested(paths)`.

It deliberately does not define export formats, destinations, share-sheet behavior or batch export semantics. Those are P3-I.

## 9. Acceptance

P3-H is complete when automated validation proves the 300 ms / 1,000 ms gesture exclusivity; long-press release cannot become a single tap; multi-select double tap on an unselected card does not alter the existing selection; selected cards use outline + check; rename preserves UUID and rejects collisions; duplicate naming and new UUID rules are exact; single/batch delete removes managed PXOs after confirmation; corrupted items remain deletable/revealable; Reveal reaches the P3-G bridge hook; the P3-I Export hook exists without implementing export; and all previous regression/iOS build gates remain green.

## 10. Deferred

P3-H does not implement P3-I export/share redesign, P3-J motion/polish, folder/Stack organization, search, cloud sync, Trash/undo-delete, or the P3-K real-device final acceptance matrix.
