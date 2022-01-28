$output v_texcoord0

void main() 
{
    vec2 xy = vec2(
        float((gl_VertexID & 1) << 2),
        float((gl_VertexID & 2) << 1));
    v_texcoord0 = xy * 0.5;
    gl_Position = vec4(xy-1.0, 0.0, 1.0);
}