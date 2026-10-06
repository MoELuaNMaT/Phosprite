shader_type canvas_item;
render_mode unshaded;

uniform bool enabled = false;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (enabled) {
		float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
		color.rgb = vec3(luminance);
	}
	COLOR = color;
}
