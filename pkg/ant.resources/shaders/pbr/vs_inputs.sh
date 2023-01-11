#ifndef __VS_INPUTS_SH__
#define __VS_INPUTS_SH__

struct VSInput {
	highp vec3 pos;
	lowp vec4 color;
	mediump vec3 normal;
	mediump vec4 tangent;
	highp vec2 uv0;
	highp vec2 uv1;
	highp ivec4 indices;
	highp vec4 weights;
};

struct VSOutput{
	highp vec4 pos;
	lowp vec4 color;
	mediump vec3 normal;
	mediump vec3 tangent;
	highp vec2 uv0;
	highp vec2 uv1;
};

#endif //__VS_INPUTS_SH__