#include "bgfx_compute.sh"
#include "uniforms.sh"


BUFFER_RO(b_skinning_matrices_vb, vec4, 0);
//p3 t2 i4 w4 T4
BUFFER_RO(b_skinning_in_dynamic_vb, vec4, 1);
//p3 t2 T4
BUFFER_WR(b_skinning_out_dynamic_vb, vec4, 2);


vec4 mat2quatrow(in mat4 m)
{
	//mat4 m = transpose(mm);
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

void Skinning(inout vec3 pos, inout vec4 tan, in vec4 ind, in vec4 wei)
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
        mat4 m;
        m[0] = b_skinning_matrices_vb[id*4+0];
        m[1] = b_skinning_matrices_vb[id*4+1];
        m[2] = b_skinning_matrices_vb[id*4+2];
        m[3] = b_skinning_matrices_vb[id*4+3];
		float weight = wei[ii];

		wm += m * weight;
	}
    pos = mul(wm, vec4(pos, 1.0)).xyz;
    vec4 wm_tmp = mat2quatrow(wm);
    vec4 tan_tmp = tan;
    tan = convert2quat(wm_tmp, tan_tmp); 
}

NUM_THREADS(64, 1, 1)
void main()
{
    uint index = gl_GlobalInvocationID.x;

    vec3 pos = 0;
    {
        pos = b_skinning_in_dynamic_vb[index*5+0].xyz;
    }

    vec4 ind = 0;
    {
        ind = b_skinning_in_dynamic_vb[index*5+2];
    }

    vec4 wei = 0;
    {
        wei = b_skinning_in_dynamic_vb[index*5+3];
    }

    vec4 tan = 0;
    {
        tan = b_skinning_in_dynamic_vb[index*5+4];
    }

    Skinning(pos, tan, ind, wei);

    b_skinning_out_dynamic_vb[index*3+0] = vec4(pos, 0.0);
    b_skinning_out_dynamic_vb[index*3+1] = b_skinning_in_dynamic_vb[index*5+1];
    b_skinning_out_dynamic_vb[index*3+2] = tan;
}