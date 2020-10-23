#include "font_manager.h"
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>

#define STB_TRUETYPE_IMPLEMENTATION
#include <stb/stb_truetype.h>

/*
	F->priority is a circular linked list for the LRU cache.
	F->hash is for lookup with [font, codepoint].
*/

#define COLLISION_STEP 7
#define DISTANCE_OFFSET 5
#define ORIGINAL_SIZE (FONT_MANAGER_GLYPHSIZE - DISTANCE_OFFSET * 2)

void
font_manager_init(struct font_manager *F) {
	F->version = 1;
	F->count = 0;
	F->font_number = 0;
// init priority list
	int i;
	for (i=0;i<FONT_MANAGER_SLOTS;i++) {
		F->priority[i].prev = i+1;
		F->priority[i].next = i-1;
	}
	int lastslot = FONT_MANAGER_SLOTS-1;
	F->priority[0].next = lastslot;
	F->priority[lastslot].prev = 0;
	F->list_head = lastslot;
// init hash
	for (i=0;i<FONT_MANAGER_SLOTS;i++) {
		F->slots[i].codepoint_ttf = -1;
	}
	for (i=0;i<FONT_MANAGER_HASHSLOTS;i++) {
		F->hash[i] = -1;	// empty slot
	}
}

int
font_manager_font_num(struct font_manager *F, const void *ttfbuffer){
	return stbtt_GetNumberOfFonts(ttfbuffer);
}

static inline int
codepoint_ttf(int font, int codepoint) {
	return (font << 24 | codepoint);
}

static inline int
hash(int value) {
	return (value * 0xdeece66d + 0xb) % FONT_MANAGER_HASHSLOTS;
}

static int
hash_lookup(struct font_manager *F, int cp) {
	int slot;
	int position = hash(cp);
	while ((slot = F->hash[position]) >= 0) {
		struct font_slot * s = &F->slots[slot];
		if (s->codepoint_ttf == cp)
			return slot;
		position = (position + COLLISION_STEP) % FONT_MANAGER_HASHSLOTS;
	}
	return -1;
}

static void rehash(struct font_manager *F);

static void
hash_insert(struct font_manager *F, int cp, int slotid) {
	++F->count;
	if (F->count > FONT_MANAGER_SLOTS + FONT_MANAGER_SLOTS/2) {
		rehash(F);
	}
	int position = hash(cp);
	int slot;
	while ((slot = F->hash[position]) >= 0) {
		struct font_slot * s = &F->slots[slot];
		if (s->codepoint_ttf < 0)
			break;
		assert(s->codepoint_ttf != cp);

		position = (position + COLLISION_STEP) % FONT_MANAGER_HASHSLOTS;
	}
	F->hash[position] = slotid;
	F->slots[slotid].codepoint_ttf = cp;
}

static void
rehash(struct font_manager *F) {
	int i;
	for (i=0;i<FONT_MANAGER_HASHSLOTS;i++) {
		F->hash[i] = -1;	// reset slots
	}
	F->count = 0;
	int count = 0;
	for (i=0;i<FONT_MANAGER_SLOTS;i++) {
		int cp = F->slots[i].codepoint_ttf;
		if (cp >= 0) {
			assert(++count <= FONT_MANAGER_SLOTS);
			hash_insert(F, cp, i);
		}
	}
}

static void
remove_node(struct font_manager *F, struct priority_list *node) {
	struct priority_list *prev_node = &F->priority[node->prev];
	struct priority_list *next_node = &F->priority[node->next];
	prev_node->next = node->next;
	next_node->prev = node->prev;
}

static void
touch_slot(struct font_manager *F, int slotid) {
	struct priority_list *node = &F->priority[slotid];
	node->version = F->version;
	if (slotid == F->list_head)
		return;
	remove_node(F, node);
	// insert before head
	int head = F->list_head;
	int tail = F->priority[head].prev;
	node->prev = tail;
	node->next = head;
	struct priority_list *head_node = &F->priority[head];
	struct priority_list *tail_node = &F->priority[tail];
	head_node->prev = slotid;
	tail_node->next = slotid;
	F->list_head = slotid;
}

