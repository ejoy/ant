#ifndef __ROAD_SH__
#define __ROAD_SH__
#include "pbr/attribute_define.sh"

vec3 blend(vec3 texture1, float a1, float d1, vec3 texture2, float a2, float d2){
    float depth = 0.2;
    float ma = max(d1 + a1, d2 + a2) - depth;

    float b1 = max(d1  + a1 - ma, 0);
    float b2 = max(d2  + a2 - ma, 0);

    return (texture1.rgb * b1 + texture2.rgb * b2) / (b1 + b2);
}


vec3 calc_road_basecolor(vec4 road_basecolor, float road_type)
{
    vec3 stop_color   = vec3(255.0/255,  37.0/255,  37.0/255);
    vec3 choose_color = vec3(228.0/255, 228.0/255, 228.0/255);
    if(road_type == 1){
        return road_basecolor.rgb;
    }
    else if (road_type == 2){
        return vec3((stop_color.r+road_basecolor.r)*0.5, (stop_color.g+road_basecolor.g)*0.5, (stop_color.b+road_basecolor.b)*0.5);
    }
    else{
        return vec3((choose_color.r+road_basecolor.r)*0.5, (choose_color.g+road_basecolor.g)*0.5, (choose_color.b+road_basecolor.b)*0.5);
    }  
}

vec3 calc_road_mark_blend_color(float road_type, vec4 road_basecolor, float mark_type, vec4 mark_basecolor, float mark_alpha)
{

    if(road_type != 0.0 && mark_type != 0.0)
    {
        vec3 tmp_color = calc_road_basecolor(road_basecolor, road_type);
        return blend(mark_basecolor.rgb, 1.0 - mark_alpha, 0.5, tmp_color, mark_alpha, 0.5); 
    }
    else if(road_type != 0.0 && mark_type == 0.0)
    {
        return calc_road_basecolor(road_basecolor, road_type);
    }
    else if(road_type == 0.0 && mark_type != 0.0)
    {
        return mark_basecolor.rgb;
    }
    else
    {
        return road_basecolor.rgb;
    }
}
#endif //
