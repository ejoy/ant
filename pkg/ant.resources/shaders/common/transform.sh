#ifndef __SHADER_TRANSFORMS_SH__
#define __SHADER_TRANSFORMS_SH__

#include <shaderlib.sh>
#include "common/constants.sh"
#include "common/camera.sh"

#ifdef ENABLE_CURVE_WORLD
#include "common/curve_world.sh"
#endif //ENABLE_CURVE_WORLD

highp vec3 quat_to_normal(const highp vec4 q){
    return	vec3( 0.0,  0.0,  1.0 ) + 
        	vec3( 2.0, -2.0, -2.0 ) * q.x * q.zwx +
        	vec3( 2.0,  2.0, -2.0 ) * q.y * q.wzy;
}

highp vec3 quat_to_tangent(const highp vec4 q){
    return	vec3( 1.0,  0.0,  0.0 ) + 
        	vec3(-2.0,  2.0, -2.0 ) * q.y * q.yxw +
        	vec3(-2.0,  2.0,  2.0 ) * q.z * q.zwx;
}

mat4 calc_bone_transform(ivec4 indices, vec4 weights)
{
	mat4 wolrdMat = mat4(
		0, 0, 0, 0, 
		0, 0, 0, 0, 
		0, 0, 0, 0, 
		0, 0, 0, 0
	);
	for (int ii = 0; ii < 4; ++ii)
	{
		int id = int(indices[ii]);
		float weight = weights[ii];

		wolrdMat += u_model[id] * weight;
	}

	return wolrdMat;
}

// mat4 get_world_matrix(VS_Input vsin)
// {
// #if defined(GPU_SKINNING) && !defined(USING_LIGHTMAP)
// 	return calc_bone_transform(a_indices, a_weight);
// #else
// 	return	u_model[0];
// #endif
// }

#if defined(GPU_SKINNING) && !defined(USING_LIGHTMAP)
#define get_world_matrix()	calc_bone_transform(a_indices, a_weight)
#else
#define get_world_matrix()	u_model[0]
#endif

vec4 transformWS(mat4 wm, vec4 pos)
{
	vec4 posWS = mul(wm, pos);
#if CURVE_WORLD
	posWS.xyz = curve_world_offset(posWS.xyz);
#endif //ENABLE_CURVE_WORLD
	return posWS;
}

vec4 map_screen_coord_to_ndc(vec2 p)
{
    vec2 pos    = p.xy * u_viewTexel.xy;
    pos.y       = 1 - pos.y;
	pos         = pos * 2.0 - 1.0;
	return vec4(pos, 0.0, 1.0);
}

vec4 transform_ui_point(mat4 m, vec2 apos)
{
	vec4 p = mul(m, vec4(apos, 0.0, 1.0));
	p /= p.w;
	return p;
}

vec4 transform_screen_coord_to_ndc(mat4 m, vec2 apos)
{
	vec4 p = transform_ui_point(m, apos);
	return map_screen_coord_to_ndc(p.xy);
}

#ifdef ENABLE_CLIP_RECT
uniform vec4 u_clip_rect[2];
float check_dist(vec2 A, vec2 B, vec2 P)
{
	return (B.x - A.x) * (P.y - A.y) - (B.y - A.y) * (P.x - A.x);
}
void check_clip_rotated_rect(vec2 pixel)
{
	vec2 lt = u_clip_rect[0].xy;
	vec2 rt = u_clip_rect[0].zw;
	vec2 lb = u_clip_rect[1].xy;
	vec2 rb = u_clip_rect[1].zw;

	if (any(bvec4(
		check_dist(lt, rt, pixel) <= 0,
		check_dist(rt, rb, pixel) <= 0,
		check_dist(rb, lb, pixel) <= 0,
		check_dist(lb, lt, pixel) <= 0)
	)){
		discard;
	}
}
#endif //ENABLE_CLIP_RECT

#if BGFX_SHADER_TYPE_FRAGMENT
// code from: http://www.thetenthplanet.de/archives/1180
mat3 cotangent_frame(vec3 N, vec3 p, vec2 uv)
{
    // get edge vectors of the pixel triangle
    vec3 dp1 = dFdx( p );
    vec3 dp2 = dFdy( p );
    vec2 duv1 = dFdx( uv );
    vec2 duv2 = dFdy( uv );
 
 	// solve the linear system
	vec3 dp2perp = cross( dp2, N);
    vec3 dp1perp = cross( N, dp1 );
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;
 
    // construct a scale-invariant frame 
    float invmax = inversesqrt( max( dot(T,T), dot(B,B) ) );
	return mat3(T * invmax, B * invmax, N);
}
#endif //BGFX_SHADER_TYPE_FRAGMENT
#endif //__SHADER_TRANSFORMS_SH__