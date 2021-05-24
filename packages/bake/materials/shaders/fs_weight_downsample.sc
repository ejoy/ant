#include <bgfx_shader.sh>

SAMPLER2D(hemispheres, 0);
SAMPLER2D(weights, 1);

vec4 weightedSample(ivec2 h_uv, ivec2 w_uv, ivec2 quadrant)
{
    vec4 sample = texelFetch(hemispheres, h_uv + quadrant, 0);
    vec2 weight = texelFetch(weights, w_uv + quadrant, 0).rg;
    return vec4(sample.rgb * weight.r, sample.a * weight.g);
}

vec4 threeWeightedSamples(ivec2 h_uv, ivec2 w_uv, ivec2 offset)
{ // horizontal triple sum
    vec4 sum = weightedSample(h_uv, w_uv, offset);
    sum += weightedSample(h_uv, w_uv, offset + ivec2(2, 0));
    sum += weightedSample(h_uv, w_uv, offset + ivec2(4, 0));
    return sum;
}

void main()
{
    // this is a weighted sum downsampling pass (alpha component contains the weighted valid sample count)
    vec2 in_uv = gl_FragCoord.xy * vec2(6.0, 2.0) + vec2_splat(0.5);
    ivec2 h_uv = ivec2(in_uv);
    ivec2 w_uv = ivec2(mod(in_uv, vec2(textureSize(weights, 0)))); // there's no integer modulo :(
    vec4 lb = threeWeightedSamples(h_uv, w_uv, ivec2(0, 0));
    vec4 rb = threeWeightedSamples(h_uv, w_uv, ivec2(1, 0));
    vec4 lt = threeWeightedSamples(h_uv, w_uv, ivec2(0, 1));
    vec4 rt = threeWeightedSamples(h_uv, w_uv, ivec2(1, 1));
    gl_FragColor = lb + rb + lt + rt;
};