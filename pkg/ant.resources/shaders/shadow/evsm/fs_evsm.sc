#include <bgfx_shader.sh>
$input v_texcoord0

// #ifdef SM_DEPTH_FORMAT16
// #define MAX_EXPONENT 5.54
// #else //!SM_DEPTH_FORMAT16
// #define MAX_EXPONENT 42
// #endif //SM_DEPTH_FORMAT16

uniform vec4 u_evsm_param;

// Clamp to maximum range of fp32/fp16 to prevent overflow/underflow
//MAX_EXPONENT

#define u_evsm_exponents u_evsm_param.xy

void main()
{
    vec2 exponent = get_exponents();
    float depth = v_texcoord0.x;
    return vec2(depth, depth*depth);
}