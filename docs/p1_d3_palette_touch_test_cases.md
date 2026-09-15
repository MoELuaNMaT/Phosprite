# P1-D3 Palette / Color Touch Acceptance

Target: iPad Air 5 / iPadOS 18.x. Use both Finger and Apple Pencil where relevant.

## D3-A — Primary / Secondary Palette contract

1. Select **Primary** in the Color Picker, then tap a non-empty Palette swatch. The Primary color changes to that swatch and the Primary Palette highlight follows it. Secondary remains unchanged.
2. Select **Secondary**, then tap a different non-empty Palette swatch. The Secondary color changes and the Secondary Palette highlight follows it. Primary remains unchanged.
3. With Primary active, tap an empty swatch. The active Primary color is inserted into that slot and becomes selected through the normal Palette model.
4. Repeat the empty-swatch test with Secondary active. The Secondary color must be inserted; Primary must not change.
5. With Primary active, tap **Add Color**. The added color must come from Primary. Repeat with Secondary active and verify it comes from Secondary.
6. Select different Palette colors for Primary and Secondary. With Secondary active, tap **Delete Color**. Only the Secondary-selected Palette color is removed. Repeat for Primary.
7. Attach a mouse/trackpad: left click must still address Primary and right click must still address Secondary. No touch-only state may override pointer behavior.

## D3-B — Edit / reorder / scroll arbitration

8. Double-tap a non-empty swatch. The existing swatch Color Picker popup opens. Change the color, close the popup, then Undo/Redo; behavior must match desktop Palette editing.
9. Tap an empty swatch once to fill it. It must not immediately open the edit popup. A later deliberate double-tap may edit it.
10. Scroll a long Palette normally. A drag that starts moving before the long-hold threshold must scroll and must not select, edit, or reorder a swatch.
11. Long-press a non-empty swatch for about 450 ms, then drag it onto another swatch. The existing Palette reorder transaction must run. Undo/Redo must restore/reapply the reorder.
12. Long-press and drag a swatch while Secondary is the active color target. Reordering must still work; Primary/Secondary color-slot state must not be swapped or collapsed.
13. Long-press then release without dragging. It should behave as a normal tap, not reorder.
14. Drag outside the visible Palette area after acquiring reorder. Releasing outside must not perform an accidental swap.

## D3-C — Touch ergonomics / regressions

15. On a fresh iPad configuration, Palette swatches should default to 32×32. If the user previously changed swatch size, that saved preference remains authoritative.
16. Palette toolbar buttons should have an approximately 44 pt touch-height target on iPad without forcing the desktop layout to the same dimensions.
17. Create Palette, Edit Palette, Palette selector, Sort, and Lock Grid remain usable after the touch-target adjustment and after orientation changes.
18. Switch between touch and an external mouse/trackpad. Tooltips and pointer hit behavior must restore normally; touch must not cause duplicate Palette activation.
19. Verify D1 Canvas long-press temporary eyedropper and Color Picker Tap/Drag are unchanged.
20. Verify D2 Selection proxy, Selection modes, content transform, two-finger pan/pinch, Confirm/Cancel remain unchanged.
21. Indexed-color project: selecting a Palette swatch through touch must preserve the Palette index in the same path used by pointer selection.

## Failure conditions

D3 fails if any of the following occurs: touch always writes Primary regardless of the active color target; scrolling selects or reorders colors; a single empty-slot tap opens edit; synthetic mouse causes duplicate add/delete/select; external mouse right-click semantics regress; or Palette operations bypass existing Undo/indexed-color behavior.
