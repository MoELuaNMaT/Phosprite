# P1-D4B Layer / Group Touch Reorder — target iPad acceptance

Scope: Layer / Group touch reorder only. This stage does not change Frame, Cel, Tag, Onion Skin, or P1-E Timeline selection behavior.

## 1. Gesture arbitration

1. Tap a Layer once: it selects normally.
2. Double-touch a Layer: the D4-A context menu still opens.
3. Drag vertically immediately, before holding: the Timeline scrolls normally and no reorder preview appears.
4. Hold a Layer for about 450 ms, then move: reorder ownership begins.
5. After reorder ownership begins, normal finger-delta scrolling stops.
6. Long-press on Visibility / Lock / Link / Expand controls must not begin Layer reorder.

## 2. Basic Layer reorder

1. Create at least four normal Pixel Layers.
2. Long-press one Layer and drag to the upper region of another Layer.
   - Existing drag highlight shows the insertion target.
   - Release moves the source above the target according to the existing Layer ordering convention.
3. Repeat using the lower target region and verify the opposite insertion side.
4. The source Layer remains drawn at its original row during the gesture and receives a distinct dashed source marker.
5. A semi-transparent preview follows the finger.
6. Release over the source Layer itself: no transaction occurs.
7. Release outside the visible Layer list: no transaction occurs.
8. Undo once fully restores one completed reorder; Redo once reapplies it.

## 3. Group hierarchy

1. Create Group A, Group B, and several Pixel Layers.
2. Drag a Pixel Layer into the center region of Group A.
   - It becomes a child of Group A.
   - One Undo restores the previous parent and order.
3. Drag that child to a top/bottom insertion region outside Group A.
   - It can leave the Group through the same native move/reparent rules.
4. Drag Group A itself.
   - All descendants move with the Group subtree.
5. Try to drag Group A into one of its own descendants.
   - Target must be rejected and release must be a no-op.
6. Collapse Group A and drag another Layer to the center of the collapsed Group row.
   - The collapsed Group itself remains a valid parent target.
   - Hidden descendants are not independently targetable.
7. Nested Groups must preserve their hierarchy after move, Undo, and Redo.

## 4. Existing selection compatibility

1. If a pre-existing desktop/mouse multi-Layer selection includes the long-pressed Layer, touch reorder keeps the existing selected Layer payload.
2. If the long-pressed Layer is outside the existing selection, it becomes the single selected Layer before reorder begins.
3. No new Finger multi-selection gesture is introduced in D4-B.

## 5. Edge auto-scroll

Use enough Layers to require vertical scrolling.

1. Start reorder and keep the finger inside the visible Timeline area: the list stays fixed.
2. Move above the visible top edge: the Timeline continuously auto-scrolls upward.
3. Hold the finger stationary above the top edge: auto-scroll continues.
4. Move below the visible bottom edge: the Timeline continuously auto-scrolls downward.
5. Hold stationary below the bottom edge: auto-scroll continues.
6. Move back inside: auto-scroll stops immediately and the list holds its current position.
7. Re-enter over a legal Layer target: native target highlight updates to the Layer currently under the finger after scrolling.
8. Release while still outside: no reorder transaction occurs.

## 6. Modifier and desktop regression

1. With an external keyboard attached, hold Ctrl/Cmd while performing a Finger long-press reorder.
   - Finger still performs ordinary Move/Reparent; it must not switch to Swap semantics.
2. With mouse/trackpad, native Layer drag still works.
3. Desktop Ctrl/Cmd + single-Layer drag still performs the existing Swap behavior.
4. Desktop drag preview and native target highlight still work.
5. Desktop double-click Rename and right-click context menu remain unchanged.

## 7. D4-A regression

1. Single-touch selection works.
2. Double-touch context menu works.
3. Rename from the context menu works.
4. Rename → hide keyboard → touch another Layer commits the name and selects the other Layer.
5. Visibility / Lock / Link / Expand retain their existing behavior.

## Pass gate

D4-B passes only if all of the following are true on the target iPad:

- fast vertical movement scrolls instead of reordering;
- long-press then drag reliably acquires reorder ownership;
- top/bottom Layer reorder works;
- Group center reparent and Group subtree movement work;
- ancestor-to-descendant illegal drops are rejected;
- edge auto-scroll works while stationary outside the visible region;
- invalid/outside release creates no transaction;
- each completed reorder is exactly one UndoRedo action;
- Finger never inherits Ctrl/Cmd Swap semantics;
- D4-A touch behavior and desktop native Layer drag do not regress.
