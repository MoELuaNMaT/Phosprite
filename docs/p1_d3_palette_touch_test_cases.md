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
11. Long-press a non-empty swatch for about 450 ms, then drag it onto another swatch. Once reorder ownership is acquired, a visible copy of the source swatch must follow the finger so the gesture has continuous feedback. The existing Palette reorder transaction must run on release. Undo/Redo must restore/reapply the reorder.
12. While reorder ownership is active and the finger remains inside the visible Palette ScrollContainer, the Palette itself must remain stationary. Moving the finger upward or downward within the visible region must not scroll the Palette in the opposite direction.
13. Continue holding the dragged swatch and move the finger above the visible Palette region. Only after crossing the top boundary may the Palette auto-scroll upward to reveal earlier rows. Keep the finger above the boundary without moving; auto-scroll should continue while held.
14. Repeat at the bottom boundary. Only after crossing below the visible Palette region may the Palette auto-scroll downward to reveal later rows. The scroll direction must follow the boundary crossed, not the finger-drag delta used by normal scrolling.
15. Move the finger back inside the visible Palette region while still holding. Edge auto-scroll must stop immediately and the Palette must remain at its new managed scroll position while the swatch preview continues following the finger.
16. Long-press and drag a swatch while Secondary is the active color target. Reordering must still work; Primary/Secondary color-slot state must not be swapped or collapsed.
17. Long-press then release without dragging. It should behave as a normal tap, not reorder.
18. Drag outside the visible Palette area after acquiring reorder and release outside. It must not perform an accidental swap, and the transient drag preview must disappear.

## D3-C — Touch ergonomics / regressions

19. On a fresh iPad configuration, Palette swatches should default to 32×32. If the user previously changed swatch size, that saved preference remains authoritative.
20. Palette toolbar buttons should have an approximately 44 pt touch-height target on iPad without forcing the desktop layout to the same dimensions.
21. Create Palette, Edit Palette, Palette selector, Sort, and Lock Grid remain usable after the touch-target adjustment and after orientation changes.
22. Switch between touch and an external mouse/trackpad. Tooltips and pointer hit behavior must restore normally; touch must not cause duplicate Palette activation.
23. Verify D1 Canvas long-press temporary eyedropper and Color Picker Tap/Drag are unchanged.
24. Verify D2 Selection proxy, Selection modes, content transform, two-finger pan/pinch, Confirm/Cancel remain unchanged.
25. Indexed-color project: selecting a Palette swatch through touch must preserve the Palette index in the same path used by pointer selection.

## Failure conditions

D3 fails if any of the following occurs: touch always writes Primary regardless of the active color target; normal scrolling selects or reorders colors; an acquired reorder drag has no visible following preview; the Palette scrolls while a reorder finger remains inside its visible region; edge auto-scroll moves opposite to the crossed boundary; a single empty-slot tap opens edit; synthetic mouse causes duplicate add/delete/select; external mouse right-click semantics regress; or Palette operations bypass existing Undo/indexed-color behavior.
