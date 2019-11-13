$input a_position, a_normal, a_texcoord0, a_texcoord1, a_weight, a_indices
$output v_posWS, v_normal, v_texcoord0, v_texcoord1
//#version 450

// layout (location = 0) in vec3 inPos;
// layout (location = 1) in vec3 inNormal;
// layout (location = 2) in vec2 inUV0;
// layout (location = 3) in vec2 inUV1;
// layout (location = 4) in vec4 inJoint0;
// layout (location = 5) in vec4 inWeight0;

// layout (set = 0, binding = 0) uniform UBO 
// {
// 	mat4 projection;
// 	mat4 model;
// 	mat4 view;
// 	vec3 camPos;
// } ubo;

// #ifdef ENABLE_ANIMATION
// #define MAX_NUM_JOINTS 128
// #endif //ENABLE_ANIMATION

// layout (set = 2, binding = 0) uniform UBONode {
// 	mat4 matrix;
// 	mat4 jointMatrix[MAX_NUM_JOINTS];
// 	float jointCount;
// } node;

// layout (location = 0) out vec3 outWorldPos;
// layout (location = 1) out vec3 outNormal;
// layout (location = 2) out vec2 outUV0;
// layout (location = 3) out vec2 outUV1;

// out gl_PerVertex
// {
// 	vec4 gl_Position;
// };

void main() 
{
	vec4	locPos = mul(u_model[0], vec4(inPos, 1.0));
	v_normal = normalize(mul(transpose(inverse(mat3(u_model[0]))), a_normal));

	v_posWS = locPos;
	v_texcoord0 = a_texcoord0;
    v_texcoord1 = a_texcoord1;

	gl_Position = mul(u_viewProj, vec4(outWorldPos, 1.0);
}
