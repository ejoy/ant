$input a_position, a_color0, a_texcoord0
$output v_VColor, v_UV1, v_PosP

#include <common.sh>

uniform mat4 u_cameraProj;
uniform mat4 u_Model;
uniform vec4 u_fUV;
uniform vec4 u_fModelColor;
uniform vec4 u_vsLightDirection;
uniform vec4 u_vsLightColor;
uniform vec4 u_vsLightAmbient;
uniform vec4 u_UVInversed;
void main()
{
    vec4 worldPos = mul(u_Model, vec4(a_position, 1.0));
    vec4 proj_pos = mul(u_cameraProj, worldPos);
    v_PosP = proj_pos;
    gl_Position = proj_pos;
    vec2 outputUV = a_texcoord0;
    vec4 uv = u_fUV;
    outputUV.x = (outputUV.x * uv.z) + uv.x;
    outputUV.y = (outputUV.y * uv.w) + uv.y;
    outputUV.y = u_UVInversed.x + (u_UVInversed.y * outputUV.y);
    v_UV1 = outputUV;
    v_VColor = u_fModelColor * a_color0;
}