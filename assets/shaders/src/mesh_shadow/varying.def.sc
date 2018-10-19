vec2 v_texcoord0   : TEXCOORD0 = vec2(0.0, 0.0);

vec4 v_texcoord1   : TEXCOORD8 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_texcoord2   : TEXCOORD9 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_texcoord3   : TEXCOORD10 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_texcoord4   : TEXCOORD11 = vec4(0.0, 0.0, 0.0, 0.0);

vec3 v_view        : TEXCOORD5 = vec3(0.0, 0.0, 0.0);
vec4 v_shadowcoord : TEXCOORD6 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_position    : TEXCOORD7 = vec4(0.0, 0.0, 0.0, 0.0);
vec3 v_normal      : NORMAL    = vec3(0.0, 0.0, 1.0);
float v_depth      : FOG       = 0.0;

vec3 a_position  : POSITION;
vec4 a_normal    : NORMAL;
vec2 a_texcoord0 : TEXCOORD0;
