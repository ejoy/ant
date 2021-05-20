#include <bgfx_shader.sh>
SAMPLER2D(hemispheres, 0);

void main()
{ // this is a sum downsampling pass (alpha component contains the weighted valid sample count)
    ivec2 h_uv = ivec2(gl_FragCoord.xy) * 2;
    vec4 lb = texelFetch(hemispheres, h_uv + ivec2(0, 0), 0);
    vec4 rb = texelFetch(hemispheres, h_uv + ivec2(1, 0), 0);
    vec4 lt = texelFetch(hemispheres, h_uv + ivec2(0, 1), 0);
    vec4 rt = texelFetch(hemispheres, h_uv + ivec2(1, 1), 0);
    gl_FragColor = lb + rb + lt + rt;
}