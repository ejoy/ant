#ifndef __SHADER_POSTPROCESS_SH__
#define __SHADER_POSTPROCESS_SH__

#include <shaderlib.sh>
SAMPLER2D(s_scene_color, 0);
SAMPLER2D(s_scene_depth, 1);

uniform vec4 u_pp_param;

#include "common/camera.sh"

float linear_depth_pp(float nolinear_depth)
{
	return linear_depth(nolinear_depth, u_pp_param.x, u_pp_param.y);
}

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
    return linear_depth_pp(depth);
}


highp vec3 normalVS_from_depth(
        const highp sampler2D depthTexture, const highp vec2 uv,
        const highp vec3 position){
    highp vec2 uvdx = uv + vec2(u_viewTexel.x, 0.0);
    highp vec2 uvdy = uv + vec2(0.0, u_viewTexel.y);

	highp vec3 px = posVS_from_depth(uvdx, depthVS_from_texture(depthTexture, uvdx, 0.0));
    highp vec3 py = posVS_from_depth(uvdy, depthVS_from_texture(depthTexture, uvdy, 0.0));
    highp vec3 dpdx = px - position;
    highp vec3 dpdy = py - position;
    return normalVS_from_dxdy(dpdy, dpdx);
}
#endif //BGFX_SHADER_TYPE_FRAGMENT

vec2 screen_uv(vec2 fragcoord)
{
	vec2 xy = fragcoord.xy - u_viewRect.xy;
	return xy / u_viewRect.zw;
}


#endif //__SHADER_POSTPROCESS_SH__