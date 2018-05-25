#define LUA_LIB

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <bgfx/c99/bgfx.h>

#include "luabgfx.h"

#define NK_INCLUDE_FONT_BAKING
#define NK_INCLUDE_DEFAULT_FONT

#define NK_IMPLEMENTATION
#define NK_INCLUDE_FIXED_TYPES
#define NK_INCLUDE_STANDARD_VARARGS
#define NK_INCLUDE_DEFAULT_ALLOCATOR
#define NK_PRIVATE

// nuklear global stack 
#define NK_BUTTON_BEHAVIOR_STACK_SIZE   32
#define NK_FONT_STACK_SIZE              32
#define NK_STYLE_ITEM_STACK_SIZE        256
#define NK_FLOAT_STACK_SIZE             256
#define NK_VECTOR_STACK_SIZE            128
#define NK_FLAGS_STACK_SIZE             64
#define NK_COLOR_STACK_SIZE             256

#define NK_INCLUDE_VERTEX_BUFFER_OUTPUT

#include "nuklear/nuklear.h"

#define NK_ANT_EDIT_BUFFER_LEN      (128 * 1024)
#define NK_ANT_COMBOBOX_MAX_ITEMS   1024
#define NK_ANT_MAX_RATIOS           512
#define NK_ANT_MAX_FONTS            16
#define NK_ANT_MAX_CHARSET			16

#define MY_DEBUG 

#define IMAGE_LIB

#ifdef  IMAGE_LIB 
#define  STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
unsigned char *
loadImage( char const *filename, int *x, int *y, int *comp, int req_comp) {
    return  stbi_load(filename, x, y, comp, req_comp);
}
void 
freeImage(void *data) {
    stbi_image_free(data);
}
static int  
lnk_load_image(lua_State *L) 
{
	const char *filename = luaL_checkstring(L,1);
	int w,h,n;
    unsigned char *data = loadImage(filename, &w, &h, &n, 0);
    if (!data) 
        printf_s("can not load image %s.\n",filename);

    int size = w * h *n;
    const bgfx_memory_t *m = bgfx_alloc(size);    
	memcpy(m->data,data,size);
    bgfx_texture_handle_t tex = bgfx_create_texture_2d(w,h,0,1,BGFX_TEXTURE_FORMAT_RGBA8,0,m);
    freeImage(data);

#ifdef MY_DEBUG 
	printf("std bgfx load =%d (%d,%d)\n",tex.idx,w,h);
#endif 

	struct nk_image image; 
    image.handle.id = (tex.idx);   //int
    image.w = w;
    image.h = h;
    image.region[0] = image.region[1] = 0;
    image.region[2] = w;
    image.region[3] = h;

#ifdef MY_DEBUG 
	printf("return image id = %d(%d,%d)\n",image.handle.id,w,h);
#endif 

	lua_newtable(L);
	lua_pushnumber(L,image.handle.id);
	lua_setfield(L,-2,"handle");
	lua_pushnumber(L,image.w);
	lua_setfield(L,-2,"w");
	lua_pushnumber(L,image.h);
	lua_setfield(L,-2,"h");
	lua_pushnumber(L,image.region[0]);
	lua_setfield(L,-2,"x0");
	lua_pushnumber(L,image.region[1]);
	lua_setfield(L,-2,"y0");
	lua_pushnumber(L,image.region[2]);
	lua_setfield(L,-2,"x1");
	lua_pushnumber(L,image.region[3]);
	lua_setfield(L,-2,"y1");

	return 1;
}
#endif 


struct lnk_ui_vertex {
	float position[2];
	float uv[2];
	nk_byte col[4];
};
struct charset {
	char name[64];
	nk_rune *rune; 
};

struct lnk_context {
	int init;
	int width;
	int height;
	struct nk_font **fonts;
	int num_fonts;

	struct nk_buffer cmds;	// draw commands
	struct nk_font_atlas atlas;
	struct nk_context context;
	struct nk_convert_config cfg;

	// bgfx handles
	uint64_t state;
	uint32_t rgba;
	int view;	// bgfx view id
	bgfx_program_handle_t		prog;
	bgfx_uniform_handle_t		tid;
	bgfx_texture_handle_t		fontexture;
	bgfx_dynamic_vertex_buffer_handle_t	vb;
	bgfx_dynamic_index_buffer_handle_t	ib;

	// ui control temp buffer
	char *	     		 		edit_buf;
	char ** 		 		 	combobox_items;
	// style setting 
	float *		 		 		layout_ratios;                
	int    	     		 		num_layout_ratios;   
	// charset 
	struct charset 				*charsets;
	int							num_charsets;
	// scroll value todo...
};

static struct lnk_context *get_context(lua_State *L);

// charset manager 管理最多 NK_ANT_MAX_CHARSET 个字符集合，超过的将被舍弃
void 
lnk_charset_init(struct lnk_context *lc) {
	lc->num_charsets = 0;
	lc->charsets = malloc(sizeof(struct charset)* NK_ANT_MAX_CHARSET );
	memset(&lc->charsets[0],0x0,sizeof(struct charset)*NK_ANT_MAX_CHARSET );
}

void 
lnk_charset_shutdown(struct lnk_context *lc) {
	int i =0 ;
	for(i=0;i<lc->num_charsets && i< NK_ANT_MAX_CHARSET ;i++) {
		if(lc->charsets[i].rune)
			free(lc->charsets[i].rune);
	}
	free(lc->charsets);
	lc->num_charsets = 0;
}

// control buffer
// 编辑控件，组合框等缓冲区
static void 
lnk_uicache_init(lua_State *L,struct lnk_context *lc )  {
	// editor cache system , 注意进一步确定使用方法!
	lc->edit_buf = (char *) malloc( NK_ANT_EDIT_BUFFER_LEN );
	lc->combobox_items = (char **) malloc(sizeof(char*)*NK_ANT_COMBOBOX_MAX_ITEMS);
	lc->layout_ratios = (float*) malloc(sizeof(float)*NK_ANT_MAX_RATIOS);
	lc->num_layout_ratios = 0;
}

static void 
lnk_uicache_shutdown(lua_State *L,struct lnk_context *lc) {
	free(lc->edit_buf);
	free(lc->combobox_items);
	free(lc->layout_ratios);
}

// 风格设置的栈
// for setStyle,unsetStyle 
// 注册 nuklear 的全局属性表,font,image,stack,保留lua使用者的风格，字体，图象信息   
void 
lnk_stack_init(lua_State *L,struct lnk_context *lc) {
   //  nuklear = { font  = { } , image = { } , stack = { }   
	lua_newtable(L);
	lua_pushvalue(L,-1);      					   // copy stack top table and push stack 
	lua_setfield(L,LUA_REGISTRYINDEX,"nuklear");   // table name = nuklear
	lua_newtable(L);
	lua_setfield(L,-2,"stack");                    //  stack table in nuklear table

	//lua_newtable(L);
	//lua_setfield(L,-2,"font");                   //  font table in nuklear table
	//lua_newtable(L);
	//lua_setfield(L,-2,"image");                  //  image table in nuklear table

	//int luaL_ref (lua_State *L, int t);
	//lua_rawgeti(L, LUA_REGISTRYINDEX, r);
	//void luaL_unref (lua_State *L, int t, int ref);
}
void 
lnk_stack_shutdown(lua_State* L,struct lnk_context *lc) {
	// 退出vm，是否存在释放一说?
	lua_pushnil(L);
	lua_setfield(L, LUA_REGISTRYINDEX, "nuklear");
}

 

static int
lnk_context_delete(lua_State *L) {
	struct lnk_context *lc = lua_touserdata(L, 1);
	if (lc->init) {
		nk_buffer_free(&lc->cmds);
		nk_font_atlas_clear(&lc->atlas);   // delete fonts,delete own ttf mem,delete glyphs， 创建的字体从目前看时在这里删除的
		nk_free(&lc->context);

		bgfx_destroy_dynamic_vertex_buffer(lc->vb);
		bgfx_destroy_dynamic_index_buffer(lc->ib);
		bgfx_destroy_texture(lc->fontexture);
		bgfx_destroy_uniform(lc->tid);
		bgfx_destroy_program(lc->prog);
        
		// nk_font_atlas_clear will do this work ,not here 
		// for(int i=0;i<NK_ANT_MAX_FONTS;i++) { 
		//	 if(lc->fonts[i]) nk_font_clear(lc->fonts);
		// }
		free(lc->fonts);

		lnk_uicache_shutdown(L,lc);
		lnk_stack_shutdown(L,lc);
		lnk_charset_shutdown(lc);

		lc->init = 0;
	}
	return 0;
}

static int
lnk_context_new(lua_State *L) {
	struct lnk_context * lc = lua_newuserdata(L, sizeof(*lc));
	lc->init = 0;	// not init
	lc->num_fonts = 0;
	lc->fonts = 0;
	lua_createtable(L, 0, 1);
	lua_pushcfunction(L, lnk_context_delete);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);
	return 1;
}

static struct lnk_context *
get_context(lua_State *L) {
	struct lnk_context *lc = lua_touserdata(L, lua_upvalueindex(1));
	if (!lc->init) {
		luaL_error(L, "Init context first");
	}
	return lc;
}

static struct lnk_context *
get_context_uninit(lua_State *L) {
	struct lnk_context *lc = lua_touserdata(L, lua_upvalueindex(1));
	if (lc->init) {
		luaL_error(L, "Can't init context more than once");
	}
	return lc;
}

static int
getint(lua_State *L, int table, const char *key) {
	if (lua_getfield(L, table, key) != LUA_TNUMBER) {
		luaL_error(L, "Need %s as number", key);
	}
	if (!lua_isinteger(L, -1)) {
		luaL_error(L, "%s should be integer", key);
	}
	int n = lua_tointeger(L, -1);
	lua_pop(L, 1);
	return n;
}

static int
getintopt(lua_State *L, int table, const char *key, int opt) {
	if (lua_getfield(L, table, key) == LUA_TNIL) {
		lua_pop(L, 1);
		return opt;
	}
	int n = luaL_checkinteger(L, -1);
	lua_pop(L, 1);
	return n;
}

static const char *
getstring(lua_State *L, int table, const char *key) {
	if (lua_getfield(L, table, key) != LUA_TSTRING) {
		luaL_error(L, "Need %s as string", key);
	}
	const char * s = lua_tostring(L, -1);
	lua_pop(L, 1);
	return s;
}

static inline int 
c2i(char ch)  {  
	if( ch >= '0' && ch <= '9' ) 
		return ch - 48;  
	if( ch >= 'A' && ch <='Z'  ) 
		return ch - 55;
	if( ch >= 'a' && ch <= 'z' )
		return ch - 87;
    return -1;  
}  

static inline int 
hex2dec(char *hex_s) {
	int i,l,t,bits;  
	int num = 0;  
	hex_s += 2;
	l = strlen( hex_s );  
	for (i=0, t=0; i<l; i++, t=0)  	{  
		t = c2i( hex_s[i] );  
		bits = (l - i - 1) * 4;  
		t = t << bits;  
		num = num | t;  
	}  
	return num;  
}


struct nk_rune *
get_charset_rune(struct lnk_context *lc,char *name) {
	for(int i=0;i<lc->num_charsets;i++)
		if(!strncmp(lc->charsets[i].name,name,64))
			return lc->charsets[i].rune;
	// not found ,new charset
	return NULL;
}

static nk_rune* 
add_charset_rune(struct lnk_context *lc,char *name,nk_rune *rune ) {
	strncpy(lc->charsets[ lc->num_charsets ].name,name,64);
	lc->charsets[ lc->num_charsets ++].rune  = rune;

	#ifdef MY_DEBUG
		printf("add new font charset =%s, num charsets =%d\n",name,lc->num_charsets);
	#endif
	return rune;
}


