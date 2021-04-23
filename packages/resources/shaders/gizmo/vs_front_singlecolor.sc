$input a_position
#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
    gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
    vec4 origin = mul(u_modelViewProj,vec4(0.0,0.0,0.0,1.0));
    if((gl_Position.z+gl_Position.w)/gl_Position.w > (origin.z+origin.w)*1.0001/origin.w)
        gl_Position.z = gl_Position.w+1;
}