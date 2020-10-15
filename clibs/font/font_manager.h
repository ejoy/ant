#ifndef lua_bgfx_font_manager_h
#define lua_bgfx_font_manager_h

#include <stb/stb_truetype.h>

#define FONT_MANAGER_TEXSIZE 2048
#define FONT_MANAGER_GLYPHSIZE 32

#define FONT_MANAGER_SLOTLINE (FONT_MANAGER_TEXSIZE/FONT_MANAGER_GLYPHSIZE)
#define FONT_MANAGER_SLOTS (FONT_MANAGER_SLOTLINE*FONT_MANAGER_SLOTLINE)
#define FONT_MANAGER_HASHSLOTS (FONT_MANAGER_SLOTS * 2)
#define FONT_MANAGER_MAXFONT 8

struct font_slot {
	int codepoint_ttf;	// high 8 bits (ttf index)
	short offset_x;
	short offset_y;
	short advance_x;
	short advance_y;
	unsigned short w;
	unsigned short h;
};

struct priority_list {
	int version;
	short prev;
	short next;
};

struct font_manager {
	int version;
	int count;
	short list_head;
	short font_number;
	struct stbtt_fontinfo ttf[FONT_MANAGER_MAXFONT];
	struct font_slot slots[FONT_MANAGER_SLOTS];
	struct priority_list priority[FONT_MANAGER_SLOTS];
	short hash[FONT_MANAGER_HASHSLOTS];
};

struct font_glyph {
	short offset_x;
	short offset_y;
	short advance_x;
	short advance_y;
	unsigned short w;
	unsigned short h;
	unsigned short u;
	unsigned short v;
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

FONT_API int font_manager_addfont(struct font_manager *, const void *ttfbuffer, int index);
typedef enum {
	FF_Blod			= 0x01,
	FF_ITALIC		= 0x02,
	FF_UNDERSCORE	= 0x04,
	FF_NONE			= 0x08,
}FamilyFlag;
FONT_API int font_manager_addfont_with_family(struct font_manager *F, const void *ttfbuffer, const char* family, FamilyFlag flags);
FONT_API int font_manager_family_name(struct font_manager *F, int fontid, char name[128], int *namelen);
FONT_API int font_manager_rebindfont(struct font_manager *, int fontid, const void *ttfbuffer);
FONT_API void font_manager_fontheight(struct font_manager *F, int fontid, int size, int *ascent, int *descent, int *lineGap);

// 1 exist in cache. 0 not exist in cache, call font_manager_update. -1 failed.
FONT_API int font_manager_touch(struct font_manager *, int font, int codepoint, struct font_glyph *glyph);
// buffer size should be [ glyph->w * glyph->h ] ,  NULL succ , otherwise returns error msg
FONT_API const char * font_manager_update(struct font_manager *, int font, int codepoint, struct font_glyph *glyph, unsigned char *buffer);
FONT_API void font_manager_flush(struct font_manager *);
FONT_API void font_manager_scale(struct font_manager *F, struct font_glyph *glyph, int size);


#endif
