#include "common/inputs.sh"
#ifdef USING_LIGHTMAP
DEF_SKINNING_INPUTS2(a_texcoord0, a_texcoord1)
$output v_texcoord0, v_texcoord1
#else //!USING_LIGHTMAP
DEF_SKINNING_INPUTS3(a_normal, a_tangent, a_texcoord0)
$output v_texcoord0, v_posWS, v_normal, v_tangent, v_bitangent
#endif //USING_LIGHTMAP

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
#ifdef BAKING_LIGHTMAP
	mat4 wm = u_model[0];
#else //!BAKING_LIGHTMAP
	mat4 wm = get_world_matrix();
#endif //BAKING_LIGHTMAP

	v_posWS = mul(wm, vec4(a_position, 1.0));
	gl_Position   = mul(u_viewProj, v_posWS);
#if !defined(BAKING_LIGHTMAP) &&	defined(ENABLE_SHADOW)
	v_posWS.w = mul(u_view, v_posWS).z;
#endif //ENABLE_SHADOW

	v_texcoord0	= a_texcoord0;
#ifdef USING_LIGHTMAP
	v_texcoord1 = a_texcoord1;
#else //!USING_LIGHTMAP
	//TODO: normal and tangent should use inverse transpose matrix
	v_normal	= normalize(mul(wm, vec4(a_normal, 0.0)).xyz);
	v_tangent	= normalize(mul(wm, vec4(a_tangent, 0.0)).xyz);
	v_bitangent	= cross(v_normal, v_tangent);	//left hand
#endif //USING_LIGHTMAP
}