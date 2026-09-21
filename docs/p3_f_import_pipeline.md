# P3-F — iOS Import Pipeline Business Layer

P3-F makes the Project Gallery Import entry functional at the application/business
layer while deliberately stopping before native iOS picker integration.

P3-G remains responsible for Document Picker / Photo Picker, Files "Open in
Phosprite", UTType/document declarations, Reveal in Files and real native handoff.

## 1. Import source UI

The Gallery Import button opens a source popover with two choices:

- 文件
- 照片

P3-F does not open native iOS pickers itself.

Instead AppShell exposes:

- `files_import_source_requested`
- `photos_import_source_requested`

and one common future handoff entry:

`handoff_import_path(source_path)`

P3-G can bind its native picker results directly to that path-based business API.

## 2. Supported business-layer imports

P3-F classifies:

- `.pxo`
- `.ase` / `.aseprite`
- ordinary image types already supported by the existing Pixelorama open path:
  PNG, BMP, HDR, JPG/JPEG, SVG, TGA, WebP and EXR.

Unknown file types are rejected rather than guessed.

All successful imports end as managed `.pxo` files under the configured Projects
directory. External sources are read-only inputs and never become the subsequent
save target.

## 3. PXO copy-in

PXO import:

1. records all existing managed UUIDs;
2. allocates a collision-safe target basename in Projects;
3. copies the external PXO into that managed location;
4. opens the managed copy, never the external source;
5. if the copied project UUID collides with an existing managed project, only the
   imported Project receives a new UUID;
6. runs the P3-B transactional save path so the managed copy is normalized and
   receives current gallery metadata/preview;
7. only then can AppShell enter Editor.

File-name conflicts use the existing deterministic `_1`, `_2`, ... rule.

The external PXO bytes are never changed.

## 4. ASE / ASEPRITE conversion

ASE/ASEPRITE import reuses the existing high-quality
`AsepriteParser.open_aseprite_file()` parser.

The parsed runtime Project is immediately assigned a collision-safe Projects path
and committed through the P3-B save coordinator.

The Aseprite source is never used as the new project's save path after conversion.

A parser or managed-save failure rolls back the temporary runtime Project/tab and
keeps AppShell in Gallery.

## 5. Image mode choice

After a valid image path is handed off, P3-F shows exactly two choices:

- 作为图层
- 作为参考图

Images always create a new managed project. P3-F does not import an external image
into whichever existing project happens to be open.

## 6. CanvasSizeResolver

Image imports share one resolver.

For a valid source image:

1. compute major/minor aspect ratio;
2. choose the nearest family among 1:1, 4:3 and 16:9;
3. preserve source orientation;
4. within that family, choose the first approved P3-E preset whose width and
   height both contain the source at 1:1;
5. portrait sources use the swapped preset;
6. if no family preset contains the source, fall back exactly to 256×256.

Invalid/non-positive source dimensions also fall back to 256×256.

The approved family presets are the P3-E preset tables.

## 7. Image as layer

Selecting 作为图层 opens the existing iPad NewProjectDialog with the
CanvasSizeResolver result pre-filled.

The user can still choose another approved preset or custom width/height before
confirming.

When the image becomes a layer:

- if it already fits, its pixel size stays exactly 1:1;
- smaller images are never upscaled;
- oversized images uniformly downfit until the whole source fits;
- downfit uses nearest-neighbor interpolation;
- the result is centered on the target canvas;
- the underlying project remains a normal managed RGBA project.

The project is committed through P3-B before Editor becomes visible.

## 8. Image as reference

Selecting 作为参考图 immediately creates a new project using the inferred
CanvasSizeResolver size.

The ReferenceImage keeps the original image pixel data.

Only its transform is adjusted:

- one uniform scale factor fits the complete source into the canvas;
- the transformed image is centered;
- subsequent reference move/rotate/scale behavior remains the existing editor
  behavior.

The reference project is also committed through P3-B before Editor becomes
visible.

## 9. Failure and rollback

Any failed managed commit must leave no half-imported Project.

Rollback removes:

- temporary runtime Project;
- temporary tab;
- save-coordinator state;
- P3 recovery/staging for that UUID;
- any managed target created only for the failed import.

When an existing parser temporarily activates the imported tab before commit,
rollback briefly bypasses the project-switch save guard so it can restore the
previous Project without recursively retrying the failed save.

External source files are never deleted or modified.

## 10. Desktop testability

P3-F's business layer accepts ordinary filesystem paths and must be testable in
desktop/headless CI.

Native iOS APIs are not required to validate:

- PXO copy-in;
- ASE parser routing;
- image loading;
- canvas resolution;
- layer/reference construction;
- managed first commit;
- identity collision handling;
- rollback.

This is intentional so P3-G can remain a thin native handoff layer.

## 11. Acceptance

P3-F is complete when automated validation proves:

1. Import source UI exposes 文件 / 照片;
2. image mode UI exposes 作为图层 / 作为参考图;
3. Files/Photos choices emit handoff signals rather than implementing P3-G native
   picker logic;
4. `handoff_import_path()` is the single path-based business entry;
5. PXO copies into Projects and never mutates the external source;
6. PXO basename collisions use `_1`, `_2`, ...;
7. duplicate PXO identity changes only the imported copy UUID;
8. ASE/ASEPRITE routes through the existing parser and then managed PXO commit;
9. all successful imports use managed Projects paths;
10. CanvasSizeResolver chooses nearest 1:1/4:3/16:9 family, preserves orientation
    and uses exact 256×256 fallback when no preset contains the source;
11. image-as-layer stays 1:1 when it fits, never upscales, nearest-neighbor
    downfits when needed and centers;
12. image-as-reference keeps source pixels and uses a centered uniform-fit
    transform;
13. 作为图层 seeds NewProjectDialog with the inferred size but still allows user
    changes;
14. failed imports leave no transient managed project/tab/recovery;
15. desktop Create/Open behavior is not replaced by the P3-F Gallery pipeline;
16. all earlier P0/P1/P2/P3-0…P3-E regression tests stay green;
17. unsigned iOS export stays green.

## 12. Deferred to P3-G

P3-F intentionally does not implement:

- UIDocumentPicker / native Document Picker;
- PHPicker / native Photo Picker;
- Files app "Open in Phosprite";
- UTType / document-type declarations;
- security-scoped bookmark / URL lifecycle;
- Reveal in Files / 在文件中查看;
- native iOS multi-file picker behavior;
- native Photos asset-to-temporary-file handoff.

Those are P3-G responsibilities and should call the P3-F handoff API rather than
duplicate import logic.
