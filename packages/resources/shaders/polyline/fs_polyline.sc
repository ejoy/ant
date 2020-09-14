$input v_color, v_texcoord0

//v_texcoord0: xy for uv, z for line counter

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"

SAMPLER2D(s_tex,        0);
SAMPLER2D(s_alphatex,   1);

void main() {
    vec4 c  = v_color;
    vec2 uv = v_texcoord0.xy * u_repeat;
    if(u_use_tex == 1.0 ) {
        c *= texture2D(s_tex, uv);
    }

    if(u_use_alphatex == 1.0){
        c.a *= texture2D(s_alphatex, uv).a;
    }

    if(c.a < u_alphatest)
        discard;

    float v_counters = v_texcoord0.z;
    if(u_use_dash == 1.0){
        c.a *= ceil(mod(v_counters + u_dash_offset, u_dash_array) - (u_dash_array * u_dash_ratio));
    }

    gl_FragColor = c;
    gl_FragColor.a *= step(v_counters, u_visible);

}