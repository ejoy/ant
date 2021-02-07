#include "bgfx_compute.sh"

#if BGFX_SHADER_LANGUAGE_HLSL
#define SBUFFER_RO(_NAME, _TYPE, _STAGE)    StructuredBuffer<_TYPE>	_NAME : register(t[_STAGE]);
#define SBUFFER_RW(_NAME, _TYPE, _STAGE)    RWStructuredBuffer<_TYPE> _NAME : register(u[_STAGE]);
#else	//!BGFX_SHADER_LANGUAGE_HLSL
#define SBUFFER_RO(_NAME, _TYPE, _STAGE)    BUFFER_RO(_NAME, _TYPE, _STAGE)
#define SBUFFER_RO(_NAME, _TYPE, _STAGE)    BUFFER_RW(_NAME, _TYPE, _STAGE)
#endif  //BGFX_SHADER_LANGUAGE_HLSL

//TODO: if we need more accurate attenuation, we can utilize pos.w/dir.w/color.w to transfer data, right now, the light attenuation: light_color/(distance*distance), 
struct light_info{
	vec3	pos;
	float	range;
	vec3	dir;
	uint	enable;
	vec4	color;
	float	type;
	float	intensity;
	float	inner_cutoff;
	float	outter_cutoff;
};

struct light_grid{
    uint offset;
    uint count;
};

struct AABB {
    vec4 minv;
    vec4 maxv;
};

#ifdef CLUSTER_PREPROCESS
#define CLUSTER_BUFFER_AABB_STAGE               0
#define CLUSTER_BUFFER_GLOBAL_INDEX_COUNT_STAGE 1
#define CLUSTER_BUFFER_LIGHT_GRID_STAGE         2
#define CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE   3
#define CLUSTER_BUFFER_LIGHT_INFO_STAGE         4
SBUFFER_RW(b_cluster_AABBs,		AABB,		CLUSTER_BUFFER_AABB_STAGE);
SBUFFER_RW(b_global_index_count,uint,  		CLUSTER_BUFFER_GLOBAL_INDEX_COUNT_STAGE);
#else
#define CLUSTER_BUFFER_LIGHT_GRID_STAGE         10
#define CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE   11
#define CLUSTER_BUFFER_LIGHT_INFO_STAGE         12
#endif
SBUFFER_RW(b_light_grids,		light_grid,	CLUSTER_BUFFER_LIGHT_GRID_STAGE);
SBUFFER_RW(b_light_index_lists, uint,		CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE);
SBUFFER_RO(b_lights,			light_info, CLUSTER_BUFFER_LIGHT_INFO_STAGE);

uniform vec4 u_cluster_size;
// unit_pre_pixel = u_screen_width / u_cluster_size.x, mean num pixel pre tile in x direction
#define u_tile_unit_pre_pixel   u_cluster_size.w
uniform vec4 u_cluster_shading_param;
#define u_screen_width  u_cluster_shading_param.x
#define u_screen_height u_cluster_shading_param.y
#define u_nearZ         u_cluster_shading_param.z
#define u_farZ          u_cluster_shading_param.w
uniform vec4 u_cluster_shading_param2;
#define u_slice_scale	u_cluster_shading_param2.x
#define u_slice_bias	u_cluster_shading_param2.y

/**
about the depth slice:
	depth_slice = f(linearZ) = floor(
		log(linearZ) * num_slice/log(far/near) - log(near) * num_slice/log(far/near)
	)
	we can see 'num_slice/log(far/near)' and 'log(near) * num_slice/log(far/near)' are const in shader
	so, we can calculate them in cpu, and make them as 'scale' and 'bias'

	see below: which_cluster()
where inverse function is:
	linezeZ = F(depth_slice) = near * pow(far/near, depth_slice/num_slice)
	see below: which_z()
*/

//see: 	http://www.songho.ca/opengl/gl_projectionmatrix.html or
//		https://gist.github.com/kovrov/a26227aeadde77b78092b8a962bd1a91
// where z_e and z_n relationship, this function is the revserse of projection matrix
float linear_depth(float nolinear_depth){
    float ndc_depth = 2.0 * nolinear_depth - 1.0;
    
    float ldepth = 2.0 * u_nearZ * u_farZ / (u_farZ + u_nearZ - ndc_depth * (u_farZ - u_nearZ));
    return ldepth;
}

uint which_cluster(vec3 fragcoord){
	uint cluster_z     = uint(max(log2(linear_depth(fragcoord.z)) * u_slice_scale + u_slice_bias, 0.0));
    uvec3 cluster_coord= uvec3(fragcoord.xy / u_tile_unit_pre_pixel, cluster_z);
    return 	cluster_coord.x +
            u_cluster_size.x * cluster_coord.y +
            (u_cluster_size.x * u_cluster_size.y) * cluster_coord.z;

}

float which_z(uint depth_slice, uint num_slice){
	return u_nearZ * pow(u_nearZ / u_farZ, (depth_slice + 1) / float(num_slice));
}