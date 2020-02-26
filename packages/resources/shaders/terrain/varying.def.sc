vec3 a_position  : POSITION;
vec3 a_normal    : NORMAL;
vec3 a_color     : COLOR0;

vec2 a_texcoord0 : TEXCOORD0;
vec2 a_texcoord1 : TEXCOORD1;
vec2 a_texcoord2 : TEXCOORD2;
vec2 a_texcoord3 : TEXCOORD3;

vec2 v_texcoord0 : TEXCOORD0  = vec2(0.0, 0.0);
vec2 v_texcoord1 : TEXCOORD1  = vec2(0.0, 0.0);
vec2 v_texcoord2 : TEXCOORD2;
vec2 v_texcoord3 : TEXCOORD3;

vec4 v_positionWS: TEXCOORD7  = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_normal    : NORMAL     = vec4(0.0, 0.0, 1.0, 0.0);
