# Stage 0 acceptance evidence and capture checklist

Baseline branch `fix/p0-p2-audit-repairs-20261117` SHA `11c86c04471ff1094122b4a83fca5f59890271b4`.

## Stage-0 evidence status

| Requirement | Status | Evidence / limitation |
|---|---|---|
| Pin latest chosen repair branch against master | **PASS (repository comparison)** | Ahead 23, behind 0; both SHA recorded in README |
| Read both Google Drive specifications | **PASS (document content)** | Links and policy differences recorded in README / errata |
| Verify manifest ID/priority counts | **PASS (static enumeration)** | 78 entries = 42 P0 + 27 P1 + 9 P2 |
| Map current UI ownership and icon candidates | **PASS (static, not device-confirmed)** | ui_inventory.md + icon_registry.csv |
| Record design conflicts and functional protections | **PASS (static)** | spec_errata.md |
| Capture original iPad UI screenshots | **PENDING (no running device/session)** | Capture matrix below; must be collected before visual implementation changes are judged |
| Godot automated smoke and iOS device validation | **NOT EXECUTED** | No build or test execution in Stage 0 |
| Establish on-device size/zoom/Chinese text proof | **PENDING** | Requires an actual iPad exported build and screenshots |

**Important:** Do not label the entire visual baseline 'device verified' until the pending rows are complete.

## Baseline screenshot capture matrix

Capture **before** visual replacement and then repeat **after**. Each image should include device model, iPadOS version, app build identifier, viewport orientation/available size, UI profile, and theme. Use the same sample project and palette where practical.

| Shot ID | UI state | Required features visible | Regression to compare |
|---|---|---|---|
| S01 | Gallery: empty and new-project dialog | top actions, card grid empty state, input sizes | Full view and safe margins |
| S02 | Gallery: several named and untitled projects | project thumbnails, metadata, selected state | Project name fallback, six/four-column behavior |
| S03 | Gallery: multi-select with 2+ cards | multi-select feedback and action menu | Tap/drag and delete confirmation |
| S04 | UI1: pencil and tool-option panel | tool icon + caption, vertical numeric input | Actual touch region, no label clipping |
| S05 | UI3: pencil selected | fixed size/opacity quick strip, top taskbar | Position relative to canvas and Timeline |
| S06 | UI3: eraser / selection family popup | quick strip content changes, mode toggles | Tap-to-open/collapse, no overflow |
| S07 | UI3: Preview dragged toward left strip | reserved zone and floating limits | Floating window does not obscure fixed strip |
| S08 | UI3: Palette & Color popup open | current color, palette, tool option popup | Independent popup placement and color match |
| S09 | UI3: long-press color picking | progress ring and sampled pixel | No accidental activation on ordinary tap |
| S10 | UI4: animation timeline / 2+ frames | CelButton, play/stop, onion skin, layer states | 36×36 frame and safe area |
| S11 | UI4: single-frame layer multi-select | layer eyes, folders, selection outline | Multiple selection and undo feedback |
| S12 | Reference image / Preview grayscale | editor canvas plus Preview | Both views display same grayscale mode |
| S13 | Any UI: Chinese + English + digits | text labels, numbers, fallback glyphs | Prevent the previous glyph-to-digit regression |
| S14 | Workspace: floating resizing and rotation | resize handles, docked Timeline, overlays | Retain draggable regions and saved layout |

For critical shots S02, S04, S05, S07, S08, S10 and S13, repeat on (a) landscape full-screen, (b) portrait, and (c) iPad split view close to the intended 590pt **when the device supports it**. Also capture Sunny Cream and Twilight Berry only **after** they exist; current theme screenshots are references, not invented new-theme results.

## Comparison rules

1. Keep the painted canvas/project image, palette entries and zoom level fixed while comparing UI shell colors.
2. Exclude canvas art, color swatch interiors and reference images from shell color budget metrics.
3. Inspect actual rendered click/hit regions, not just visual button backgrounds. A gap between buttons does not automatically enlarge tap targets.
4. Test PNG nearest-neighbor rendering separately from font anti-aliasing. Do **not** force nearest-neighbor on all text.
5. Verify rounded swatch outline and selection overlays without modifying the displayed paint color.
6. Exercise touch cancel, hold, Pencil and finger input, palette empty-cell operations, Timeline multi-select, and color-popup close/reopen.
7. Verify both dark and light *when implemented*, including text contrast; always check UI after reopening a project.
8. A failing scenario blocks that feature's stage completion; do not hide the failure with additional visual overlays.

## Stage-1 entry gate

- [x] Static source baseline pinned.
- [x] Icon IDs and priority counts checked; existing candidates listed.
- [x] UI owner/interaction mapping published.
- [x] Specification conflicts and acceptance rules recorded.
- [ ] Obtain on-device baseline screenshots **or explicitly accept a documented visual-validation gap**.
- [ ] Choose tested logical pixel / pt scaling policy for the initial iPad model(s).
- [ ] Confirm the new design theme's compatibility policy for custom/legacy themes.

Stage 1 may start with a **small isolated style sample** while device screenshots remain pending, but **must not** claim a production-ready visual system until device checks complete.
