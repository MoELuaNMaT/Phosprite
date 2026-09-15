# Phosprite iOS touch input system

This document records the iPad input contract implemented through P1-D2. The desktop tool model remains authoritative; iOS adds input arbitration and compact touch presentation without creating a second editing model.

## Input ownership

`CanvasInputAdapter` owns raw iOS canvas contacts. It identifies Pencil/direct touch, arbitrates one-finger content versus two-finger navigation, filters touch-generated mouse events only on the Canvas path, and forwards committed content through the existing left-tool event boundary.

P1-D1 keeps Primary/Secondary as the existing data model. Direct touch operates Primary unless a feature explicitly targets a color slot. The toolbar and normal GUI Controls continue to use ordinary GUI interaction; canvas input does not globally disable touch-to-mouse emulation.

## P1-D2 Selection family

On iOS, the seven selection tools are presented through one compact Selection family entry:

- ColorSelect
- EllipseSelect
- Lasso
- MagicWand
- PaintSelect
- PolygonSelect
- RectSelect

The existing `RectSelect` toolbar button is reused as the family entry so `Tools` still sees only its normal tool-button children. The other six buttons are hidden on iOS only. Desktop keeps the original seven-button layout unchanged.

A normal touch tap activates the most recently used Selection child. The default is `RectSelect`. The recent child is saved in the shared config cache and written to disk so it survives project changes and app restart.

A 450 ms long press opens a vertical `PopupMenu` to the right of the family entry. Choosing an item activates that tool in Primary and updates the persisted recent child. This presentation layer does not remove or replace the underlying seven tools.

## Rect / Ellipse Perfect Shape

Finger and Apple Pencil use the same touch rule:

1. Start and drag freely.
2. After the drag has begun, remaining within the existing D1 12 px acquisition slop for 1000 ms locks Perfect Shape.
3. Perfect Shape reuses the existing `_square` implementation, so the short side determines the 1:1 size.
4. The lock remains active until lift/cancel.
5. The timer is invalidated on release/cancel and cannot fire into a later contact.

The 1000 ms timer starts from the active drag path, not touch-down. This is intentionally separate from D1's 450 ms finger long-press color sampling arbitration.

## Polygon touch workflow

Polygon retains the existing selection geometry and desktop behavior. On iOS:

- Tap adds the next point through the existing draw start/end path.
- Tapping the first point closes and applies using the existing close rule.
- Two taps within 350 ms and the shared 12 px touch slop complete the polygon, matching desktop double-click intent without depending on a synthesized `double_click` flag.
- While a polygon is in progress, a 44 px-high `Cancel polygon` button is shown in the tool options and calls the existing `cancel_tool()` boundary.

## Selection modes

Replace, Add, Subtract and Intersect remain the existing `BaseSelectionTool` mode model. The existing `Modes` `OptionButton` is already a normal GUI Control and remains the explicit mobile selector. No parallel touch-only mode state is introduced.

## Transform workflow

Selection transform keeps the existing `TransformationHandles` implementation for move, scale, rotate, skew and pivot. Confirm/Cancel remain the existing BaseSelectionTool controls and commit/cancel boundaries. P1-D2 does not introduce a second transform implementation.

The iOS build must be acceptance-tested for handle acquisition and Confirm/Cancel because transform handles receive the normal global GUI/mouse stream rather than the Canvas adapter's drawing stream.

## Explicitly deferred

P1-D2 does not redesign Center, Displace Origin, Snap Axis, Snap Grid, Quick Copy, Duplicate, two-finger rotation, Palette/Layer/Timeline touch UI, or Primary/Secondary switching.
