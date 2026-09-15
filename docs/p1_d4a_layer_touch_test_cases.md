# P1-D4A Layer Touch Context — iPad Acceptance

Scope: Layer selection and context actions only. Layer reorder remains P1-D4B.

## Gesture contract

- Single direct touch on a Layer row: select that Layer.
- Double direct touch on the same Layer row: select it, then open the existing Layer context menu.
- Long press is not assigned in D4-A; it remains reserved for D4-B Layer/Group reorder.
- Vertical movement beyond the tap slop before release is Timeline scrolling, not a tap/context action.
- Desktop mouse behavior remains unchanged: left double-click renames; right-click opens the context menu.

## Target-iPad acceptance

1. Tap an unselected Layer once.
   - The touched Layer becomes current.
   - No context menu opens.

2. Double-tap an unselected Layer.
   - The touched Layer becomes current first.
   - The existing Layer context menu opens at the touched Layer.
   - The menu contains Properties, Clipping mask, Flatten, Flatten visible, and Rename.

3. From the double-touch context menu choose Rename.
   - The existing inline Layer name editor opens.
   - Confirm a new name, then Undo/Redo it.
   - Rename must use the existing Layer rename transaction.

4. Double-tap another Layer while the previous Layer is current.
   - The newly touched Layer becomes current.
   - Its context menu opens; actions must target the newly selected Layer.

5. Start on a Layer row and immediately drag vertically more than the tap slop.
   - The Timeline/Layer list scrolls normally.
   - No context menu opens.
   - The drag is not treated as D4-A reorder.

6. Touch and hold without moving, then release.
   - In D4-A this behaves as an ordinary single selection.
   - No context menu opens solely because of hold duration.
   - D4-B will later claim long-hold + drag for reorder.

7. Connect/use a real mouse or trackpad on iPad.
   - Left click still selects.
   - Left double-click still enters Rename.
   - Right-click still opens the Layer context menu.
   - Direct-touch handling must not cause duplicate pointer actions.

## Failure conditions

- Double touch opens Rename directly instead of the context menu.
- Context menu opens without first selecting the touched Layer.
- A single touch opens the context menu.
- Vertical scrolling triggers a context action.
- D4-A introduces Layer reorder/drop behavior.
- Synthetic mouse events cause duplicate selection/menu/Rename actions.
- Desktop left-double-click or right-click semantics regress.
