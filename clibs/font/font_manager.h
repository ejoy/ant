#ifndef lua_bgfx_font_manager_h
#define lua_bgfx_font_manager_h

#include <stb/stb_truetype.h>
#include <stdint.h>

#define FONT_MANAGER_TEXSIZE 2048
#define FONT_MANAGER_GLYPHSIZE 32

#define FONT_MANAGER_SLOTLINE (FONT_MANAGER_TEXSIZE/FONT_MANAGER_GLYPHSIZE)
#define FONT_MANAGER_SLOTS (FONT_MANAGER_SLOTLINE*FONT_MANAGER_SLOTLINE)
#define FONT_MANAGER_HASHSLOTS (FONT_MANAGER_SLOTS * 2)
#define FONT_MANAGER_MAXFONT 8

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

struct font_manager {
	int version;
	int count;
	int16_t list_head;
	int16_t font_number;
	struct stbtt_fontinfo ttf[FONT_MANAGER_MAXFONT];
	struct font_slot slots[FONT_MANAGER_SLOTS];
	struct priority_list priority[FONT_MANAGER_SLOTS];
	int16_t hash[FONT_MANAGER_HASHSLOTS];
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

#ifdef _MSC_VER 
#	ifdef FONT_EXPORT
#define FONT_API __declspec(dllexport)
#	else //!FONT_EXPORT
#define FONT_API __declspec(dllimport)
#	endif //FONT_EXPORT
#else
#define FONT_API
#endif 

void font_manager_init(struct font_manager *);

FONT_API int font_manager_font_num(struct font_manager *F, const void *ttfbuffer);
FONT_API int font_manager_addfont(struct font_manager *, const void *ttfbuffer, int index);
typedef enum {
	FF_Blod			= 0x01,
	FF_ITALIC		= 0x02,
	FF_UNDERSCORE	= 0x04,
	FF_NONE			= 0x08,
}FamilyFlag;
FONT_API int font_manager_addfont_with_family(struct font_manager *F, const void *ttfbuffer, const char* family, FamilyFlag flags);
FONT_API int font_manager_rebindfont(struct font_manager *, int fontid, const void *ttfbuffer);
FONT_API void font_manager_fontheight(struct font_manager *F, int fontid, int size, int *ascent, int *descent, int *lineGap);

// 1 exist in cache. 0 not exist in cache, call font_manager_update. -1 failed.
FONT_API int font_manager_touch(struct font_manager *, int font, int codepoint, struct font_glyph *glyph);
// buffer size should be [ glyph->w * glyph->h ] ,  NULL succ , otherwise returns error msg
FONT_API const char * font_manager_update(struct font_manager *, int font, int codepoint, struct font_glyph *glyph, uint8_t *buffer);
FONT_API void font_manager_flush(struct font_manager *);
FONT_API void font_manager_scale(struct font_manager *F, struct font_glyph *glyph, int size);

FONT_API int font_manager_style_name(struct font_manager *F, int fontid, char style[64]);
FONT_API int font_manager_family_name(struct font_manager *F, int fontid, char family[64]);

// example: see 'font_manager.c'
FONT_API int font_manager_name_table_num(struct font_manager *F, int fontid, int *offset);
struct name_item {
	uint16_t platformID;
	uint16_t encodingID;
	uint16_t languageID;
	uint16_t nameID;
	const char* name;	// 'name' maybe bigendian unicode char, platformID and encodingID determine what encoding 'name' is
	uint16_t namelen;	// 'namlen' is 'name' buffer size
};
FONT_API void font_manager_name_item(struct font_manager *F, int fontid, int offset, int idx, struct name_item *ni);

#define is_unicode(_PLATID, _ENCODINGID) (_PLATID == STBTT_PLATFORM_ID_UNICODE ||\
										(_PLATID == STBTT_PLATFORM_ID_MICROSOFT && _ENCODINGID == STBTT_MS_EID_UNICODE_BMP)\
										||(_PLATID == STBTT_PLATFORM_ID_MICROSOFT && _ENCODINGID == STBTT_MS_EID_UNICODE_FULL))
#define name_item_is_unicode(ni) is_unicode((ni)->platformID, (ni)->encodingID)
FONT_API int unicode_bigendian_to_utf8(const uint16_t *u, uint32_t len, uint8_t *utf8);
#endif
