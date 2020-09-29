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
    float z = (u_near * u_far) / (depth * (u_near - u_far) + u_far);
    float x = xy.x * z / u_near;
    float y = xy.y * z / u_near;

    return vec3(x, y, z);
}

void main() {
    vec2 tex_size   = textureSize(s_mainview, 0).xy;
    vec2 uv         = gl_FragCoord.xy / tex_size;

    vec4 focus      = texture2D(s_mainview,       uv);
    float depth     = texture2D(s_mainview_depth, uv);

    vec3 pos        = reconstruct_3dpoint(gl_FragCoord.xy, depth);

    vec4 outfocus   = texture2D(s_outfocus, uv);

    float blur      = smoothstep(u_distance_range.x, u_distance_range.y, length(pos - u_focuspoint.xyz));

    gl_FragColor    = mix(focus, outfocus, blur);
}
