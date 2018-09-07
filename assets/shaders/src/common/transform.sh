mat4 calc_bone_transform(ivec4 indices, vec4 weights)
{
	vec4 pos = vec4(0, 0, 0, 1);
	mat4 wolrdMat;
	for (int ii = 0; ii < 4; ++ii)
	{
		int id = indices[ii];
		float weight = weights[ii];

		wolrdMat += u_model[id] * weight;
	}

	return wolrdMat;
}

mat3 calc_tbn_with_nt(vec3 n, vec3 t, float bitangent_sign, mat4 worldMat)
{
	vec3 normal = normalize(mul(worldMat, vec4(n, 1)).xyz);
	vec3 tangent = normalize(mul(worldMat, vec4(t, 1)).xyz);
	vec3 bitangent = normalize(cross(normal, tangent) * bitangent_sign);

 	return transpose(
			mat3(
			tangent,
			bitangent,
			normal)
		);
}

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