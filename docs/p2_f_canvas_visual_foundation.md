# P2-F — Canvas Visual Foundation

P2-F makes the editor Canvas read as a pixel document instead of a screen-space image pasted over an arbitrary checker texture. It is presentation-only: document data, rendering semantics, tools, touch routing, and Workspace layout behavior are unchanged.

## 1. Document-pixel checker contract

The main editor `TransparentChecker` uses document-pixel mode:

- one checker cell is exactly one Canvas/document pixel;
- the checker follows both Canvas movement and Canvas scale;
- a 16×16 document therefore contains 16×16 checker cells at the document level;
- checker colors still come from the existing Preferences;
- secondary previews keep the existing `checker_size`, `checker_follow_movement`, and `checker_follow_scale` preferences.

This deliberately separates the main pixel-editing Canvas from preview surfaces: the editor background communicates pixel coordinates, while preview checkers remain presentation preferences.

## 2. Canvas visual hierarchy

The main and secondary viewport containers install a screen-space backdrop on a dedicated `CanvasLayer` at layer `-100`. The backdrop ignores mouse input and derives its color from the active application Theme.

The visual stack is:

1. theme-derived Canvas workspace backdrop;
2. document-pixel transparency checker;
3. document content and editor overlays;
4. pixel/user grids;
5. theme-derived document boundary;
6. selection/transform/tool overlays.

The boundary is a separate `CanvasBoundary` node, so it does not pass through the document `BlendLayers` shader. It uses a screen-space hairline and updates after document resizing, project switching, and application theme switching.

## 3. Pixel-grid hierarchy

The pixel grid remains controlled by the existing View option, zoom threshold, and `pixel_grid_color` preference.

P2-F changes only presentation:

- only interior pixel separators are drawn;
- the document boundary owns the outer edge, preventing doubled/darker seams;
- the configured pixel-grid color is multiplied by a shared alpha factor so the grid remains subordinate to artwork and the document boundary;
- the grid remains a non-interactive `Node2D` overlay.

## 4. Theme adaptation

`CanvasVisualPolicy` resolves semantic Canvas colors from the active Pixelorama Theme:

- Panel/PanelContainer surface color is the base;
- Label font color provides the contrasting boundary direction;
- the backdrop is a slightly recessed form of the active surface;
- the document boundary is a controlled blend toward the active text color.

There are no fixed dark-theme-only Canvas chrome colors. Existing user-configurable checker and pixel-grid colors remain authoritative.

## 5. Automated acceptance

`tests/unit/test_p2_f_canvas_visual_foundation.gd` verifies:

- document checker size is exactly `1.0` Canvas pixel;
- only the main editor checker opts into document-pixel mode;
- previews retain their checker preference path;
- pixel-grid lines begin inside the outer boundary;
- grid alpha is subordinate but non-zero;
- dark and light Themes produce distinct, correctly separated backdrop/boundary colors;
- Canvas backdrop and boundary are mounted in the correct visual layers;
- the backdrop cannot capture Canvas input.

## 6. iPad real-device visual gate

P2-F is the first formal real-device visual gate in the P2 Workspace sequence. Automated CI cannot replace this check.

On an iPad, verify:

1. Create/open a 16×16 transparent document. Confirm the document shows 16×16 checker cells — one cell per document pixel.
2. Inspect at 100%, 400%, and approximately 1600% zoom. Checker cells must remain locked to document pixels while panning and zooming.
3. Enable Pixel Grid at its normal threshold. Internal separators should be visible but lighter than the document boundary, with no double-dark outer seam.
4. Pan the document across the viewport. The outer Canvas area should remain screen-fixed while the checker/document move with the camera.
5. Switch between a dark and a light application Theme. The Canvas workspace backdrop and document boundary should remain distinguishable without becoming dominant.
6. Rotate between portrait and landscape. No backdrop gaps or stale sizing should appear.
7. On Retina/high-DPI output, confirm the boundary remains a crisp hairline rather than scaling into a thick band.
8. Draw with Apple Pencil and perform touch pan/zoom. The backdrop and boundary must not consume input or change P1 input behavior.

The gate is considered complete only after those checks are performed on physical hardware. CI success alone means the implementation is ready for the device gate, not that the device gate has passed.

## 7. Out of scope

P2-F does not:

- migrate current editor panels into Workspace Modules;
- replace the legacy DockableContainer layout;
- change the Window > Layouts surface;
- alter document pixel data or blend/render semantics;
- change tool hit testing, Pencil routing, gesture routing, or Canvas navigation;
- redesign the user grid feature;
- add P2-G Workspace panel interactions.

Those live editor layout/migration concerns remain P2-G.
