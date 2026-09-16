# P1-E3 / P1-E4 Timeline touch completion scope

P1-E3 and P1-E4 finish the iPad touch-access portion of the existing Timeline without replacing its data model, selection model, transactions, or desktop behavior.

## P1-E3 — Timeline top toolbar touch layout

On iPadOS only:
- keep high-frequency actions directly visible and finger-sized: Add Frame, Delete Frame, Previous, Play Backwards, Play Forward, Next, Onion Skin, Loop, and FPS;
- use 44 pt direct targets, with a wider FPS control;
- move low-frequency Duplicate, Move Left, Move Right, First Frame, Last Frame, and Timeline Settings into one 44 pt `…` menu;
- keep the original Buttons alive and delegate menu actions to the existing `AnimationTimeline` handlers;
- keep E1 Select and E2 long-press reorder unchanged.

P1-E3 does not require a separate target-iPad manual gate. Static checks, automated contract tests, desktop regression builds, and the unsigned iOS build are sufficient for this stage; its layout is then covered again by the combined E4 target-device pass.

## P1-E4 — advanced Timeline features remain touch reachable

On iPadOS only:
- expose Frame Properties / Duration through the Timeline `…` menu by invoking the existing FrameButton context handler;
- expose New Tag, Import Tag, Reverse Frames, and Center Frames through the same existing FrameButton handler;
- expose Cel Properties, Link Cels, and Unlink Cels through the existing CelButton context handler;
- keep Onion Skin as a direct 44 pt action and keep its existing settings/rendering implementation;
- add direct Finger resize for both Animation Tag edges using a 22 px edge radius (44 pt total edge zone), frame snapping, the existing Tag preview geometry, and the existing `AnimationTagUI._resize_tag()` UndoRedo transaction;
- keep central Tag tap/edit behavior unchanged.

## Explicitly out of scope

- no new Timeline selection model;
- no changes to `Project.selected_cels` semantics;
- no second Frame/Cel reorder path;
- no new Frame duration data model;
- no new Linked Cel transaction;
- no Onion Skin algorithm/rendering changes;
- no Tag data transaction outside `AnimationTagUI._resize_tag()`;
- no desktop toolbar/layout changes;
- no Keyframe Timeline redesign.

## Merge gate

P1-E3/E4 may merge after CI is green and the combined P1-E4 target-iPad test cases pass. P1-E3 itself does not need an additional standalone device-test round.
