#include "bgfx_compute.sh"

#ifndef ORIGIN_TOP_LEFT
#define ORIGIN_TOP_LEFT 1
#endif //ORIGIN_TOP_LEFT

#ifndef HOMOGENEOUS_DEPTH
#define HOMOGENEOUS_DEPTH 0
#endif //HOMOGENEOUS_DEPTH

//TODO: if we need more accurate attenuation, we can utilize pos.w/dir.w/color.w to transfer data, right now, the light attenuation: light_color/(distance*distance), 
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

struct light_grid{
    uint offset;
    uint count;
};

struct AABB {
    vec4 minv;
    vec4 maxv;
};

#if defined(CLUSTER_BUILD) || defined(CLUSTER_PREPROCESS)
#define CLUSTER_BUFFER_AABB_STAGE               0
#define CLUSTER_BUFFER_GLOBAL_INDEX_COUNT_STAGE 1
#define CLUSTER_BUFFER_LIGHT_GRID_STAGE         2
#define CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE   3
#define CLUSTER_BUFFER_LIGHT_INFO_STAGE         4

#	if defined(CLUSTER_BUILD)
// only 2 buffer needed: lihgt info for read and aabb for write
BUFFER_RW(b_cluster_AABBs,		vec4,		CLUSTER_BUFFER_AABB_STAGE);
#	else //defined(CLUSTER_BUILD)
// 5 buffer needed, aabb and light infor for read, light grid and light index list for write, global index count for read/write
BUFFER_RO(b_cluster_AABBs,		vec4,		CLUSTER_BUFFER_AABB_STAGE);
BUFFER_RW(b_light_grids,		uint,		CLUSTER_BUFFER_LIGHT_GRID_STAGE);
BUFFER_RW(b_global_index_count,	uint,  		CLUSTER_BUFFER_GLOBAL_INDEX_COUNT_STAGE);
BUFFER_RW(b_light_index_lists,	uint,		CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE);
#	endif //defined(CLUSTER_BUILD)

#else //!(defined(CLUSTER_BUILD) || defined(CLUSTER_PREPROCESS))
// render stage need 3 buffer, light grid, light index lists and light info only for read
#define CLUSTER_BUFFER_LIGHT_GRID_STAGE         10
#define CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE   11
#define CLUSTER_BUFFER_LIGHT_INFO_STAGE         12
BUFFER_RO(b_light_grids,		uint,		CLUSTER_BUFFER_LIGHT_GRID_STAGE);
BUFFER_RO(b_light_index_lists,	uint,		CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE);
#endif //defined(CLUSTER_BUILD) || defined(CLUSTER_PREPROCESS)

BUFFER_RO(b_lights,				vec4,		CLUSTER_BUFFER_LIGHT_INFO_STAGE);

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
// right hand coordinate, where:
// z_n = A*z_e+B/-z_e ==> z_e = -B / (z_n + A)
// left hand coordinate, where:
// z_n = A*z_e+B/z_e ==> z_e = B / (z_n - A)
float linear_depth(float nolinear_depth){
#if HOMOGENEOUS_DEPTH
	float z_n = 2.0 * nolinear_depth - 1.0;
	float A = (u_farZ + u_nearZ) / (u_farZ - u_nearZ);
	float B = -2.0 * u_farZ * u_nearZ/(u_farZ - u_nearZ);
#else //!HOMOGENEOUS_DEPTH
	float z_n = nolinear_depth;
	float A = u_farZ / (u_farZ - u_nearZ);
	float B = -(u_farZ * u_nearZ) / (u_farZ - u_nearZ);
#endif //HOMOGENEOUS_DEPTH
	float z_e = B / (z_n - A);
    return z_e;
}

uint which_cluster(vec3 fragcoord){
	uint cluster_z     = uint(max(log2(linear_depth(fragcoord.z)) * u_slice_scale + u_slice_bias, 0.0));
    uvec3 cluster_coord= uvec3(fragcoord.xy / u_tile_unit_pre_pixel, cluster_z);
    return 	cluster_coord.x +
            u_cluster_size.x * cluster_coord.y +
            (u_cluster_size.x * u_cluster_size.y) * cluster_coord.z;

}

float which_z(uint depth_slice, uint num_slice){
	return u_nearZ*pow(u_farZ/u_nearZ, depth_slice/float(num_slice));
}

#define load_light_info(_BUF, _INDEX, _LIGHT){\
		int idx = _INDEX * 4;\
		vec4 v0 = _BUF[idx+0];\
		vec4 v1 = _BUF[idx+1];\
		vec4 v2 = _BUF[idx+2];\
		vec4 v3 = _BUF[idx+3];\
		_LIGHT.pos = v0.xyz; _LIGHT.range = v0.w;\
		_LIGHT.dir = v1.xyz; _LIGHT.enable = v1.w;\
		_LIGHT.color = v2;\
		_LIGHT.type = v3[0]; _LIGHT.intensity = v3[1]; _LIGHT.inner_cutoff = v3[2]; _LIGHT.outter_cutoff = v3[3];\
	}

#define load_light_grid(_BUF, _INDEX, _GRID){\
		int idx = _INDEX * 2;\
		_GRID.offset = _BUF[idx+0];\
		_GRID.count = _BUF[idx+1];\
	}

#define store_light_grid(_BUF, _INDEX, _GRID){\
		int idx = _INDEX * 2;\
		_BUF[idx+0] = _GRID.offset;\
		_BUF[idx+1] = _GRID.count;\
	}

#define store_light_grid2(_BUF, _INDEX, _OFFSET, _COUNT){\
		int idx = _INDEX * 2;\
		_BUF[idx+0] = _OFFSET;\
		_BUF[idx+1] = _COUNT;\
	}

#define load_cluster_aabb(_BUF, _INDEX, _AABB){\
		int idx = _INDEX * 2;\
		_AABB.minv = _BUF[idx+0];\
		_AABB.maxv = _BUF[idx+1];\
	}

#define store_cluster_aabb(_BUF, _INDEX, _AABB){\
		int idx = _INDEX * 2;\
		_BUF[idx+0] = _AABB.minv;\
		_BUF[idx+1] = _AABB.maxv;\
	}

#define store_cluster_aabb2(_BUF, _INDEX, _MINV, _MAXV){\
		int idx = _INDEX * 2;\
		_BUF[idx+0] = _MINV;\
		_BUF[idx+1] = _MAXV;\
	}

#if BGFX_SHADER_LANGUAGE_HLSL
#define buffer_length(_BUF, _LEN){\
    _BUF.GetDimensions(_LEN);\
}
#else //!BGFX_SHADER_LANGUAGE_HLSL
#define buffer_length(_BUF, _LEN){
	_LEN = _BUF.length();\
}
#endif //BGFX_SHADER_LANGUAGE_HLSL