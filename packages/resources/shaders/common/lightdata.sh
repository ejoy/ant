#ifndef _LIHGT_DATA_SH_
#define _LIHGT_DATA_SH_

uniform vec4 u_light_count;

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
};

#define LightType_Directional 0
#define LightType_Point 1
#define LightType_Spot 2

#define IS_DIRECTIONAL_LIGHT(_type) (_type==LightType_Directional)
#define IS_POINT_LIGHT(_type)       (_type==LightType_Point)
#define IS_SPOT_LIGHT(_type)        (_type==LightType_Spot)

#endif //_LIHGT_DATA_SH_