// 1 exist in cache. 0 not exist in cache , call font_manager_update. -1 failed.
int
font_manager_touch(struct font_manager *F, int font, int codepoint, struct font_glyph *glyph) {
	int cp = codepoint_ttf(font, codepoint);
	int slot = hash_lookup(F, cp);
	if (slot >= 0) {
		touch_slot(F, slot);
		struct font_slot *s = &F->slots[slot];
		glyph->offset_x = s->offset_x;
		glyph->offset_y = s->offset_y;
		glyph->advance_x = s->advance_x;
		glyph->advance_y = s->advance_y;
		glyph->w = s->w;
		glyph->h = s->h;
		glyph->u = (slot % FONT_MANAGER_SLOTLINE) * FONT_MANAGER_GLYPHSIZE;
		glyph->v = (slot / FONT_MANAGER_SLOTLINE) * FONT_MANAGER_GLYPHSIZE;

		return 1;
	}
	int last_slot = F->priority[F->list_head].prev;
	struct priority_list *last_node = &F->priority[last_slot];
	if (font < 0 || font >= F->font_number) {
		// invalid font
		memset(glyph, 0, sizeof(*glyph));
		return -1;
	}

	float scale = stbtt_ScaleForPixelHeight(&F->ttf[font], ORIGINAL_SIZE);
	int ascent, descent, lineGap;
	int advance, lsb;
	int ix0, iy0, ix1, iy1;

	stbtt_GetFontVMetrics(&F->ttf[font], &ascent, &descent, &lineGap);
	stbtt_GetCodepointHMetrics(&F->ttf[font], codepoint, &advance, &lsb);
	stbtt_GetCodepointBitmapBox(&F->ttf[font], codepoint, scale, scale, &ix0, &iy0, &ix1, &iy1);

	glyph->w = ix1-ix0 + DISTANCE_OFFSET * 2;
	glyph->h = iy1-iy0 + DISTANCE_OFFSET * 2;
	glyph->offset_x = (short)(lsb * scale) - DISTANCE_OFFSET;
	glyph->offset_y = iy0 - DISTANCE_OFFSET;
	glyph->advance_x = (short)(((float)advance) * scale + 0.5f);
	glyph->advance_y = (short)((ascent + descent + lineGap) * scale + 0.5f);
	glyph->u = 0;
	glyph->v = 0;

	if (last_node->version == F->version)	// full ?
		return -1;

	return 0;
}

static inline int
scale_font(int v, float scale, int size) {
	return ((int)(v * scale * size) + ORIGINAL_SIZE/2) / ORIGINAL_SIZE;
}

void
font_manager_fontheight(struct font_manager *F, int fontid, int size, int *ascent, int *descent, int *lineGap) {
	if (fontid < 0 || fontid >=F->font_number) {
		*ascent = 0;
		*descent = 0;
		*lineGap = 0;
	}
	float scale = stbtt_ScaleForPixelHeight(&F->ttf[fontid], ORIGINAL_SIZE);
	stbtt_GetFontVMetrics(&F->ttf[fontid], ascent, descent, lineGap);
	*ascent = scale_font(*ascent, scale, size);
	*descent = scale_font(*descent, scale, size);
	*lineGap = scale_font(*lineGap, scale, size);
}

void
font_manager_boundingbox(struct font_manager *F, int fontid, int size, int *x0, int *y0, int *x1,int *y1){
	stbtt_GetFontBoundingBox(&F->ttf[fontid], x0, y0, x1, y1);
	float scale = stbtt_ScaleForPixelHeight(&F->ttf[fontid], ORIGINAL_SIZE);
	*x0 = scale_font(*x0, scale, size);
	*y0 = scale_font(*y0, scale, size);
	*x1 = scale_font(*x1, scale, size);
	*y1 = scale_font(*y1, scale, size);
}

