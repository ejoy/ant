#ifndef _BLOOM_SH_
#define _BLOOM_SH_
uniform vec4 u_bloom_param;
uniform vec4 u_bloom_param2;
#define u_bloom_level           u_bloom_param.x
#define u_bloom_inv_highlight   u_bloom_param.y
#define u_bloom_threshold       u_bloom_param.z

#endif //_BLOOM_SH_