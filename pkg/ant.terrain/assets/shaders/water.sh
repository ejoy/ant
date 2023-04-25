#ifndef _WATER_SH_
#define _WATER_SH_

uniform vec4    u_water_param = vec4(0.5, 0.04, 0.0, 0.0);
#define         u_wave_speed            u_water_param.x
#define         u_uv_shifting_strength  u_water_param.y     // UV shifting strength

uniform vec4    u_water_param2= vec4(0.25, 0.25, 0.05, 0.04);   //xy for scale, zw for direction
#define         u_uv_scale              u_water_param2.xy
#define         u_uv_direction          u_water_param2.zw


#endif //_WATER_SH_