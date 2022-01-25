#ifndef _SKY_COMMON_SH_
#define _SKY_COMMON_SH_
vec2 sampleEquirectangularMap(vec3 v)
{
	return vec2(
		0.5f + 0.5f * atan2(v.z, v.x) / M_PI,
		acos(v.y) / M_PI);
}

#endif //_SKY_COMMON_SH_