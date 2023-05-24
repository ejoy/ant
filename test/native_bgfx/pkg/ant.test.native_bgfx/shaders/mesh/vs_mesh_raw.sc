

#version 450
layout(location = 0) in vec3 a_position;

// Uniform buffer containing an MVP matrix.
// Currently the vulkan backend only sets the rotation matix
// required to handle device rotation.
layout(binding = 0) uniform UniformBufferObject {
    mat4 MVP;
} ubo;

void main()
{
    vec3 pos = a_position;
	gl_Position = ubo.MVP * vec4(pos, 1.0);
}