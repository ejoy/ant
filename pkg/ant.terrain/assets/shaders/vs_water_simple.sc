$input a_position a_texcoord0
$output v_posCS v_distortUV v_noiseUV
#include <bgfx_shader.sh>

uniform vec4 u_distort_scale_bais;
uniform vec4 u_noise_scale_bais;

vec2 uv_scale_bais(vec2 uv, vec4 t)
{
    return uv * t.xy + t.zw;
}

void main()
{
    v_posCS = mul(u_modelViewProj, vec4(a_position, 1.0));
    gl_Position = v_posCS;

    v_distortUV = uv_scale_bais(a_texcoord0, u_distort_scale_bais);
    v_noiseUV   = uv_scale_bais(a_texcoord0, u_noise_scale_bais);
}