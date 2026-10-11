shader_type canvas_item;
render_mode unshaded;

// SubViewportContainer draws the preview's completed render texture.
// Sample that texture directly instead of reading the screen back-buffer.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float brightness = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(vec3(brightness), pixel.a);
}
