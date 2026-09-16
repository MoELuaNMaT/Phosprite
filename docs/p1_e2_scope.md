# P1-E2 Timeline touch reorder scope

P1-E2 adds iPad long-press drag ownership for existing Timeline Cel and Frame reorder behavior. It extends the P1-E1 touch manager rather than introducing a second competing touch recognizer.

## In scope

- Finger movement before long-press ownership remains Timeline scrolling.
- Reorder ownership requires about 450 ms hold, matching the accepted Layer D4-B contract.
- A held Cel can drag one Cel or the existing `Project.selected_cels` set.
- A held Frame can drag one Frame or the Frame set derived from existing `Project.selected_cels`.
- An unselected drag source collapses selection to that source before drag payload construction.
- Touch drag reuses the existing Cel/Frame drag payload builders, `_can_drop_data()` and `_drop_data()`.
- Touch payload explicitly disables Ctrl/Cmd-forced Swap; desktop two-field payloads keep existing Ctrl/Cmd behavior.
- Cross-layer Cel drag keeps the existing native cross-layer Swap rule.
- Cel/Frame left/right placement is based on the supplied local drop `pos`, not global mouse position.
- Frame and Cel reorder support horizontal edge auto-scroll.
- Cel reorder also supports vertical edge auto-scroll.
- Edge auto-scroll continues while the owned finger is stationary.
- Owned reorder shows a floating preview, source outline, and reuses the existing Timeline `drag_highlight` for drop feedback.
- Valid release invokes native `_drop_data()` at most once. Invalid release/cancel invokes no drop transaction.
- One successful touch reorder remains one native Undo transaction.

## Explicitly out of scope

- No P1-E3 Timeline toolbar reorganization.
- No Frame duration touch changes.
- No Tag touch resize/edit redesign.
- No Linked Cel behavior changes.
- No Onion Skin behavior changes.
- No Keyframe Timeline redesign.
- No second Cel/Frame move/swap implementation in the touch manager.
- No new selection model beyond `Project.selected_cels`.
- No changes to desktop Shift/Ctrl/Cmd selection or native mouse drag semantics.

## Acceptance rule

P1-E2 may merge only after static checks, regression tests, desktop builds and unsigned iOS build pass, followed by target-iPad acceptance of long-press ownership, scrolling coexistence, Cel/Frame reorder, edge auto-scroll, Undo/Redo, and P1-E1 regression behavior.
