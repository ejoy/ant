#include "bgfx_compute.sh"

BUFFER_RO(b_skinning_matrices_vb, vec4, 0);

// p i w [T] t/c
BUFFER_RO(b_skinning_in_dynamic_vb, vec4, 1);
// p [T] t/c
BUFFER_WO(b_skinning_out_dynamic_vb, vec4, 2);

struct attrib_input{
	vec3 pos;
	uvec4 indices;
	vec4 weights;
	vec4 tangent;
	vec3 normal;
	bool hastangent;
	bool hasnormal;
	bool is_tangentframe;
};

uniform vec4 u_attrib_indices[3];
uniform vec4 u_skinning_param;
#define u_vertex_count u_skinning_param.x

#define u_attrib_pos		u_attrib_indices[0].x
#define u_attrib_index		u_attrib_indices[0].y
#define u_attrib_weight		u_attrib_indices[0].z
#define u_attrib_tangent	u_attrib_indices[0].w
#define u_attrib_normal		u_attrib_indices[1].z

#define ATTRIB_OFFSET		5
#define ATTRIB_COUNT		(3*4)

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

void transform_attributes_to_world(mat4 wm, inout attrib_input ai)
{
	ai.pos = mul(wm, vec4(ai.pos, 1.0)).xyz;
	if (ai.is_tangentframe)
	{
		ai.tangent = convert2quat(mat2quat(wm), ai.tangent);
	}
	else
	{
		if (ai.hastangent)
		{
			ai.tangent = vec4(mul(wm, vec4(ai.tangent.xyz, 0.0)).xyz, ai.tangent.w);
		}

		if (ai.hasnormal)
		{
			ai.normal = mul(wm, vec4(ai.normal, 0.0)).xyz;
		}
	}
}

mat4 get_skinning_matrix(in uvec4 index, in vec4 weight)
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
		wm += m * weight[ii];
	}
	return wm;
}

uint input_attrib_num()
{
	float s = 0;
	for (int i=0; i<3; ++i)
	{
		bvec4 b = u_attrib_indices[i] >= 0.0;
		s += dot(b, vec4_splat(1.0));
	}

	return (uint)s;
}

attrib_input load_attrib_input(uint offset)
{
	attrib_input ai;
	ai.pos = b_skinning_in_dynamic_vb[offset+u_attrib_pos].xyz;
	vec4 indices = b_skinning_in_dynamic_vb[offset+u_attrib_index];
	//TODO: we assume indices is always uint16 and pack as float
	ai.indices = uvec4(indices * 65535.0);
	ai.weights = b_skinning_in_dynamic_vb[offset+u_attrib_weight];

	ai.hastangent		= u_attrib_tangent >= 0;
	ai.hasnormal		= u_attrib_normal >= 0;
	ai.is_tangentframe	= !ai.hasnormal && ai.hastangent;

	ai.tangent = ai.hastangent ? b_skinning_in_dynamic_vb[offset+u_attrib_tangent] : vec4_splat(0);
	ai.normal  = ai.hasnormal ? b_skinning_in_dynamic_vb[offset+u_attrib_normal].xyz : vec3_splat(0);
	return ai;
}

int find_next_attrib_index(int startidx)
{
	for(; startidx<ATTRIB_COUNT; ++startidx)
	{
		int vidx = startidx / 4;
		int sidx = startidx % 4;
		float aidx = u_attrib_indices[vidx][sidx];
		if (aidx >= 0)
		{
			return (int)aidx;
		}
	}

	return -1;
}

NUM_THREADS(64, 1, 1)
void main()
{
    uint vi = gl_GlobalInvocationID.x;
	if (vi >= u_vertex_count)
	{
		return ;
	}

	uint input_num	= input_attrib_num();
	uint output_num	= input_num - 2;

	uint input_offset = vi*input_num;
	uint output_offset= vi*output_num;

	attrib_input ai = load_attrib_input(input_offset);

    mat4 wm = get_skinning_matrix(ai.indices, ai.weights);

	transform_attributes_to_world(wm, ai);

	int ii = 0;
	b_skinning_out_dynamic_vb[output_offset+ii] = vec4(ai.pos, 0.0); ++ii;

	if(ai.hastangent)
	{
		b_skinning_out_dynamic_vb[output_offset+ii] = ai.tangent; ++ii;
	}

	if (ai.hasnormal)
	{
		b_skinning_out_dynamic_vb[output_offset+ii] = vec4(ai.normal, 0.0); ++ii;
	}

	int next_attrib_idx = ATTRIB_OFFSET;

	for(; ii < output_num; ++ii)
	{
		int aidx = find_next_attrib_index(next_attrib_idx);
		if (aidx < 0)
			break;

		b_skinning_out_dynamic_vb[output_offset+ii] = b_skinning_in_dynamic_vb[input_offset+aidx];

		next_attrib_idx = aidx + 1;
	}
}