static int 
get_charset(lua_State *L,struct lnk_context *lc) {
	if(lua_geti(L,-1,1)!=LUA_TSTRING) {  //charset name
		luaL_error(L,"Need charset name.");
	}
	const char *cn = lua_tostring(L,-1);
	lua_pop(L,1); 

	#ifdef MY_DEBUG
	printf("charset name = [%s] ",cn);
	#endif 

	nk_rune *rune = get_charset_rune(lc,cn);
	if(!rune) {
		// new rune
		if( lc->num_charsets>= NK_ANT_MAX_CHARSET)
			return lc->charsets[0].rune;   // return 0 as default if charset array is full 

		if(lua_geti(L,-1,2)!=LUA_TTABLE) {  // get new rune table
			luaL_error(L,"Need charset table.");
		}

		int num = lua_rawlen(L,-1);
		rune = malloc( sizeof(nk_rune)*(num+1) );  // plus 1 for end flags 0x0 

		int i=0;

        /* ok
		int tindex = lua_gettop( L);
		lua_pushnil(L);
		while(0!= lua_next(L,tindex)) {
			rune[i] = luaL_optinteger(L,-1,0);
			// printf("0x%04X ",rune[i]);
			lua_pop(L,1);
			i = i+1;
		} 
	    */
        /* ok
		for(i=1;i<num+1;i++) {
			lua_geti(L,-1,i);
			rune[i-1] = luaL_optinteger(L,-1,0);
			lua_pop(L,1);
		}
		*/ 
		for(i=1;  i<num+1 && lua_geti(L,-1,i)!=LUA_TNIL; i++) {
			rune[i-1] = luaL_optinteger(L,-1,0);
			lua_pop(L,1);
		}

		//staging code 
		//memset(rune,0x0,num+1);
		//rune[0]   = 0x0020;
		//rune[1]   = 0x00FF;
		//rune[3]   = 0x0;
		rune[num] = 0x0;

		lua_pop(L,1); 

		add_charset_rune(lc,cn,rune);
	} else {
		#ifdef MY_DEBUG
			printf("found an exist range.\n");
		#endif 
	}

	return rune;
}

static int 
add_font(lua_State *L,struct lnk_context *lc) {   
	if(lua_geti(L,-1,1)!=LUA_TSTRING) {
		luaL_error(L,"Need font name.");
	}
	const char *fn = lua_tostring(L,-1);  			// font name 
	lua_pop(L,1);
	#ifdef MY_DEBUG
	printf("found font %s\n",fn);
	#endif 

	lua_geti(L,-1,2);     							// font ttf memory
	size_t ttf_len;
	const char *ttf_m = luaL_checklstring(L, -1, &ttf_len);
	lua_pop(L,1);
	#ifdef MY_DEBUG
	printf_s("ttf mem size = %dk\n",ttf_len/1024);
	#endif 

	lua_geti(L,-1,3);     							// font size
	int fontsize = lua_tointeger(L,-1);
	if( fontsize < 0 )
	    fontsize = 16;
	lua_pop(L,1);
													
	if(lua_geti(L,-1,4)!=LUA_TTABLE) {             // charset - table 需要真正使用!
		luaL_error(L,"Charset must be range table");
	}
	nk_rune *charset_range = get_charset(L,lc);
	lua_pop(L,1);

	struct nk_font_config cfg = nk_font_config( fontsize );     // cfg : font size 
	cfg.oversample_v =1;
	cfg.oversample_h =1;
	cfg.range = charset_range;  								//nk_font_chinese_glyph_ranges(); 
																// cfg : unicode range list

	if(lc->num_fonts<NK_ANT_MAX_FONTS) {
		// make font 
		if(!lc->fonts) {
			//lc->fonts = malloc( sizeof(lc->fonts[0]) * NK_ANT_MAX_FONTS);  
			lc->fonts = malloc( sizeof(struct nk_font*) * NK_ANT_MAX_FONTS);  
		}
		lc->fonts[ lc->num_fonts ] = nk_font_atlas_add_from_memory(&lc->atlas,ttf_m,ttf_len,fontsize,&cfg);
		lc->num_fonts ++;

		#ifdef MY_DEBUG 
		printf("num fonts=%d\n",lc->num_fonts);
		for(int i=0;i<lc->num_fonts;i++) {
			printf("font %d = %.02f\n",i,lc->fonts[i]->config->size);
		}
		#endif 

		return 1;
	}
	return 0;
}

static int 
get_fonts(lua_State *L,struct lnk_context *lc) {
	luaL_checktype(L,-1,LUA_TTABLE);
	int i,type,num=0;
	for(i=1; (type=lua_geti(L,-1,i))!=LUA_TNIL; i++) {
		if(type == LUA_TTABLE) {
			num += add_font(L,lc);
		}
		lua_pop(L,1);
	}
	return num;
}

// font idx, nk_init{ fonts = { {font1},{font2}} }
// the index in nk.init fonts list
static int 
lnk_set_font(lua_State *L)
{
	struct lnk_context *lc = get_context(L);
	int fid = luaL_checkinteger(L,1) - 1;    //idx start from 1
	if( fid<0 || fid>= lc->num_fonts )
		return 0;
	
	struct nk_font *font  = lc->fonts[ fid ];

	nk_style_set_font(&lc->context,&font->handle );

	return 0;
}


static void
bake_default(lua_State *L, struct lnk_context *lc) {
	lc->fonts = malloc(sizeof(lc->fonts[0]) * 1);
	lc->fonts[0] =  nk_font_atlas_add_default(&lc->atlas, 13.0f, NULL);
	lc->num_fonts = 1;
}

static void
bake_fonts(lua_State*L,struct lnk_context *lc) {
	lua_getfield(L, 1, "fonts");
	get_fonts(L,lc);
	lua_pop(L,1);
	//staging code
	//bake_default(L,lc);
}
 

static void
gen_fontexture(lua_State *L, struct lnk_context *lc) {
	int w=0,h=0;
	int c = 4;

	int nk_fmt = NK_FONT_ATLAS_RGBA32; //ALPHA8;     //  
	int bgfx_fmt = BGFX_TEXTURE_FORMAT_RGBA8;  //A8; // 
	if( nk_fmt == NK_FONT_ATLAS_ALPHA8 ) 
	   c = 1;

	const void* image = nk_font_atlas_bake(&lc->atlas,&w,&h, nk_fmt );  // todo: use ALPHA8
	int size = w * h *c;
	const bgfx_memory_t *m = bgfx_alloc(size);
	memcpy(m->data,image,size);
	lc->fontexture = bgfx_create_texture_2d(w,h,0,1, bgfx_fmt ,0,m);   //BGFX_TEXTURE_FORMAT_RGBA8,A8,R8,R1
	#ifdef MY_DEBUG 
	printf("bake size(w,h) = %d(%d,%d),texid =%d \n",size,w,h,lc->fontexture);
	#endif 
}

static void
init_config(lua_State *L, struct lnk_context *lc) {
	struct nk_convert_config *config = &lc->cfg;
	NK_MEMSET(config, 0, sizeof(*config));

	static const struct nk_draw_vertex_layout_element vertex_layout[] = {
		{NK_VERTEX_POSITION, NK_FORMAT_FLOAT, NK_OFFSETOF(struct lnk_ui_vertex, position)},
		{NK_VERTEX_TEXCOORD, NK_FORMAT_FLOAT, NK_OFFSETOF(struct lnk_ui_vertex, uv)},
		{NK_VERTEX_COLOR, NK_FORMAT_R8G8B8A8, NK_OFFSETOF(struct lnk_ui_vertex, col)},
		{NK_VERTEX_LAYOUT_END}
	};

	config->vertex_layout = vertex_layout;
	config->vertex_size = sizeof(struct lnk_ui_vertex);
	config->vertex_alignment = NK_ALIGNOF(struct lnk_ui_vertex);
	// init config->null from atlas later

	config->circle_segment_count = getintopt(L, 1, "circle", 22);
	config->curve_segment_count = getintopt(L, 1, "curve", 22);
	config->arc_segment_count = getintopt(L, 1, "arc", 22);

	// todo: read etc from config table
	config->global_alpha = 1.0f;
	config->shape_AA = NK_ANTI_ALIASING_ON;
	config->line_AA = NK_ANTI_ALIASING_ON;
}

static void
context_resize(lua_State *L, struct lnk_context *lc, int w, int h) {
	lc->width = w;
	lc->height = h;
	if (w == 0 || h == 0)
		luaL_error(L, "Width %d or Height %d can't be zero", w, h);
	float ortho[4][4] = {
		{2.0f, 0.0f, 0.0f, 0.0f},
		{0.0f,-2.0f, 0.0f, 0.0f},
		{0.0f, 0.0f,-1.0f, 0.0f},
		{-1.0f,1.0f, 0.0f, 1.0f},
	};
	ortho[0][0] /= w;
	ortho[1][1] /= h;
	bgfx_set_view_rect(lc->view, 0, 0, w, h);
	bgfx_set_view_transform(0, 0, ortho);
}

static int
lnk_resize(lua_State *L) {
	struct lnk_context *lc = get_context(L);
	int w = luaL_checkinteger(L, 1);
	int h = luaL_checkinteger(L, 2);
	context_resize(L, lc, w, h);
	return 0;
}

static int
lnk_context_init(lua_State *L) {
	struct lnk_context *lc = get_context_uninit(L);
	// todo:  if init raise error, bgfx handles may leak.
	luaL_checktype(L, 1, LUA_TTABLE);
	lc->view = getint(L, 1, "view");

	if (lua_getfield(L, 1, "state") != LUA_TSTRING) {
		luaL_error(L, "Need state as string");
	}
	get_state(L, -1, &lc->state, &lc->rgba);
	lua_pop(L, 1);

	int w = getint(L, 1, "width");
	int h = getint(L, 1, "height");
	context_resize(L, lc, w, h);
	int prog = BGFX_LUAHANDLE_ID(PROGRAM, getint(L, 1, "prog"));
	lc->prog.idx = prog;
	const char * tid_uniform = getstring(L, 1, "texture");
	lc->tid = bgfx_create_uniform(tid_uniform, BGFX_UNIFORM_TYPE_INT1, 1);

	if (lua_getfield(L, 1, "decl") != LUA_TUSERDATA) {
		luaL_error(L, "Need decl as userdata");
	}
	bgfx_vertex_decl_t *decl = lua_touserdata(L, -1);
	lua_pop(L, 1);

	lc->vb = bgfx_create_dynamic_vertex_buffer(0, decl, BGFX_BUFFER_ALLOW_RESIZE);
	lc->ib = bgfx_create_dynamic_index_buffer(0, BGFX_BUFFER_ALLOW_RESIZE);

	// ui cache init
	lnk_uicache_init(L,lc);
	// style stack 
	lnk_stack_init(L,lc);
	// charset
	lnk_charset_init(lc);

	nk_buffer_init_default(&lc->cmds);
	
	// init config
	init_config(L, lc);

	nk_font_atlas_init_default(&lc->atlas);
	nk_font_atlas_begin(&lc->atlas);

	if (lua_getfield(L, 1, "fonts") == LUA_TNIL) {
		bake_default(L, lc);
	} else {
		// todo: bake_fonts
		//luaL_error(L, "TODO: bake fonts");
		bake_fonts(L, lc);
	}
	lua_pop(L, 1);

	gen_fontexture(L, lc);

	nk_font_atlas_end(&lc->atlas, nk_handle_id(lc->fontexture.idx), &lc->cfg.null);
	nk_font_atlas_cleanup(&lc->atlas);     // only delete ttf mem

	nk_init_default(&lc->context,&lc->fonts[0]->handle);


	lc->init = 1;

	return 0;
}



// lua 5.1 后舍弃的函数
LUALIB_API int 
luaL_typerror (lua_State *L, int narg, const char *typename) {
  const char *msg = lua_pushfstring(L, "%s expected, got %s",
                                    typename, luaL_typename(L, narg));
  return luaL_argerror(L, narg, msg);
}


