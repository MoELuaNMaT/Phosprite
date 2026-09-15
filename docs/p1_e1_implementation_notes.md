# P1-E1 implementation notes

Implementation head is intentionally adapter-based:

- `TimelineTouchSelectionManager.gd` owns iOS touch recognition only.
- Existing `Project.selected_cels` is the only selection set.
- Existing `Project.change_cel()` publishes current Frame/Layer changes and drives Timeline UI refresh through `Global.cel_switched`.
- Existing Cel/Frame `PopupMenu` nodes are reused for double-tap context access.
- No Cel/Frame drag/drop method is called or duplicated in E1.
- The existing LayerPanel iOS bootstrap installs one Timeline manager because it is already guaranteed to run when the Timeline creates its Layer rows; duplicate installation is guarded by node name.

The explicit Select toggle is temporary E1 placement inside the existing Frame toolbar. P1-E3 may reorganize Timeline toolbar layout, but must preserve the same selection-mode state contract rather than inventing another selection model.
