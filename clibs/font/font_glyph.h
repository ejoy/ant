#ifndef __FONT_GLYPH_H__
#define __FONT_GLYPH_H__
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

#endif //__FONT_GLYPH_H__