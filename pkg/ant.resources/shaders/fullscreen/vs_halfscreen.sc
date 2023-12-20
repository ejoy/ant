$output v_texcoord0

void main()
{
    vec2 coord = vec2(
        float((gl_VertexID & 1) << 2),
        float((gl_VertexID & 2) << 1));

    v_texcoord0 = coord * 0.5;
#if !BGFX_SHADER_LANGUAGE_GLSL
    v_texcoord0.y = 1.0 - v_texcoord0.y;
#endif //BGFX_SHADER_LANGUAGE_GLSL
    gl_Position = vec4(coord * 0.5 - 1.0, 0.0, 1.0);
}