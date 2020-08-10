$input v_posWS, v_normalWS, v_pos, v_texcoord0

#include "common.sh"
#include "common/transform.sh"

SAMPLER2D(s_LavaDiffuse, 0);
SAMPLER2D(s_StoneDiffuse, 1);
SAMPLERCUBE(s_LavaNoise, 2);

uniform vec4 u_eyepos;
uniform vec4 u_lava_hot_stone_color;
uniform vec4 u_lava_cold_stone_color;
uniform vec4 u_lava_bright_color;

uniform vec4 u_star_atmosphere;
#define u_star_atmosphere_width     u_star_atmosphere.x
#define u_star_atmosphere_intensity u_star_atmosphere.y
uniform vec4 u_star_atmosphere_color;


// --------------------------------------------------------------
// ------------------    LAVA           -------------------------
// --------------------------------------------------------------
#define LAVA_ANIMATION_SPEED 0.08
#define LAVA_FIELD_SIZE      10.0
#define LAVA_STONE_HOTTNESS  0.1

#define LAVA_TEXTURE_TILE    10.0
#define LAVA_TEXTURE_PARALLAX 0.1

#define STONE_TEXTURE_TILE  25.0
#define STONE_TEXTURE_PARALLAX 0.15

void main()
{
    //vec2 uv0 = Input.vUV0 + vUVAnimationDir * vUVAnimationTime;
    vec2 uv0 = v_texcoord0;

    vec3 noisenormal = normalize(v_pos);

    float noise1 = textureCube(s_LavaNoise, noisenormal).r - 0.5;
    float noise2 = textureCube(s_LavaNoise, noisenormal * 4.0f).r - 0.5;
    float noise3 = textureCube(s_LavaNoise, noisenormal * 8.0f).r - 0.5;

    float noise = noise1 + noise2 + noise3;

    //float noiseAnimationTime = Time * LAVA_ANIMATION_SPEED;
    //float animatedNoise = sin((noise + noiseAnimationTime) * LAVA_FIELD_SIZE);

    // float invertedAnimatedNoise = 1.0 - animatedNoise;
    // float invertedAnimatedNoiseRescaled = invertedAnimatedNoise * 0.5;
    // float invertedAnimatedNoiseRescaled2 = invertedAnimatedNoiseRescaled * invertedAnimatedNoiseRescaled;

    float scale_noise = sin(noise * LAVA_FIELD_SIZE);
    float inverted_noise = 1.0 - scale_noise;
    float inverted_noise_rescaled = inverted_noise * 0.5;
    float inverted_noise_rescaled2 = inverted_noise_rescaled * inverted_noise_rescaled;

    float lava_mask = saturate(-scale_noise) * saturate(-scale_noise);

    vec3 viewdir = normalize(u_eyepos.xyz - v_posWS);
    vec2 parallax_offset = inverted_noise_rescaled * viewdir.xz;

    vec2 lavauv = uv0 * LAVA_TEXTURE_TILE - (parallax_offset * LAVA_TEXTURE_PARALLAX);
    vec3 lava_color = texture2D(s_LavaDiffuse, lavauv ).rgb;

    vec2 stoneuv = uv0 * STONE_TEXTURE_TILE - (parallax_offset * STONE_TEXTURE_PARALLAX);
    vec3 stone_color = texture2D(s_StoneDiffuse, stoneuv ).rgb;

    vec3 heatedstone = stone_color * u_lava_hot_stone_color.rgb * (pow(inverted_noise_rescaled2, 0.5) + LAVA_STONE_HOTTNESS );
    float stoneLerp = (1.0 - saturate(scale_noise));
    heatedstone = lerp(heatedstone + stone_color * u_lava_cold_stone_color, heatedstone, stoneLerp);
    vec3 lava = lava_color * u_lava_bright_color * pow(lava_mask, 0.7);

    vec3 finalcolor = saturate(heatedstone + lava);

    // Atmosphere
    vec3 normal = normalize(v_normalWS);
    float vAtmosphere = saturate(dot(normal, -viewdir + u_star_atmosphere_width));
    finalcolor = lerp(finalcolor, u_star_atmosphere_color.rgb, 
        vAtmosphere * vAtmosphere * 
            u_star_atmosphere_color.a * 
            u_star_atmosphere_intensity);

    // float vAlpha = 1.0;

    // #ifdef IS_NEUTRON_STAR_SHELL
    //     float NdotL = saturate( 0.5 - dot(normal, viewdir));
    //     vAlpha *= NdotL;
    //     vAlpha *= 0.2;
    // #else
    //     vAlpha = 0.1 * vBloomFactor;

    //     float vRim = smoothstep( 0.5, 1.0, 1.0 - dot(normal, viewdir));
    //     finalcolor.rgb += finalcolor.rgb * vRim * 3.5f;
    //     finalcolor = saturate( finalcolor );
    // #endif

    gl_FragColor = vec4(finalcolor.rgb*2, 1.0f);
    //return float4(finalcolor.rgb*2, vAlpha);
}