const char *
font_manager_update(struct font_manager *F, int font, int codepoint, struct font_glyph *glyph, uint8_t *buffer) {
	if (font < 0 || font >= F->font_number)
		return "Invalid font";
	int cp = codepoint_ttf(font, codepoint);
	int slot = hash_lookup(F, cp);
	if (slot < 0) {
		// move last node to head
		slot = F->priority[F->list_head].prev;
		struct priority_list *last_node = &F->priority[slot];
		if (last_node->version == F->version) {	// full ?
			return "Too many glyph";
		}
		last_node->version = F->version;
		F->list_head = slot;
		F->slots[slot].codepoint_ttf = -1;
		hash_insert(F, cp, slot);
	}

	float scale = stbtt_ScaleForPixelHeight(&F->ttf[font], ORIGINAL_SIZE);

	int width, height, xoff, yoff;

	unsigned char *tmp = stbtt_GetCodepointSDF(&F->ttf[font], scale, codepoint, DISTANCE_OFFSET, 180, 36.0f, &width, &height, &xoff, &yoff);
	if (tmp == NULL){
		return NULL;
	}
	int size = width * height;
	int gsize = glyph->w * glyph->h; 
	if (size > gsize) {
		size = gsize;
	}
	memcpy(buffer, tmp, size);

	stbtt_FreeSDF(tmp, F->ttf[font].userdata);

	struct font_slot *s = &F->slots[slot];
	s->codepoint_ttf = cp;
	s->offset_x = glyph->offset_x;
	s->offset_y = glyph->offset_y;
	s->advance_x = glyph->advance_x;
	s->advance_y = glyph->advance_y;
	s->w = glyph->w;
	s->h = glyph->h;

	glyph->u = (slot % FONT_MANAGER_SLOTLINE) * FONT_MANAGER_GLYPHSIZE;
	glyph->v = (slot / FONT_MANAGER_SLOTLINE) * FONT_MANAGER_GLYPHSIZE;

	return NULL;
}

void
font_manager_flush(struct font_manager *F) {
	++F->version;
}

static int
fm_addfont(struct font_manager *F, const void *ttfbuffer, int offset){
	if (F->font_number >= FONT_MANAGER_MAXFONT || offset < 0)
		return -1;
	int fontid = F->font_number;
	if (!stbtt_InitFont(&F->ttf[fontid], (const unsigned char *)ttfbuffer, offset))
		return -1;
	++F->font_number;
	return fontid;
}

int
font_manager_addfont(struct font_manager *F, const void *ttfbuffer, int index) {
	return fm_addfont(F, ttfbuffer, stbtt_GetFontOffsetForIndex(ttfbuffer,index));
}

int
font_manager_addfont_with_family(struct font_manager *F, const void *ttfbuffer, const char* family, FamilyFlag flags) {
	return fm_addfont(F, ttfbuffer, stbtt_FindMatchingFont(ttfbuffer, family, (int)flags));
}

int
font_manager_name_table_num(struct font_manager *F, int fontid, int *offset){
	const stbtt_fontinfo *font = &F->ttf[fontid];
	stbtt_uint8 *fc = font->data;
    stbtt_uint32 nm = stbtt__find_table(fc, font->fontstart, "name");
    if (!nm)
		return -1;

	*offset = nm;
	return ttUSHORT(fc+nm+2);
}

// static void
// list_tt_name_table(const stbtt_fontinfo *font, int idx, struct name_item *ni){
//     stbtt_int32 count,stringOffset;
//     stbtt_uint8 *fc = font->data;
//     stbtt_uint32 offset = font->fontstart;
//     stbtt_uint32 nm = stbtt__find_table(fc, offset, "name");
//     if (!nm) 
//         return ;
 
//     count = ttUSHORT(fc+nm+2);
//     stringOffset = nm + ttUSHORT(fc+nm+4);
//     const char* ntp = (const char*)(fc + stringOffset);
//     //for (i=0; i < count; ++i) {
//         stbtt_uint32 loc = nm + 6 + 12 * idx;

//         ni->platformID  = ttUSHORT(fc+loc+0); 
//         ni->encodingID  = ttUSHORT(fc+loc+2);
//         ni->languageID  = ttUSHORT(fc+loc+4);
//         ni->nameID      = ttUSHORT(fc+loc+6);

//         ni->namelen 	= ttUSHORT(fc+loc+8);
//         ni->name		= ntp+ttUSHORT(fc+loc+10);
//     //}
// }

void
font_manager_name_item(struct font_manager *F, int fontid, int offset, int idx, struct name_item *ni){
	const stbtt_fontinfo *font = &F->ttf[fontid];

	stbtt_uint8 *fc = font->data;
	int str_offset = offset + ttUSHORT(fc+offset+4);
	const char* ntp = (const char*)(fc + str_offset);

	stbtt_uint32 loc = offset + 6 + 12 * idx;

	ni->platformID  = ttUSHORT(fc+loc+0); 
	ni->encodingID  = ttUSHORT(fc+loc+2);
	ni->languageID  = ttUSHORT(fc+loc+4);
	ni->nameID      = ttUSHORT(fc+loc+6);

	ni->namelen 	= ttUSHORT(fc+loc+8);
	ni->name    	= ntp+ttUSHORT(fc+loc+10);
}

