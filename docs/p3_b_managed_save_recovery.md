# P3-B — Managed Save and Recovery

P3-B replaces the legacy iPad project-save cadence with a managed transactional
save coordinator. It does not add the Project Gallery UI or recovery prompt UI;
those remain P3-C responsibilities.

## 1. Ownership

`ProjectSaveCoordinator` is a normal child owned by `Main`, not an Autoload.

It is enabled only when `StoragePolicy.uses_managed_project_storage()` is true.
Desktop/Web/Android retain their existing save behavior. P3-B therefore changes
the iPad managed-storage lifecycle without turning every platform into an
autosave-only editor.

## 2. Dirty generations

Every `Global.project_data_changed(project)` event increments that project's
save generation.

For the first dirty generation the coordinator records:

- first dirty time;
- latest dirty time;
- generation number.

A save captures the generation at serialization start. If another modification
is emitted while that save is in progress, the generation changes.

After the transaction:

- if generation is unchanged, the live Project is marked clean;
- if generation changed, the completed file remains valid but the Project stays
  dirty and another save is required.

Ordinary autosave may requeue that newer dirty generation. Forced navigation
flushes must not report success while a newer generation is still dirty.

## 3. Timing

Two independent thresholds are enforced:

- idle debounce: 2,000 ms after the latest dirty event;
- maximum dirty age: 30,000 ms after the first dirty event.

Therefore normal drawing does not serialize on every stroke, but continuous
editing cannot postpone managed persistence indefinitely.

## 4. Transaction format

P3-B does not create another project format. All recovery and staging files are
ordinary PXO archives written by `OpenSave.save_pxo_file()`.

For project UUID `<uuid>` the single recovery slot is:

`user://backups/projects/<uuid>.pxo`

The transient writer path is:

`user://backups/projects/<uuid>.pxo.staging`

The save sequence is:

1. serialize the live Project into the staging PXO;
2. close the archive;
3. reopen and validate ZIP + `data.json`;
4. require `data.json.project_uuid` to match the live Project UUID;
5. atomically install staging as the UUID recovery slot;
6. atomically replace the formal managed PXO with that recovery file;
7. only after the formal replacement succeeds, finalize the live Project as
   saved.

Because step 6 consumes the recovery path, successful transactions leave no
pending recovery. If formal replacement fails or the app terminates between
steps 5 and 6, the validated UUID recovery remains available.

Recovery is a single transactional candidate, not version history.

## 5. Recovery API

`ProjectRecoveryStore` owns the project recovery namespace and provides:

- staging/recovery path calculation;
- ZIP/data.json/UUID validation;
- staging installation;
- formal-project commit;
- explicit recovery restore;
- explicit recovery discard;
- pending-recovery lookup.

A failed restore does not delete recovery. Recovery is removed only by:

- successful formal replacement;
- successful explicit restore;
- explicit discard.

P3-C will decide when the user chooses Restore or Discard. P3-B only provides the
mechanism and Project Library state.

## 6. Project Library integration

After scanning and duplicate-UUID repair, `ProjectLibrary.scan()` checks the
final UUID of every healthy entry against `ProjectRecoveryStore`.

`ProjectLibraryEntry.has_pending_recovery` therefore becomes true only for the
matching project identity. No global "some previous session crashed" state is
needed for the new recovery mechanism.

## 7. Forced flush boundaries

On managed iPad storage P3-B forces persistence before:

- project switch;
- returning Home / leaving Editor;
- application focus loss/background transition;
- application suspend;
- application close/exit.

`Main.flush_before_home()` is the P3-C handoff API. It returns false when the
save cannot be completed, so Gallery navigation must remain in Editor.

`Global.current_project_index` also consults a save guard before switching.
When the guard fails, the project index does not change.

Background/suspend cannot prevent iOS itself from moving the app out of the
foreground, but the coordinator still performs the same synchronous flush
attempt before suspension handling continues.

## 8. Save failure

A failed transaction:

- never clears `Project.has_changed`;
- never reports the forced flush as successful;
- never deletes a validated recovery candidate after formal commit failure;
- does not replace the formal PXO with an unvalidated staging archive.

Automatic retry starts from a fresh dirty window rather than retrying every
frame. Forced Home/switch/exit remains blocked until a later save succeeds.

## 9. Legacy backup coexistence

The existing Pixelorama-style minute-based session backup remains available for
platforms that do not use managed iPad project storage.

On managed iPad storage it is disabled, because P3-B is now the authoritative
save/recovery mechanism.

The `user://backups/projects` directory is excluded from:

- legacy session-crash detection;
- empty-session cleanup;
- legacy max-session retention.

This prevents a valid project recovery from being mistaken for an old session
backup or being deleted by legacy retention.

## 10. Manual Save compatibility

Manual PXO saves continue to use the existing `OpenSave.save_pxo_file()`
contract.

P3-B adds a shared `finalize_project_save()` step so manual saves and managed
transactions converge on the same successful-save state:

- formal `save_path`;
- dirty clearing when appropriate;
- last-project/current-directory config;
- current-project title/menu state;
- recovery cleanup.

Managed autosaves suppress the recurring "File saved" notification and Steam
achievement signal; the first automatically allocated managed path is still
added to the legacy recent-project list for compatibility.

## 11. P3-B acceptance

P3-B is complete when automated tests prove:

1. two-second idle debounce;
2. thirty-second continuous-edit maximum;
3. dirty generation created during serialization remains dirty;
4. a later stable forced flush clears it;
5. staging must validate before recovery installation;
6. recovery UUID must match the project;
7. successful formal commit consumes recovery;
8. failed formal commit preserves validated recovery;
9. failed forced flush blocks leave/switch semantics;
10. explicit restore consumes recovery only on success;
11. Project Library exposes pending recovery only for the matching UUID;
12. legacy iPad session autosave is disabled;
13. existing P0/P1/P2/P3-0/P3-A tests remain green.

## 12. Deferred to P3-C

P3-B deliberately does not implement:

- cold-start routing into Project Gallery;
- removal of the legacy startup recovery dialog;
- the new App Shell;
- recovery prompt presentation;
- Restore / Discard buttons or user-facing recovery wording;
- Gallery visual state;
- returning Home after the P3-B flush gate succeeds.

P3-C consumes the mechanisms implemented here.
