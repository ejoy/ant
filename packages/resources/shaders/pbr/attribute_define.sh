#ifndef __ATTRIBUTE_DEFINE_SH__
#define __ATTRIBUTE_DEFINE_SH__

struct input_attributes
{
    lowp vec4 basecolor;
    mediump vec4 emissive;

    mediump vec3 N;
    mediump float metallic;

    mediump vec3 V;
    mediump float perceptual_roughness;

    mediump vec3 pos;
    mediump float occlusion;

    mediump vec2 uv;
    mediump vec2 screen_uv;

    mediump vec3 posWS;
    mediump float distanceVS;
    mediump vec4 fragcoord;
    mediump vec3 gN;

#ifdef ENABLE_BENT_NORMAL
    // this bent normal is pixel bent normal in world space
    mediump vec3 bent_normal;
#endif //ENABLE_BENT_NORMAL

#ifdef USING_LIGHTMAP
    mediump vec2 uv1;
#endif //USING_LIGHTMAP
};

#endif //__ATTRIBUTE_DEFINE_SH__
