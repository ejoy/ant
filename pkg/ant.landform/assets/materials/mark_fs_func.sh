void CUSTOM_FS(Varyings varyings, out FSOutput fsoutput)
{
    float mark_alpha = texture2D(s_basecolor, varyings.texcoord0).r;
    fsoutput.color = vec4(varyings.color0.rgb, mark_alpha);
}