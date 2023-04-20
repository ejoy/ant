#include "common/inputs.sh"
$input a_position INPUT_INDICES INPUT_WEIGHT INPUT_INSTANCE

#include <bgfx_shader.sh>
#include "common/transform.sh"


void main()
{
#ifdef CS_SKINNING
	mat4 wm = u_model[0];
#else //!CS_SKINNING
	mat4 wm = get_world_matrix();
#endif //CS_SKINNING

#ifdef HEAP_MESH
	wm[0][3] = wm[0][3] + i_data0.x;
	wm[1][3] = wm[1][3] + i_data0.y;
	wm[2][3] = wm[2][3] + i_data0.z;
#endif //HEAP_MESH

#ifdef STONE_MOUNTAIN
	float scale = i_data0.x;
	float scale_y = scale;
	float tx = i_data0.y;
	float tz = i_data0.z;
	float cosy = i_data0.w;
	float scosy = cosy * scale;
	float ssiny = sqrt(1 - cosy*cosy) * scale;
 	if(scale_y > 1){
		scale_y = scale_y * 0.5;
	}
 	wm = mat4(
		scosy,            0,     -ssiny,       tx, 
		0    ,      scale_y,          0,        0, 
	    ssiny,            0,      scosy,       tz, 
		0    ,            0,          0,        1
	);	 		 
#endif //STONE_MOUNTAIN

	highp vec4 posWS = transformWS(wm, mediump vec4(a_position, 1.0));
	gl_Position   = mul(u_viewProj, posWS);	
}