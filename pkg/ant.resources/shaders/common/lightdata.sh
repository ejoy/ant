#ifndef _LIHGT_DATA_SH_
#define _LIHGT_DATA_SH_

uniform vec4 u_light_count;
#define u_all_light_count		u_light_count.x
#define u_culled_light_count	u_light_count.y
#define ENABLE_MODULATE_INDIRECT_COLOR
#ifdef ENABLE_MODULATE_INDIRECT_COLOR
uniform vec4 u_indirect_modulate_color;
#endif //ENABLE_MODULATE_INDIRECT_COLOR
struct light_info{
	vec3	pos;
	float	range;
	vec3	dir;
	float	enable;
	vec4	color;
	float	type;
	float	intensity;
	float	inner_cutoff;
	float	outter_cutoff;
	vec3	pt2l;
	float	attenuation;
};

#define LightType_Directional 0
#define LightType_Point 1
#define LightType_Spot 2

#define IS_DIRECTIONAL_LIGHT(_type) (_type==LightType_Directional)
#define IS_POINT_LIGHT(_type)       (_type==LightType_Point)
#define IS_SPOT_LIGHT(_type)        (_type==LightType_Spot)

bool has_directional_light()
{
    return u_all_light_count > u_culled_light_count;
}

#endif //_LIHGT_DATA_SH_