#ifndef __SHADER_TRANSFORMS_SH__
#define __SHADER_TRANSFORMS_SH__

#include <shaderlib.sh>
#include "common/constants.sh"

uniform vec4 u_clip_planes[4];

mat3 to_tbn(vec3 t, vec3 b, vec3 n)
{
	mat3 TBN = mat3(t, b, n);
#if BGFX_SHADER_LANGUAGE_HLSL
	return TBN;
#else
	return transpose(TBN);
#endif
}

vec4 transform_skin_position(vec4 pos, ivec4 indices, vec4 weights)
{
	vec4 worldpos = vec4(0.0, 0.0, 0.0, 0.0);
	for (int ii = 0; ii < 4; ++ii)
	{
		float weight = weights[ii];
		vec4 p = mul(u_model[int(indices[ii])], pos);
		worldpos += p * weight;
	}
	worldpos.w = 1.0;
	return worldpos;
}

mat4 calc_bone_transform(ivec4 indices, vec4 weights)
{
	mat4 wolrdMat = mat4(0, 0, 0, 0, 
	0, 0, 0, 0, 
	0, 0, 0, 0, 
	0, 0, 0, 0);
	for (int ii = 0; ii < 4; ++ii)
	{
		int id = int(indices[ii]);
		float weight = weights[ii];

		wolrdMat += u_model[id] * weight;
	}

	return wolrdMat;
}

#ifdef GPU_SKINNING
#define get_world_matrix()	calc_bone_transform(a_indices, a_weight)
#else //!GPU_SKINNING
#define get_world_matrix()	u_model[0]
#endif //GPU_SKINNING

mat3 calc_tbn_lh_ex(vec3 n, vec3 t, float b_sign, mat4 worldMat)
{
	vec3 normal = normalize(mul(worldMat, vec4(n, 0.0)).xyz);
	vec3 tangent = normalize(mul(worldMat, vec4(t.xyz, 0.0)).xyz);
	vec3 bitangent = cross(normal, tangent) * b_sign;

	return to_tbn(tangent, bitangent, normal);
}

// left handside
mat3 calc_tbn_lh(vec3 n, vec3 t, mat4 worldMat)
{
	return calc_tbn_lh_ex(n, t, 1.0, worldMat);
}

// mat3 calc_tbn_rh(vec3 n, vec3 t, mat4 worldMat)
// {
// 	vec3 normal = normalize(mul(worldMat, vec4(n, 1)).xyz);
// 	vec3 tangent = normalize(mul(worldMat, vec4(t, 1)).xyz);
// 	vec3 bitangent = cross(tangent, normal);

//  	return transpose(
// 			mat3(
// 			tangent,
// 			bitangent,
// 			normal)
// 		);
// }


// mat3 calc_tbn_with_nt_ex(vec3 n, vec3 t, mat4 worldMat))
// {
// 	vec3 normal = normalize(mul(worldMat, vec4(n, 1)).xyz);
// 	vec3 tangent = normalize(mul(worldMat, vec4(t, 1)).xyz);
// 	vec3 bitangent = cross(normal, tangent);

//  	return transpose(
// 			mat3(
// 			tangent,
// 			bitangent,
// 			normal)
// 		);
// }

mat3 calc_tbn(vec3 n, vec3 t, vec3 b, mat4 worldMat)
{
	vec3 normal = normalize(mul(worldMat, vec4(n, 0.0)).xyz);
	vec3 tangent = normalize(mul(worldMat, vec4(t, 0.0)).xyz);
	vec3 bitangent = normalize(mul(worldMat, vec4(b, 0.0)).xyz);
 	return to_tbn(tangent, bitangent, normal);
}

// #if BGFX_SHADER_TYPE_FRAGMENT
// mat3 tbn_from_world_pos(vec3 normal, vec3 posWS, vec2 texcoord)
// {
//     vec3 Q1  = dFdx(posWS);
//     vec3 Q2  = dFdy(posWS);
//     vec2 st1 = dFdx(texcoord);
//     vec2 st2 = dFdy(texcoord);

//     vec3 N  = normalize(normal);
//     vec3 T  = normalize(Q1*st2.y - Q2*st1.y);
//     vec3 B  = -normalize(cross(N, T));

// 	return to_tbn(T, B, N);
// }
// #endif //BGFX_SHADER_TYPE_FRAGMENT

vec3 remap_normal(vec2 normalTSXY)
{
    vec2 normalXY = normalTSXY * 2.0 - 1.0;
	float z = sqrt(1.0 - dot(normalXY, normalXY));
    return vec3(normalXY, z);
}

vec3 fetch_bc5_normal(sampler2D normalMap, vec2 texcoord)
{
    return remap_normal(texture2DBc5(normalMap, texcoord));
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

uniform vec4 	u_camera_info;
#define u_near 	u_camera_info.x
#define u_far 	u_camera_info.y

vec4 do_cylinder_transform(vec4 posWS)
{
	vec4 posVS = mul(u_view, posWS);
    float radian = (posVS.z / u_far) * PI * 0.1;
    float c = cos(radian), s = sin(radian);

    mat4 ct = mtxFromCols4(
        vec4(1.0, 0.0, 0.0, 0.0),
        vec4(0.0, c,   s,   0.0),
        vec4(0.0, -s,   c,   0.0),
        vec4(0.0, 0.0, 0.0, 1.0));

    vec4 posCT = mul(ct, posVS);
	return mul(u_proj, posCT);
}

#endif //__SHADER_TRANSFORMS_SH__