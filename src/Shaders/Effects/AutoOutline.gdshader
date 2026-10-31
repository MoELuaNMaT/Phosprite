shader_type texture_blit;
render_mode blend_disabled;

// Auto Outline's live pixel expansion is evaluated by AutoOutlineRenderer.
// Keep this resource as a valid identity and safe pass-through for effect
// persistence, and never risk a failed GPU shader replacing the whole canvas.
uniform sampler2D source_texture0 : hint_blit_source0, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int outline_width : hint_range(1, 4, 1) = 1;
uniform bool include_diagonals = false;

void blit() {
    COLOR0 = texture(source_texture0, UV);
}
