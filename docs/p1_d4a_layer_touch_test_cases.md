# P1-D4A Layer Touch Context — iPad Acceptance

Scope: Layer selection and context actions only. Layer reorder remains P1-D4B.

## Gesture contract

- Single direct touch on a Layer row: select that Layer.
- Double direct touch on the same Layer row: select it, then open the existing Layer context menu.
- While inline Rename is active, the next direct touch outside the name editor commits the current text before that touch continues into the rest of the UI.
- Touches inside the inline Rename editor remain editing interactions and must not be converted into Layer selection/context gestures.
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

4. While Rename is active, type a new name and dismiss the software keyboard without pressing Return.
   - The inline editor may remain visible immediately after keyboard dismissal because iOS keeps LineEdit focus.
   - Tap any UI outside the name editor, including another Layer.
   - The current text is committed before the new touch action continues.
   - The inline editor closes, and tapping another Layer still selects that Layer normally.
   - Undo/Redo the rename once; there must not be a duplicate Rename transaction.

5. While Rename is active, tap back inside the name editor.
   - Editing continues normally.
   - The tap must not select the Layer again or open the context menu.

6. Double-tap another Layer while the previous Layer is current.
   - The newly touched Layer becomes current.
   - Its context menu opens; actions must target the newly selected Layer.

7. Start on a Layer row and immediately drag vertically more than the tap slop.
   - The Timeline/Layer list scrolls normally.
   - No context menu opens.
   - The drag is not treated as D4-A reorder.

8. Touch and hold without moving, then release.
   - In D4-A this behaves as an ordinary single selection.
   - No context menu opens solely because of hold duration.
   - D4-B will later claim long-hold + drag for reorder.

9. Connect/use a real mouse or trackpad on iPad.
   - Left click still selects.
   - Left double-click still enters Rename.
   - Right-click still opens the Layer context menu.
   - Direct-touch handling must not cause duplicate pointer actions.

## Failure conditions

- Dismissing the software keyboard and then touching elsewhere leaves Rename stuck open.
- An outside touch closes Rename but loses the typed name.
- An outside touch creates two Rename Undo entries.
- Tapping inside the active name editor is intercepted as a Layer gesture.
- Double touch opens Rename directly instead of the context menu.
- Context menu opens without first selecting the touched Layer.
- A single touch opens the context menu.
- Vertical scrolling triggers a context action.
- D4-A introduces Layer reorder/drop behavior.
- Synthetic mouse events cause duplicate selection/menu/Rename actions.
- Desktop left-double-click or right-click semantics regress.