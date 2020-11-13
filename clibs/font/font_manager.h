#ifndef font_manager_h
#define font_manager_h

#include <stb/stb_truetype.h>
#include <stdint.h>

#define FONT_MANAGER_TEXSIZE 2048
#define FONT_MANAGER_GLYPHSIZE 48

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
//     origin   |         | gggggg      g:::::g     |              |
//              |         | g:::::gg   gg:::::g     |              |
//              |         |  g::::::ggg:::::::g     |              |
//              |         |   gg:::::::::::::g      |              |
//              |         |     ggg::::::ggg        |              |
//              |         |         gggggg          |              v
//              |         +-------------------------+----------------- ymin
//              |                                   |
//              |------------- advance_x ---------->|

struct font_slot {
	int codepoint_ttf;	// high 8 bits (ttf index)
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

	struct _sdf {
		// sdf value is compute as:
		// distance: pixel(center) to glyph contour line, unit is number of pixels on sdf texture
		// 			 if pixel inside glyph contour(which mean inisde glyph), distance is positive, or is nagitive
		// sdf value = clamp(0, 255, onedge_value + pixel_dist_scale * distance) 
		//			 = clamp(0, 255, onedge_value * (1.0 + (distance/max_detect_distance)))
		// we can image that, distance is larger than max_detect_distance, if distance is nagitive, then sdfvalue must 0, otherwise it will increase the value to 255
		int		onedge_value;			// 0 .. 255
		//float	max_detect_distance;	// we make max_detect_distance equal to DISTANCE_OFFSET, because max_detect_distance should not exceed padding pixel
		float	pixel_dist_scale;		// onedge_value / max_detect_distance
	} sdf;
};

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

#ifdef FONT_EXPORT
#   ifdef FONT_IMP
#define FONT_API __declspec(dllexport)
#	else //!FONT_IMP
#define FONT_API __declspec(dllimport)
#	endif//FONT_IMP
#else //!FONT_EXPORT
#define FONT_API extern
#	endif //FONT_EXPORT

void font_manager_init(struct font_manager *, struct truetype_font *ttf, void *L);
FONT_API int font_manager_addfont_with_family(struct font_manager *F, const char* family);
FONT_API void font_manager_fontheight(struct font_manager *F, int fontid, int size, int *ascent, int *descent, int *lineGap);
FONT_API void font_manager_boundingbox(struct font_manager *F, int fontid, int size, int *x0, int *y0, int *x1, int *y1);
FONT_API int font_manager_pixelsize(struct font_manager *F, int fontid, int pointsize);
// return 0 for need updated
FONT_API int font_manager_glyph(struct font_manager *F, int fontid, int codepoint, int size, struct font_glyph *g, struct font_glyph *og);

// 1 exist in cache. 0 not exist in cache, call font_manager_update. -1 failed.
FONT_API int font_manager_touch(struct font_manager *, int font, int codepoint, struct font_glyph *glyph);
// buffer size should be [ glyph->w * glyph->h ] ,  NULL succ , otherwise returns error msg
FONT_API const char * font_manager_update(struct font_manager *, int font, int codepoint, struct font_glyph *glyph, uint8_t *buffer);
FONT_API void font_manager_flush(struct font_manager *);
FONT_API void font_manager_scale(struct font_manager *F, struct font_glyph *glyph, int size);

FONT_API float font_manager_sdf_mask(struct font_manager *F, int offset);
FONT_API float font_manager_sdf_distance(struct font_manager *F, float numpixel);
FONT_API void font_manager_sdf_onedge_value(struct font_manager *F, int onedge_value);

#endif //font_manager_h
