$input a_position, a_normal, a_texcoord0, a_texcoord1, a_tangent, a_bitangent
$output v_posWS, v_normal, v_tangent, v_bitangent

void main()
{
    VSOutput output;
    // Calc the clip-space position based on the lightmap texture coordinates
    gl_Position = vec4((a_texcoord1 * 2.0 - 1.0) * vec2(1.0, -1.0), 1.0, 1.0);

	// Pass along the vertex data
    v_posWS = a_position;
    v_normal = a_normal;
    v_tangent = a_tangent;
    v_bitangent = a_bitangent;
}
