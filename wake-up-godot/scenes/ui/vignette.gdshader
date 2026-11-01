shader_type canvas_item;

// Smooth radial vignette shader providing high contrast for edge UI elements.

uniform float inner_radius : hint_range(0.0, 1.0) = 0.35;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.05;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.7;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 1.4142;
	float factor = smoothstep(inner_radius, outer_radius, dist);
	COLOR = vec4(vignette_color.rgb, factor * vignette_opacity);
}
