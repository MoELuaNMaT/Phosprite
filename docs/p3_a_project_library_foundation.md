# P3-A — Project Library Foundation

P3-A adds the data foundation used by the future Project Gallery. It does not add
Gallery UI, startup routing, autosave, recovery UI, import, project actions, or
App Shell behavior.

## 1. Components

P3-A adds three small non-Autoload services under `src/ProjectLibrary/`:

- `ProjectIdentity.gd` generates and validates RFC-4122-shaped UUIDs;
- `ProjectLibraryEntry.gd` is the lightweight Gallery DTO;
- `ProjectLibrary.gd` scans managed project files without constructing
  `Project` objects.

`ProjectLibrary` is instantiated by its consumer rather than being added to
`Global`. P3-C/P3-D can later own it from App Shell / Gallery lifetime without
creating another permanent singleton.

## 2. Stable project identity

Every newly constructed `Project` receives a UUID.

The UUID is serialized at the top level of `.pxo/data.json` as:

```json
{
  "project_uuid": "12345678-1234-4234-8234-123456789abc"
}
```

When an existing PXO already contains a valid UUID, `Project.deserialize()`
restores it. When an old PXO has no UUID, the newly constructed Project keeps its
generated UUID; the next normal save writes that identity into the PXO.

Renaming a project therefore keeps the same identity. Copying a PXO outside
Phosprite initially copies the UUID too, which is repaired by the duplicate
identity rule below. A future in-app Duplicate action must explicitly assign a
new UUID when that action is implemented.

## 3. gallery.json

Every current PXO save now writes a tiny root ZIP entry named `gallery.json`.

Schema 1 is intentionally minimal:

```json
{
  "schema": 1,
  "project_uuid": "12345678-1234-4234-8234-123456789abc",
  "size_x": 320,
  "size_y": 180
}
```

It is a read-optimization sidecar inside the PXO, not a second project format and
not an external database. `data.json` remains authoritative project data.

The Project Library reads `gallery.json` first. Old PXO files without it fall
back to parsing only `data.json` metadata. Neither path constructs layers,
frames, cels, textures, or a complete Project.

## 4. ProjectLibraryEntry

Each scan result exposes:

- `path: String`;
- `uuid: String`;
- `canvas_size: Vector2i`;
- `modified_time: int` — filesystem Unix timestamp;
- `thumbnail: Image` — decoded from `preview.png` when available;
- `health_state` — `OK` or `CORRUPTED`;
- `has_pending_recovery: bool`.

P3-A initializes `has_pending_recovery` to false. P3-B/P3-C will attach the
actual per-project recovery state later.

## 5. scan()

`ProjectLibrary.scan()` scans `StoragePolicy.PROJECTS_DIRECTORY`, currently
`user://Projects`.

Rules:

1. only direct `.pxo` files are included;
2. the ZIP central directory is opened first;
3. valid schema-1 `gallery.json` supplies UUID and canvas size;
4. old projects fall back to top-level fields in `data.json`;
5. `preview.png` is decoded as a small `Image` when present;
6. filesystem mtime comes from `FileAccess.get_modified_time()`;
7. unreadable PXO/metadata remains visible with `CORRUPTED` health;
8. results sort by mtime descending, with normalized path as a deterministic
   tie-breaker.

A missing Projects directory is created on first scan. External additions,
deletions, renames, or replacements become visible on the next scan. P3-A does
not add a background watcher or cache.

## 6. Old PXO identity behavior

For an old healthy PXO that has no UUID:

- scan generates a temporary in-memory UUID for the DTO;
- scan does not mutate the user's file merely because it was discovered;
- when that project is actually opened, its Project instance also receives a
  generated UUID;
- the next normal PXO save persists that Project UUID and emits
  `gallery.json`.

This keeps discovery read-only for ordinary legacy files.

## 7. Duplicate UUID repair

A duplicated/copy-pasted PXO can legitimately contain the same UUID as its
source. P3-A repairs this during scanning.

For every duplicate group:

1. normalize each path;
2. sort paths lexicographically;
3. the first path keeps the original UUID;
4. every other path receives a newly generated UUID;
5. the non-canonical PXO is repacked once, changing only project identity
   metadata and adding/updating `gallery.json`;
6. all unrelated ZIP entries are copied byte-for-byte through the repack;
7. a later scan reads the persisted replacement UUID, so the split is stable.

If the exceptional identity rewrite cannot be completed safely, that entry is
reported as `CORRUPTED` instead of silently returning two live projects with
the same identity.

## 8. Performance boundary

The normal Gallery scan never calls `OpenSave.open_pxo_file()` and never calls
`Project.deserialize()`.

For current files it reads only:

- ZIP file index;
- `gallery.json`;
- `preview.png`;
- filesystem mtime.

Reading full pixel/cel/layer payloads is reserved for actually opening a
project. The only P3-A path that copies the rest of the ZIP is rare duplicate
UUID repair.

## 9. Automated acceptance

`tests/unit/test_p3_a_project_library.gd` covers:

- valid UUID generation;
- schema-1 metadata and preview scanning;
- Unix mtime exposure;
- old-PXO `data.json` fallback;
- discovery not rewriting ordinary legacy PXOs;
- corrupted PXOs remaining visible;
- deterministic duplicate UUID canonical selection;
- persisted duplicate UUID repair in both `data.json` and `gallery.json`;
- preservation of unrelated ZIP entries during repair;
- second-scan UUID stability;
- `.pxo` filtering and mtime-descending ordering;
- serialization/save source contracts for UUID and `gallery.json`.

The existing P0/P1/P2/P3-0 suites remain mandatory through the shared
`tests/runner.gd` entry.

## 10. Out of scope

P3-A does not implement:

- Project Gallery visual UI;
- App Shell or cold-start Gallery routing;
- the P3-B dirty/2-second/30-second managed autosave model;
- project-bound crash recovery records or recovery prompts;
- New Project;
- Files document picker/import;
- rename, duplicate, delete, share, or export Gallery actions;
- long-press/context menus;
- Gallery animations or visual polish.
