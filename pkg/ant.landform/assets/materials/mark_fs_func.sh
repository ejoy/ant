#include "road.sh"

void CUSTOM_FS(Varyings varyings, out FSOutput fsoutput)
{
    float mark_alpha = texture2D(s_basecolor, fsinput.texcoord0).r;
    fsoutput.color = vec4(fsinput.color.rgb, mark_alpha);
}