# P3-0 — Baseline Freeze

P3-0 freezes the verified P2-G state before Project Gallery work begins. It is
deliberately evidence-only: no Gallery, App Shell, autosave, recovery, startup,
or project-library production behavior changes are allowed in this stage.

## 1. Frozen source

- P2-G final HEAD: `ea5c0169fd1e2df1a90895ec98167e64c9fa5958`
- P3 working branch: `codex/implement-p3-project-gallery`
- The branch is created from the P2-G final HEAD, not from repository
  `master` or the older `main` branch.
- Godot remains frozen at 4.6.3 for the existing regression workflow.

## 2. Current project-file contract

Phosprite still uses the ordinary Pixelorama-compatible `.pxo` project format.

Current implementation evidence:

- `src/PlatformServices/StoragePolicy.gd`
  - managed iOS project root is `user://Projects`;
  - project extension is `.pxo`;
  - managed project storage is enabled only when `OS.get_name() == "iOS"`;
  - name conflicts are resolved by appending `_2`, `_3`, and so on.
- `src/Main.gd`
  - `request_save()` sends a first iOS Save directly to managed storage;
  - an unsaved iOS Quit Save uses the same managed-storage path;
  - iOS Save As is confined to the managed project directory.
- `src/Autoload/OpenSave.gd`
  - `save_pxo_file()` remains the project serializer;
  - the saved container contains `data.json`;
  - its mimetype remains `application/x-pixelorama`.

P3 must not replace `.pxo` with a new project format.

## 3. Current autosave and backup behavior

The behavior currently named "autosave" is the legacy crash-backup mechanism,
not the P3 managed-project autosave model.

Current behavior:

1. `OpenSave.update_autosave()` configures a repeating timer from
   `Global.autosave_interval * 60`.
2. When it fires, `_on_Autosave_timeout()` assigns each project a
   `backup_path` inside the current session directory.
3. The backup root is `user://backups`.
4. Each backup is written through
   `save_pxo_file(project.backup_path, true, false, project)`.
5. Because the write is marked as an autosave, it is a recovery copy and does
   not become the project's ordinary managed `.pxo` save path.

The already approved P3 target — dirty project, about 2 seconds of idle before
saving the real project, a maximum of about 30 seconds during continuous edits,
and a forced save when returning Home — belongs to P3-B and is intentionally
not implemented in P3-0.

## 4. Current startup and recovery behavior

The P2-G baseline still contains the legacy startup flow in `src/Main.gd`:

- if the previous session crashed and backup sessions exist,
  `RestoreSessionConfirmationDialog` is opened during application startup;
- after one process frame, `Global.open_last_project` may call
  `load_last_project(true)`.

This is recorded as the current baseline, not as the P3 product target.

The approved P3 target is deferred to later stages:

- iOS cold start enters Project Gallery instead of automatically opening the
  previous project;
- the global startup recovery popup is removed;
- crash-recovery information is attached to the corresponding project and is
  offered when that project is opened.

P3-0 does not make those production changes.

## 5. P3 regression entry

P3 reuses the existing headless regression infrastructure instead of creating a
second competing runner.

- `tests/runner.gd` remains the single headless test entry.
- It already discovers every `.gd` suite recursively under
  `tests/unit` and `tests/integration`.
- P3-0 adds `tests/unit/test_p3_0_project_library_baseline.gd`, so the P3
  baseline contracts automatically participate in the full existing suite.
- `.github/workflows/regression-tests.yml` continues to invoke
  `res://tests/runner.gd` on Godot 4.6.3.

## 6. P3-0 acceptance

P3-0 passes only when all of the following are true:

1. the P3 branch ancestry starts at the verified P2-G final HEAD above;
2. the current `.pxo`, iOS managed storage, legacy backup/autosave, and
   startup/recovery behavior is explicitly recorded;
3. the P3 baseline suite is part of the existing regression runner;
4. no production source behavior is changed by P3-0;
5. existing P2-G and earlier automated suites remain green on the final P3-0
   commit.

## 7. Explicitly out of scope

P3-0 does not implement any of the following:

- Project Gallery or project-library UI;
- project metadata/indexing;
- the new managed autosave model;
- per-project recovery UI;
- removal of the startup recovery dialog;
- App Shell or startup routing;
- New Project flow;
- iOS import/document-picker changes;
- project rename, duplicate, delete, export, or other Gallery actions.
