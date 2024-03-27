#ifndef __SHADOW_DEFINES_SH__
#define __SHADOW_DEFINES_SH__

#define USE_VIEW_SPACE_DISTANCE
//#define SHADOW_COVERAGE_DEBUG

//#define SM_HARD 
//#define SM_PCF
//#define SM_EVSM

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

// omni
uniform mat4 u_omni_matrix[4];
uniform vec4 u_tetra_normal_Green;
uniform vec4 u_tetra_normal_Yellow;
uniform vec4 u_tetra_normal_Blue;
uniform vec4 u_tetra_normal_Red;

//TODO: we keep omni shadow with cluster shading, find the shadowmap in cluster index
uniform vec4 u_omni_param;
#define u_omni_count u_omni_param.x

#ifdef SM_EVSM
#define SHADOW_SAMPLER2DARRAY	SAMPLER2DARRAY
#define shadow_sampler_type     sampler2DArray
#define sample_shadow           sample_shadow_directly
#else //!SM_EVSM
#define SHADOW_SAMPLER2DARRAY	SAMPLER2DARRAYSHADOW
#define shadow_sampler_type     sampler2DArrayShadow
#define sample_shadow           sample_shadow_compare
#endif //SM_EVSM

SHADOW_SAMPLER2DARRAY(s_shadowmap, 8);

#endif //__SHADOW_DEFINES_SH__