# P1-E1 Timeline touch selection scope

P1-E1 adds an iPad-only touch selection layer to the existing Pixelorama Timeline. It does not replace the Timeline data model or business transactions.

## In scope

- Single-finger tap on a Cel selects that Cel.
- Single-finger tap on a Frame header selects that Frame at the current Layer.
- Double tap on a Cel opens its existing PopupMenu.
- Double tap on a Frame header opens its existing PopupMenu.
- An explicit iPad Timeline multi-select mode is available.
- In multi-select mode, tapping a Cel toggles that Cel while preserving at least one selected Cel.
- In multi-select mode, tapping a Frame header toggles all Cels in that Frame while preserving at least one selected Cel.
- `Project.selected_cels` remains the only multi-selection state.
- `Project.change_cel()` remains the path that publishes current Frame/Layer changes and refreshes Timeline selection visuals.
- Pre-selection movement beyond the touch slop remains Timeline scrolling.
- Synthetic mouse events generated from iOS touch are suppressed for touched Frame/Cel controls; physical pointer input restores native pointer behavior.

## Explicitly out of scope

- No Frame/Cel long-press reorder ownership. That belongs to P1-E2.
- No `_drop_data` or new move/swap transactions.
- No Timeline toolbar redesign beyond the one explicit multi-select mode entry required by E1.
- No Frame duration changes.
- No Tag touch resize.
- No Linked Cel behavior changes.
- No Onion Skin behavior changes.
- No Keyframe Timeline redesign.
- No changes to desktop Shift/Ctrl/Cmd selection semantics.

## Acceptance rule

P1-E1 may merge only after static checks, regression tests, desktop builds and unsigned iOS build pass, followed by target-iPad acceptance of tap, double-tap, multi-select and scroll coexistence.
