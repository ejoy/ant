#ifndef _CAMERA_SH_
#define _CAMERA_SH_

uniform vec4    u_eyepos;

uniform vec4    u_camera_param;
#define u_near 	u_camera_param.x
#define u_far 	u_camera_param.y

uniform vec4    u_exposure_param;

//uniform vec4 u_dof_param;

#endif //_CAMERA_SH_