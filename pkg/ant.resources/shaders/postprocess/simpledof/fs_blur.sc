$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/postprocess.sh"

uniform vec4 u_param;
#define u_blur_size         u_param.x
#define u_separation        u_param.y
#define u_min_merge_factor  u_param.z
#define u_max_merge_factor  u_param.w

void main() {
    int size = int(u_blur_size);

    vec2 texSize   = textureSize(s_mainview, 0).xy;

    vec4 fragColor = texture2D(s_mainview, v_texcoord0);

    float bright = 0.0;
    vec4  max_brightcolor = fragColor;

    for (int i = -size; i <= size; ++i) {
        for (int j = -size; j <= size; ++j) {
            // For a rectangular shape.
            //if (false);

            // For a diamond shape;
            //if (!(abs(i) <= size - abs(j))) { continue; }

            // For a circular shape.
            if (distance(vec2(i, j), vec2(0, 0)) > size){
                vec2 offset = (vec2(i, j) * u_separation)/texSize;
                vec4 c = texture2D(s_mainview, v_texcoord0 + offset);

                float b = dot(c.rgb, vec3(0.3, 0.59, 0.11));

                if (b > bright) {
                    bright = b;
                    max_brightcolor = c;
                }
            }
        }
    }

    gl_FragColor = mix(fragColor, max_brightcolor, smoothstep(u_min_merge_factor, u_max_merge_factor, bright));
}
