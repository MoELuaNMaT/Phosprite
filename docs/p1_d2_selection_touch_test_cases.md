# P1-D2 Selection Touch Workflow — Test Cases

Target: iPad / iOS production build unless a case explicitly says desktop.

| ID | Area | Procedure | Expected result |
| --- | --- | --- | --- |
| D2-01 | Selection family | Launch on iPad and inspect the tool palette. | The seven Selection tools occupy one compact family entry; unrelated tools are unchanged. |
| D2-02 | Family tap default | On a clean install/config, tap the Selection family entry once. | `RectSelect` becomes Primary. No popup opens and no tooltip/drag ghost remains. |
| D2-03 | Family long press | Long-press the Selection family entry without moving beyond touch slop. | A vertical seven-item menu opens to the right, containing ColorSelect, EllipseSelect, Lasso, MagicWand, PaintSelect, PolygonSelect and RectSelect. |
| D2-04 | Recent child | Choose EllipseSelect from the menu, switch to another tool, then tap the family entry once. | EllipseSelect is reactivated directly. |
| D2-05 | Restart persistence | With a non-default Selection child as recent, fully quit and relaunch Phosprite, then tap the family entry. | The same recent child is activated after restart. |
| D2-06 | Desktop baseline | Run desktop build and inspect Selection tools. | All seven original Selection buttons remain independently visible and behave as before. |
| D2-07 | Rect finger free drag | Select RectSelect, drag a clearly non-square rectangle with one finger, keep moving or lift before 1000 ms stationary dwell. | Shape remains freeform; no premature 1:1 lock. |
| D2-08 | Rect finger perfect hold | Drag a non-square rectangle, then hold the finger within 12 px for at least 1000 ms. Continue dragging after lock. | Preview immediately becomes 1:1 using the short side and stays 1:1 until lift. |
| D2-09 | Rect dwell reset | Drag, pause less than 1000 ms, move more than 12 px, then pause again. | The first dwell is invalidated; lock occurs only after a full 1000 ms dwell from the new position. |
| D2-10 | Ellipse Pencil perfect hold | Repeat D2-08 with Apple Pencil and EllipseSelect. | Circle lock has the same 1000 ms / 12 px semantics as finger RectSelect. |
| D2-11 | D1 long-press regression | With a normal drawing tool selected, stationary finger long-press on canvas. | D1 temporary color sampling still triggers around 450 ms; D2 perfect-shape logic does not interfere. |
| D2-12 | Polygon tap points | Select PolygonSelect and tap several distinct points. | Each tap extends the polygon preview through the existing polygon path. |
| D2-13 | Polygon close at start | After at least two segments, tap the first point. | Polygon closes and applies through the existing close rule. |
| D2-14 | Polygon double tap | Build an open polygon and double-tap the final point. | Polygon completes and applies without requiring a desktop mouse double-click event. |
| D2-15 | Polygon cancel | Start an open polygon and tap `Cancel polygon`. | In-progress polygon is discarded, preview clears, existing committed selection is not replaced by the unfinished polygon. |
| D2-16 | Selection modes | For RectSelect or EllipseSelect, apply Replace, Add, Subtract and Intersect from the existing Mode control. | All four modes produce their existing semantics; no touch-only parallel mode state appears. |
| D2-17 | Transform move | Create a selection, drag inside selected content with touch, then Confirm and repeat with Cancel. | Move preview is touch-operable; Confirm commits and Cancel restores the pre-transform state. |
| D2-18 | Transform handles | On an active transform, acquire scale, rotate and skew handles with touch and manipulate each. Also try touches near adjacent handle types. | Each existing transform handle responds and updates the same preview/commit model used on desktop. Visual handle size is unchanged; iOS adapter input uses an invisible 44 px acquisition target and overlapping targets resolve to the nearest handle. |
| D2-19 | Two-finger navigation regression | During normal canvas use, perform two-finger pan/pinch. | P1-C navigation behavior remains unchanged; P1-D2 does not enable two-finger rotation. |
| D2-20 | Primary/Secondary regression | Set distinct Primary and Secondary tools/colors, then use the Selection family entry. | Touch Selection changes Primary only; Secondary data/model is preserved. |

## Automated regression coverage

`tests/unit/test_p1_d2_selection_touch.gd` checks the exact seven-tool family, recent-child fallback/persistence hooks, iOS-only compaction, 1000 ms Perfect Shape dwell, reuse of D1 touch slop, timer-driven stationary acquisition, Polygon double-tap/cancel hooks, the four existing Selection modes, and preservation of the existing transform model.

`tests/unit/test_p1_d2c_selection_transform_touch.gd` additionally checks that CanvasAdapter events are offered to transform handles before normal Selection drawing, acquired handles consume that adapter event, the router reuses the existing handle press/drag/release state machine, the invisible touch target remains 44 px with nearest-handle resolution, and Selection move/Confirm/Cancel still use the existing transform model.

## Release gate

P1-D2 is acceptable only when the headless regression suite passes, the iOS unsigned export succeeds, and D2-01 through D2-20 have no hard functional blocker on the target iPad. Automated source/logic checks are not a substitute for the touch/handle acceptance cases above.
