# P1-E2 implementation notes

P1-E2 extends the existing iOS-only `TimelineTouchSelectionManager` rather than creating a second gesture owner.

- Pre-ownership movement beyond 12 px remains native Timeline scrolling.
- A held touch acquires Frame/Cel reorder ownership at 450 ms when movement begins.
- Finger reorder builds the same payload as desktop drag, with a third payload field that explicitly disables Ctrl/Cmd-forced Swap.
- Cel cross-layer drag keeps the native cross-layer Swap rule; same-layer touch drag remains Move.
- Frame touch drag remains Move regardless of an external modifier key; desktop two-field payloads keep their existing modifier-driven Swap behavior.
- Native `_can_drop_data(pos, data)` and `_drop_data(pos, data)` remain the validation and transaction boundary. The adapter never creates UndoRedo actions.
- Native left/right placement consumes the passed local `pos`, so touch does not depend on mouse position.
- Horizontal edge auto-scroll applies to Frame and Cel reorder; vertical edge auto-scroll applies to Cel reorder. It continues from `_process(delta)` while the finger is stationary.
- Existing Timeline `drag_highlight` is reused, with an additive floating preview and dashed source outline.
- Invalid release and canceled touch do not call `_drop_data`.

P1-E3 toolbar work, Tag resize, Onion Skin changes, and Linked Cel behavior changes remain out of scope.
