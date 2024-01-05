#ifndef font_manager_h
#define font_manager_h

#include <stb/stb_truetype.h>
#include <stdint.h>
#include "fontmutex.h"
#include "font_define.h"

#define FONT_MANAGER_SLOTLINE (FONT_MANAGER_TEXSIZE/FONT_MANAGER_GLYPHSIZE)
#define FONT_MANAGER_SLOTS (FONT_MANAGER_SLOTLINE*FONT_MANAGER_SLOTLINE)
#define FONT_MANAGER_HASHSLOTS (FONT_MANAGER_SLOTS * 2)

// --------------
//
//                       xmin                     xmax
//                        |                         |
//                        |<-------- width -------->|
//                        |                         |
//              |         +-------------------------+----------------- ymax
//              |         |    ggggggggg   ggggg    |     ^        ^
//              |         |   g:::::::::ggg::::g    |     |        |
//              |         |  g:::::::::::::::::g    |     |        |
//              |         | g::::::ggggg::::::gg    |     |        |
//              |         | g:::::g     g:::::g     |     |        |
//    offset_x -|-------->| g:::::g     g:::::g     |  offset_y    |
//              |         | g:::::g     g:::::g     |     |        |
//              |         | g::::::g    g:::::g     |     |        |
//              |         | g:::::::ggggg:::::g     |     |        |
//              |         |  g::::::::::::::::g     |     |      height
//              |         |   gg::::::::::::::g     |     |        |
//  baseline ---*---------|---- gggggggg::::::g-----*--------      |
//            / |         |             g:::::g     |              |
//     origin   |         |
//              |         | g:::::gg   gg:::::g     |              |
//              |         | g:::::gg   gg:::::g     |              |
//              |         |  g::::::ggg:::::::g     |              |
//              |         |   gg:::::::::::::g      |              |
//              |         |     ggg::::::ggg        |              |
//              |         |         gggggg          |              v
//              |         +-------------------------+----------------- ymin
//              |                                   |
//              |------------- advance_x ---------->|

struct font_slot {
	uint32_t codepoint_key;	// high 8 bits (ttf index)
	int16_t offset_x;
	int16_t offset_y;
	int16_t advance_x;
	int16_t advance_y;
	uint16_t w;
	uint16_t h;
};

struct priority_list {
	int version;
	int16_t prev;
	int16_t next;
};

struct truetype_font;

struct font_manager {
	int version;
	int count;
	int16_t list_head;
	struct font_slot slots[FONT_MANAGER_SLOTS];
	struct priority_list priority[FONT_MANAGER_SLOTS];
	int16_t hash[FONT_MANAGER_HASHSLOTS];
	struct truetype_font* ttf;
	void *L;
	int dpi_perinch;
	struct mutex_t* mutex;
	uint16_t texture;

	uint16_t (*font_manager_texture)(struct font_manager *F);
	void (*font_manager_import)(struct font_manager *F, void* fontdata);
	int  (*font_manager_addfont_with_family)(struct font_manager *F, const char* family);

	void (*font_manager_fontheight)(struct font_manager *F, int fontid, int size, int *ascent, int *descent, int *lineGap);
	int  (*font_manager_pixelsize)(struct font_manager *F, int fontid, int pointsize);
	// return 0 for need updated
	const char* (*font_manager_glyph)(struct font_manager *F, int fontid, int codepoint, int size, struct font_glyph *g, struct font_glyph *og);

	// 1 exist in cache. 0 not exist in cache, call font_manager_update. -1 failed.
	int  (*font_manager_touch)(struct font_manager *, int font, int codepoint, struct font_glyph *glyph);
	// buffer size should be [ glyph->w * glyph->h ] ,  NULL succ , otherwise returns error msg
	const char* (*font_manager_update)(struct font_manager *, int font, int codepoint, struct font_glyph *glyph, uint8_t *buffer);
	void (*font_manager_flush)(struct font_manager *);
	void (*font_manager_scale)(struct font_manager *F, struct font_glyph *glyph, int size);
	int (*font_manager_underline)(struct font_manager *F, int fontid, int size, float *underline_position, float *thickness);

	float (*font_manager_sdf_mask)(struct font_manager *F);
	float (*font_manager_sdf_distance)(struct font_manager *F, uint8_t numpixel);
};

void font_manager_init(struct font_manager *);
void font_manager_init_lua(struct font_manager *, void *L);
void* font_manager_release_lua(struct font_manager *);
void font_manager_import(struct font_manager *F, void* fontdata);

uint16_t font_manager_texture(struct font_manager *F);
int font_manager_addfont_with_family(struct font_manager *F, const char* family);
void font_manager_fontheight(struct font_manager *F, int fontid, int size, int *ascent, int *descent, int *lineGap);
int font_manager_pixelsize(struct font_manager *F, int fontid, int pointsize);
const char* font_manager_glyph(struct font_manager *F, int fontid, int codepoint, int size, struct font_glyph *g, struct font_glyph *og);
int font_manager_touch(struct font_manager *, int font, int codepoint, struct font_glyph *glyph);
const char * font_manager_update(struct font_manager *, int font, int codepoint, struct font_glyph *glyph, uint8_t *buffer);
void font_manager_flush(struct font_manager *);
void font_manager_scale(struct font_manager *F, struct font_glyph *glyph, int size);
int font_manager_underline(struct font_manager *F, int fontid, int size, float *underline_position, float *thickness);
float font_manager_sdf_mask(struct font_manager *F);
float font_manager_sdf_distance(struct font_manager *F, uint8_t numpixel);

#endif //font_manager_h
