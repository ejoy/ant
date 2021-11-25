$input v_color, v_texcoord0

//v_texcoord0: xy for uv, z for line counter

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"

#ifdef POLYLINE_TEXTURE
SAMPLER2D(s_tex, 0);
#endif //POLYLINE_TEXTURE

void main() {
    vec4 c  = v_color;

#ifdef ENABLE_POLYLINE_TEXTURE
    vec2 uv = v_uv * u_repeat;
    c *= texture2D(s_tex, uv);
#endif //POLYLINE_TEXTURE

#ifdef ENABLE_POLYLINE_DASH
    //c.a *= ceil(mod(v_counters + u_dash_offset, u_dash_array) - (u_dash_array * u_dash_ratio));
    float dash = mod(v_counters, u_dash_round);
    c.a *= step(dash, u_dash_ratio);
#endif //ENABLE_POLYLINE_DASH

    if(c.a <= u_alphaRef)
        discard;

    gl_FragColor = c;
}