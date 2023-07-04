#ifndef __DEFAULT_INPUTS_STRUCTURE_SH__
#define __DEFAULT_INPUTS_STRUCTURE_SH__

struct VSInput {
	highp vec3 pos;
	lowp  vec4 color;
	mediump vec3 normal;
	mediump vec4 tangent;
	mediump vec4 weight;
	ivec4 index;
	highp vec2 uv0;
	highp vec2 uv1;
	highp vec4 idata0;
	highp vec4 idata1;
	highp vec4 idata2;
	mediump vec4 user0;
	mediump vec4 user1;
	mediump vec4 user2;
};

struct VSOutput{
	highp vec4 clip_pos;
	highp vec4 world_pos;
	lowp  vec4 color;
	mediump vec3 normal;
	mediump vec3 tangent;
	highp vec2 uv0;
	highp vec2 uv1;
    mediump vec4 user0;
	mediump vec4 user1;
	mediump vec4 user2;
	mediump vec4 user3;
	mediump vec4 user4;
};

struct FSInput{
 	highp vec4 pos;
	lowp  vec4 color;
	mediump vec3 normal;
	mediump vec3 tangent;
	highp vec2 uv0;
	highp vec2 uv1;
    mediump vec4 user0;
	mediump vec4 user1;
	mediump vec4 user2;
	mediump vec4 user3;
	mediump vec4 user4;
	mediump vec4 frag_coord; 
};

struct FSOutput{
	lowp vec4 color;
	mediump vec4 others;
};

#endif //__DEFAULT_INPUTS_STRUCTURE_SH__