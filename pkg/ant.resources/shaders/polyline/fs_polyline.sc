#include "polyline/input.sh"

$input v_texcoord0 MASK_UV VELOCITY_CUR_POS VELOCITY_PREV_POS

//v_texcoord0: xy for uv, z for line counter

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"
#include "common/uvmotion.sh"
#ifdef ENABLE_POLYLINE_TEXTURE
SAMPLER2D(s_tex, 0);
#endif //ENABLE_POLYLINE_TEXTURE
#ifdef ENABLE_POLYLINE_EMISSIVE_TEXTURE
SAMPLER2D(s_emissive, 1);
uniform vec4 u_emissive_factor;
#endif //ENABLE_POLYLINE_EMISSIVE_TEXTURE

#ifdef ENABLE_POLYLINE_MASK
SAMPLER2D(s_mask, 2);
#endif //ENABLE_POLYLINE_MASK

float2 CalcVelocity(float4 newPos, float4 oldPos, float2 viewSize)
{
    oldPos /= oldPos.w;
    oldPos.xy = (oldPos.xy+1)/2.0f;
    oldPos.y = 1 - oldPos.y;
    
    newPos /= newPos.w;
    newPos.xy = (newPos.xy+1)/2.0f;
    newPos.y = 1 - newPos.y;
    
    return (newPos - oldPos).xy;
}


void main() {
    #ifdef ENABLE_TAA
        gl_FragColor = vec4(CalcVelocity(v_cur_pos, v_prev_pos, u_viewRect.zw), 0, 0);
    #else
        vec4 c  = u_color;

        vec2 uv = uv_motion(v_uv);
    #ifdef ENABLE_POLYLINE_TEXTURE
        c *= texture2D(s_tex, uv);
    #endif //POLYLINE_TEXTURE

    #ifdef ENABLE_POLYLINE_EMISSIVE_TEXTURE
        c += texture2D(s_emissive, uv) * u_emissive_factor;
    #endif //ENABLE_POLYLINE_EMISSIVE_TEXTURE

    #ifdef ENABLE_POLYLINE_DASH
        //c.a *= ceil(mod(v_counters + u_dash_offset, u_dash_array) - (u_dash_array * u_dash_ratio));
        float dash = mod(v_counters, u_dash_round);
        c.a *= step(dash, u_dash_ratio);
    #endif //ENABLE_POLYLINE_DASH

    #ifdef ENABLE_POLYLINE_MASK
        c.a *= texture2D(s_mask, MASK_UV).r;
    #endif //ENABLE_POLYLINE_MASK

        gl_FragColor = c;
    #endif
}