int
unicode_bigendian_to_utf8(const uint16_t *u, uint32_t len, uint8_t *utf8){
	uint8_t* b = utf8;
	for (uint32_t ii=0; ii < len; ++ii){
		uint16_t c = (0xff00&u[ii])>>8|(0x00ff&u[ii])<<8; // to little endian

		if (c<0x80) *b++=c;
		else if (c<0x800) *b++=192+c/64, *b++=128+c%64;
		else if (c-0xd800u<0x800) return -2;
		else if (c<0x10000) *b++=224+c/4096, *b++=128+c/64%64, *b++=128+c%64;
		else if (c<0x110000) *b++=240+c/262144, *b++=128+c/4096%64, *b++=128+c/64%64, *b++=128+c%64;
		else return -1;
	}
	return (b - utf8);
}

int
font_manager_is_unicode_name_item(struct font_manager *F, struct name_item *ni){
	return ( ni->platformID == 0 || 
		(ni->platformID == 3 && ni->encodingID == 1) ||
		(ni->platformID == 3 && ni->encodingID== 10));
}

// extern void
// cvt_name_info(const char* name, size_t numbytes, char *newname, size_t maxbytes, int needcvt);

static const uint16_t NAMEID_family = 1;
static const uint16_t NAMEID_style = 2;

static int
get_name_info(struct stbtt_fontinfo * fi, 
	uint16_t platformID, uint16_t encodingID, uint16_t languageID, uint16_t nameID, 
	char *name, uint8_t maxbytes){

	int namelen = 0;
	const char* n = stbtt_GetFontNameString(fi, &namelen, platformID, encodingID, languageID, nameID);
	if (n) {
		if (is_unicode(platformID, encodingID)) {
			if (maxbytes > namelen){
				return unicode_bigendian_to_utf8((const uint16_t*)n, namelen / 2, name);
			}
		} else {
			if (maxbytes > namelen){
				memcpy(name, n, namelen < maxbytes  ?  namelen : maxbytes);
				return namelen;
			}
		}
	}
	return -1;
}

int 
fm_name_item(struct font_manager *F, int fontid, uint16_t nameid, char name[64]){
	struct stbtt_fontinfo * fi = &F->ttf[fontid];

	static const uint16_t platforms[] = {
		STBTT_PLATFORM_ID_MAC,
		STBTT_PLATFORM_ID_UNICODE,
		STBTT_PLATFORM_ID_MICROSOFT,
	};

#define COUNTOF(_A) (sizeof((_A))/sizeof(_A[0]))

	for (int pidx=0; pidx < COUNTOF(platforms); ++pidx){
		const uint16_t platformID = platforms[pidx];
		switch (platformID){
		case STBTT_PLATFORM_ID_UNICODE:{
			static const uint16_t encodings[] = {
				STBTT_UNICODE_EID_UNICODE_1_0,
				STBTT_UNICODE_EID_UNICODE_1_1,
				STBTT_UNICODE_EID_ISO_10646,
				STBTT_UNICODE_EID_UNICODE_2_0_BMP,
				STBTT_UNICODE_EID_UNICODE_2_0_FULL,
			};
			const uint16_t languageID = 0;	// always 0
			for (int e=0; e<sizeof(encodings)/sizeof(encodings[0]); ++e){
				const int namelen = get_name_info(fi, platformID, encodings[e], languageID, nameid, name, 64);
				if (namelen > 0)
					return namelen;
			}
			break;
		}
		case STBTT_PLATFORM_ID_MAC:{
			static const uint16_t encodings[] = {
				STBTT_MAC_EID_ROMAN, 		STBTT_MAC_EID_ARABIC,
				STBTT_MAC_EID_JAPANESE,   	STBTT_MAC_EID_HEBREW,
				STBTT_MAC_EID_CHINESE_TRAD, STBTT_MAC_EID_GREEK,
				STBTT_MAC_EID_KOREAN, 		STBTT_MAC_EID_RUSSIAN,
			};
			static const uint16_t languageIDs[] = {
				STBTT_MAC_LANG_ENGLISH, STBTT_MAC_LANG_CHINESE_SIMPLIFIED, STBTT_MAC_LANG_CHINESE_TRAD,
			};
			for (int e=0; e<sizeof(encodings)/sizeof(encodings[0]); ++e){
				for (int l=0; l<sizeof(languageIDs)/sizeof(languageIDs[0]); ++l){
					const int namelen = get_name_info(fi, platformID, encodings[e], languageIDs[l], nameid, name, 64);
					if (namelen > 0){
						return namelen;
					}
				}
			}
			break;
		}
		case STBTT_PLATFORM_ID_MICROSOFT:
			static const uint16_t languageIDs[] = {
				STBTT_MS_LANG_ENGLISH, STBTT_MS_LANG_CHINESE,
			};
			static const uint16_t encodings[] = {
				STBTT_MS_EID_SYMBOL,
				STBTT_MS_EID_UNICODE_BMP,
				STBTT_MS_EID_SHIFTJIS,
				STBTT_MS_EID_UNICODE_FULL,
			};
			for (int e=0; e<sizeof(encodings)/sizeof(encodings[0]); ++e){
				for (int l=0; l<sizeof(languageIDs)/sizeof(languageIDs[0]); ++l){
					const int namelen = get_name_info(fi, platformID, encodings[e], languageIDs[l], nameid, name, 64);
					if (namelen > 0){
						return namelen;
					}
				}
			}
			break;
		case STBTT_PLATFORM_ID_ISO:
		default:
			return -2;
		}
	}
	
	return -1;
}

