#ifndef __SHADER_LIGHTING_SH__
#define __SHADER_LIGHTING_SH__

uniform vec4 u_light_count;
uniform vec4 u_eyepos;

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
#define LightType_Spot 0

#define IS_DIRECTIONAL_LIGHT(_type) (_type==LightType_Directional)
#define IS_POINT_LIGHT(_type)       (_type==LightType_Point)
#define IS_SPOT_LIGHT(_type)        (_type==LightType_Spot)

// https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_lights_punctual/README.md#range-property
float get_range_attenuation(float range, float distance)
{
    return max(min(1.0 - pow(distance / range, 4.0), 1.0), 0.0) / pow(distance, 2.0);
}

// https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_lights_punctual/README.md#inner-and-outer-cone-angles
float get_spot_attenuation(vec3 pt2l, vec3 spotdir, float outer_cone, float inner_cone)
{
    float cosv = dot(normalize(spotdir), normalize(-pt2l));
    return smoothstep(outer_cone, inner_cone, cosv);
}

#endif //__SHADER_LIGHTING_SH__