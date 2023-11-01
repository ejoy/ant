$input v_texcoord0
#include <bgfx_shader.sh>

//see that magic code:
// https://bgolus.medium.com/the-best-darn-grid-shader-yet-727f9278b9d8
// https://www.humus.name/index.php?page=3D&ID=89
// https://iquilezles.org/articles/checkerfiltering/

void main()
{
    const float lineWidth = 0.5;

    const float duv = fwidth(v_texcoord0.x);
    const float drawWidth = max(lineWidth, duv); // use max lineWith, for keep line at least has 'lineWidth' pixel

    const float lineAA = duv * 1.5; // 1.5 for the duv, the mark more anti-aliasing for line
    float lineUV = abs(v_texcoord0.x * 2.0);
    
    float la = smoothstep(drawWidth + lineAA, drawWidth - lineAA, lineUV); //

    la *= saturate(lineWidth / drawWidth);  // to make line which lower than lineWidth to fade out

    gl_FragColor = vec4(1.0, 0.0, 1.0, la);
}