int 
font_manager_style_name(struct font_manager *F, int fontid, char style[64]){
	return fm_name_item(F, fontid, NAMEID_style, style);
}

int 
font_manager_family_name(struct font_manager *F, int fontid, char family[64]){
	return fm_name_item(F, fontid, NAMEID_family, family);
}

int
font_manager_rebindfont(struct font_manager *F, int fontid, const void *ttfbuffer) {
	if (fontid < 0 || fontid >= F->font_number)
		return -1;
	if (!stbtt_InitFont(&F->ttf[fontid], (const unsigned char *)ttfbuffer, 0)) {
		F->ttf[fontid] = F->ttf[0];
		return -1;
	}
	return fontid;
}

static inline void
scale(short *v, int size) {
	*v = (*v * size + ORIGINAL_SIZE/2) / ORIGINAL_SIZE;
}

static inline void
uscale(uint16_t *v, int size) {
	*v = (*v * size + ORIGINAL_SIZE/2) / ORIGINAL_SIZE;
}

void
font_manager_scale(struct font_manager *F, struct font_glyph *glyph, int size) {
	(void)F;
	scale(&glyph->offset_x, size);
	scale(&glyph->offset_y, size);
	scale(&glyph->advance_x, size);
	scale(&glyph->advance_y, size);
	uscale(&glyph->w, size);
	uscale(&glyph->h, size);
}

#if 0

void fetch_tt_font_name_table(struct font_manager *F, int fontid){
	int offset;
	int num_nt = font_manager_name_table_num(F, fontid, &offset);
	for(int idx=0; idx<num_nt;++idx){
		struct name_item ni;
		font_manager_name_item(F, fontid, offset, idx, &ni);
		char*name = (char*)malloc(sizeof(char) * ni.namelen);
		uint16_t namelen_utf8;
		font_manager_name_item_to_utf8(F, &ni, name, &namelen_utf8);
		printf(name);
		free(name);
	}
}
#include <stdlib.h>
#include <stdio.h>
int
main() {
	FILE * f = fopen("msyh.ttc", "rb");
	fseek(f, 0, SEEK_END);
	int sz = ftell(f);
	fseek(f, 0, SEEK_SET);
	void * ttf = malloc(sz);
	int read = fread(ttf, 1, sz, f);
	fprintf(stderr, "read %d %d\n", sz, read);
	fclose(f);
	struct font_manager F;
	font_manager_init(&F);
	int font = font_manager_addfont(&F, ttf);
	fprintf(stderr,"load font %d\n", font);

	struct font_glyph g;
	font_manager_touch(&F, font, 0x6C49, &g);

	unsigned char buffer[g.w * g.h];

	const char * err = font_manager_update(&F, font, 0x6C49, &g, buffer);

	if (err != NULL) {
		fprintf(stderr, "Error : %s\n", err);
	} else {
		fprintf(stderr, "x=%d y=%d (%d x %d) (%d x %d), u=%d v=%d",
			g.offset_x, g.offset_y,
			g.advance_x, g.advance_y,
			g.w, g.h,
			g.u, g.v);

		printf("P2\n%d %d\n255\n", g.w, g.h);
		int i,j;
		for (i=0;i<g.h;i++) {
			for (j=0;j<g.w;j++) {
				printf("%d ", buffer[i*g.w+j]);
			}
			printf("\n");
		}

	}

	fetch_tt_font_name_table(&F, font);

	return 0;
}

#endif