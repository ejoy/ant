mat4 calc_bone_transform(ivec4 indices, vec4 weights)
{
	mat4 wolrdMat = mat4(0);
	for (int ii = 0; ii < 4; ++ii)
	{
		int id = int(indices[ii]);
		float weight = weights[ii];

		wolrdMat += u_model[id] * weight;
	}

	return wolrdMat;
}

// left handside
mat3 calc_tbn_lh(vec3 n, vec3 t, mat4 worldMat)
{
	vec3 normal = normalize(mul(worldMat, vec4(n, 1)).xyz);
	vec3 tangent = normalize(mul(worldMat, vec4(t, 1)).xyz);
	vec3 bitangent = cross(normal, tangent);

 	return transpose(
			mat3(
			tangent,
			bitangent,
			normal)
		);
}

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
	vec3 normal = normalize(mul(worldMat, vec4(n, 1)).xyz);
	vec3 tangent = normalize(mul(worldMat, vec4(t, 1)).xyz);
	vec3 bitangent = normalize(mul(worldMat, vec4(b, 1)).xyz);
 	return transpose(
			mat3(
			tangent,
			bitangent,
			normal)
		);
}