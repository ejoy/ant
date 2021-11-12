#ifndef _CAMERA_SH_
#define _CAMERA_SH_

uniform vec4    u_eyepos;

uniform vec4    u_camera_param;
#define u_near 	u_camera_param.x
#define u_far 	u_camera_param.y

uniform vec4    u_exposure_param;

//uniform vec4 u_dof_param;

//see: 	http://www.songho.ca/opengl/gl_projectionmatrix.html or
//		https://gist.github.com/kovrov/a26227aeadde77b78092b8a962bd1a91
// where z_e and z_n relationship, this function is the revserse of projection matrix
// right hand coordinate, where:
// z_n = A*z_e+B/-z_e ==> z_e = -B / (z_n + A)
// left hand coordinate, where:
// z_n = A*z_e+B/z_e ==> z_e = B / (z_n - A)

// we are *LEFT* hand coordinate, and depth from [0, 1]
float linear_depth(float nolinear_depth)
{
	//#ifdef HOMOGENEOUS_DEPTH
	// float A = (u_far + u_near) / (u_far - u_near);
	// float B = -2.0 * u_far * u_near/(u_far - u_near);
	//#else
	// float A = u_far / (u_far - u_near);
	// float B = -(u_far * u_near) / (u_far - u_near);
	//#endif
	float z_n = nolinear_depth;
	float A = u_proj[2][2];
	float B = u_proj[3][2];
	return B / (z_n - A);
}

#endif //_CAMERA_SH_