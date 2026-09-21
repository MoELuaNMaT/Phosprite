# P3-D — Project Gallery UI Core

P3-D turns the P3-C Project Gallery shell into the first real iPad project
browser. The stage is visual and read-oriented: it presents the project library
and opens projects, but it deliberately does not implement project-management
operations or New/Import flows yet.

## 1. Visual structure

The Gallery uses a dark full-screen background with two vertical regions:

1. a fixed Top Bar;
2. a scrolling project grid.

The Top Bar contains:

- left: Phosprite application mark and wordmark;
- right: Import and New buttons;
- an Exit Multi-Select button that is visible only when the shell is placed into
  multiselect mode.

P3-D freezes these entry points as UI contracts. Their workflows are deferred.

## 2. Project card

Each project is represented by one card.

A healthy card contains:

- one square thumbnail area;
- canvas dimensions;
- last filesystem modification time.

The project filename/name is intentionally not shown.

The thumbnail uses keep-aspect-centered rendering:

- the full preview is always visible;
- no cropping;
- no non-uniform stretching;
- transparent preview pixels reveal the dark thumbnail/card background directly;
- no checkerboard is drawn in Gallery.

The square thumbnail size follows the card's computed column width.

## 3. Responsive columns

The Gallery uses orientation, not arbitrary breakpoint tiers:

- landscape: exactly 6 columns;
- portrait: exactly 4 columns.

Column choice is recomputed when the Gallery root resizes.

Card width is calculated from the visible Gallery width, fixed side margins and
fixed inter-card spacing. The column count itself does not vary beyond 6/4 in
P3-D.

## 4. Ordering

`ProjectLibrary.scan()` continues to provide newest-first ordering using the
formal PXO filesystem modification time, with normalized path as the stable
tie-breaker.

P3-D consumes that ordering directly and does not re-sort cards independently.

## 5. Lazy thumbnails

P3-D must not decode all `preview.png` files during Gallery scan.

`ProjectLibrary.scan(include_thumbnails := true)` keeps the P3-A default
behavior for existing callers and compatibility tests.

The Project Gallery calls:

`library.scan(false)`

so its initial scan reads only project metadata/health/mtime/recovery state.

`ProjectLibrary.load_thumbnail(entry)` opens that individual PXO and decodes
`preview.png` on demand. The decoded Image is cached on
`ProjectLibraryEntry.thumbnail`.

The Gallery requests thumbnails only for cards intersecting the current
ScrollContainer viewport plus a small preload margin. Already-decoded previews
remain cached while the Gallery is alive.

## 6. Corrupted projects

A PXO marked `CORRUPTED` by P3-A remains in the same grid ordering and retains
a concrete card.

Its card:

- does not attempt thumbnail decode;
- shows a Corrupted state in the square preview region;
- shows an unreadable-project metadata state;
- still routes activation through the existing P3-C open path, which refuses the
  full project load and reports the error.

P3-D does not silently hide malformed projects.

## 7. Empty state

When the library contains no projects, the grid area displays a minimal
`No projects yet` state.

No onboarding flow is added in this stage.

## 8. Multiselect boundary

P3-D exposes `set_multiselect_mode(enabled)` so the Top Bar can display
`Exit Multi-Select`.

P3-D does not implement:

- long-press selection;
- card checkmarks;
- selection sets;
- batch operations.

Those belong to the later project-operations stage.

## 9. New / Import boundary

The Top Bar exposes `new_project_requested` and `import_requested` signals.

The buttons do not create or import anything in P3-D. This prevents visual UI
work from prematurely defining file-picker, naming, duplicate-handling or
import semantics.

## 10. P3-D acceptance

P3-D is complete when automated validation proves:

1. dark Gallery root and Top Bar exist;
2. Top Bar contains Phosprite branding, Import and New;
3. Exit Multi-Select is hidden normally and can be exposed by shell state;
4. landscape is fixed at 6 columns;
5. portrait is fixed at 4 columns;
6. project cards have square thumbnail regions;
7. thumbnails use full-image aspect fit, not crop/stretch;
8. no Gallery checkerboard is present;
9. healthy cards display canvas dimensions and modification time;
10. project names are not displayed;
11. Gallery scan can skip thumbnail decoding;
12. visible thumbnails load on demand and cache on the entry;
13. corrupted projects retain a visible abnormal card;
14. newest-first ordering continues from ProjectLibrary;
15. all existing P0/P1/P2/P3-0/P3-A/P3-B/P3-C regression tests remain green;
16. unsigned iOS export remains green.

## 11. Deferred

P3-D does not implement:

- New Project workflow;
- Import workflow;
- long-press or gesture selection;
- actual multiselect selection state;
- rename / duplicate / delete;
- export/share from Gallery;
- project operation menus;
- folder/Stack organization;
- search;
- settings;
- cloud sync;
- rotation animations or other transition polish.

Those remain later P3 stages.
