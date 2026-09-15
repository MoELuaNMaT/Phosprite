# P1-D3 Scope Freeze

P1-D3 closes Palette / color touch UX on iPad without replacing Pixelorama's existing Primary/Secondary, Palette, Undo, or indexed-color models.

## In scope

- Direct touch Palette selection uses `Tools.picking_color_for` to address Primary or Secondary.
- Empty swatch fill, Add Color, and Delete Color reuse the existing PalettePanel transaction paths.
- Non-empty swatch double-tap reuses the existing swatch edit popup path.
- Palette reorder uses a deliberate long-hold then drag and reuses the existing dropped-swatch transaction.
- Normal drag before long-hold remains available to the ScrollContainer as scrolling.
- Fresh iPad swatch default is 32×32 unless the user already saved a swatch-size preference.
- Palette toolbar controls receive an iPad-only 44 pt minimum touch target.
- Synthetic touch mouse activation is suppressed for direct-touch-owned Palette controls and restored for real pointer input.
- Mouse/trackpad left/right semantics remain unchanged.

## Out of scope

- Layer / Group / Timeline redesign.
- Tool Primary/Secondary assignment redesign.
- Palette file-format changes or Palette model refactors.
- Final visual redesign of the Palette panel.
- Replacing desktop modifier behaviors with new mobile-only menus.
