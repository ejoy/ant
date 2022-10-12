#ifndef __SHADER_POSTPROCESS_SH__
#define __SHADER_POSTPROCESS_SH__

#include <shaderlib.sh>
#include "common/common.sh"
#include "common/camera.sh"

SAMPLER2D(s_scene_color, 0);
SAMPLER2D(s_scene_depth, 1);

uniform vec4 u_reverse_pos_param;

float linear_depth_pp(float nolinear_depth)
{
	return linear_depth(nolinear_depth, u_reverse_pos_param.z, u_reverse_pos_param.w);
}

vec3 posVS_from_depth(vec2 uv, float depthVS)
{
	// from [0, 1] ==> [-1, 1]
#if ORIGIN_BOTTOM_LEFT
	vec2 pos2dNDC = uv * 2.0 - 1.0;
#else //!ORIGIN_BOTTOM_LEFT
	vec2 pos2dNDC = vec2(uv.x*2.0-1.0, 1.0-uv.y*2.0);
#endif //ORIGIN_BOTTOM_LEFT

	// u_reverse_pos_param.xy is projection matrix col0.x and col1.y, make XY = u_reverse_pos_param.xy
	// xn for x in NDC space, xc for x in Clip space, 
	// xn = xc / wc, xc = X * xe, so:
	// why xc = X * xe? we assume projection matrix(it's column matrix) first row is: r0 = [X, 0, 0, 0], so:
	// 		xc = r0 dot Ve ==> xc = X * xe
	// so:
	// 		xn = (X * xe)/wc ==> xe = (xn * wc) / X, and wc = ze = depthVS
	// so:
	// 		xe = (xn * ze) / X
	//		ye = (yn * ze) / Y
	vec2 pos2dVS = pos2dNDC * depthVS / u_reverse_pos_param.xy;
	return vec3(pos2dVS, depthVS);
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

vec2 get_texel_coord(vec2 xy)
{
#if ORIGIN_BOTTOM_LEFT
	return xy;
#else //!ORIGIN_BOTTOM_LEFT
	return vec2(xy.x, 1.0-xy.y);
#endif //ORIGIN_BOTTOM_LEFT
}

highp vec3 normalVS_from_depth(
        const highp sampler2D depthTexture, const highp vec2 uv,
        const highp vec3 position){
    highp vec2 uvdx = uv + vec2(u_viewTexel.x, 0.0);
#if ORIGIN_BOTTOM_LEFT
    highp vec2 uvdy = uv + vec2(0.0, u_viewTexel.y);
#else //ORIGIN_BOTTOM_LEFT
	highp vec2 uvdy = uv + vec2(0.0, -u_viewTexel.y);
#endif //ORIGIN_BOTTOM_LEFT

	highp vec3 px = posVS_from_depth(uvdx, depthVS_from_texture(depthTexture, uvdx, 0.0));
    highp vec3 py = posVS_from_depth(uvdy, depthVS_from_texture(depthTexture, uvdy, 0.0));
    highp vec3 dpdx = px - position;
    highp vec3 dpdy = py - position;
    return normalVS_from_dxdy(dpdy, dpdx);
}
#endif //BGFX_SHADER_TYPE_FRAGMENT


#endif //__SHADER_POSTPROCESS_SH__