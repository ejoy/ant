$input v_posWS, v_normal, v_tangent, v_bitangent

void main()
{
    float width = length(ddx(v_posWS));
    float height = length(ddx(v_posWS));

	// Output the vertex data + coverage
    PSOutput output;
    gl_FragData[0]   = vec4(v_posWS, width);
    gl_FragData[1]   = vec4(normalize(v_normal), height);
    gl_FragData[2]   = normalize(v_tangent);
    gl_FragData[3]   = normalize(v_bitangent);
    gl_FragData[4]   = 1;
}