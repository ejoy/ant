$input v_color, v_texcoord0

//v_texcoord0: xy for uv, z for line counter

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"

SAMPLER2D(s_tex, 0);

void main() {
    vec4 c  = v_color;

    if(u_tex_enable == 1.0 ) {
        vec2 uv = v_uv * u_repeat;
        c *= texture2D(s_tex, uv);
        if(c.a <= u_alphaRef)
            discard;
    }

    if(u_dash_enable == 1.0){
        //c.a *= ceil(mod(v_counters + u_dash_offset, u_dash_array) - (u_dash_array * u_dash_ratio));
        float dash = mod(v_counters, u_dash_round);
        c.a *= step(dash, u_dash_ratio);

        if(c.a <= u_alphaRef)
            discard;
    }

    gl_FragColor = c;
}