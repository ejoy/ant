#ifndef __SHADER_TRANSFORMS_SH__
#define __SHADER_TRANSFORMS_SH__
mat3 mat3_from_columns(vec3 v0, vec3 v1, vec3 v2)
{
	mat3 m = mat3(v0, v1, v2);
#ifdef BGFX_SHADER_LANGUAGE_HLSL
	return transpose(m);
#else
	return m;
#endif
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

mat3 calc_tbn_lh_ex(vec3 n, vec3 t, float b_sign, mat4 worldMat)
{
	vec3 normal = normalize(mul(worldMat, vec4(n, 0.0)).xyz);
	vec3 tangent = normalize(mul(worldMat, vec4(t.xyz, 0.0)).xyz);
	vec3 bitangent = cross(normal, tangent) * b_sign;

	mat3 tbn = mat3(tangent, bitangent, normal);
#if BGFX_SHADER_LANGUAGE_HLSL
	return tbn;
#else
	return transpose(tbn);
#endif
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
 	return transpose(
			mat3_from_columns(
			tangent,
			bitangent,
			normal)
		);
}

#ifdef FRAGMENT_SHADER
mat3 tbn_from_world_pos(vec3 normal, vec3 posWS, vec2 texcoord)
{
    vec3 Q1  = dFdx(posWS);
    vec3 Q2  = dFdy(posWS);
    vec2 st1 = dFdx(texcoord);
    vec2 st2 = dFdy(texcoord);

    vec3 N  = normalize(normal);
    vec3 T  = normalize(Q1*st2.y - Q2*st1.y);
    vec3 B  = -normalize(cross(N, T));

	mat3 TBN = mat3(T, B, N);
#if BGFX_SHADER_LANGUAGE_HLSL
	return TBN;
#else
	return transpose(TBN);
#endif
}
#endif //FRAGMENT_SHADER

#endif //__SHADER_TRANSFORMS_SH__