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
float getRangeAttenuation(float range, float distance)
{
    if (range <= 0.0)
    {
        // negative range means unlimited
        return 1.0 / pow(distance, 2.0);
    }
    return max(min(1.0 - pow(distance / range, 4.0), 1.0), 0.0) / pow(distance, 2.0);
}

// https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_lights_punctual/README.md#inner-and-outer-cone-angles
float getSpotAttenuation(vec3 pointToLight, vec3 spotDirection, float outerConeCos, float innerConeCos)
{
    float actualCos = dot(normalize(spotDirection), normalize(-pointToLight));
    if (actualCos > outerConeCos)
    {
        if (actualCos < innerConeCos)
        {
            return smoothstep(outerConeCos, innerConeCos, actualCos);
        }
        return 1.0;
    }
    return 0.0;
}

#endif //__SHADER_LIGHTING_SH__