void 
lnk_assert(lua_State *L,int ignore,const char *msg) {
	if(ignore)
	  return;
	lua_Debug debug;
	debug.name = NULL;
	uint32_t level = 0;
	while(lua_getstack(L,level,&debug)) {
		level++;
	}
	if(!level)
		return 0; // can't catch error

	lua_getstack(L,level,&debug);
	lua_getinfo(L,"Sln",&debug);   //src ,line ,name
	if( debug.name == NULL)      
	   debug.name = "?";
	luaL_error(L,msg,debug.name);  // src,line needed?
}

/*
static void *
nk_lua_malloc(size_t size) {
	void *mem = malloc(size);
	return mem;
}

void 
nk_lua_free(void *men) {
	free(men);
}
*/

//-----------------
static int lnk_is_hex(char c)
{
	return (c >= '0' && c <= '9')
			|| (c >= 'a' && c <= 'f')
			|| (c >= 'A' && c <= 'F');
}

// 判断字符串是否是有效的颜色值格式,"#2d2d2d00"
static int lnk_is_color(lua_State *L,int index)
{
	index = lua_absindex(L,index);
	//if (index < 0)
	//	index += lua_gettop(s_L) + 1;
	if (lua_isstring(L, index)) {
		size_t len;
		const char *color_string = lua_tolstring(L , index, &len);
		if ((len == 7 || len == 9) && color_string[0] == '#') {
			int i;
			for (i = 1; i < len; ++i) {
				if (!lnk_is_hex(color_string[i]))
					return 0;
			}
			return 1;
		}
	}
	return 0;
}

static nk_flags 
lnk_checkedittype(lua_State *L,int index) 
{
	index = lua_absindex(L,index);
	//if(index <0)
	//	index += lua_gettop(s_L) +1;
	nk_flags flags = NK_EDIT_SIMPLE;
	if(!lua_isstring(L,index))
		return flags;
    const char *edit_s = luaL_checkstring(L,index);
	if(!strcmp(edit_s,"simple")) 
		flags = NK_EDIT_SIMPLE;
	else if(!strcmp(edit_s,"box"))
		flags = NK_EDIT_BOX;
	else if(!strcmp(edit_s,"field"))
		flags = NK_EDIT_FIELD;
	else if(!strcmp(edit_s,"editor"))
		flags = NK_EDIT_EDITOR;
	else {
		// 不存在的编辑类型值
		const char *err_msg = lua_pushfstring(L,"wrong edit type:'%s'",edit_s);
		return (nk_flags) luaL_argerror(L,index,err_msg);
	}
	return flags;
}

static enum nk_layout_format 
lnk_checkformat(lua_State*L,int index) {
	index = lua_absindex(L,index);
    //if (index < 0 )
    //  index += lua_gettop(s_L)+1;
    const char *type = luaL_checkstring(L,index);
    if(!strcmp(type,"dynamic")){
        return NK_DYNAMIC;
    } else if(!strcmp(type,"static")){
        return NK_STATIC;
    } else {
        const char *err_msg = lua_pushfstring(L,"unrecognized layout format: '%s' ",type);
        return (enum nk_layout_format ) luaL_argerror(L,index,err_msg );
    }
}

// staging ，check status 
static int 
lnk_is_active(struct nk_context *ctx)
{
	struct nk_window *iter;
	NK_ASSERT(ctx);
	if (!ctx) return 0;
	iter = ctx->begin;
	while (iter) {
		// check if window is being hovered 
		if (iter->flags & NK_WINDOW_MINIMIZED) {
			struct nk_rect header = iter->bounds;
			header.h = ctx->style.font->height + 2 * ctx->style.window.header.padding.y;
			if (nk_input_is_mouse_hovering_rect(&ctx->input, header))
				return 1;
		} else if (nk_input_is_mouse_hovering_rect(&ctx->input, iter->bounds)) {
			return 1;
		}
		// check if window popup is being hovered 
		if (iter->popup.active && iter->popup.win && nk_input_is_mouse_hovering_rect(&ctx->input, iter->popup.win->bounds))
			return 1;
		if (iter->edit.active & NK_EDIT_ACTIVE)
			return 1;
		iter = iter->next;
	}
	return 0;
}

nk_flags lnk_checkalign(lua_State *L,int index)
{
	index = lua_absindex(L,index); 

	//if(index<0)
	//  index += lua_gettop(s_L)+1;
	
	const char *align_s = luaL_checkstring(L,index);
	nk_flags 	flags ;
	if(!strcmp(align_s,"left")) {
		flags = NK_TEXT_LEFT;
	} else if(!strcmp(align_s,"right")) {
		flags = NK_TEXT_RIGHT;
	} else if(!strcmp(align_s,"centered")) {
		flags = NK_TEXT_CENTERED;
	} else if(!strcmp(align_s,"top left")) {
		flags = NK_TEXT_ALIGN_TOP | NK_TEXT_ALIGN_LEFT;
	} else if(!strcmp(align_s,"top centered")) {
		flags = NK_TEXT_ALIGN_CENTERED | NK_TEXT_ALIGN_TOP;
	} else if(!strcmp(align_s,"top right")) {
		flags = NK_TEXT_ALIGN_TOP | NK_TEXT_ALIGN_RIGHT;
	} else if(!strcmp(align_s,"bottom left")) {
		flags = NK_TEXT_ALIGN_BOTTOM | NK_TEXT_ALIGN_LEFT;
	} else if(!strcmp(align_s,"bottom centered")) {
		flags = NK_TEXT_ALIGN_BOTTOM | NK_TEXT_ALIGN_CENTERED;
	} else if(!strcmp(align_s,"bottom_right")) {
		flags = NK_TEXT_ALIGN_BOTTOM | NK_TEXT_ALIGN_RIGHT;
	} else {
		//return luaL_error(L,"unrecognized aligenment word '%s'.\n ",align_s);
	   const char *msg = lua_pushfstring(L,"unrecognized aligenment word '%s'.\n ",align_s);
	   return luaL_argerror(L,index,msg);
	}
	return flags;
}

struct nk_color lnk_checkcolor(lua_State*L,int index) 
{
	index = lua_absindex(L,index); 
	//if(index<0) {
	//   index += lua_gettop(s_L)+1;
	//}
	if(!lnk_is_color(L,index)) {
       if( lua_isstring( L,index)) {
		   const char *msg = lua_pushfstring( L,"Wrong color string format '%s'",lua_tostring(L,index));
		   luaL_argerror( L,index,msg);
	   } else {
		   luaL_typerror( L,index,"Need color string '0xFFFFFF' ");
	   }
	}

	size_t len = 0;
	const char *color_string = lua_tolstring(L,index,&len);
	int r,g,b,a = 255;
	sscanf_s(color_string,"#%02x%02x%02x",&r,&g,&b);
	if( len==9 )
		sscanf_s(color_string+7,"%02x",&a);
	
	struct nk_color color = {(nk_byte)r,(nk_byte)g,(nk_byte)b,(nk_byte)a};
	return color;
}


enum nk_symbol_type lnk_checksymbol(lua_State *L,int index)
{
	index = lua_absindex(L,index);
	//if(index<0)
	//	index += lua_gettop(s_L) + 1;

	enum nk_symbol_type symbol_flags = NK_SYMBOL_NONE;	
	const char* symbol_s = luaL_checkstring(L,index);
	if(!strcmp(symbol_s,"underscore")) 
		symbol_flags =  NK_SYMBOL_UNDERSCORE;
	else if(!strcmp(symbol_s,"circle solid"))
		symbol_flags =  NK_SYMBOL_CIRCLE_SOLID;
	else if(!strcmp(symbol_s,"circle outline"))
		symbol_flags =  NK_SYMBOL_CIRCLE_OUTLINE;
	else if(!strcmp(symbol_s,"rect solid"))
		symbol_flags =  NK_SYMBOL_RECT_SOLID;
	else if(!strcmp(symbol_s,"rect outline"))
		symbol_flags =  NK_SYMBOL_RECT_OUTLINE;
	else if(!strcmp(symbol_s,"triangle up"))
		symbol_flags =  NK_SYMBOL_TRIANGLE_UP;
	else if(!strcmp(symbol_s,"triangle down"))
		symbol_flags =  NK_SYMBOL_TRIANGLE_DOWN;
	else if(!strcmp(symbol_s,"triangle left"))
		symbol_flags =  NK_SYMBOL_TRIANGLE_LEFT;
	else if(!strcmp(symbol_s,"triangle right"))
		symbol_flags =  NK_SYMBOL_TRIANGLE_RIGHT;
	else if(!strcmp(symbol_s,"plus"))
		symbol_flags =  NK_SYMBOL_PLUS;
	else if(!strcmp(symbol_s,"minus"))
		symbol_flags =  NK_SYMBOL_MINUS;
	else {
		const char *err_msg = lua_pushfstring(L,"unrecognized symbol type '%s'",symbol_s);
		return (enum nk_symbol_type) luaL_argerror(L,index,err_msg);
	}
	return symbol_flags;
}

static void *
getfield_touserdata(lua_State *L,int table, const char *key) {
	lua_getfield(L, table, key);
	void * ud = lua_touserdata(L, -1);
	lua_pop(L, 1);
	return ud;
}

static inline int 
getfield_tointeger(lua_State *L,int table,const char *key) {
	if( lua_getfield(L,table,key) != LUA_TNUMBER) {
		luaL_error(L,"Need %s as number",key );
	}
	//if (!lua_isinteger(L, -1)) {
	//	luaL_error(L, "%s should be integer", key);
	//}
	int ivalue = luaL_checkinteger(L,-1);
	lua_pop(L,1);
	return ivalue;
}

// struct nk_image {nk_handle handle;unsigned short w,h;unsigned short region[4];};
// 从栈顶 table(nk_image),解码所有参数,填写返回*image 
void lnk_checkimage(lua_State *L,int index,struct nk_image *image) 
{
	if(!image)
		return;
	memset(image,0,sizeof(struct nk_image));

	index = lua_absindex(L,index);

	luaL_checktype(L, index  ,LUA_TTABLE);

	image->handle = nk_handle_id( getfield_tointeger( L,index,"handle") );
	image->w = getfield_tointeger( L,index,"w");
	image->h = getfield_tointeger( L,index,"h");
	image->region[0] = getfield_tointeger( L,index,"x0");
	image->region[1] = getfield_tointeger( L,index,"y0");
	image->region[2] = getfield_tointeger( L,index,"x1");
	image->region[3] = getfield_tointeger( L,index,"y1");
}

/*
static void *
getfield(lua_State *L,const char *key)
{
	lua_getfield(L,1,key);
	void *ud = lua_touserdata(L,-1);
	lua_pop(L,1);
	return ud;
}
*/

// "dynamic",height,cols
//  nk: nk_layout_row_dynamic
static int 
lnk_layout_row(lua_State *L)
{
	struct lnk_context *lc = get_context(L);

	int argc = lua_gettop(L);

	enum  nk_layout_format format = lnk_checkformat(L,1);
	float height = luaL_checknumber(L, 2);
	int   use_ratios = 0;
	if ( format == NK_DYNAMIC ) {
		if (lua_isnumber(L, 3)) {
			int cols = luaL_checkinteger(L, 3);
			nk_layout_row_dynamic(&lc->context, height, cols);
		} else {
			if (!lua_istable(L, 3)) 
				luaL_argerror(L, 3, "should be a number or table");
			use_ratios = 1;
		}
	} else if (format == NK_STATIC) {
		if (argc == 4) {
			int item_width = luaL_checkinteger(L, 3);
			int cols = luaL_checkinteger(L, 4);
			nk_layout_row_static( &lc->context, height, item_width, cols);
		} else {
			if (!lua_istable(L, 3)) 
				luaL_argerror(L, 3, "should be a number or table");
			use_ratios = 1;
		}
	}
	if (use_ratios==1) {  
		int cols = lua_rawlen(L, -1);   // table length is cols   
		int i, j;
		for ( i=1,j= lc->num_layout_ratios;  i<=cols && j<NK_ANT_MAX_RATIOS;  ++i, ++j) {
			if( lua_rawgeti(L,-1,i)!= LUA_TNUMBER )
			 	luaL_argerror(L, lua_gettop(L) - 1, "ratios table must include numbers only");
			lc->layout_ratios[j] = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}
		// format = static ratio use pixels {120,100,180}
		//        = dynamic ratio use scale {0.2,0.3,0.5}
		nk_layout_row(&lc->context, format, height, cols, lc->layout_ratios + lc->num_layout_ratios);
		lc->num_layout_ratios += cols;
	}
	return 0;   
}

