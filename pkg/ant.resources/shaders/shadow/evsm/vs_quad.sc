void main()
{
    vec2 coord = vec2(
    float((gl_VertexID & 1) << 2),
    float((gl_VertexID & 2) << 1));
    gl_Position = vec4(coord - 1.0, 0.0, 1.0);
}