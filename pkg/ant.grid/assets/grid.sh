
#define u_grid_width    u_grid_params.x
#define u_grid_height   u_grid_params.y
#define u_line_scale    u_grid_params.zw

//https://bgolus.medium.com/the-best-darn-grid-shader-yet-727f9278b9d8#2311
float pristineGrid(vec2 uv, vec2 lineWidth)
{
    vec4 uvDDXY = float4(ddx(uv), ddy(uv));
    vec2 uvDeriv = float2(length(uvDDXY.xz), length(uvDDXY.yw));
    bvec2 invertLine = lineWidth > 0.5;
    vec2 targetWidth = invertLine ? 1.0 - lineWidth : lineWidth;
    vec2 drawWidth = clamp(targetWidth, uvDeriv, 0.5);
    vec2 lineAA = uvDeriv * 1.5;
    vec2 gridUV = abs(frac(uv) * 2.0 - 1.0);
    gridUV = invertLine ? gridUV : 1.0 - gridUV;
    vec2 grid2 = smoothstep(drawWidth + lineAA, drawWidth - lineAA, gridUV);
    grid2 *= saturate(targetWidth / drawWidth);
    grid2 = lerp(grid2, targetWidth, saturate(uvDeriv * 2.0 - 1.0));
    grid2 = invertLine ? 1.0 - grid2 : grid2;
    return lerp(grid2.x, 1.0, grid2.y);
}

