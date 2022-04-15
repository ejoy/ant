#ifndef _SPHERE_COORD_SH_
#define _SPHERE_COORD_SH_

vec3 uvface2dir(vec2 uv, int face)
{
    switch (face){
    case 0:
        return vec3( 1.0, uv.y,-uv.x);
    case 1:
        return vec3(-1.0, uv.y, uv.x);
    case 2:
        return vec3( uv.x, 1.0,-uv.y);
    case 3:
        return vec3( uv.x,-1.0, uv.y);
    case 4:
        return vec3( uv.x, uv.y, 1.0);
    default:
        return vec3(-uv.x, uv.y,-1.0);
    }
}

vec2 dir2spherecoord(vec3 v)
{
	return vec2(
		0.5f + 0.5f * atan2(v.z, v.x) / M_PI,
		acos(v.y) / M_PI);
}

vec3 id2dir(ivec3 id, vec2 size)
{
    vec2 uv = (id.xy / size);
    uv = vec2(uv.x, 1.0-uv.y) * 2.0 - 1.0;
    int faceidx = id.z;
    return normalize(uvface2dir(uv, faceidx));
}



#endif //_SPHERE_COORD_SH_