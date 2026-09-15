# P1-D4C iPad acceptance cases

Target: iPad Air 5 / iPadOS 18 baseline. D4-C is Layer/Group touch-layout cleanup only.

## 1. Layer row direct controls

- Open a project with a Pixel Layer and a Group Layer.
- Tap Visibility and Lock repeatedly with Finger.
- On Pixel Layer, tap Link.
- On Group Layer, tap Expand/Collapse.

Expected:
- The direct targets are noticeably wider/easier to hit than the desktop-sized controls.
- Icons themselves are not visually enlarged.
- Layer row height still follows the existing Timeline cel-size preference.
- Tapping the neighboring Layer name does not accidentally trigger these controls.

## 2. Add Layer split control

- Tap the left side of Add Layer.
- Tap the right-side dropdown area of Add Layer.

Expected:
- Left side adds a Pixel Layer through the existing Add Layer transaction.
- Right side opens the existing layer-type menu.
- Pixel, Group, 3D, Tilemap and Audio options remain available.
- Both halves are easy to hit with Finger.

## 3. Delete remains direct

- Select a normal Layer and tap Delete Layer.
- Undo and Redo.
- Select a Layer state where Delete is disabled by existing rules.

Expected:
- Delete behavior and Undo/Redo are unchanged.
- Disabled state remains authoritative.

## 4. More Layer Actions menu

Open the new `…` Layer Actions menu.

Expected entries:
- Move layer up
- Move layer down
- Duplicate layer
- Merge down
- Layer effects

Verify each available action once and Undo/Redo where applicable.

Expected:
- Actions behave exactly like the previous direct toolbar buttons.
- No duplicate transaction or double execution occurs.

## 5. Disabled-state sync

Test at least:
- top Layer: Move Up disabled;
- bottom/top-level boundary cases: Move Down follows old rules;
- Group/Audio/invalid merge combinations: Merge Down disabled as before;
- Audio Layer: Layer Effects disabled as before.

Expected:
- The `…` menu disabled states match the old hidden toolbar Button states.
- A disabled menu item cannot execute an action.

## 6. D4-A regression

Verify:
- single tap Layer selects;
- double tap opens Layer context menu;
- Rename commits when the next outside operation occurs after keyboard dismissal.

## 7. D4-B regression

Verify:
- ordinary vertical drag scrolls before long-press ownership;
- long press then drag reorders;
- Group reparent works;
- edge auto-scroll works;
- one reorder equals one Undo.

## 8. Layout / rotation

Test landscape and portrait.

Expected:
- Add, Delete, `…`, and the existing Keyframe Timeline button remain reachable.
- Layer toolbar does not require the old row of five low-frequency Layer action buttons.
- Layer names remain usable at normal panel widths.

## 9. Desktop regression

If available, launch a desktop build.

Expected:
- The original full Layer toolbar remains unchanged on desktop.
- Desktop shortcuts, mouse drag/drop, right click and double-click Rename remain unchanged.

## Fail conditions

D4-C fails if any of the following occurs:
- iPad still shows Move Up/Down/Duplicate/Merge/FX as the old tiny direct button row instead of `…`;
- `…` executes a different transaction from the existing handler;
- menu disabled states disagree with the old Button states;
- D4-A context/Rename behavior regresses;
- D4-B reorder/Group behavior regresses;
- Frame/Cel controls or behavior are changed by this stage;
- desktop Layer toolbar is changed by the iOS-only layout adapter.
