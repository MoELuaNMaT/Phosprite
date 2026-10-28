shader_type texture_blit;
render_mode blend_disabled;

// Keep the source pixels unchanged. Only transparent pixels adjacent to
// opaque pixels receive the generated outline. The layer effect is evaluated
// again whenever the source cel changes, so erased edges never leave residue.
uniform sampler2D source_texture0 : hint_blit_source0, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int outline_width : hint_range(1, 4, 1) = 1;
uniform bool include_diagonals = false;

void blit() {
    vec4 source_color = texture(source_texture0, UV);
    if (source_color.a > 0.0001) {
        COLOR0 = source_color;
        return;
    }

    ivec2 dimensions = textureSize(source_texture0, 0);
    ivec2 pixel = clamp(ivec2(UV * vec2(dimensions)), ivec2(0), dimensions - ivec2(1));
    bool adjacent_to_shape = false;
    for (int y = -4; y <= 4; y++) {
        for (int x = -4; x <= 4; x++) {
            if (x == 0 && y == 0) {
                continue;
            }
            if (include_diagonals) {
                if (max(abs(x), abs(y)) > outline_width) {
                    continue;
                }
            } else if (abs(x) + abs(y) > outline_width) {
                continue;
            }
            ivec2 neighbor = pixel + ivec2(x, y);
            if (neighbor.x < 0 || neighbor.y < 0 ||
                    neighbor.x >= dimensions.x || neighbor.y >= dimensions.y) {
                continue;
            }
            if (texelFetch(source_texture0, neighbor, 0).a > 0.0001) {
                adjacent_to_shape = true;
                break;
            }
        }
        if (adjacent_to_shape) {
            break;
        }
    }
    COLOR0 = adjacent_to_shape ? outline_color : source_color;
}
