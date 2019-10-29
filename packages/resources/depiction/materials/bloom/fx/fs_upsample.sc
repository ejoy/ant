$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/postprocess.sh"

uniform vec4 u_intensity;

void main()
{
#ifdef MULTI_SAMPLE_BLOOM
	vec2 half_view_texel = u_viewTexel.xy * 0.5;
	vec4 sum = vec4_splat(0.0);

	sum += (1.0 /  8.0) * texture2D(s_postprocess_input, v_texcoord0 + vec2(-half_view_texel.x,  0.0) );
	sum += (1.0 /  8.0) * texture2D(s_postprocess_input, v_texcoord0 + vec2( 0.0,                half_view_texel.y) );
	sum += (1.0 /  8.0) * texture2D(s_postprocess_input, v_texcoord0 + vec2( half_view_texel.x,  0.0) );
	sum += (1.0 /  8.0) * texture2D(s_postprocess_input, v_texcoord0 + vec2( 0.0,               -half_view_texel.y) );

	sum += (1.0 / 16.0) * texture2D(s_postprocess_input, v_texcoord0 + vec2(-half_view_texel.x, -half_view_texel.y) );
	sum += (1.0 / 16.0) * texture2D(s_postprocess_input, v_texcoord0 + vec2(-half_view_texel.x,  half_view_texel.y) );
	sum += (1.0 / 16.0) * texture2D(s_postprocess_input, v_texcoord0 + vec2( half_view_texel.x, -half_view_texel.y) );
	sum += (1.0 / 16.0) * texture2D(s_postprocess_input, v_texcoord0 + vec2( half_view_texel.x,  half_view_texel.y) );

	sum += (1.0 /  4.0) * texture2D(s_postprocess_input, v_texcoord0);

	gl_FragColor = u_intensity.x * sum;
#else
    gl_FragColor = u_intensity.x * texture2D(s_postprocess_input, v_texcoord0);
#endif 
}