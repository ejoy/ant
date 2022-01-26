#include <bgfx_compute.sh>

SAMPLER2D(s_source, 0);
IMAGE2D_ARRAY_WR(s_cubemap_source, rgba16f, 1);

vec3 uvToXYZ(int face, vec2 uv)
{
	if(face == 0)
		return vec3(     1.f,   uv.y,    -uv.x);

	else if(face == 1)
		return vec3(    -1.f,   uv.y,     uv.x);

	else if(face == 2)
		return vec3(   +uv.x,   -1.f,    +uv.y);

	else if(face == 3)
		return vec3(   +uv.x,    1.f,    -uv.y);

	else if(face == 4)
		return vec3(   +uv.x,   uv.y,      1.f);

	else //if(face == 5)
	{	return vec3(    -uv.x,  +uv.y,     -1.f);}
}

vec2 dirToUV(vec3 dir)
{
	return vec2(
		0.5f + 0.5f * atan2(dir.z, dir.x) / M_PI,
		1.0 - acos(dir.y) / M_PI);
}

vec3 panoramaToCubeMap(int face, vec2 texCoord)
{
	vec2 texCoordNew = texCoord*2.0-1.0;
	vec3 scan = uvToXYZ(face, texCoordNew);
	vec3 direction = normalize(scan);
	vec2 src = dirToUV(direction);

	return texture2DLod(s_source, src, 0.0).rgb;
}

NUM_THREADS(8, 8, 1)
void main()
{
    //ivec2 size = imageSize(s_cubemap_source);
    vec2 uv = vec2(gl_GlobalInvocationID.xy) / 512.0;
    int face = (int)gl_GlobalInvocationID.z;

    imageStore(s_cubemap_source, ivec3(gl_GlobalInvocationID), vec4(panoramaToCubeMap(face, uv), 0.0));
}
