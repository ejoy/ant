#include "common/inputs.sh"

$input 	a_position INPUT_INDICES INPUT_WEIGHT
$output v_prev_pos v_cur_pos

#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"

#ifdef GPU_SKINNING
	uniform mat4 u_prev_model[BGFX_CONFIG_MAX_BONES];
	uniform mat4 u_prev_vp;
	mat4 calc_prev_bone_transform(ivec4 indices, vec4 weights)
	{
		mat4 wolrdMat = mat4(
			0, 0, 0, 0, 
			0, 0, 0, 0, 
			0, 0, 0, 0, 
			0, 0, 0, 0
		);
		for (int ii = 0; ii < 4; ++ii)
		{
			int id = int(indices[ii]);
			float weight = weights[ii];

			wolrdMat += u_prev_model[id] * weight;
		}

		return wolrdMat;
	}
#else
	uniform mat4 u_prev_mvp;
#endif


void main()
{
    mediump mat4 wm = get_world_matrix();
	highp vec4 posWS = transformWS(wm, mediump vec4(a_position, 1.0));
	vec4 clipPos = mul(u_viewProj, posWS);
	v_cur_pos  = clipPos;
	gl_Position = clipPos;
	#ifdef TAA_FIRST_FRAME
		v_prev_pos = v_cur_pos;
	#else
		#ifdef GPU_SKINNING
			mediump mat4 prev_wm = calc_prev_bone_transform(a_indices, a_weight);
			highp vec4 prev_posWS = transformWS(prev_wm, mediump vec4(a_position, 1.0));
			v_prev_pos = mul(u_prev_vp, prev_posWS);
		#else
			v_prev_pos = mul(u_prev_mvp, vec4(a_position, 1.0));
		#endif
	#endif
}