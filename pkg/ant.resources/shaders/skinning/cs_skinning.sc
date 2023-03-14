#include "bgfx_compute.sh"
#include "uniforms.sh"


BUFFER_RO(b_skinning_matrices_vb, vec4, 0);
//p3 t2 i4 w4 T4
BUFFER_RO(b_skinning_in_dynamic_vb, vec4, 1);
//p3 t2 T4
BUFFER_WR(b_skinning_out_dynamic_vb, vec4, 2);

uniform float4 u_skinning_param;

vec4 mat2quat(in mat3 m)
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

mat3 quat2mat(in vec4 q)
{
	float x = q.y;float y = q.z;float z = q.w;float w = q.x;
	float x2 = x*x; float y2 = y*y; float z2 = z*z;
	float xy = x*y; float xz = x*z; float wx = w*x;
	float yz = y*z; float wy = w*y; float wz = w*z;
	vec3 m0 = vec3(1-2*y2-2*z2, 2*xy-2*wz, 2*xz+2*wy);
	vec3 m1 = vec3(2*xy+2*wz, 1-2*x2-2*z2, 2*yz-2*wx);
	vec3 m2 = vec3(2*xz-2*wy, 2*yz+2*wx, 1-2*x2-2*y2);
	return mat3(m0, m1, m2);
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

void Skinning(inout vec3 pos, inout vec4 tan, in vec4 ind, in vec4 wei, bool has_t)
{
    mat4 wm = mat4(
		0, 0, 0, 0, 
		0, 0, 0, 0, 
		0, 0, 0, 0, 
		0, 0, 0, 0
	);

	for (int ii = 0; ii < 4; ++ii)
	{
        int id = int(ind[ii]);
        mat4 m = mtxFromCols(b_skinning_matrices_vb[id*4+0], b_skinning_matrices_vb[id*4+1], b_skinning_matrices_vb[id*4+2], b_skinning_matrices_vb[id*4+3]);
		float weight = wei[ii];
		wm += m * weight;
	}
	wm[0][0] = 1;
	wm[1][1] = 1;
	wm[2][2] = 1;
    pos = mul(wm, vec4(pos, 1.0)).xyz;
  	if(has_t){
 		mat3 m3 = mtxFromCols(wm[0].xyz, wm[1].xyz, wm[2].xyz);
		vec4 wm_tmp = mat2quat(m3);
 		vec4 tan_tmp = tan;
		tan = convert2quat(wm_tmp, tan_tmp);  
	}  
}

NUM_THREADS(64, 1, 1)
void main()
{
    uint index = gl_GlobalInvocationID.x;
	uint stride_input = u_skinning_param.x;
	uint stride_output = u_skinning_param.y;
    vec3 pos = b_skinning_in_dynamic_vb[index*stride_input+0].xyz;
	bool has_t = false;
	vec4 tan = 0;

	if(stride_output > 1)
	{
		tan = b_skinning_in_dynamic_vb[index*stride_input+1];
		has_t = true;
	}
    vec4 ind = b_skinning_in_dynamic_vb[index*stride_input+stride_output];
	vec4 wei = b_skinning_in_dynamic_vb[index*stride_input+stride_output+1];

    Skinning(pos, tan, ind, wei, has_t);
    b_skinning_out_dynamic_vb[index*stride_output+0] = vec4(pos, 0.0);

	int ii = 1;
	if(has_t){
		b_skinning_out_dynamic_vb[index*stride_output+1] = tan;
		ii = 2;
	}
	for(; ii < stride_output; ++ii)
	{
		b_skinning_out_dynamic_vb[index*stride_output+ii] = b_skinning_in_dynamic_vb[index*stride_input+ii];
	}
}