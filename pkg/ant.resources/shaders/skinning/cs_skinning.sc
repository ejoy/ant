#include "bgfx_compute.sh"
#include "uniforms.sh"


BUFFER_RO(b_skinning_matrices_vb, vec4, 0);

// p i w [T] t/c
BUFFER_RO(b_skinning_in_dynamic_vb, vec4, 1);
// p [T] t/c
BUFFER_WR(b_skinning_out_dynamic_vb, vec4, 2);

uniform float4 u_skinning_param;

vec4 mat2quat(in mat4 m)
{
	float m11 = m[0][0];float m12 = m[1][0]; float m13 = m[2][0];
	float m21 = m[0][1];float m22 = m[1][1]; float m23 = m[2][1];
	float m31 = m[0][2];float m32 = m[1][2]; float m33 = m[2][2];

	float fourXSquaredMinus1 = m11 - m22 - m33;
	float fourYSquaredMinus1 = m22 - m11 - m33;
	float fourZSquaredMinus1 = m33 - m11 - m22;
	float fourWSquaredMinus1 = m11 + m22 + m33;  
    
	int biggestIndex = 0;
	float fourBiggestSquaredMinus1 = fourWSquaredMinus1;
	if(fourXSquaredMinus1 > fourBiggestSquaredMinus1)
	{
		fourBiggestSquaredMinus1 = fourXSquaredMinus1;
		biggestIndex = 1;
	}
	if(fourYSquaredMinus1 > fourBiggestSquaredMinus1)
	{
		fourBiggestSquaredMinus1 = fourYSquaredMinus1;
		biggestIndex = 2;
	}
	if(fourZSquaredMinus1 > fourBiggestSquaredMinus1)
	{
		fourBiggestSquaredMinus1 = fourZSquaredMinus1;
		biggestIndex = 3;
	}

	float biggestVal = sqrt(fourBiggestSquaredMinus1 + 1) * 0.5;
	float mult = 0.25 / biggestVal;

	switch(biggestIndex)
	{
	    case 0:
		    return vec4(biggestVal, (m23 - m32) * mult, (m31 - m13) * mult, (m12 - m21) * mult);
	    case 1:
			return vec4((m23 - m32) * mult, biggestVal, (m12 + m21) * mult, (m31 + m13) * mult);
		case 2:
			return vec4((m31 - m13) * mult, (m12 + m21) * mult, biggestVal, (m23 + m32) * mult);
		case 3:
			return vec4((m12 - m21) * mult, (m31 + m13) * mult, (m23 + m32) * mult, biggestVal);
		default: // Silence a -Wswitch-default warning in GCC. Should never actually get here. Assert is just for sanity.
			return vec4(1, 0, 0, 0);
	}
}

vec4 convert2quat(vec4 wm, vec4 tan)
{
    vec4 p = wm;
    vec4 q = vec4(tan.w, tan.x, tan.y, tan.z);
    return vec4(
        p[0]*q[1]+p[1]*q[0]+p[2]*q[3]-p[3]*q[2],
        p[0]*q[2]+p[2]*q[0]+p[3]*q[1]-p[1]*q[3],
        p[0]*q[3]+p[3]*q[0]+p[1]*q[2]-p[2]*q[1],
        p[0]*q[0]-p[1]*q[1]-p[2]*q[2]-p[3]*q[3]
    );
}

void transform_attributes_to_world(mat4 wm, inout vec3 pos, inout vec4 tan, bool has_tangent)
{
    pos = mul(wm, vec4(pos, 1.0)).xyz;
  	if(has_tangent){
		vec4 quat_wm  = mat2quat(wm);
 		vec4 quat_tan = tan;
		tan = convert2quat(quat_wm, quat_tan);  
	}  
}

mat4 get_skinning_matrix(in vec4 index, in vec4 weight)
{
    mat4 wm = mat4(
		0, 0, 0, 0, 
		0, 0, 0, 0, 
		0, 0, 0, 0, 
		0, 0, 0, 0
	);

	for (int ii = 0; ii < 4; ++ii)
	{
        int id = int(index[ii]);
        mat4 m = mtxFromCols(b_skinning_matrices_vb[id*4+0], b_skinning_matrices_vb[id*4+1], b_skinning_matrices_vb[id*4+2], b_skinning_matrices_vb[id*4+3]);
		float wei = weight[ii];
		wm += m * wei;
	}
	return wm;
}

NUM_THREADS(64, 1, 1)
void main()
{
    uint vi = gl_GlobalInvocationID.x;
	uint stride_input  = u_skinning_param.x;
	uint stride_output = u_skinning_param.y;
	bool has_tangent   = u_skinning_param.z;

    vec3 pos = b_skinning_in_dynamic_vb[vi*stride_input].xyz;
    vec4 index  = b_skinning_in_dynamic_vb[vi*stride_input+1];
	vec4 weight = b_skinning_in_dynamic_vb[vi*stride_input+2];

	vec4 tan = 0;
	if(has_tangent){
		tan = b_skinning_in_dynamic_vb[vi*stride_input+3];
	}

    mat4 wm = get_skinning_matrix(index, weight);

	transform_attributes_to_world(wm, pos, tan, has_tangent);

    b_skinning_out_dynamic_vb[vi*stride_output] = vec4(pos, 0.0);

	int ii = 1;
	if(has_tangent){
		b_skinning_out_dynamic_vb[vi*stride_output+1] = tan;
		ii = 2;
	}
	for(; ii < stride_output; ++ii)
	{
		b_skinning_out_dynamic_vb[vi*stride_output+ii] = b_skinning_in_dynamic_vb[vi*stride_input+ii+2];
	}
}