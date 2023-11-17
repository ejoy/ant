#include "common/transform.sh"
#include "default/utils.sh"

mat4 mountain_worldmat(VSInput vsinput)
{
    //idata0, idata1, idata2 already transpose before set to instance buffer
    return mat4(vsinput.data0, vsinput.data1, vsinput.data2, vec4(0.0, 0.0, 0.0, 1.0));
}

vec4 CUSTOM_VS_POSITION(VSInput vsinput, inout Varyings varyings, out mat4 worldmat)
{
    worldmat = mountain_worldmat(vsinput);
    vec4 posCS; varyings.posWS = transform_worldpos(worldmat, vsinput.position, posCS);
    return posCS;
}

void CUSTOM_VS(mat4 wm, VSInput vsinput, inout Varyings varyings)
{
    varyings.posWS.w = mul(u_view, varyings.posWS).z;
    varyings.texcoord0 = vsinput.texcoord0;

    // normal
    unpack_tbn_from_quat(wm, vsinput, varyings);
}