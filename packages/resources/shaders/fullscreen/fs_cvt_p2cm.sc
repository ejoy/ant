$input v_texcoord0
#include <bgfx_shader.sh>
SAMPLER2D(s_tex, 0);
uniform vec4 u_param;
#define u_faceidx u_param.x

vec3 uvToXYZ(int face, vec2 uv)
{
	if(face == 0)
		return vec3(     1.0,   uv.y,    -uv.x);

	else if(face == 1)
		return vec3(    -1.0,   uv.y,     uv.x);

	else if(face == 2)
		return vec3(   +uv.x,    1.0,    -uv.y);

	else if(face == 3)
		return vec3(   +uv.x,   -1.0,    +uv.y);

	else if(face == 4)
		return vec3(   +uv.x,   uv.y,      1.0);

	else //if(face == 5)
	{	return vec3(    -uv.x,  +uv.y,    -1.0);}
}

vec2 dirToUV(vec3 dir)
{
	return vec2(
		0.5 + 0.5 * atan2(dir.z, dir.x) / M_PI,
		acos(dir.y) / M_PI);
}

void main()
{
	vec2 uv = v_texcoord0*2.0-1.0;
	vec3 scan = uvToXYZ(int(u_faceidx), uv);
	vec3 direction = normalize(scan);
	vec2 src = dirToUV(direction);

	gl_FragColor = texture2D(s_tex, src);
}

// void main()
// {
//     int faceidx = int(u_param.x);
//     vec4 colors[6] = {
//         vec4(1.0, 0.0, 0.0, 1.0),
//         vec4(0.0, 1.0, 0.0, 1.0),
//         vec4(0.0, 0.0, 1.0, 1.0),
//         vec4(1.0, 0.0, 1.0, 1.0),
//         vec4(1.0, 1.0, 1.0, 1.0),
//         vec4(0.0, 1.0, 1.0, 1.0),
//     };
//     gl_FragColor = texture2D(s_tex, v_texcoord0) + colors[faceidx];
// }