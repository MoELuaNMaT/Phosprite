# P1-E2 acceptance summary

Target device acceptance should verify the following minimal gate before merge:

1. A normal drag started from a Cel before the hold threshold still scrolls the Timeline and does not reorder.
2. A held Cel drag reorders on the same Layer using native Move semantics.
3. A held selected Cel drags the existing `selected_cels`; a held unselected Cel collapses selection to itself before drag.
4. Cross-Layer Cel touch drag keeps the native Swap restrictions.
5. A held Frame drag reorders one or multiple selected Frames.
6. Frame reorder keeps native animation-tag recalculation and one-step Undo/Redo.
7. Finger drag ignores external Ctrl/Cmd forced Swap; desktop pointer drag keeps existing modifier Swap.
8. Horizontal edge auto-scroll works for Frame and Cel drag; vertical edge auto-scroll works for Cel drag, including while the finger is stationary.
9. Invalid release or touch cancel performs no drop transaction.
10. P1-E1 single tap, double tap, multi-select, and Timeline scrolling remain unchanged; D4 Layer reorder remains unchanged.

Do not merge P1-E2 until CI is green and this target-iPad gate passes.
