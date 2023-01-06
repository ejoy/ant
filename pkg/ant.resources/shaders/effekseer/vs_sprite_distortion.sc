$input a_position, a_color0, a_normal, a_tangent, a_texcoord0, a_texcoord1
$output v_vspos, v_texcoord0, v_binormal, v_tangent, v_ppos, v_color0

#include <common.sh>

//uniform mat4 u_camera;
uniform mat4 u_cameraProj;
uniform vec4 u_UVInversed;
uniform vec4 u_vsFlipbookParameter;

void main()
{
    vec4 worldNormal = vec4((a_normal.xyz - vec3(0.5)) * 2.0, 0.0);
    vec4 worldTangent = vec4((a_tangent.xyz - vec3(0.5)) * 2.0, 0.0);
    vec4 worldBinormal = vec4(cross(worldNormal.xyz, worldTangent.xyz), 0.0);
    vec4 worldPos = vec4(a_position, 1.0);
    vec4 PosVS = mul(u_cameraProj, worldPos);
    v_tangent = mul(u_cameraProj, (worldPos + worldTangent));
    v_binormal = mul(u_cameraProj, (worldPos + worldBinormal));
    v_vspos = PosVS;
    v_ppos = PosVS;
    v_color0 = a_color0;
    vec2 uv1 = a_texcoord0;
    uv1.y = u_UVInversed.x + (u_UVInversed.y * uv1.y);
    v_texcoord0 = uv1;
    gl_Position = PosVS;
}