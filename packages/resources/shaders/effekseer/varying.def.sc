vec4 v_VColor       : COLOR0    = vec4(0.0, 0.0, 0.0, 1.0);
vec2 v_UV1          : TEXCOORD0 = vec2(0.0, 0.0);
vec2 v_UV2          : TEXCOORD1 = vec2(0.0, 0.0);
vec4 v_WorldN_PX    : TEXCOORD2 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_WorldB_PY    : TEXCOORD3 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_WorldT_PZ    : TEXCOORD4 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_PosP         : TEXCOORD5 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_CustomData1  : TEXCOORD6 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_CustomData2  : TEXCOORD7 = vec4(0.0, 0.0, 0.0, 0.0);

vec3 a_position  : POSITION;
vec3 a_normal	 : NORMAL;
vec3 a_bitangent : BITANGENT;
vec3 a_tangent	 : TANGENT;
vec2 a_texcoord0 : TEXCOORD0;
vec2 a_texcoord1 : TEXCOORD1;
vec4 a_color0    : COLOR0;
vec4 a_texcoord2 : TEXCOORD2;
vec4 a_texcoord3 : TEXCOORD3;