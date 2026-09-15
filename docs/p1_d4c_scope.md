# P1-D4C scope

D4-C closes the Layer / Group touch-layout portion of P1-D.

In scope on iPadOS only:
- widen Layer row Visibility / Lock / Link / Expand touch slots to 44 pt while leaving row height under the existing Timeline cel-size preference;
- keep Add Layer and Delete Layer as direct actions;
- preserve Add Layer's existing split behavior, with two 44 pt halves for direct Pixel Layer creation and the existing layer-type popup;
- move low-frequency Move Up / Move Down / Duplicate / Merge Down / Layer Effects actions into one 44 pt Layer Actions menu;
- derive menu disabled states from the existing toolbar Buttons;
- delegate every action to the existing AnimationTimeline handlers.

Out of scope:
- Frame/Cel/Tag/Onion Skin behavior;
- touch multi-selection;
- Timeline redesign;
- new Layer business transactions;
- desktop toolbar changes.

D4-A and D4-B behavior must remain unchanged.
