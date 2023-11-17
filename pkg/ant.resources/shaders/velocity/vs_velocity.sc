#ifdef GPU_SKINNING
$input a_position a_indices a_weight v_cur_pos v_prev_pos
#else //!GPU_SKINNING
$input a_position v_cur_pos v_prev_pos
#endif //GPU_SKINNING

#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"

#ifdef GPU_SKINNING
	//TODO: put view projection matrix into 'u_prev_model' struct in CPU, and remove u_prev_vp
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
#ifdef GPU_SKINNING
    mat4 wm = calc_bone_transform(a_indices, a_weight);
#else
	mat4 wm = u_model[0];
#endif //
	highp vec4 posWS = mul(wm, vec4(a_position, 1.0));
	v_cur_pos = mul(u_viewProj, posWS);
	gl_Position = v_cur_pos;
	#ifdef TAA_FIRST_FRAME
		v_prev_pos = v_cur_pos;
	#else	//!TAA_FIRST_FRAME
		#ifdef GPU_SKINNING
			mediump mat4 prev_wm = calc_prev_bone_transform(a_indices, a_weight);
			highp vec4 prev_posWS = mul(prev_wm, vec4(a_position, 1.0));
			v_prev_pos = mul(u_prev_vp, prev_posWS);
		#else
			v_prev_pos = mul(u_prev_mvp, vec4(a_position, 1.0));
		#endif
	#endif	//TAA_FIRST_FRAME
}