static int 
lnk_spacing(lua_State *L) {
	struct lnk_context *lc = get_context(L);
	int cols = luaL_checkinteger(L,1);
	nk_spacing(&lc->context,cols);
	return 1;
}


// 默认传入图象的rgba memory block
// parameters:image,w,h,c
// not used 预留
/*
static int 
lnk_load_image(lua_State *L)
{
	if(!lua_isstring(L,1)) 
		luaL_typerror(L,1,"%s: must be a string .\n");

	size_t image_size;
	const char *image_m = luaL_checklstring(L,1, &image_size);
	int w = luaL_checkinteger(L,2);
	int h = luaL_checkinteger(L,3);
	int c = luaL_checkinteger(L,4);


	int tex_fmt = BGFX_TEXTURE_FORMAT_RGBA8;
	if( c== 1 ) tex_fmt = BGFX_TEXTURE_FORMAT_A8;
	const bgfx_memory_t *m = bgfx_alloc(image_size);
	memcpy(m->data,image_m,image_size);
	bgfx_texture_handle_t tex = bgfx_create_texture_2d(w,h,0,1,tex_fmt ,0,m);

	struct nk_image image;
    image.handle.id = (int) tex.idx;   //int
    image.w = w;
    image.h = h;
    image.region[0] = image.region[1] = 0;
    image.region[2] = w;
    image.region[3] = h;

	lua_newtable(L);
	lua_pushnumber(L,image.handle.id);
	lua_setfield(L,-2,"handle");
	lua_pushnumber(L,image.w);
	lua_setfield(L,-2,"w");
	lua_pushnumber(L,image.h);
	lua_setfield(L,-2,"h");
	lua_pushnumber(L,image.region[0]);
	lua_setfield(L,-2,"x0");
	lua_pushnumber(L,image.region[1]);
	lua_setfield(L,-2,"y0");
	lua_pushnumber(L,image.region[2]);
	lua_setfield(L,-2,"x1");
	lua_pushnumber(L,image.region[3]);
	lua_setfield(L,-2,"y1");
	return 1;	
}
static int 
lnk_free_image(lua_State *L) {
  // not need ,case texture hanlde managed by outside 
  // create ,permainment,free etc 
}
*/

// convert bgfx texture into nk_image
// input texture id ,width,height 
// output nuklear nk_image 
// not used currently 
// nk_image image = convert_image(texid,w,h);
// nk_image subimage = subImage(image,0,0,32,32);
static int 
lnk_convert_image(lua_State *L) {
	int texid = luaL_checkinteger(L,1);
	texid = texid&0xffff;
	int w = luaL_checkinteger(L,2);
	int h = luaL_checkinteger(L,3);
	int c = luaL_optinteger(L,4,4);   //not need 

	struct nk_image image;
    image.handle.id = (texid);        
    image.w = w;
    image.h = h;
    image.region[0] = image.region[1] = 0;
    image.region[2] = w;
    image.region[3] = h;

	lua_newtable(L);
	lua_pushnumber(L,image.handle.id);
	lua_setfield(L,-2,"handle");
	lua_pushnumber(L,image.w);
	lua_setfield(L,-2,"w");
	lua_pushnumber(L,image.h);
	lua_setfield(L,-2,"h");
	lua_pushnumber(L,image.region[0]);
	lua_setfield(L,-2,"x0");
	lua_pushnumber(L,image.region[1]);
	lua_setfield(L,-2,"y0");
	lua_pushnumber(L,image.region[2]);
	lua_setfield(L,-2,"x1");
	lua_pushnumber(L,image.region[3]);
	lua_setfield(L,-2,"y1");

	return 1;	
}

//return subimage from altas texture 
// input nk_image, if only texture handle,will be faster 
// nk_subimage_id need to know atlas(w,h),for uv calc 
static int 
lnk_sub_image(lua_State *L)
{
	if(!lua_istable(L,1))
		luaL_argerror(L,1,"must a table\n");

	struct nk_image  image; 
	lnk_checkimage(L,1,&image);

	int x = luaL_checkinteger(L,2);
	int y = luaL_checkinteger(L,3);
	int w = luaL_checkinteger(L,4);
	int h = luaL_checkinteger(L,5);

	struct nk_image s_image = nk_subimage_id( image.handle.id,image.w,image.h,nk_rect(x,y,w,h));

	lua_newtable(L);
	lua_pushnumber(L,s_image.handle.id);
	lua_setfield(L,-2,"handle");
	lua_pushnumber(L,s_image.w);
	lua_setfield(L,-2,"w");
	lua_pushnumber(L,s_image.h);
	lua_setfield(L,-2,"h");
	lua_pushnumber(L,s_image.region[0]);
	lua_setfield(L,-2,"x0");
	lua_pushnumber(L,s_image.region[1]);
	lua_setfield(L,-2,"y0");
	lua_pushnumber(L,s_image.region[2]);
	lua_setfield(L,-2,"x1");
	lua_pushnumber(L,s_image.region[3]);
	lua_setfield(L,-2,"y1");	

	return 1;
}

// onlye texture id and sub rect
static int 
lnk_sub_image_id(lua_State *L)
{
	int sid = luaL_checkinteger(L,1);
	int sw = luaL_checkinteger(L,2);
	int sh = luaL_checkinteger(L,3);

	int x = luaL_checkinteger(L,4);
	int y = luaL_checkinteger(L,5);
	int w = luaL_checkinteger(L,6);
	int h = luaL_checkinteger(L,7);
	
	struct nk_image s_image = nk_subimage_id( sid,sw,sh,nk_rect(x,y,w,h));

	lua_newtable(L);
	lua_pushnumber(L,s_image.handle.id);
	lua_setfield(L,-2,"handle");
	lua_pushnumber(L,s_image.w);
	lua_setfield(L,-2,"w");
	lua_pushnumber(L,s_image.h);
	lua_setfield(L,-2,"h");
	lua_pushnumber(L,s_image.region[0]);
	lua_setfield(L,-2,"x0");
	lua_pushnumber(L,s_image.region[1]);
	lua_setfield(L,-2,"y0");
	lua_pushnumber(L,s_image.region[2]);
	lua_setfield(L,-2,"x1");
	lua_pushnumber(L,s_image.region[3]);
	lua_setfield(L,-2,"y1");	

	return 1;
}

//image show control 
// input nk_image 
static int 
lnk_image(lua_State *L) {
	struct lnk_context  *lc = get_context(L);	
	// hung lock if args not exist or not a table ? case lua nested itself 
	// luaL_checktype(L, 1, LUA_TTABLE);

	struct nk_image  image; 
	lnk_checkimage(L,1,&image);
	nk_image(&lc->context,image);

	return 0;
}


// 风格化相关
// default Style
static int 
lnk_set_style_default(lua_State *L)
{
	struct lnk_context *lc = get_context(L);
	nk_style_default(&lc->context);

	// 在默认外额外的测试设置 
	// my default
	/*
	#ifdef MY_BUG 
	struct nk_context *ctx = &lc->context;
 // window 
 	struct nk_color background_color = nk_rgb(128,128,128);
	ctx->style.window.background = nk_rgb(204,204,204);
	ctx->style.window.fixed_background = nk_style_item_color(background_color); 
	ctx->style.window.border_color = nk_rgb(167,167,167);
	ctx->style.window.combo_border_color = nk_rgb(67,67,67);
	ctx->style.window.contextual_border_color = nk_rgb(67,67,67);
	ctx->style.window.menu_border_color = nk_rgb(67,67,67);
	ctx->style.window.group_border_color = nk_rgb(67,67,67);
	ctx->style.window.tooltip_border_color = nk_rgb(67,67,67);
	ctx->style.window.scrollbar_size = nk_vec2(16,16);
	ctx->style.window.border_color = nk_rgba(250,0,0,128);
	ctx->style.window.padding = nk_vec2(8,14);
	ctx->style.window.border = 3;
// button 
	ctx->style.button.text_background  = nk_rgb(20,120,20);
	ctx->style.button.text_hover       = nk_rgb(120,120,20);
	#endif 
	}
    */
	return 0;
}

// color style
static int 
lnk_set_style_colors(lua_State *L) 
{
	const char *styles[] = {
	    "text",
    	"window",
		"header",
		"border",
    	"button",
    	"button hover",
		"button active",
		"toggle",
		"toggle hover",
		"toggle cursor",
		"select",
		"select active",
		"slider",
		"slider cursor",
		"slider cursor hover",
		"slider cursor active",
		"property",
		"edit",
		"edit cursor",
		"combo",
		"chart",
		"chart color",
		"chart color highlight",
		"scrollbar",
		"scrollbar cursor",
		"scrollbar cursor hover",
		"scrollbar cursor active",
		"tab header",
	};

	if(!lua_istable(L,1))
	   luaL_typerror(L, 1, "table");

	struct nk_color colors[ NK_COLOR_COUNT ];
	for(int type = NK_COLOR_TEXT; type< NK_COLOR_COUNT; type++) {
		lua_getfield(L,-1, styles[type] );            // push color key into stack 
		colors[type] = lnk_checkcolor(L,-1);
		lua_pop(L,1);
	}
	struct lnk_context *lc = get_context( L );
	nk_style_from_table(&lc->context, colors);
	return 0;
}


