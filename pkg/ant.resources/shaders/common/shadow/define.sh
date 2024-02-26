#ifndef __SHADOW_DEFINES_SH__
#define __SHADOW_DEFINES_SH__

#define USE_VIEW_SPACE_DISTANCE
//#define SHADOW_COVERAGE_DEBUG

//#define SM_HARD 
//#define SM_PCF
//#define SM_ESM

#ifndef USE_SHADOW_COMPARE
#define USE_SHADOW_COMPARE	//define by default
#endif //USE_SHADOW_COMPARE

#include "common/common.sh"

//csm
uniform mat4 u_csm_matrix[4];
uniform vec4 u_csm_split_distances;
uniform vec4 u_shadow_param1;

#define u_normal_offset 		u_shadow_param1.x
#define u_shadowmap_texelsize	u_shadow_param1.y
#define u_max_cascade_level		u_shadow_param1.z

uniform vec4 u_shadow_filter_param;

#if defined(SM_PCF)
#define u_pcf_kernelsize		u_shadow_filter_param.x
#elif defined(SM_ESM)
#define u_far_offset			u_shadow_filter_param.x
#define u_minVariance 			u_shadow_filter_param.y
#define u_depthMultiplier 		u_shadow_filter_param.z
#endif 

// omni
uniform mat4 u_omni_matrix[4];
uniform vec4 u_tetra_normal_Green;
uniform vec4 u_tetra_normal_Yellow;
uniform vec4 u_tetra_normal_Blue;
uniform vec4 u_tetra_normal_Red;

//TODO: we keep omni shadow with cluster shading, find the shadowmap in cluster index
uniform vec4 u_omni_param;
#define u_omni_count u_omni_param.x

#ifdef USE_SHADOW_COMPARE
#define SHADOW_SAMPLER2D	SAMPLER2DSHADOW
#define shadow_sampler_type sampler2DShadow
#else
#define SHADOW_SAMPLER2D	SAMPLER2D
#define shadow_sampler_type sampler2D 
#endif

SHADOW_SAMPLER2D(s_shadowmap, 8);

#ifdef USE_SHADOW_COMPARE
#define sample_shadow sample_shadow_hardware
#else //!USE_SHADOW_COMPARE
#define sample_shadow sample_shadow_directly
#endif //USE_SHADOW_COMPARE

#endif //__SHADOW_DEFINES_SH__