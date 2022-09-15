#pragma once

#define FONT_MANAGER_TEXSIZE 2048
#define FONT_MANAGER_GLYPHSIZE 48
#define FONT_POSTION_FIX_POINT  8

#define MAX_FONT_NUM 64

#include <stdint.h>
struct font_glyph {
	int16_t offset_x;
	int16_t offset_y;
	int16_t advance_x;
	int16_t advance_y;
	uint16_t w;
	uint16_t h;
	uint16_t u;
	uint16_t v;
};

#define IMAGE_FONT_MASK 0x40    //7 bit
#define FONT_ID_MASK    0x3F    //low 6 bits

static inline uint32_t
codepoint_key(int font, int codepoint) {
	return (uint32_t)((font << 24) | codepoint);
}

static inline int
font_index(int fontid){
    return FONT_ID_MASK&((uint8_t)fontid);
}