enum theme {THEME_BLACK, THEME_WHITE, THEME_RED, THEME_BLUE, THEME_DARK};
void set_style_theme(struct nk_context* ctx,enum theme t ) 
{
    struct nk_color table[NK_COLOR_COUNT];
    if (t == THEME_WHITE) {
        table[NK_COLOR_TEXT] = nk_rgba(70, 70, 70, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_HEADER] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_BORDER] = nk_rgba(0, 0, 0, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(185, 185, 185, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(170, 170, 170, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(160, 160, 160, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(150, 150, 150, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(120, 120, 120, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_SELECT] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(80, 80, 80, 255);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(70, 70, 70, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(60, 60, 60, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_EDIT] = nk_rgba(150, 150, 150, 255);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(0, 0, 0, 255);
        table[NK_COLOR_COMBO] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_CHART] = nk_rgba(160, 160, 160, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(45, 45, 45, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba( 255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(180, 180, 180, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(140, 140, 140, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(150, 150, 150, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(160, 160, 160, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(180, 180, 180, 255);
        nk_style_from_table(ctx, table);
    } else if (t == THEME_RED) {
        table[NK_COLOR_TEXT] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(30, 33, 40, 215);
        table[NK_COLOR_HEADER] = nk_rgba(181, 45, 69, 220);
        table[NK_COLOR_BORDER] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(190, 50, 70, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(195, 55, 75, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(45, 60, 60, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_SELECT] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(186, 50, 74, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(191, 55, 79, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_EDIT] = nk_rgba(51, 55, 67, 225);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_COMBO] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_CHART] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(170, 40, 60, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba( 255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(30, 33, 40, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(64, 84, 95, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(70, 90, 100, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(75, 95, 105, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(181, 45, 69, 220);
        nk_style_from_table(ctx, table);
    } else if (t == THEME_BLUE) {
        table[NK_COLOR_TEXT] = nk_rgba(20, 20, 20, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(202, 212, 214, 215);
        table[NK_COLOR_HEADER] = nk_rgba(137, 182, 224, 220);
        table[NK_COLOR_BORDER] = nk_rgba(140, 159, 173, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(142, 187, 229, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(147, 192, 234, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(177, 210, 210, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(182, 215, 215, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_SELECT] = nk_rgba(177, 210, 210, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(177, 210, 210, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(137, 182, 224, 245);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(142, 188, 229, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(147, 193, 234, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_EDIT] = nk_rgba(210, 210, 210, 225);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(20, 20, 20, 255);
        table[NK_COLOR_COMBO] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_CHART] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba( 255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(190, 200, 200, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(64, 84, 95, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(70, 90, 100, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(75, 95, 105, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(156, 193, 220, 255);
        nk_style_from_table(ctx, table);
    } else if ( t == THEME_DARK) {
        table[NK_COLOR_TEXT] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(57, 67, 71, 215);
        table[NK_COLOR_HEADER] = nk_rgba(51, 51, 56, 220);
        table[NK_COLOR_BORDER] = nk_rgba(46, 46, 46, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(58, 93, 121, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(63, 98, 126, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(45, 53, 56, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_SELECT] = nk_rgba(57, 67, 61, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(48, 83, 111, 245);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(53, 88, 116, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(58, 93, 121, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_EDIT] = nk_rgba(50, 58, 61, 225);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_COMBO] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_CHART] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba(255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(53, 88, 116, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(58, 93, 121, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(48, 83, 111, 255);
        nk_style_from_table(ctx, table);
	} else {
        nk_style_default(ctx);
    }
}

// theme Style
static int 
lnk_set_style_theme(lua_State *L)
{
	struct lnk_context *lc = get_context(L);
	const char *theme_string = luaL_checkstring(L,1);
	if(!stricmp(theme_string,"THEME WHITE")) {
		set_style_theme(&lc->context,THEME_WHITE);
	} 
	else if(!stricmp(theme_string,"THEME RED")) {
		set_style_theme(&lc->context,THEME_RED);
	}
	else if(!stricmp(theme_string,"THEME BLUE")) {
		set_style_theme(&lc->context,THEME_BLUE);
	}
	else if(!stricmp(theme_string,"THEME DARK")) {
		set_style_theme(&lc->context,THEME_DARK);
	}
	return 0;
}


//skin Style
//----------- set style macro prototype ---------
// get style name from table in stack top
// we have one style item
// call this style setup function
// The next three functions and macro are standard sample
#define NK_SET_STYLE(L,lc, stylename, functype, valuevar ) \
	lua_getfield( L,-1,stylename); \
	if(!lua_isnil(L,-1)) \
			lnk_set_style_##functype(L,lc,valuevar ); \
	lua_pop(L,1);

//--- ui base item prototype ---
//    nk_color , nk_vec2 , nk_style_item , nk_flags , float 

// nk_style_item 
static int lnk_set_style_base_item(lua_State *L,struct lnk_context *lc,struct nk_style_item *target ) 
{   
	struct  nk_style_item item;
	if( lua_isstring( L,-1)) {   			// item is color string 
		if(!lnk_is_color( L,-1)) {
			const char *msg = lua_pushfstring( L," '%s': wrong color string",lua_tostring(L,-1) );
			lnk_assert(L, 0, msg );
		}
		item.type = NK_STYLE_ITEM_COLOR;
		item.data.color = lnk_checkcolor(L,-1);
	} 
	else {  								// user data is nk_image table 
		item.type = NK_STYLE_ITEM_IMAGE;
		lnk_checkimage(L,-1,&item.data.image);      
	}
    // item to nk 
	int result  = nk_style_push_style_item( &lc->context,target,item );
	if( result != 0 )  {
		lua_pushstring( L,"item");           // save item
		size_t size = lua_rawlen( L,1);       // item count
		lua_rawseti( L,1, size+1 );           // item count + 1 and save to stack bottom
	}
	return result;
}
// nk_color
static int lnk_set_style_base_color(lua_State *L,struct lnk_context *lc,struct nk_color *target) 
{
	if(!lnk_is_color(L,-1)) {
		const char *msg = lua_pushfstring(L," '%s': wrong color string",lua_tostring(L,-1) );
		lnk_assert(L, 0, msg );
	}

	struct nk_color color = lnk_checkcolor(L,-1);
	int result = nk_style_push_color(&lc->context,target,color);
	if( result ) {
		lua_pushstring( L,"color");
		size_t size = lua_rawlen( L,1);
		lua_rawseti( L,1,size + 1);
	}
	return result;
}

// nk_align
static int lnk_set_style_align(lua_State *L,struct lnk_context *lc,nk_flags *target)
{
	nk_flags align = lnk_checkalign(L,-1); 
	int result = nk_style_push_flags(&lc->context,target,align);
	if( result ) {
		lua_pushstring( L,"flags");   // push stack
		int size = lua_rawlen( L,1);
		lua_rawseti( L,1,size +1 );
	}
	return result;
}

// nk_float
static int lnk_set_style_float(lua_State *L,struct lnk_context *lc,nk_float *target)
{
	float fv = luaL_checknumber( L,-1);
	int result = nk_style_push_float(&lc->context,target,fv);
	if( result ){
		lua_pushstring( L,"float");
		int size = lua_rawlen( L,1);
		lua_rawseti( L,1,size + 1);
	}
	return result;
}

// nk_vec2 
static int lnk_set_style_vec2(lua_State *L,struct lnk_context *lc,struct nk_vec2 *target)
{
	if(!lua_istable(L,-1))
		luaL_typerror(L,-1,"must be table");

	struct nk_vec2 vec;
	lua_getfield( L,-1,"x");
	vec.x = lua_tonumber( L,-1);
	lua_pop( L,1);
	lua_getfield( L,-1,"y");
	vec.y = lua_tonumber( L,-1);
	lua_pop( L,1);

	int result = nk_style_push_vec2(&lc->context,target,vec);
	if( result ){
		lua_pushstring( L, "vec2");
		int size  = lua_rawlen( L,1);
		lua_rawseti( L,1,size + 1);
	}
	return result ;
}

// ui control prototype
//--- set button style -----
static void 
lnk_set_style_button(lua_State *L,struct lnk_context *lc,struct nk_style_button *style)
{
	lnk_assert(L,lua_istable(L,-1),"%s: button style must be a table.\n" );

	NK_SET_STYLE(L,lc,"normal",base_item,&style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item,&style->hover);
	NK_SET_STYLE(L,lc,"active",base_item,&style->active);
	NK_SET_STYLE(L,lc,"border color",base_color,&style->border_color);
	NK_SET_STYLE(L,lc,"text background",base_color, &style->text_background);
	NK_SET_STYLE(L,lc,"text normal", base_color, &style->text_normal);
	NK_SET_STYLE(L,lc,"text hover", base_color, &style->text_hover);
	NK_SET_STYLE(L,lc,"text active", base_color, &style->text_active);
	// align
	NK_SET_STYLE(L,lc,"text alignment", align, &style->text_alignment);
	// float 
	NK_SET_STYLE(L,lc,"border", float, &style->border);
	NK_SET_STYLE(L,lc,"rounding", float, &style->rounding);
	// vec2 
	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);
	NK_SET_STYLE(L,lc,"image padding", vec2, &style->image_padding);
	NK_SET_STYLE(L,lc,"touch padding", vec2, &style->touch_padding);
}

//scrollbar 
static void 
lnk_set_style_scrollbar(lua_State *L,struct lnk_context *lc,struct nk_style_scrollbar *style)
{
	lnk_assert(L,lua_istable(L, -1), "%s: scrollbar style must be a table");
	NK_SET_STYLE(L,lc,"normal", base_item, &style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item, &style->hover);
	NK_SET_STYLE(L,lc,"active", base_item, &style->active);

	NK_SET_STYLE(L,lc,"inc button", button, &style->inc_button);
	NK_SET_STYLE(L,lc,"dec button", button, &style->dec_button);
	style->show_buttons = true; 
	style->dec_symbol = NK_SYMBOL_NONE;
	style->inc_symbol = NK_SYMBOL_NONE;
	

	NK_SET_STYLE(L,lc,"cursor normal", base_item, &style->cursor_normal);
	NK_SET_STYLE(L,lc,"cursor hover", base_item, &style->cursor_hover);
	NK_SET_STYLE(L,lc,"cursor active", base_item, &style->cursor_active);
	NK_SET_STYLE(L,lc,"cursor border color", base_color, &style->cursor_border_color);

	NK_SET_STYLE(L,lc,"border", float, &style->border);
	NK_SET_STYLE(L,lc,"border color", base_color, &style->border_color);
	NK_SET_STYLE(L,lc,"rounding", float, &style->rounding);
	NK_SET_STYLE(L,lc,"border cursor", float, &style->border_cursor);
	NK_SET_STYLE(L,lc,"rounding cursor", float, &style->rounding_cursor);
	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);
}


//--- set checkbox style ---
static void 
lnk_set_style_checkbox(lua_State *L,struct lnk_context *lc,struct nk_style_toggle *style)
{
	lnk_assert(L,lua_istable( L,-1),"%s: checkbox style must be a table.\n");

	NK_SET_STYLE(L,lc,"normal",base_item,&style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item,&style->hover);
	NK_SET_STYLE(L,lc,"active",base_item,&style->active);
	NK_SET_STYLE(L,lc,"border color",base_color,&style->border_color);

	NK_SET_STYLE(L,lc,"text background",base_color, &style->text_background);
	NK_SET_STYLE(L,lc,"text normal", base_color, &style->text_normal);
	NK_SET_STYLE(L,lc,"text hover", base_color, &style->text_hover);
	NK_SET_STYLE(L,lc,"text active", base_color, &style->text_active);
	// align
	NK_SET_STYLE(L,lc,"text alignment", align, &style->text_alignment);
	// float 
	NK_SET_STYLE(L,lc,"border", float, &style->border);
	NK_SET_STYLE(L,lc,"spacing", float, &style->spacing);
	// vec2 
	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);
	NK_SET_STYLE(L,lc,"touch padding", vec2, &style->touch_padding);

	NK_SET_STYLE(L,lc,"cursor normal",base_item, &style->cursor_normal);
	NK_SET_STYLE(L,lc,"cursor hover", base_item, &style->cursor_hover);
}

//------- set window style -------------
// window header
static void 
lnk_set_style_window_header(lua_State *L,struct lnk_context *lc,struct nk_style_window_header *style)
{
	lnk_assert(L,lua_istable( L,-1),"%s: window header style must be a table.\n");

	NK_SET_STYLE(L,lc,"normal", base_item, &style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item, &style->hover);
	NK_SET_STYLE(L,lc,"active", base_item, &style->active);
	NK_SET_STYLE(L,lc,"close button", button, &style->close_button);
	NK_SET_STYLE(L,lc,"minimize button", button, &style->minimize_button);
	NK_SET_STYLE(L,lc,"label normal", base_color, &style->label_normal);
	NK_SET_STYLE(L,lc,"label hover", base_color, &style->label_hover);
	NK_SET_STYLE(L,lc,"label active", base_color, &style->label_active);
	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);
	NK_SET_STYLE(L,lc,"label padding", vec2, &style->label_padding);
	NK_SET_STYLE(L,lc,"spacing", vec2, &style->spacing);
}

// window 
static void
lnk_set_style_window(lua_State *L,struct lnk_context *lc,struct nk_style_window *style)
{
	lnk_assert(L,lua_istable(L,-1),"%s: window style must be a table.\n");

	NK_SET_STYLE(L,lc,"header", window_header, &style->header);
	NK_SET_STYLE(L,lc,"fixed background", base_item, &style->fixed_background);
	NK_SET_STYLE(L,lc,"background", base_color, &style->background);

	NK_SET_STYLE(L,lc,"border", float, &style->border);
	NK_SET_STYLE(L,lc,"border color", base_color, &style->border_color);

	NK_SET_STYLE(L,lc,"scrollbar size", vec2, &style->scrollbar_size);

	NK_SET_STYLE(L,lc,"popup border", float, &style->popup_border);
	NK_SET_STYLE(L,lc,"popup border color", base_color, &style->popup_border_color);

	NK_SET_STYLE(L,lc,"combo border", float, &style->combo_border);
	NK_SET_STYLE(L,lc,"combo border color", base_color, &style->combo_border_color);

	NK_SET_STYLE(L,lc,"contextual border", float, &style->contextual_border);
	NK_SET_STYLE(L,lc,"contextual border color", base_color, &style->contextual_border_color);

	NK_SET_STYLE(L,lc,"menu border", float, &style->menu_border);	
	NK_SET_STYLE(L,lc,"menu border color", base_color, &style->menu_border_color);

	NK_SET_STYLE(L,lc,"group border", float, &style->group_border);
	NK_SET_STYLE(L,lc,"group border color", base_color, &style->group_border_color);

	NK_SET_STYLE(L,lc,"tooltip border", float, &style->tooltip_border);
	NK_SET_STYLE(L,lc,"tooltip border color", base_color, &style->tooltip_border_color);

	NK_SET_STYLE(L,lc,"scaler", base_item, &style->scaler);
	NK_SET_STYLE(L,lc,"rounding", float, &style->rounding);
	NK_SET_STYLE(L,lc,"spacing", vec2, &style->spacing);
	NK_SET_STYLE(L,lc,"min size", vec2, &style->min_size);
	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);
	NK_SET_STYLE(L,lc,"group padding", vec2, &style->group_padding);
	NK_SET_STYLE(L,lc,"popup padding", vec2, &style->popup_padding);
	NK_SET_STYLE(L,lc,"combo padding", vec2, &style->combo_padding);
	NK_SET_STYLE(L,lc,"contextual padding", vec2, &style->contextual_padding);
	NK_SET_STYLE(L,lc,"menu padding", vec2, &style->menu_padding);
	NK_SET_STYLE(L,lc,"tooltip padding", vec2, &style->tooltip_padding);
}

// slider 
static int 
lnk_set_style_slider(lua_State *L,struct lnk_context *lc,struct nk_style_slider *style)
{
	lnk_assert(L, lua_istable(L,-1),"%s: slider style must be a table.\n");

	NK_SET_STYLE(L,lc,"normal", base_item, &style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item, &style->hover);
	NK_SET_STYLE(L,lc,"active", base_item, &style->active);

	NK_SET_STYLE(L,lc,"border color", base_color, &style->border_color);

	NK_SET_STYLE(L,lc,"bar normal", base_color, &style->bar_normal);
	NK_SET_STYLE(L,lc,"bar active", base_color, &style->bar_active);
	NK_SET_STYLE(L,lc,"bar filled", base_color, &style->bar_filled);

	NK_SET_STYLE(L,lc,"cursor normal", base_item, &style->cursor_normal);
	NK_SET_STYLE(L,lc,"cursor hover", base_item, &style->cursor_hover);
	NK_SET_STYLE(L,lc,"cursor active", base_item, &style->cursor_active);

	NK_SET_STYLE(L,lc,"border", float, &style->border);
	NK_SET_STYLE(L,lc,"rounding", float, &style->rounding);
	NK_SET_STYLE(L,lc,"bar height", float, &style->bar_height);
	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);
	NK_SET_STYLE(L,lc,"spacing", vec2, &style->spacing);

	NK_SET_STYLE(L,lc,"cursor size", vec2, &style->cursor_size);
}

// progress
static int 
lnk_set_style_progress(lua_State *L,struct lnk_context *lc,struct nk_style_progress *style)
{
	lnk_assert( L,lua_istable(L,-1),"%s: progress style must be a table.\n");

	NK_SET_STYLE(L,lc,"normal", base_item, &style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item, &style->hover);
	NK_SET_STYLE(L,lc,"active", base_item, &style->active);

	NK_SET_STYLE(L,lc,"border color", base_color, &style->border_color);

	NK_SET_STYLE(L,lc,"cursor normal", base_item, &style->cursor_normal);
	NK_SET_STYLE(L,lc,"cursor hover", base_item, &style->cursor_hover);
	NK_SET_STYLE(L,lc,"cursor active", base_item, &style->cursor_active);


	NK_SET_STYLE(L,lc,"cursor border", float, &style->border);
	NK_SET_STYLE(L,lc,"cursor rounding", float, &style->rounding);

	NK_SET_STYLE(L,lc,"border", float, &style->border);
	NK_SET_STYLE(L,lc,"rounding", float, &style->rounding);
	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);
}
// edit 
static int 
lnk_set_style_edit(lua_State *L,struct lnk_context *lc,struct nk_style_edit *style)
{
	lnk_assert(L,lua_istable( L, -1), "%s: edit style must be a table.\n");

	NK_SET_STYLE(L,lc,"normal", base_item, &style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item, &style->hover);
	NK_SET_STYLE(L,lc,"active", base_item, &style->active);

	NK_SET_STYLE(L,lc,"border color", base_color, &style->border_color);

	NK_SET_STYLE(L,lc,"cursor normal", base_color, &style->cursor_normal);
	NK_SET_STYLE(L,lc,"cursor hover", base_color, &style->cursor_hover);
	NK_SET_STYLE(L,lc,"cursor text normal", base_color, &style->cursor_text_normal);
	NK_SET_STYLE(L,lc,"cursor text hover", base_color, &style->cursor_text_hover);
	NK_SET_STYLE(L,lc,"text normal", base_color, &style->text_normal);
	NK_SET_STYLE(L,lc,"text hover", base_color, &style->text_hover);
	NK_SET_STYLE(L,lc,"text active", base_color, &style->text_active);
	NK_SET_STYLE(L,lc,"selected normal", base_color, &style->selected_normal);
	NK_SET_STYLE(L,lc,"selected hover", base_color, &style->selected_hover);
	NK_SET_STYLE(L,lc,"selected text normal", base_color, &style->selected_text_hover );
	NK_SET_STYLE(L,lc,"selected text hover", base_color, &style->selected_text_hover);

	NK_SET_STYLE(L,lc,"border", float, &style->border);
	NK_SET_STYLE(L,lc,"rounding", float, &style->rounding);
	NK_SET_STYLE(L,lc,"cursor size", float, &style->cursor_size);

	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);
	NK_SET_STYLE(L,lc,"row padding", float, &style->row_padding);	

	NK_SET_STYLE(L,lc,"scrollbar", scrollbar, &style->scrollbar);
	NK_SET_STYLE(L,lc,"scrollbar size", vec2, &style->scrollbar_size);
}
// property 
static int 
lnk_set_style_property(lua_State *L,struct lnk_context *lc,struct nk_style_property *style)
{
	lnk_assert(L, lua_istable(L,-1),"%s: property style must be a table.\n");

	NK_SET_STYLE(L,lc,"normal", base_item, &style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item, &style->hover);
	NK_SET_STYLE(L,lc,"active", base_item, &style->active);

	NK_SET_STYLE(L,lc,"label normal", base_color, &style->label_normal);
	NK_SET_STYLE(L,lc,"label hover", base_color, &style->label_hover);
	NK_SET_STYLE(L,lc,"label active", base_color, &style->label_active);

	NK_SET_STYLE(L,lc,"border color", base_color, &style->border_color);
	NK_SET_STYLE(L,lc,"border", float, &style->border);
	NK_SET_STYLE(L,lc,"rounding", float, &style->rounding);
	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);	

	NK_SET_STYLE(L,lc,"edit", edit, &style->edit);
	NK_SET_STYLE(L,lc,"inc button", button, &style->inc_button);
	NK_SET_STYLE(L,lc,"dec button", button, &style->dec_button);
}
// radio option
static int 
lnk_set_style_radio(lua_State *L,struct lnk_context *lc,struct nk_style_toggle *style)
{
	lnk_assert(L, lua_istable( L,-1),"%s: radio style must be a table.\n");

	NK_SET_STYLE(L,lc,"normal", base_item, &style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item, &style->hover);
	NK_SET_STYLE(L,lc,"active", base_item, &style->active);

	NK_SET_STYLE(L,lc,"cursor normal", base_item, &style->cursor_normal);
	NK_SET_STYLE(L,lc,"cursor hover", base_item, &style->cursor_hover);

	NK_SET_STYLE(L,lc,"text normal",base_color,&style->text_normal);
	NK_SET_STYLE(L,lc,"text hover",base_color,&style->text_hover);
	NK_SET_STYLE(L,lc,"text active",base_color,&style->text_active);

	NK_SET_STYLE(L,lc,"border",float,&style->border);
	NK_SET_STYLE(L,lc,"border color", base_color, &style->border_color);	
	NK_SET_STYLE(L,lc,"padding", vec2, &style->padding);
	NK_SET_STYLE(L,lc,"touch padding", vec2, &style->touch_padding);
}


// combobox
static int 
lnk_set_style_combobox(lua_State *L,struct lnk_context *lc, struct nk_style_combo *style)
{
	lnk_assert(L,lua_istable(L, -1), "%s: combobox style must be a table.\n");
	NK_SET_STYLE(L,lc,"normal", base_item, &style->normal);
	NK_SET_STYLE(L,lc,"hover", base_item, &style->hover);
	NK_SET_STYLE(L,lc,"active", base_item, &style->active);

	NK_SET_STYLE(L,lc,"border", float, &style->border);
	NK_SET_STYLE(L,lc,"border color", base_color, &style->border_color);
	NK_SET_STYLE(L,lc,"button", button, &style->button);


	NK_SET_STYLE(L,lc,"label normal", base_color, &style->label_normal);
	NK_SET_STYLE(L,lc,"label hover", base_color, &style->label_hover);
	NK_SET_STYLE(L,lc,"label active", base_color, &style->label_active);

	NK_SET_STYLE(L,lc,"symbol normal", base_color, &style->symbol_normal);
	NK_SET_STYLE(L,lc,"symbol hover", base_color, &style->symbol_hover);
	NK_SET_STYLE(L,lc,"symbol active", base_color, &style->symbol_active);

	NK_SET_STYLE(L,lc,"rounding", float, &style->rounding);
	NK_SET_STYLE(L,lc,"content padding", vec2, &style->content_padding);
	NK_SET_STYLE(L,lc,"button padding", vec2, &style->button_padding);
	NK_SET_STYLE(L,lc,"spacing", vec2, &style->spacing);	
}


// 设置新风格 image skin
static int 
lnk_set_style(lua_State *L)
{
	if(!lua_istable(L,1)) 
	  luaL_typerror(L,1,"style must be table.\n");

	lua_newtable(L);
	lua_insert(L,1);    			// put new table in stack bottom 1(-2), parameters in stack top 2(-1)

	struct lnk_context *lc = get_context(L);

    // lua_State, context, control name, func type, setting var 
	NK_SET_STYLE(L,lc,"button",button,&lc->context.style.button);
	NK_SET_STYLE(L,lc,"window",window,&lc->context.style.window);
	NK_SET_STYLE(L,lc,"checkbox",checkbox,&lc->context.style.checkbox);
	NK_SET_STYLE(L,lc,"radio",radio,&lc->context.style.option);
	NK_SET_STYLE(L,lc,"slider",slider,&lc->context.style.slider);
	NK_SET_STYLE(L,lc,"progress",progress,&lc->context.style.progress);
	NK_SET_STYLE(L,lc,"property",property,&lc->context.style.property);
    NK_SET_STYLE(L,lc,"edit",edit,&lc->context.style.edit);
	NK_SET_STYLE(L,lc,"combobox",combobox,&lc->context.style.combo);
	NK_SET_STYLE(L,lc,"scrollh", scrollbar, &lc->context.style.scrollh);
	NK_SET_STYLE(L,lc,"scrollv", scrollbar, &lc->context.style.scrollv);

    // image ?
	// area ? 
	lua_pop(L,1);       			// pop parameters

	lua_getfield(L,LUA_REGISTRYINDEX,"nuklear");
	lua_getfield(L,-1,"stack");
	size_t size = lua_rawlen(L,-1);  
	lua_pushvalue(L,1);         	// push & copy stack bottom's new table to stack top ,save
	lua_rawseti(L,-2,size+1 );  	// copy new table to  "stack"[size + 1] slot 

	return 0;
}

// 恢复到上一个风格
static int 
lnk_unset_style(lua_State *L)
{
	struct lnk_context *lc = get_context(L);
	lua_getfield(L,LUA_REGISTRYINDEX,"nuklear");
	lua_getfield(L,-1,"stack");         // stack on top
	size_t size = lua_rawlen(L,-1);     // stack size = entry count 
	size_t idx = size;
	lua_rawgeti(L,-1,idx);              // get stack[idx] value(source)
	lua_pushnil(L);                     // set nil
	lua_rawseti(L,-3,idx);  			// set stack[idx] = nil 
	size = lua_rawlen(L,-1);     		// value(source) size  
	for(int i= size ;i> 0; i--)         // pop,restore previous   
	{
		lua_rawgeti(L,-1,i);
		const char *type_s = lua_tostring(L,-1);
		if(!strcmp(type_s,"color")) 
			nk_style_pop_color(&lc->context);
		else if(!strcmp(type_s,"item"))
			nk_style_pop_style_item(&lc->context);
		else if(!strcmp(type_s,"font"))
			nk_style_pop_font(&lc->context);
		else if(!strcmp(type_s,"flags"))
			nk_style_pop_flags(&lc->context);
		else if(!strcmp(type_s,"float"))
			nk_style_pop_float(&lc->context);		
		else if( !strcmp(type_s,"vec2"))
			nk_style_pop_vec2(&lc->context);
		else {
			const char *errmsg = lua_pushfstring(L,"%s: style item type is wrong.\n",lua_tostring(L,-1));
			lnk_assert(L,0,errmsg);
		}
		lua_pop(L,1);
	}
	return 0;
}

/*
//-------------
static int lnk_load_font(lua_State *L) 
{
	if(!lua_isstring(L,1)) {
		luaL_typerror(L,1,"must be font path name.\n");
	}
	const char *font_name = luaL_checkstring(L,1);
	int 		font_size = luaL_checkinteger(L,2);
	int font_id = load_font_id( font_name,font_size );
	lua_pushnumber(L,font_id);
	return 1;
}

*/


//-------- control prototype ---
static int
lnk_label(lua_State *L) {
	struct lnk_context *lc = get_context(L);

	int nargs = lua_gettop(L);
	// nargs >=1 && nargs<3
	const char *label_name = luaL_checkstring(L,1);

	int wrap = 0;
	int user_color = 0;
	struct nk_color color;
	nk_flags align = NK_TEXT_LEFT;

	if(nargs>=2) {
		const char *align_string = luaL_checkstring(L,2);
		if(!stricmp(align_string,"wrap"))
			wrap = 1;
		else {
			align = lnk_checkalign(L,2);
		}
	}
	if(nargs>=3) {
		color = lnk_checkcolor(L,3);
		user_color = 1;
	}

   if(user_color) {
	   if(wrap)
	   		nk_label_colored_wrap(&lc->context,label_name,color);
	   else 
	   		nk_label_colored(&lc->context,label_name,align,color);
   } else {
	   // do not know what is wrap effect
	   if(wrap)
	    	nk_label_wrap(&lc->context,label_name);
	   else 
	   		nk_label(&lc->context,label_name,align);
   }
   return 1;
}

// 是否增加button 的align 外接参数? 
static int 
lnk_button(lua_State *L) 
{
	struct lnk_context *lc = get_context(L);
	struct nk_context *ctx = &lc->context;

	int nargs = lua_gettop(L);
	const char *btn_name = NULL;
	if(!lua_isnil(L,1))
	   btn_name = luaL_checkstring(L,1);

	struct nk_color color;
	struct nk_image image;
	int user_color = 0;   // user special 
	int user_image = 0;
	enum nk_symbol_type symbol = NK_SYMBOL_NONE;

	if(nargs>=2 && !lua_isnil(L,2)) {
		if(lua_isstring(L,2)) {     // color or symbol string type
			if(lnk_is_color(L,2)) {
				user_color = 1;
				color = lnk_checkcolor(L,2);	
			} else {
				symbol = lnk_checksymbol(L,2);
			}
		} else {
			lnk_checkimage(L,2,&image);  // image userdata
			user_image = 1;
		}
	}
    // 应该在增加一个文本对齐参数 ！
	nk_flags align = ctx->style.button.text_alignment;
	int ac = 0;
	if( btn_name != NULL ) {
		if(user_color)
			lnk_assert(L,0,"%s:color button can not have titile name\n");
		else if(user_image) 
			ac = nk_button_image_label( ctx,image,btn_name,align);
		else if( symbol != NK_SYMBOL_NONE)
			ac = nk_button_symbol_label( ctx,symbol,btn_name,align);
		else 
			ac = nk_button_label( ctx,btn_name);
	} else { 
		// no title name
		if(user_color)
			ac = nk_button_color( ctx,color);
		else if(symbol != NK_SYMBOL_NONE)
			ac = nk_button_symbol( ctx,symbol);
		else if(user_image)
			ac = nk_button_image( ctx,image);
	}
	lua_pushboolean(L,ac);
	return 1;
}

// ctx
// edit type,data string,len,max_len,nk_plugin_filter
// lua args( type,text,filter)
static int 
lnk_edit(lua_State* L) {
	struct lnk_context *lc = get_context(L);

	nk_flags  edit_type = lnk_checkedittype(L,1);
	if(!lua_istable(L,2))       // text table
		luaL_typerror(L,2,"text need table {value =... } ");    
	 lua_getfield(L,2,"value");  // text value
	if(!lua_isstring(L,-1))
		luaL_argerror(L,2,"must have a string value { value = '...'}.\n");
	
	const char *edit_value = lua_tostring(L,-1);
	size_t len  = NK_CLAMP( 0, strlen(edit_value), NK_ANT_EDIT_BUFFER_LEN-1 );
	memcpy( lc->edit_buf,edit_value,len );
	lc->edit_buf[len] = '\0';

	nk_plugin_filter filter = nk_filter_default;   // limit
    if(!lua_isnil(L,3)) {
		if(!lua_isstring(L,3)) {
			const char *filter_s = luaL_checkstring(L,3);
			if(!strcmp(filter_s,"hex")) 
				filter = nk_filter_hex;
			else if(!strcmp(filter_s,"ascii"))
				filter = nk_filter_ascii;
			else if(!strcmp(filter_s,"float"))
				filter = nk_filter_float;
			else if(!strcmp(filter_s,"binary"))
				filter = nk_filter_binary;
			else if(!strcmp(filter_s,"oct"))
				filter = nk_filter_oct;
			else if(!strcmp(filter_s,"decimal"))
				filter = nk_filter_decimal;
		}else {
			// user define filter function 
		}
	}
    
	nk_flags event = nk_edit_string_zero_terminated(&lc->context,edit_type,lc->edit_buf,NK_ANT_EDIT_BUFFER_LEN-1,filter);

	lua_pushstring(L,lc->edit_buf);
	lua_pushvalue(L,-1);
	lua_setfield(L,2,"value");
	int changed = !lua_rawequal(L,-1,-2);  // compare source and new text value
	if(event & NK_EDIT_ACTIVATED)
		lua_pushstring(L,"activated");
	else if(event & NK_EDIT_DEACTIVATED)
		lua_pushstring(L,"deactivated");
	else if(event & NK_EDIT_ACTIVE)
		lua_pushstring(L,"active");
	else if(event & NK_EDIT_INACTIVE)
		lua_pushstring(L,"inactive");
	else if(event & NK_EDIT_COMMITED)
		lua_pushstring(L,"commited");
	else 
		lua_pushnil(L);
	lua_pushboolean(L,changed);
	return 2;
}

//value,max,modifiable
// return changed state if value = { value = ...}
//     or number if input value as number 
static int 
lnk_progress(lua_State *L) {
   // args 2 or 3 ,3 = modifiable
   struct lnk_context *lc = get_context(L);
   nk_size max  = lua_tonumber(L,2);
   int modifiable = 0;
   if(!lua_isnil(L,3))
	  modifiable = lua_toboolean(L,3);
   if(lua_istable(L,1)) {
	   lua_getfield(L,1,"value");
	   nk_size value = lua_tonumber(L,-1);
	   int changed = nk_progress(&lc->context,&value,max,modifiable);
	   if( changed ) {
		   lua_pushnumber(L,value);
		   lua_setfield(L,1,"value");
	   }
	   lua_pushboolean(L,changed);
   }
   else if(lua_isnumber(L,1)) {
	   nk_size value = luaL_checknumber(L,1);
	   nk_progress(&lc->context,&value,max,modifiable);
	   lua_pushnumber(L,value);
   }
   else {
	   luaL_typerror(L,1,"progress value must be number or table.\n");
   }
   return 1;
}

// value ,min,max,step
static int 
lnk_slider(lua_State *L) {
	//args == 4
	struct lnk_context* lc = get_context(L);

	float min = luaL_checknumber(L,2);
	float max = luaL_checknumber(L,3);
	float step = luaL_checknumber(L,4);

	if(lua_istable(L,1)) {
		lua_getfield(L,1,"value");
		float value = lua_tonumber(L,-1);
		int changed = nk_slider_float(&lc->context,min,&value,max,step);
		if( changed ) {
			lua_pushnumber(L,value);
			lua_setfield(L,1,"value");
		}
		lua_pushboolean(L,changed);
	}
	else if(lua_isnumber(L,1)) {
		float value = luaL_checknumber(L,1);
		nk_slider_float(&lc->context,min,&value,max,step);
		lua_pushnumber(L,value);
	}
	else  {
		luaL_typerror(L,1,"slider value must be number or table.\n");
	}

	return 1;
}

// ctx,name,value
static int
lnk_checkbox(lua_State *L) {
	// args = 2
	struct lnk_context *lc = get_context(L);

	const char *label_name = luaL_checkstring(L,1);
	if(lua_isboolean(L,2)) {  // bool value
		int value = lua_toboolean(L,2);
		value = nk_check_label(&lc->context,label_name,value);
		lua_pushboolean(L,value);
	} else if(lua_istable(L,2)) { // table value
	    lua_getfield(L,2,"value");
		int value = lua_toboolean(L,-1);
		int changed = nk_checkbox_label(&lc->context,label_name,&value);
		if( changed ) {
			lua_pushboolean(L,value);
			lua_setfield(L,2,"value");
		}
		lua_pushboolean(L,changed);
	} else 	{
		luaL_typerror(L,2,"boolean value or table");
	}
	return 1;
}

// table, item list,item height,size.x,size.y
static int 
lnk_combobox(lua_State *L) 
{
	// nargs>=2 && <=5
	struct lnk_context *lc = get_context(L);

	int num_args = lua_gettop(L);
	if(!lua_istable(L,1) && !lua_isnumber(L,1) )  // value
		luaL_typerror(L,1,"arg 1 must be table or number") ;
	if(!lua_istable(L,2))                         // items
		luaL_typerror(L,2,"arg 2 must be items table");
	
	// get items 
	int itemId = 0; 
	for(itemId = 0;itemId < NK_ANT_COMBOBOX_MAX_ITEMS ;itemId++ ) {
		lua_rawgeti(L,2,itemId+1);
		if(lua_isstring(L,-1))
			lc->combobox_items[itemId] = (char*) lua_tostring(L,-1);
		else if(lua_isnil(L,-1))
			break;
		else 
			luaL_argerror(L,2,"items must be string.\n");
	}

	struct nk_vec2  size;
	struct nk_rect 	bounds;
	int   			item_count;
	int 			item_height;

	bounds      = nk_widget_bounds(&lc->context);
	item_count  = itemId;
	item_height = bounds.h;

	if(num_args>=3 && !lua_isnil(L,3))
		item_height = luaL_checkinteger(L,3);

	size.x = bounds.w; 
	size.y = item_height *8;

	if( num_args>=4 && !lua_isnil(L,4) )
	 	size.x = luaL_checknumber(L,4);
	if( num_args>=5 && !lua_isnil(L,5))
		size.y = luaL_checknumber(L,5);
	
	if(lua_istable(L,1)) {
	    lua_getfield(L,1,"value");
		int value     = luaL_checkinteger(L,-1)-1;
		int old_value = value;
		nk_combobox(&lc->context,(const char **)lc->combobox_items,item_count,&value,item_height,size);
		int changed = (value != old_value);
		if( changed ) {
			lua_pushnumber(L,value+1);
			lua_setfield(L,1,"value");
		}
		lua_pushboolean(L,changed);
	}
	else if(lua_isnumber(L,1)) {
		int value = lua_tointeger(L,1) -1;     // lua to c
		nk_combobox(&lc->context,(const char **)lc->combobox_items,item_count,&value,item_height,size);
		lua_pushnumber(L,value + 1);           // c to lua
	}
	return 1;
}

// name, value,
static int 
lnk_radio(lua_State* L) {
	int nargs = lua_gettop(L);

	struct lnk_context *lc = get_context(L);
	const char *radio_name = luaL_checkstring(L,1);
	if(lua_istable(L,2)) {    // table 
		lua_getfield(L,2,"value");
		if( lua_isstring(L,-1)) {
			const char *value = lua_tostring(L,-1);
			int active = !strcmp(radio_name,value);
			int changed = nk_radio_label(&lc->context,radio_name,&active);
			if(changed && active) {
				lua_pushstring(L,radio_name);
				lua_setfield(L,2,"value");
			}
			lua_pushboolean(L,changed);
		} else {
			luaL_typerror(L,2,"value must be table or string");
		}
	} 
	else if(lua_isstring(L,2)) {   // value
		const char *value = lua_tostring(L,2);
		int active  = !strcmp(radio_name,value);
		active = nk_option_label(&lc->context,radio_name,active);
		if(active)
			lua_pushstring(L,radio_name);    // new select 
		else 
			lua_pushstring(L,value);  		// old select 
	}
	else {
		luaL_typerror(L,2,"must be table or string");
	}
	return 1;
}

//name,value,min,max,step,inc_per_pixel 
static int 
lnk_property(lua_State *L) {
	const char *name = luaL_checkstring(L,1);
	double min  = luaL_checknumber(L,3);
	double max  = luaL_checknumber(L,4);
	double step = luaL_checknumber(L,5);
	float  inc  = luaL_checknumber(L,6);

	struct lnk_context *lc = get_context(L);

	if(lua_istable(L,2)) {  // table 
		lua_getfield(L,2,"value");
		if(!lua_isnumber(L,-1))
			luaL_argerror(L,2,"must have a number value in table { value = ...} .\n");
		double value = lua_tonumber(L,-1);
		double old_value = value; 
		nk_property_double(&lc->context,name,min,&value,max,step,inc);
		int changed = (value != old_value);
		if(changed) {
			lua_pushnumber(L,value);
			lua_setfield(L,2,"value");
		}
		lua_pushboolean(L,changed);
	}
	else if(lua_isnumber(L,2)) { //value 
		double value = luaL_checknumber(L,2);
		nk_property_double(&lc->context,name,min,&value,max,step,inc);
		lua_pushnumber(L,value);
	}
	else {
		luaL_typerror(L,2,"must be number or table.\n");
	}
	return 1;
}

//---- window frame,sub rect -----------------

static int
getmessage_int(lua_State *L, int index) {
	lua_geti(L, -1, index);
	int ret = lua_tointeger(L, -1);
	lua_pop(L, 1);
	return ret;
}

static int
getmessage_bool(lua_State *L, int index) {
	lua_geti(L, -1, index);
	int ret = lua_toboolean(L, -1);
	lua_pop(L, 1);
	return ret;
}

static int
lnk_input(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int n = lua_rawlen(L, 1);
	struct lnk_context *lc = get_context(L);
	struct nk_context *ctx = &lc->context;
	if (n == 0) {
		// no new message
		nk_input_begin(ctx);
		nk_input_end(ctx);
		return 0;
	}
	int i;
	nk_input_begin(ctx);
	for (i=0;i<n;i++) {
		if (lua_geti(L, 1, i+1) != LUA_TTABLE ||
			lua_geti(L, -1, 1) != LUA_TSTRING) {
			nk_input_end(ctx);
			return luaL_error(L, "Invalid message at index %d", i+1);
		}
		const char * type = lua_tostring(L, -1);
		lua_pop(L, 1);
		int x,y,pressed,btnid;

		switch (type[0]) {
		case 'm' :
			x = getmessage_int(L, 2);
			y = getmessage_int(L, 3);
			nk_input_motion(ctx, x, y);			
			break;
		case 'b' :
			btnid = getmessage_int(L, 2);
			pressed = getmessage_bool(L, 3);
			x = getmessage_int(L, 4);
			y = getmessage_int(L, 5);
			nk_input_button(ctx, btnid, x, y, pressed);
			break;
		default:
			// ignore
			break;
		}
		lua_pop(L, 1);
		lua_pushnil(L);
		lua_seti(L, 1, i+1);
	}

	nk_input_end(ctx);
	return 0;
}

static nk_flags 
nk_parse_window_flags(lua_State *L,int flags_begin) {
	int argc = lua_gettop(L);
	nk_flags flags = NK_WINDOW_NO_SCROLLBAR;
	int i;
	for (i = flags_begin; i <= argc; ++i) {
		const char *flag = luaL_checkstring(L, i);
		if (!strcmp(flag, "border"))
			flags |= NK_WINDOW_BORDER;
		else if (!strcmp(flag, "movable"))
			flags |= NK_WINDOW_MOVABLE;
		else if (!strcmp(flag, "scalable"))
			flags |= NK_WINDOW_SCALABLE;
		else if (!strcmp(flag, "closable"))
			flags |= NK_WINDOW_CLOSABLE;
		else if (!strcmp(flag, "minimizable"))
			flags |= NK_WINDOW_MINIMIZABLE;
		else if (!strcmp(flag, "scrollbar"))
			flags &= ~NK_WINDOW_NO_SCROLLBAR;
		else if (!strcmp(flag, "title"))
			flags |= NK_WINDOW_TITLE;
		else if (!strcmp(flag, "scroll auto hide"))
			flags |= NK_WINDOW_SCROLL_AUTO_HIDE;
		else if (!strcmp(flag, "background"))
			flags |= NK_WINDOW_BACKGROUND;
		else {
			const char *msg = lua_pushfstring(L, "unrecognized window flag '%s'", flag);
			return luaL_argerror(L, i, msg);
		}
	}
	return flags;
}

//area = sub rect window in windowBein/End pairs
// title,window flags 
static int 
lnk_area_begin(lua_State *L) {

	struct lnk_context *lc = get_context(L);
	const char *name = luaL_checkstring(L,1);
	nk_flags flags = nk_parse_window_flags(L,2);

	int open = nk_group_begin(&lc->context,name,flags);
	lua_pushboolean(L,open);
	return 1;
}

static int 
lnk_area_end(lua_State *L) {
	struct lnk_context *lc = get_context(L);
	nk_group_end(&lc->context);
	return 0;
}

static int 
lnk_windowBegin(lua_State *L) {
	struct lnk_context *lc = get_context(L);
	const char *name, *title;
	int bounds_begin;
	if (lua_isnumber(L, 2)) {
		// 5 parameters ,2 = number 
		name = title = luaL_checkstring(L, 1);
		bounds_begin = 2;
	} else {
		// name ,title 
		name = luaL_checkstring(L, 1);
		title = luaL_checkstring(L, 2);
		bounds_begin = 3;
	}
	nk_flags flags = nk_parse_window_flags(L,bounds_begin + 4);
	float x = luaL_checknumber(L, bounds_begin);
	float y = luaL_checknumber(L, bounds_begin + 1);
	float width = luaL_checknumber(L, bounds_begin + 2);
	float height = luaL_checknumber(L, bounds_begin + 3);
	int open = nk_begin_titled(&lc->context, name, title, nk_rect(x, y, width, height), flags);
	lua_pushboolean(L, open);

	lc->num_layout_ratios = 0;  // collect all layout ratios in windowBegin/End 
	return 1;
}

static int 
lnk_windowEnd(lua_State* L) {
	struct lnk_context *lc = get_context(L);
	nk_end(&lc->context);

	return 1;
}

static struct nk_buffer *
new_buffer(void) {
	struct nk_buffer * buf = malloc(sizeof(struct nk_buffer));
	nk_buffer_init_default(buf);
	return buf;
}

static void
release_buf(void *ptr, void * buf) {
	(void)ptr;
	nk_buffer_free((struct nk_buffer *)buf);
	free(buf);
}

static const bgfx_memory_t *
make_memory(struct nk_buffer *buf) {
	return bgfx_make_ref_release(nk_buffer_memory(buf), buf->needed, release_buf, buf);
}

static int
lnk_update(lua_State *L) {
	struct lnk_context *lc = get_context(L);

	struct nk_buffer *vbuf = new_buffer();
	struct nk_buffer *ibuf = new_buffer();

	int ret = nk_convert(&lc->context, &lc->cmds, vbuf, ibuf,&lc->cfg);

	if (ret != NK_CONVERT_SUCCESS || vbuf->needed == 0) {
		bgfx_touch(lc->view);
		release_buf(NULL, vbuf);
		release_buf(NULL, ibuf);
		return 0;
	}

	uint32_t offset = 0;

	bgfx_update_dynamic_vertex_buffer(lc->vb, 0, make_memory(vbuf));
	bgfx_update_dynamic_index_buffer(lc->ib, 0, make_memory(ibuf));

	const struct nk_draw_command *cmd;
	struct nk_rect nrect = nk_get_null_rect();

	nk_draw_foreach(cmd,&lc->context,&lc->cmds) {
		if(!cmd->elem_count) continue;

		bgfx_set_state(lc->state, lc->rgba);
		bgfx_texture_handle_t tex = {cmd->texture.id};

		bgfx_set_texture(0, lc->tid, tex, UINT32_MAX);

		if (memcmp(&cmd->clip_rect, &nrect, sizeof(nrect))!=0) {
			bgfx_set_scissor(
				(cmd->clip_rect.x), (cmd->clip_rect.y),
				(cmd->clip_rect.w), (cmd->clip_rect.h));
		}

		bgfx_set_dynamic_vertex_buffer(0, lc->vb, 0, UINT32_MAX);
		bgfx_set_dynamic_index_buffer(lc->ib, offset, cmd->elem_count);

		bgfx_submit(lc->view, lc->prog, 0, 0);
		offset += cmd->elem_count;
	}

	nk_clear(&lc->context);

	return 0;
}


LUAMOD_API int
luaopen_bgfx_nuklear(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		// device api
		{ "init", lnk_context_init },
		{ "resize", lnk_resize },
		{ "update", lnk_update },
		{ "input", lnk_input },
		// nk api
		{"windowBegin",lnk_windowBegin},
		{"windowEnd",lnk_windowEnd},
		{"areaBegin",lnk_area_begin},
		{"areaEnd",lnk_area_end},
		{"setFont",lnk_set_font},
		{"useFont",lnk_set_font},
		{"layoutRow",lnk_layout_row},
		{"spacing",lnk_spacing},
		// nk control
		{"label",lnk_label},
		{"button",lnk_button},
		{"image",lnk_image},
		{"edit",lnk_edit},
		{"progress",lnk_progress},
		{"slider",lnk_slider},
		{"checkbox",lnk_checkbox},
		{"combobox",lnk_combobox},
		{"radio",lnk_radio},
		{"property",lnk_property},

		//nk style
		{"defaultStyle",lnk_set_style_default},
		{"themeStyle",lnk_set_style_theme},
		{"colorStyle",lnk_set_style_colors},
		{"setStyle",lnk_set_style},
		{"unsetStyle",lnk_unset_style},

		// image atlas 
		{"makeImage",lnk_convert_image},
		{"subImage",lnk_sub_image},
		{"subImageId",lnk_sub_image_id},
		{"loadImage",lnk_load_image},
		{ NULL, NULL },
	};
	luaL_newlibtable(L, l);
	lnk_context_new(L);
	luaL_setfuncs(L, l, 1);
	
	return 1;
}
