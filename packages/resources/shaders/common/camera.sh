#ifndef _CAMERA_SH_
#define _CAMERA_SH_

uniform vec4    u_eyepos;

uniform vec4    u_camera_param;
#define u_near 	u_camera_param.x
#define u_far 	u_camera_param.y
#define u_inv_near u_camera_param.z
#define u_inv_far u_camera_param.w

uniform vec4    u_exposure_param;

//uniform vec4 u_dof_param;

//see: 	http://www.songho.ca/opengl/gl_projectionmatrix.html or
//		https://gist.github.com/kovrov/a26227aeadde77b78092b8a962bd1a91
// where z_e and z_n relationship, this function is the revserse of projection matrix
// right hand coordinate, where:
// z_n = A*z_e+B/-z_e ==> z_e = -B / (z_n + A)
// left hand coordinate, where:
// z_n = A*z_e+B/z_e ==> z_e = B / (z_n - A)

// we are *LEFT* hand coordinate, and depth from [0, 1]
// it's the same as gl_FragCoord.w
float linear_depth(float nolinear_depth)
{
	//#if HOMOGENEOUS_DEPTH
	// float A = (u_far + u_near) / (u_far - u_near);
	// float B = -2.0 * u_far * u_near/(u_far - u_near);
	//#else
	// float A = u_far / (u_far - u_near);
	// float B = -(u_far * u_near) / (u_far - u_near);
	//#endif
	float z_n = nolinear_depth;
	float A = u_proj[2][2];
	float B = u_proj[2][3];
	return B / (z_n - A);
}

#include "common/postprocess.sh"
vec3 posVS_from_depth(vec2 uv, float depthVS)
{
	vec2 origin2d = vec2(uv.x-0.5,
#if BGFX_SHADER_LANGUAGE_GLSL
	uv.y - 0.5
#else //!BGFX_SHADER_LANGUAGE_GLSL
	0.5-uv.y
#endif //BGFX_SHADER_LANGUAGE_GLSL
	);
	return vec3(origin2d*depthVS*u_inv_near, depthVS);
}

vec3 normalVS_from_dxdy(vec3 dpdx, vec3 dpdy)
{
	return normalize(cross(dpdx, dpdy));
}

#if BGFX_SHADER_TYPE_FRAGMENT

highp float depthVS_from_texture(const highp sampler2D depthTexture, const highp vec2 uv, const float lod)
{
	highp float depth = texture2DLod(s_scene_depth, uv, lod).r;
    return linear_depth(depth);
}


highp vec3 normalVS_from_depth(
        const highp sampler2D depthTexture, const highp vec2 uv,
        const highp vec3 position){
    highp vec2 uvdx = uv + vec2(u_viewTexel.x, 0.0);
    highp vec2 uvdy = uv + vec2(0.0, u_viewTexel.y);

	highp vec3 px = posVS_from_depth(uv, depthVS_from_texture(depthTexture, uv, 0.0));
    highp vec3 py = posVS_from_depth(uv, depthVS_from_texture(depthTexture, uv, 0.0));
    highp vec3 dpdx = px - position;
    highp vec3 dpdy = py - position;
    return normalVS_from_dxdy(dpdx, dpdy);
}
#endif //BGFX_SHADER_TYPE_FRAGMENT

vec2 screen_uv(vec2 fragcoord)
{
	vec2 xy = fragcoord.xy - u_viewRect.xy;
	return xy / u_viewRect.zw;
}

#endif //_CAMERA_SH_