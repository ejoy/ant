$input v_texcoord0
#include <bgfx_shader.sh>

#include "common/postprocess.sh"

SAMPLER2D(s_outfocus,   0);

uniform vec4 u_focuspoint;
uniform vec4 u_distance_range;
#define u_near          u_distance_range.x
#define u_far           u_distance_range.y
#define u_min_distance  u_distance_range.z
#define u_max_distance  u_distance_range.w

vec3 reconstruct_3dpoint(vec2 xy, float depth){
    float x = xy.x * 2.0 - 1.0;
    float y = (1.0 - xy.y) * 2.0 - 1.0;

    vec4 p = mul(u_invViewProj, vec4(x, y, depth, 1.0));
    p /= p.w;
    return p.xyz;
}

void main() {
    vec4 focus      = texture2D(s_mainview,       v_texcoord0);
    float depth     = texture2D(s_mainview_depth, v_texcoord0).r;

    vec3 pos        = reconstruct_3dpoint(v_texcoord0, depth);

    vec4 outfocus   = texture2D(s_outfocus, v_texcoord0);

    float blur      = smoothstep(u_min_distance, u_max_distance, length(pos - u_focuspoint.xyz));

    gl_FragColor    = mix(focus, outfocus, blur);
}
