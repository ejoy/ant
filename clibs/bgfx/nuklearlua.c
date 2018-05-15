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

struct lnk_ui_vertex {
	float position[2];
	float uv[2];
	nk_byte col[4];
};

struct lnk_context {
	int init;
	int width;
	int height;
	struct nk_font **fonts;

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
};

static int
lnk_context_delete(lua_State *L) {
	struct lnk_context *lc = lua_touserdata(L, 1);
	if (lc->init) {
		nk_buffer_free(&lc->cmds);
		nk_font_atlas_clear(&lc->atlas);
		nk_free(&lc->context);

		bgfx_destroy_dynamic_vertex_buffer(lc->vb);
		bgfx_destroy_dynamic_index_buffer(lc->ib);
		bgfx_destroy_texture(lc->fontexture);
		bgfx_destroy_uniform(lc->tid);
		bgfx_destroy_program(lc->prog);
		free(lc->fonts);

		lc->init = 0;
	}
	return 0;
}

static int
lnk_context_new(lua_State *L) {
	struct lnk_context * lc = lua_newuserdata(L, sizeof(*lc));
	lc->init = 0;	// not init
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

static void
bake_default(lua_State *L, struct lnk_context *lc) {
	lc->fonts = malloc(sizeof(lc->fonts[0]) * 1);
	lc->fonts[0] =  nk_font_atlas_add_default(&lc->atlas, 13.0f, NULL);
}

static void
gen_fontexture(lua_State *L, struct lnk_context *lc) {
	int w=0,h=0;
	const void* image = nk_font_atlas_bake(&lc->atlas,&w,&h,NK_FONT_ATLAS_RGBA32);	// todo: use ALPHA8
	int size = w * h *4;
	const bgfx_memory_t *m = bgfx_alloc(size);
	memcpy(m->data,image,size);
	lc->fontexture = bgfx_create_texture_2d(w,h,0,1,BGFX_TEXTURE_FORMAT_RGBA8,0,m);
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

	nk_buffer_init_default(&lc->cmds);
	
	// init config
	init_config(L, lc);

	nk_font_atlas_init_default(&lc->atlas);
	nk_font_atlas_begin(&lc->atlas);

	if (lua_getfield(L, 1, "fonts") == LUA_TNIL) {
		bake_default(L, lc);
	} else {
		// todo: bake_fonts
		luaL_error(L, "TODO: bake fonts");
//		bake_fonts(L, lc);
	}
	lua_pop(L, 1);

	gen_fontexture(L, lc);

	nk_font_atlas_end(&lc->atlas, nk_handle_id(lc->fontexture.idx), &lc->cfg.null);
	nk_font_atlas_cleanup(&lc->atlas);

	nk_init_default(&lc->context,&lc->fonts[0]->handle);

	lc->init = 1;

	return 0;
}

/*
// lua 5.1 后舍弃的函数
LUALIB_API int 
luaL_typerror (lua_State *L, int narg, const char *tname) 
{
  const char *msg = lua_pushfstring(L, "%s expected, got %s",
                                    tname, luaL_typename(L, narg));
  return luaL_argerror(L, narg, msg);
}

static void *
nk_lua_malloc(size_t size) {
	void *mem = malloc(size);
	return mem;
}

nk_lua_free(void *men) {
	free(men);
}

void nk_assert(int ignore,const char *msg) {
	if(ignore)
	  return;
	lua_Debug ld;
	ld.name = NULL;
	if(lua_getstack(s_L,0,&ld))
	   lua_getinfo(s_L,"n",&ld);
	if(ld.name == NULL)
	   ld.name = "?";
	luaL_error(s_L,msg,ld.name);
}

static int nk_is_type(int index,const char *type)
{
	if(index<0)
		index += lua_gettop(s_L) + 1;
	if(lua_isuserdata(s_L,index)) {
		lua_getfield(s_L,index,"typeOf");
		if(lua_isfunction(s_L,-1)) {   // func
			lua_pushvalue(s_L,index);  // arg1
			lua_pushstring(s_L,type);  // arg2
			lua_call(s_L,2,1);         // call(func,num args,num ret)
			if(lua_isboolean(s_L,-1)) {
				int is_type = lua_toboolean(s_L,-1);
				lua_pop(s_L,1);
				return is_type;
			}
		}
	}
	return 0;
}

static int nk_is_hex(char c)
{
	return (c >= '0' && c <= '9')
			|| (c >= 'a' && c <= 'f')
			|| (c >= 'A' && c <= 'F');
}

// 判断字符串是否是有效的颜色值格式,"#2d2d2d00"
static int nk_is_color(int index)
{
	if (index < 0)
		index += lua_gettop(s_L) + 1;
	if (lua_isstring(s_L, index)) {
		size_t len;
		const char *color_string = lua_tolstring(s_L, index, &len);
		if ((len == 7 || len == 9) && color_string[0] == '#') {
			int i;
			for (i = 1; i < len; ++i) {
				if (!nk_is_hex(color_string[i]))
					return 0;
			}
			return 1;
		}
	}
	return 0;
}

static int nk_lua_checkboolean(lua_State *L, int index)
{
	if (index < 0)
		index += lua_gettop(L) + 1;
	luaL_checktype(L, index, LUA_TBOOLEAN);
	return lua_toboolean(L, index);
}

static nk_flags nk_lua_checkedittype(int index) 
{
	if(index <0)
		index += lua_gettop(s_L) +1;

	nk_flags flags = NK_EDIT_SIMPLE;
	if(!lua_isstring(s_L,index))
		return flags;
    const char *edit_s = luaL_checkstring(s_L,index);
	if(!strcmp(edit_s,"edit simple")) 
		flags = NK_EDIT_SIMPLE;
	else if(!strcmp(edit_s,"edit box"))
		flags = NK_EDIT_BOX;
	else if(!strcmp(edit_s,"edit field"))
		flags = NK_EDIT_FIELD;
	else if(!strcmp(edit_s,"edit editor"))
		flags = NK_EDIT_EDITOR;
	else {
		const char *err_msg = lua_pushfstring(s_L,"wrong edit type:'%s'",edit_s);
		return (nk_flags) luaL_argerror(s_L,index,err_msg);
	}
	return flags;
}

static enum nk_layout_format 
nk_checkformat(int index) {
    if (index < 0 )
      index += lua_gettop(s_L)+1;
    const char *type = luaL_checkstring(s_L,index);
    if(!strcmp(type,"dynamic")){
        return NK_DYNAMIC;
    } else if(!strcmp(type,"static")){
        return NK_STATIC;
    } else {
        const char *err_msg = lua_pushfstring(s_L,"unrecognized layout format: '%s' ",type);
        return (enum nk_layout_format ) luaL_argerror(s_L,index,err_msg );
    }
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

// copy & paste
static void nk_lua_clipbard_paste(nk_handle usr, struct nk_text_edit *edit)
{
	// 需要另外提供paste clipboard 功能
	(void)usr;
	lua_getglobal(s_L, "ant");
	lua_getfield(s_L, -1, "system");
	lua_getfield(s_L, -1, "getClipboardText");
	lua_call(s_L, 0, 1);
	const char *text = lua_tostring(s_L, -1);
	if (text) nk_textedit_paste(edit, text, nk_strlen(text));
	lua_pop(s_L, 3);
}

static int nk_lua_is_active(struct nk_context *ctx)
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


static void nk_lua_clipbard_copy(nk_handle usr, const char *text, int len)
{
	// 需要另外提供copy clipboard 功能
	(void) usr;
	char *str = 0;
	if (!len) return;
	str = (char*)malloc((size_t)len+1);
	if (!str) return;
	memcpy(str, text, (size_t)len);
	str[len] = '\0';
	lua_getglobal(s_L, "ant");
	lua_getfield(s_L, -1, "system");
	lua_getfield(s_L, -1, "setClipboardText");
	lua_pushstring(s_L, str);
	free(str);
	lua_call(s_L, 1, 0);
	lua_pop(s_L, 2);
}


// textinput unicode decode
static int nk_lua_textinput_event(const char *text)
{
	nk_rune rune;
	nk_utf_decode(text, &rune, strlen(text));
	nk_input_unicode(&context, rune);
	return nk_lua_is_active(&context);
}


void nk_lua_default_ui_cache_init() 
{
	// editor cache system 
	g_sys_edit_buffer = (char*)  nk_lua_malloc(NK_ANT_EDIT_BUFFER_LEN);
	g_combobox_items  = (char**) nk_lua_malloc(sizeof(char*)*NK_ANT_COMBOBOX_MAX_ITEMS);
	
	// copy & paste callbacks
	context.clip.copy     = nk_lua_clipbard_copy;
	context.clip.paste    = nk_lua_clipbard_paste;
	context.clip.userdata = nk_handle_ptr(0);
}

void nk_lua_default_ui_cache_shutdown()
{
  	nk_lua_free( g_sys_edit_buffer );
  	nk_lua_free( g_combobox_items);
}

// for setStyle,unsetStyle 
void nk_lua_stack_init()
{
   //  注册 nuklear 的全局属性表,font,image,stack   
   //  LUA_REGISTRYINDEX 
   //  nuklear = { font  = { } , image = { } , stack = { }   
   {
	   lua_newtable(s_L);
	   lua_pushvalue(s_L,-1);      					 // copy stack top table and push stack 
	   lua_setfield(s_L,LUA_REGISTRYINDEX,"nuklear");  // table name = nuklear
	   lua_newtable(s_L);
	   lua_setfield(s_L,-2,"font");                   //  font table in nuklear table
	   lua_newtable(s_L);
	   lua_setfield(s_L,-2,"image");                  //  image table in nuklear table
	   lua_newtable(s_L);
	   lua_setfield(s_L,-2,"stack");                  //  stack table in nuklear table
   }
}
void nk_lua_stack_shutdown()
{

}

static void *
getfield(lua_State *L,const char *key)
{
	lua_getfield(L,1,key);
	void *ud = lua_touserdata(L,-1);
	lua_pop(L,1);
	return ud;
}

//--- nk ui ---
// 窗口由外部创建的设置函数
// 并假设bgfx 已经由外部初始化完成
static int
lnk_set_window(lua_State *L) {
	luaL_checktype(L,1,LUA_TTABLE);

	void *lndt = getfield(L, "ndt");
	void *lnwh = getfield(L, "nwh");
	void *lcontext = getfield(L, "context");
	void *lbackBuffer = getfield(L, "backBuffer");
	void *lbackBufferDS = getfield(L, "backBufferDS");
	void *lsession = getfield(L, "session");

	if(lnwh)
		printf_s(" we got a window handle \n" ) ;
	else 
	    printf_s(" this is not a window handle \n");
  

#ifdef PLATFORM_BGFX 
	Platform_Bgfx_set_window(&device, lnwh );
#endif
	return 0;
}

// 必须在lnk_init 之后执行
static int lnk_set_window_size(lua_State *L)
{
	int w = luaL_checknumber(L,1);
	int h = luaL_checknumber(L,2);

	device.width = w;
	device.height = h;
	
#ifdef PLATFORM_BGFX
	Platform_Bgfx_reset_window(&device,w,h);
#endif 
	return 0;
} 

static int lnk_reset_window(lua_State *L)
{
	return 0;
}

static int 
lnk_init(lua_State *L) {

   s_L = L;
   
   // platform init
   device_init(&device); 

   // nuklear stack 
   nk_lua_stack_init();

   // edit & ui behavior init
   nk_lua_default_ui_cache_init();

   // init fonts array
   // must init before load any font
   nk_fonts_mgr_init();

   // default font , size = 13 
   int fontIdx = load_font_id(nullptr,13);    //"font/msyh.ttf"
   struct nk_font *font = g_fonts[ fontIdx ];

   int result =  nk_init_default(&context,&font->handle);     		

   if(g_atlas.default_font) {
	  nk_style_set_font(&context,&g_atlas.default_font->handle);
   }

}

static int 
lnk_shutdown(lua_State *L) {
  device_shutdown(&device);
  nk_lua_default_ui_cache_shutdown();
  nk_fonts_mgr_shutdown();
  nk_lua_stack_shutdown();
}

static int 
lnk_draw(lua_State *L) {
  int width  = luaL_checkinteger(L,1);
  int height = luaL_checkinteger(L,2);
  device_draw(&device,&context,width,height,NK_ANTI_ALIASING_ON);
}

static int 
lnk_mouse(lua_State *L) 
{
	int btn  = luaL_checkinteger(L,1);
	int x    = luaL_checkinteger(L,2);
	int y    = luaL_checkinteger(L,3);
	int down = luaL_checkinteger(L,4);

	struct nk_context *ctx = &context;
	nk_input_begin( ctx );

	if(btn == 49) 
		nk_input_button(ctx, NK_BUTTON_LEFT, x, y, down);
	else if(btn==50)
		nk_input_button(ctx, NK_BUTTON_MIDDLE, x, y, down);
	else if(btn==51)
		nk_input_button(ctx, NK_BUTTON_RIGHT, x, y, down);

	nk_input_end( ctx );

	return 0;
}

static int 
lnk_mouse_motion(lua_State *L)
{
	int x    = luaL_checkinteger(L,1);
	int y    = luaL_checkinteger(L,2);

	struct nk_context *ctx = &context;
	nk_input_begin( ctx );
	
    nk_input_motion(ctx, (int)x, (int)y);

	nk_input_end( ctx );
}

static int 
lnk_keyboard(lua_State *L)
{
	int keycode = luaL_checkinteger(L,1);
	int down    = luaL_checkinteger(L,2);

	struct nk_context *ctx = &context;
	nk_input_begin( ctx );

	if(keycode == 65361)     // left 
		nk_input_key(ctx, NK_KEY_LEFT, down);
	else if(keycode == 65362)  // up
		nk_input_key(ctx, NK_KEY_UP, down);
	else if(keycode == 65363)  // right
		nk_input_key(ctx, NK_KEY_RIGHT, down);
	else if(keycode == 65364)  // down
		nk_input_key(ctx, NK_KEY_DOWN, down);

	nk_input_end( ctx );

}


//-----------------------------------
// nk callback function
void nk_setupdatefunction(Icallback f)
{
	nk_update_cb = ( nk_update_func ) f;    // update_cb 
	device.nk_update_cb = nk_update_cb; 
}

Icallback nk_setfunction(const char *name,Icallback func)
{
	Icallback old_func;
	void *value;
	if(!name)
		return NULL;
	
	if( !strcmp(name,"UPDATE_ACTION") )
	  nk_setupdatefunction(func);
	return func;
}

// install update callback,transfer all ui elements into nuklearlua
static int update_cb(void)
{
	int ret = 0;
	lua_State *L = (lua_State*) s_L;  	//global lua state 
	lua_getglobal(L,"NK_LUA_UPDATE_FUNC");
	lua_call(L,0,1);  					// call update_cb
	ret = (int)lua_tointeger(L,-1);
	lua_pop(L,1);
	return ret;
}

// --- put lua ui main block by this function ----
// -- setUpdate( lua function) --
static int 
lnk_setUpdate(lua_State* L) {
	if(lua_isnoneornil(L,1))
	  nk_setfunction("UPDATE_ACTION",NULL);
	else 
	{
		luaL_checktype(L,1,LUA_TFUNCTION);
		lua_pushvalue(L,1);          
		lua_setglobal(L,"NK_LUA_UPDATE_FUNC");
		nk_setfunction("UPDATE_ACTION",(Icallback)update_cb);
	}
	return 1;
}


static int 
lnk_windowBegin(lua_State *L) {
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
	int open = nk_begin_titled(&context, name, title, nk_rect(x, y, width, height), flags);
	lua_pushboolean(L, open);

	return 1;    
}

static int 
lnk_windowEnd(lua_State* L) {   
    nk_end(&context);

	return 1;
}

static int 
lnk_frameBegin(lua_State* L){
	context.delta_time_seconds =  0.01;
}

static int 
lnk_frameEnd(lua_State* L) {
	nk_input_begin(&context);
}


// "dynamic",height,cols
//  nk: nk_layout_row_dynamic
static int 
lnk_layout_row(lua_State *L)
{
	int argc = lua_gettop(L);

	enum  nk_layout_format format = nk_checkformat(1);
	float height = luaL_checknumber(L, 2);
	int   use_ratios = 0;
	if (format == NK_DYNAMIC) {
		if (lua_isnumber(L, 3)) {
			int cols = luaL_checkinteger(L, 3);
			nk_layout_row_dynamic(&context, height, cols);
		} else {
			if (!lua_istable(L, 3))
				luaL_argerror(L, 3, "should be a number or table");
			use_ratios = 1;
		}
	} else if (format == NK_STATIC) {
		if (argc == 4) {
			int item_width = luaL_checkinteger(L, 3);
			int cols = luaL_checkinteger(L, 4);
			nk_layout_row_static(&context, height, item_width, cols);
		} else {
			if (!lua_istable(L, 3))
				luaL_argerror(L, 3, "should be a number or table");
			use_ratios = 1;
		}
	}
	if (use_ratios) {
		int cols = lua_rawlen(L, -1);    // lua_objlen <=5.1 
		int i, j;
		for (i = 1, j = g_layout_ratio_count; i <= cols && j < NK_ANT_MAX_RATIOS; ++i, ++j) {
			lua_rawgeti(L, -1, i);
			if (!lua_isnumber(L, -1))
				luaL_argerror(L, lua_gettop(L) - 1, "should contain numbers only");
			g_floats[j] = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}
		nk_layout_row(&context, format, height, cols, g_floats + g_layout_ratio_count);
		g_layout_ratio_count += cols;
	}
	return 0;   
}

static int 
lnk_set_style_default(lua_State *L)
{
	nk_style_default(&context);

	//return 1;
	// 在默认外额外的测试设置 -- 展示手工设置方法
	// my default
	struct nk_context &ctx = context;
 // window 
 	struct nk_color background_color = nk_rgb(250,250,250);
	ctx.style.window.background = nk_rgb(204,204,204);
	//ctx.style.window.fixed_background = nk_style_item_image(media.window);      //image 
    ctx.style.window.fixed_background = nk_style_item_color(background_color);    //color
	ctx.style.window.border_color = nk_rgb(167,167,167);
	ctx.style.window.combo_border_color = nk_rgb(67,67,67);
	ctx.style.window.contextual_border_color = nk_rgb(67,67,67);
	ctx.style.window.menu_border_color = nk_rgb(67,67,67);
	ctx.style.window.group_border_color = nk_rgb(67,67,67);
	ctx.style.window.tooltip_border_color = nk_rgb(67,67,67);
	ctx.style.window.scrollbar_size = nk_vec2(16,16);
	ctx.style.window.border_color = nk_rgba(250,0,0,128);
	ctx.style.window.padding = nk_vec2(8,14);
	ctx.style.window.border = 3;
// button 
	ctx.style.button.text_background  = nk_rgb(20,120,20);
	ctx.style.button.text_hover       = nk_rgb(120,120,20);

	return 1;
}

nk_flags nk_lua_checkalign(int index)
{
	if(index<0)
	  index += lua_gettop(s_L)+1;
	
	const char *align_s = luaL_checkstring(s_L,index);
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
	   const char *msg = lua_pushfstring(s_L,"unrecognized aligenment word '%s'.\n ",align_s);
	   return luaL_argerror(s_L,index,msg);
	}
	return flags;
}

// 使用 image() 函数，取得 nk_image 的信息
void nk_lua_checkimage(int index,struct nk_image *image) {
	if(index<0)
		index += lua_gettop(s_L) + 1;
	if(!nk_is_type(index,"Image"))
		luaL_typerror(s_L,index,"Image");
    lua_getfield(s_L,LUA_REGISTRYINDEX,"nuklear");
	lua_getfield(s_L,-1,"image");    // func push stack
	lua_pushvalue(s_L,index);        // arg push stack
	int ref = luaL_ref(s_L,-2);
	lua_getfield(s_L,index,"getDimensions"); // func
	lua_pushvalue(s_L,index);             // arg
	lua_call(s_L,1,2);          	 // return 2 values
	int width = lua_tointeger(s_L,1);
	int height = lua_tointeger(s_L,2);
	image->handle = nk_handle_id( ref);
	image->w = width;
	image->h = height;
	image->region[0] = image->region[1] = 0;
	image->region[2] = width;
	image->region[3] = height;
	lua_pop(s_L,4);
}

static void *
getfield_touserdata(lua_State *L, const char *key) {
	lua_getfield(L, 1, key);
	void * ud = lua_touserdata(L, -1);
	lua_pop(L, 1);
	return ud;
}

static int 
getfield_tointeger(lua_State *L,int index,const char *key) {
	if(index<0)
		index += lua_gettop(L) + 1;
	lua_getfield(L,index,key);
	int ivalue = lua_tointeger(L,-1);
	lua_pop(L,1);
	return ivalue;
}

// struct nk_image {nk_handle handle;unsigned short w,h;unsigned short region[4];};


// 从栈顶 table(nk_image),解码所有参数,填写返回*image 
void nk_checkimage(int index,struct nk_image *image) 
{
	// index 值或需要和其他的一致，后续需要注意！
	if(index<0)
		index += lua_gettop(s_L)+1; 
	luaL_checktype(s_L, index  ,LUA_TTABLE);
	if(!image)
		return;
	
	image->handle = nk_handle_id( getfield_tointeger(s_L,index,"handle") );
	image->w = getfield_tointeger(s_L,index,"w");
	image->h = getfield_tointeger(s_L,index,"h");
	image->region[0] = getfield_tointeger(s_L,index,"x0");
	image->region[1] = getfield_tointeger(s_L,index,"y0");
	image->region[2] = getfield_tointeger(s_L,index,"x1");
	image->region[3] = getfield_tointeger(s_L,index,"y1");

	//printf_s("checkImage:handle.id =%d,w=%d,h=%d,(%d,%d,%d,%d)\n",image->handle.id,image->w,image->h,
	//	image->region[0],image->region[1],image->region[2],image->region[3]);
}


enum nk_symbol_type nk_lua_checksymbol(int index)
{
	if(index<0)
		index += lua_gettop(s_L) + 1;

	enum nk_symbol_type symbol_flags = NK_SYMBOL_NONE;	
	const char* symbol_s = luaL_checkstring(s_L,index);
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
	else if(!strcmp(symbol_s,"triangle_right"))
		symbol_flags =  NK_SYMBOL_TRIANGLE_RIGHT;
	else if(!strcmp(symbol_s,"plus"))
		symbol_flags =  NK_SYMBOL_PLUS;
	else if(!strcmp(symbol_s,"minus"))
		symbol_flags =  NK_SYMBOL_MINUS;
	else {
		const char *err_msg = lua_pushfstring(s_L,"unrecognized symbol type '%s'",symbol_s);
		return (enum nk_symbol_type) luaL_argerror(s_L,index,err_msg);
	}
	return symbol_flags;
}

struct nk_color nk_lua_checkcolor(int index) 
{
	if(index<0) {
	   index += lua_gettop(s_L)+1;
	}
	if(!nk_is_color(index)) {
       if( lua_isstring(s_L,index)) {
		   const char *msg = lua_pushfstring(s_L,"wrong color string format '%s'",lua_tostring(s_L,index));
		   luaL_argerror(s_L,index,msg);
	   } else {
		   luaL_typerror(s_L,index,"color string");
	   }
	}

	size_t len = 0;
	const char *color_string = lua_tolstring(s_L,index,&len);
	int r,g,b,a = 255;
	sscanf_s(color_string,"#%02x%02x%02x",&r,&g,&b);
	if(len==9)
		sscanf_s(color_string+7,"%02x",&a);
	
	struct nk_color color = {(nk_byte)r,(nk_byte)g,(nk_byte)b,(nk_byte)a};
	//printf_s("color = {%d,%d,%d,%d}\n",r,g,b,a);
	return color;
}


#define NK_LOAD_COLOR(type) \
	lua_getfield(L, -1, (type)); \
	nk_assert( nk_is_color(-1), "%s: table missing color value for '" type "'"); \
	colors[ index ] = nk_lua_checkcolor(-1); \
	lua_pop(L, 1);


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
		colors[type] = nk_lua_checkcolor(-1);
		lua_pop(L,1);
	}
	nk_style_from_table(&context, colors);
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
static int 
lnk_set_style_theme(lua_State *L)
{
	const char *theme_string = luaL_checkstring(L,1);
	if(!stricmp(theme_string,"THEME_WHITE")) {
		set_style_theme(&context,THEME_WHITE);
	} 
	else if(!stricmp(theme_string,"THEME_RED")) {
		set_style_theme(&context,THEME_RED);
	}
	else if(!stricmp(theme_string,"THEME_BLUE")) {
		set_style_theme(&context,THEME_BLUE);
	}
	else if(!stricmp(theme_string,"THEME_DARK")) {
		set_style_theme(&context,THEME_DARK);
	}
}



//----------- set style macro prototype ---------
// get style name from table in stack top
// we have one style item
// call this style setup function
// The next three functions and macro are standard sample
#define NK_SET_STYLE( stylename, functype, valuevar ) \
	lua_getfield(s_L,-1,stylename); \
	if(!lua_isnil(s_L,-1)) \
			nk_lua_set_style_##functype( valuevar ); \
	lua_pop(s_L,1);



//--- ui base item prototype ---
//    nk_color , nk_vec2 , nk_style_item , nk_flags , float 

// nk_style_item 
static int nk_lua_set_style_base_item(struct nk_style_item *target ) 
{   // lua to item
	struct  nk_style_item item;
	if( lua_isstring(s_L,-1)) {   			// string is color
		if(!nk_is_color(-1)) {
			const char *msg = lua_pushfstring(s_L," '%s': wrong color string",lua_tostring(s_L,-1) );
			nk_assert( 0, msg );
		}
		item.type = NK_STYLE_ITEM_COLOR;
		item.data.color = nk_lua_checkcolor(-1);
	} 
	else {  								// user data is image
		item.type = NK_STYLE_ITEM_IMAGE;
		// nk_lua_checkimage(-1,&item.data.image);   // 传递函数方法
		nk_checkimage(-1,&item.data.image);          // 传递表的方法
	}
    // item to nk 
	int result  = nk_style_push_style_item( &context,target,item );
	if( result != 0 )  {
		lua_pushstring( s_L,"item");           // save item
		size_t size = lua_rawlen(s_L,1);       // item count
		lua_rawseti(s_L,1, size+1 );           // item count + 1 and save to stack bottom
		//printf_s("save stack item,size =%d \n",size+1);
	}
	return result;
}
// nk_color
static int nk_lua_set_style_base_color(struct nk_color *target) 
{
	if(!nk_is_color(-1)) {
		const char *msg = lua_pushfstring(s_L," '%s': wrong color string",lua_tostring(s_L,-1) );
		nk_assert( 0, msg );
	}

	struct nk_color color = nk_lua_checkcolor(-1);
	int result = nk_style_push_color(&context,target,color);
	if( result ) {
		lua_pushstring(s_L,"color");
		size_t size = lua_rawlen(s_L,1);
		lua_rawseti(s_L,1,size + 1);
	}
	return result;
}
// nk_align
static int nk_lua_set_style_align(nk_flags *target)
{
	nk_flags align = nk_lua_checkalign(-1); 
	int result = nk_style_push_flags(&context,target,align);
	if( result ) {
		lua_pushstring(s_L,"flags");   // push stack
		int size = lua_rawlen(s_L,1);
		lua_rawseti(s_L,1,size +1 );
	}
	return result;
}

// nk_float
static int nk_lua_set_style_float( nk_float *target)
{
	float fv = luaL_checknumber(s_L,-1);
	int result = nk_style_push_float(&context,target,fv);
	if( result ){
		lua_pushstring(s_L,"float");
		int size = lua_rawlen(s_L,1);
		lua_rawseti(s_L,1,size + 1);
	}
	//printf_s("---set style float (%.f)---\n",fv );		
	return result;
}

// nk_vec2 
static int nk_lua_set_style_vec2(struct nk_vec2 *target)
{
	if(!lua_istable(s_L,-1))
		luaL_typerror(s_L,-1,"must be table");

	struct nk_vec2 vec;
	lua_getfield(s_L,-1,"x");
	vec.x = lua_tonumber(s_L,-1);
	lua_pop(s_L,1);
	lua_getfield(s_L,-1,"y");
	vec.y = lua_tonumber(s_L,-1);
	lua_pop(s_L,1);

	int result = nk_style_push_vec2(&context,target,vec);
	if( result ){
		lua_pushstring(s_L, "vec2");
		int size  = lua_rawlen(s_L,1);
		lua_rawseti(s_L,1,size + 1);
	}
	//printf_s("\n cursor size = (%.f,%.f)",vec.x,vec.y);
	return result ;
}


// ui control prototype
//--- set button style -----
static void nk_lua_set_style_button(struct nk_style_button *style)
{
	nk_assert( lua_istable(s_L,-1),"%s: button style must be a table.\n" );

	NK_SET_STYLE("normal",base_item,&style->normal);
	NK_SET_STYLE("hover", base_item,&style->hover);
	NK_SET_STYLE("active",base_item,&style->active);
	NK_SET_STYLE("border color",base_color,&style->border_color);
	NK_SET_STYLE("text background",base_color, &style->text_background);
	NK_SET_STYLE("text normal", base_color, &style->text_normal);
	NK_SET_STYLE("text hover", base_color, &style->text_hover);
	NK_SET_STYLE("text active", base_color, &style->text_active);
	// align
	NK_SET_STYLE("text alignment", align, &style->text_alignment);
	// float 
	NK_SET_STYLE("border", float, &style->border);
	NK_SET_STYLE("rounding", float, &style->rounding);
	// vec2 
	NK_SET_STYLE("padding", vec2, &style->padding);
	NK_SET_STYLE("image padding", vec2, &style->image_padding);
	NK_SET_STYLE("touch padding", vec2, &style->touch_padding);
}
//--- set checkbox style ---
static void nk_lua_set_style_checkbox(struct nk_style_toggle *style)
{
	nk_assert( lua_istable(s_L,-1),"%s: checkbox style must be a table.\n");

	NK_SET_STYLE("normal",base_item,&style->normal);
	NK_SET_STYLE("hover", base_item,&style->hover);
	NK_SET_STYLE("active",base_item,&style->active);
	NK_SET_STYLE("border color",base_color,&style->border_color);

	NK_SET_STYLE("text background",base_color, &style->text_background);
	NK_SET_STYLE("text normal", base_color, &style->text_normal);
	NK_SET_STYLE("text hover", base_color, &style->text_hover);
	NK_SET_STYLE("text active", base_color, &style->text_active);
	// align
	NK_SET_STYLE("text alignment", align, &style->text_alignment);
	// float 
	NK_SET_STYLE("border", float, &style->border);
	NK_SET_STYLE("spacing", float, &style->spacing);
	// vec2 
	NK_SET_STYLE("padding", vec2, &style->padding);
	NK_SET_STYLE("touch padding", vec2, &style->touch_padding);

	NK_SET_STYLE("cursor normal",base_item, &style->cursor_normal);
	NK_SET_STYLE("cursor hover", base_item, &style->cursor_hover);
}

//------- set window style -------------
// window header
static void nk_lua_set_style_window_header(struct nk_style_window_header *style)
{
	nk_assert( lua_istable(s_L,-1),"%s: window header style must be a table.\n");
	//printf_s("type = %d",lua_type(s_L,-1) );

	NK_SET_STYLE("normal", base_item, &style->normal);
	NK_SET_STYLE("hover", base_item, &style->hover);
	NK_SET_STYLE("active", base_item, &style->active);
	NK_SET_STYLE("close button", button, &style->close_button);
	NK_SET_STYLE("minimize button", button, &style->minimize_button);
	NK_SET_STYLE("label normal", base_color, &style->label_normal);
	NK_SET_STYLE("label hover", base_color, &style->label_hover);
	NK_SET_STYLE("label active", base_color, &style->label_active);
	NK_SET_STYLE("padding", vec2, &style->padding);
	NK_SET_STYLE("label padding", vec2, &style->label_padding);
	NK_SET_STYLE("spacing", vec2, &style->spacing);
}
// window 
static void nk_lua_set_style_window(struct nk_style_window *style)
{
	nk_assert( lua_istable(s_L,-1),"%s: window style must be a table.\n");

	NK_SET_STYLE("header", window_header, &style->header);
	NK_SET_STYLE("fixed background", base_item, &style->fixed_background);
	NK_SET_STYLE("background", base_color, &style->background);

	NK_SET_STYLE("border", float, &style->border);
	NK_SET_STYLE("border color", base_color, &style->border_color);

	NK_SET_STYLE("scrollbar size", vec2, &style->scrollbar_size);

	NK_SET_STYLE("popup border", float, &style->popup_border);
	NK_SET_STYLE("popup border color", base_color, &style->popup_border_color);

	NK_SET_STYLE("combo border", float, &style->combo_border);
	NK_SET_STYLE("combo border color", base_color, &style->combo_border_color);

	NK_SET_STYLE("contextual border", float, &style->contextual_border);
	NK_SET_STYLE("contextual border color", base_color, &style->contextual_border_color);

	NK_SET_STYLE("menu border", float, &style->menu_border);	
	NK_SET_STYLE("menu border color", base_color, &style->menu_border_color);

	NK_SET_STYLE("group border", float, &style->group_border);
	NK_SET_STYLE("group border color", base_color, &style->group_border_color);

	NK_SET_STYLE("tooltip border", float, &style->tooltip_border);
	NK_SET_STYLE("tooltip border color", base_color, &style->tooltip_border_color);

	NK_SET_STYLE("scaler", base_item, &style->scaler);
	NK_SET_STYLE("rounding", float, &style->rounding);
	NK_SET_STYLE("spacing", vec2, &style->spacing);
	NK_SET_STYLE("min size", vec2, &style->min_size);
	NK_SET_STYLE("padding", vec2, &style->padding);
	NK_SET_STYLE("group padding", vec2, &style->group_padding);
	NK_SET_STYLE("popup padding", vec2, &style->popup_padding);
	NK_SET_STYLE("combo padding", vec2, &style->combo_padding);
	NK_SET_STYLE("contextual padding", vec2, &style->contextual_padding);
	NK_SET_STYLE("menu padding", vec2, &style->menu_padding);
	NK_SET_STYLE("tooltip padding", vec2, &style->tooltip_padding);
}

// slider 
static int nk_lua_set_style_slider(struct nk_style_slider *style)
{
	nk_assert( lua_istable(s_L,-1),"%s: slider style must be a table.\n");

	NK_SET_STYLE("normal", base_item, &style->normal);
	NK_SET_STYLE("hover", base_item, &style->hover);
	NK_SET_STYLE("active", base_item, &style->active);

	NK_SET_STYLE("border color", base_color, &style->border_color);

	NK_SET_STYLE("bar normal", base_color, &style->bar_normal);
	NK_SET_STYLE("bar active", base_color, &style->bar_active);
	NK_SET_STYLE("bar filled", base_color, &style->bar_filled);

	NK_SET_STYLE("cursor normal", base_item, &style->cursor_normal);
	NK_SET_STYLE("cursor hover", base_item, &style->cursor_hover);
	NK_SET_STYLE("cursor active", base_item, &style->cursor_active);

	NK_SET_STYLE("border", float, &style->border);
	NK_SET_STYLE("rounding", float, &style->rounding);
	NK_SET_STYLE("bar height", float, &style->bar_height);
	NK_SET_STYLE("padding", vec2, &style->padding);
	NK_SET_STYLE("spacing", vec2, &style->spacing);
	//printf_s("\n cursor beging set :---------");
	NK_SET_STYLE("cursor size", vec2, &style->cursor_size);
}
// progress
static int nk_lua_set_style_progress(struct nk_style_progress *style)
{
	nk_assert( lua_istable(s_L,-1),"%s: progress style must be a table.\n");

	NK_SET_STYLE("normal", base_item, &style->normal);
	NK_SET_STYLE("hover", base_item, &style->hover);
	NK_SET_STYLE("active", base_item, &style->active);

	NK_SET_STYLE("border color", base_color, &style->border_color);

	NK_SET_STYLE("cursor normal", base_item, &style->cursor_normal);
	NK_SET_STYLE("cursor hover", base_item, &style->cursor_hover);
	NK_SET_STYLE("cursor active", base_item, &style->cursor_active);


	NK_SET_STYLE("cursor border", float, &style->border);
	NK_SET_STYLE("cursor rounding", float, &style->rounding);

	NK_SET_STYLE("border", float, &style->border);
	NK_SET_STYLE("rounding", float, &style->rounding);
	NK_SET_STYLE("padding", vec2, &style->padding);
}
// edit 
static int nk_lua_set_style_edit(struct nk_style_edit *style)
{
	nk_assert(lua_istable(s_L, -1), "%s: edit style must be a table.\n");

	NK_SET_STYLE("normal", base_item, &style->normal);
	NK_SET_STYLE("hover", base_item, &style->hover);
	NK_SET_STYLE("active", base_item, &style->active);
	NK_SET_STYLE("border color", base_color, &style->border_color);

	NK_SET_STYLE("cursor normal", base_color, &style->cursor_normal);
	NK_SET_STYLE("cursor hover", base_color, &style->cursor_hover);
	NK_SET_STYLE("cursor text normal", base_color, &style->cursor_text_normal);
	NK_SET_STYLE("cursor text hover", base_color, &style->cursor_text_hover);
	NK_SET_STYLE("text normal", base_color, &style->text_normal);
	NK_SET_STYLE("text hover", base_color, &style->text_hover);
	NK_SET_STYLE("text active", base_color, &style->text_active);
	NK_SET_STYLE("selected normal", base_color, &style->selected_normal);
	NK_SET_STYLE("selected hover", base_color, &style->selected_hover);
	NK_SET_STYLE("selected text normal", base_color, &style->selected_text_hover );
	NK_SET_STYLE("selected text hover", base_color, &style->selected_text_hover);
	NK_SET_STYLE("border", float, &style->border);
	NK_SET_STYLE("rounding", float, &style->rounding);
	NK_SET_STYLE("cursor size", float, &style->cursor_size);

	NK_SET_STYLE("padding", vec2, &style->padding);
	NK_SET_STYLE("row padding", float, &style->row_padding);	

	//NK_SET_STYLE("scrollbar", scrollbar, &style->scrollbar);
	//NK_SET_STYLE("scrollbar size", vec2, &style->scrollbar_size);
}
// property 
static int nk_lua_set_style_property(struct nk_style_property *style)
{
	nk_assert( lua_istable(s_L,-1),"%s: property style must be a table.\n");

	NK_SET_STYLE("normal", base_item, &style->normal);
	NK_SET_STYLE("hover", base_item, &style->hover);
	NK_SET_STYLE("active", base_item, &style->active);

	NK_SET_STYLE("border color", base_color, &style->border_color);

	NK_SET_STYLE("label normal", base_color, &style->label_normal);
	NK_SET_STYLE("label hover", base_color, &style->label_hover);
	NK_SET_STYLE("label active", base_color, &style->label_active);


	NK_SET_STYLE("border", float, &style->border);
	NK_SET_STYLE("rounding", float, &style->rounding);
	NK_SET_STYLE("padding", vec2, &style->padding);	

	NK_SET_STYLE("edit", edit, &style->edit);
	NK_SET_STYLE("inc button", button, &style->inc_button);
	NK_SET_STYLE("dec button", button, &style->dec_button);
	
}
// radio option
static int nk_lua_set_style_radio( struct nk_style_toggle *style)
{
	nk_assert( lua_istable(s_L,-1),"%s: radio style must be a table.\n");

	NK_SET_STYLE("normal", base_item, &style->normal);
	NK_SET_STYLE("hover", base_item, &style->hover);
	NK_SET_STYLE("active", base_item, &style->active);

	//NK_SET_STYLE("border color", base_color, &style->border_color);
	NK_SET_STYLE("cursor normal", base_item, &style->cursor_normal);
	NK_SET_STYLE("cursor hover", base_item, &style->cursor_hover);

	NK_SET_STYLE("text normal",base_color,&style->text_normal);
	NK_SET_STYLE("text hover",base_color,&style->text_hover);
	NK_SET_STYLE("text active",base_color,&style->text_active);
}

// combobox
static int nk_lua_set_style_combobox( struct nk_style_combo *style)
{
	nk_assert(lua_istable(s_L, -1), "%s: combobox style must be a table.\n");
	NK_SET_STYLE("normal", base_item, &style->normal);
	NK_SET_STYLE("hover", base_item, &style->hover);
	NK_SET_STYLE("active", base_item, &style->active);

	NK_SET_STYLE("border", float, &style->border);
	NK_SET_STYLE("border color", base_color, &style->border_color);
	NK_SET_STYLE("button", button, &style->button);


	NK_SET_STYLE("label normal", base_color, &style->label_normal);
	NK_SET_STYLE("label hover", base_color, &style->label_hover);
	NK_SET_STYLE("label active", base_color, &style->label_active);

	NK_SET_STYLE("symbol normal", base_color, &style->symbol_normal);
	NK_SET_STYLE("symbol hover", base_color, &style->symbol_hover);
	NK_SET_STYLE("symbol active", base_color, &style->symbol_active);

	NK_SET_STYLE("rounding", float, &style->rounding);
	NK_SET_STYLE("content padding", vec2, &style->content_padding);
	NK_SET_STYLE("button padding", vec2, &style->button_padding);
	NK_SET_STYLE("spacing", vec2, &style->spacing);	
}

// 设置新风格
static int 
lnk_set_style(lua_State *L)
{
	if(!lua_istable(L,1)) 
	  luaL_typerror(L,1,"style must be table.\n");
	lua_newtable(L);
	lua_insert(L,1);    			// put new table in stack bottom 1(-2), parameters in stack top 2(-1)

    //  name, type, var 
	NK_SET_STYLE("button",button,&context.style.button);
	NK_SET_STYLE("window",window,&context.style.window);

	NK_SET_STYLE("checkbox",checkbox,&context.style.checkbox);
	NK_SET_STYLE("radio",radio,&context.style.option);
	NK_SET_STYLE("slider",slider,&context.style.slider);
	NK_SET_STYLE("progress",progress,&context.style.progress);
	NK_SET_STYLE("property",property,&context.style.property);
    NK_SET_STYLE("edit",edit,&context.style.edit);
	NK_SET_STYLE("combobox",combobox,&context.style.combo);




	lua_pop(L,1);       			// pop parameters

	lua_getfield(L,LUA_REGISTRYINDEX,"nuklear");
	lua_getfield(L,-1,"stack");
	size_t size = lua_rawlen(L,-1);  
	lua_pushvalue(L,1);         	// push & copy stack bottom's new table to stack top ,save
	lua_rawseti(L,-2,size+1 );  	// copy new table to  "stack"[size + 1] slot 

	return 1;
}

// 恢复到上一个风格
static int 
lnk_unset_style(lua_State *L)
{
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
			nk_style_pop_color(&context);
		else if(!strcmp(type_s,"item"))
			nk_style_pop_style_item(&context);
		else if(!strcmp(type_s,"font"))
			nk_style_pop_font(&context);
		else if(!strcmp(type_s,"flags"))
			nk_style_pop_flags(&context);
		else if(!strcmp(type_s,"float"))
			nk_style_pop_float(&context);		
		else if( !strcmp(type_s,"vec2"))
			nk_style_pop_vec2(&context);
		else {
			const char *errmsg = lua_pushfstring(L,"%s: style item type is wrong.\n",lua_tostring(L,-1));
			nk_assert(0,errmsg);
		}
		lua_pop(L,1);
	}
	return 1;
}



static int 
lnk_load_image(lua_State *L)
{
	if(!lua_isstring(L,1)) 
		luaL_typerror(L,1,"%s: must be a string .\n");

	const char *filename = luaL_checkstring(L,1);
	
	struct nk_image image = load_image( filename );

	//printf_s("---loadImage '%s': handle.id=%d, w=%d, h=%d, (%d,%d,%d,%d)---\n",
	//	filename,
	//	image.handle.id,image.w,image.h,
	//	image.region[0],image.region[1],image.region[2],image.region[3]);


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
	//return nk_load_image(L);
}

static int 
lnk_sub_image(lua_State *L)
{
	if(!lua_istable(L,1))
		luaL_argerror(L,1,"must a table\n");

	struct nk_image  image; 
	
	nk_checkimage(1,&image);

	int x = luaL_checkinteger(L,2);
	int y = luaL_checkinteger(L,3);
	int w = luaL_checkinteger(L,4);
	int h = luaL_checkinteger(L,5);

	//printf_s("image =%d, w=%d,h=%d,(%d,%d,%d,%d)\n",image.handle.id,image.w,image.h,x,y,w,h);

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

	//printf_s("sub image  =%d, w=%d,h=%d,(%d,%d,%d,%d)\n",s_image.handle.id,s_image.w,s_image.h,x,y,w,h);

	return 1;
}

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

	printf_s("source image id =%d, w=%d,h=%d,(%d,%d,%d,%d)\n",sid,sw,sh,x,y,w,h);

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

	printf_s("sub image id =%d, w=%d,h=%d,(%d,%d,%d,%d)\n",s_image.handle.id,s_image.w,s_image.h,x,y,w,h);
	return 1;
}

// 资源创建和释放应该由应用开发者管理，能更好的知道用途和周期.
static int 
lnk_free_image(lua_State *L)
{
	return  1;
}

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

static int lnk_set_font(lua_State *L)
{
	int font_idx = luaL_checkinteger(L,1);
	if(font_idx<0 ||font_idx>=g_font_count)
		return 0;
	
	struct nk_font *font  = g_fonts[ font_idx ];

	nk_style_set_font(&context, &font->handle );

	return 0;
}

//--------
static int
lnk_label(lua_State *L) {
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
			align = nk_lua_checkalign(2);
		}
	}
	if(nargs>=3) {
		color = nk_lua_checkcolor(3);
		user_color = 1;
	}

   if(user_color) {
	   if(wrap)
	   		nk_label_colored_wrap(&context,label_name,color);
	   else 
	   		nk_label_colored(&context,label_name,align,color);
   } else {
	   if(wrap)
	    	nk_label_wrap(&context,label_name);
	   else 
	   		nk_label(&context,label_name,align);
   }
   return 1;
}

static int 
lnk_button(lua_State *L) 
{
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
		if(lua_isstring(L,2)) {     // color,symbol string type
			if(nk_is_color(2)) {
				user_color = 1;
				color = nk_lua_checkcolor(2);	
			} else {
				symbol = nk_lua_checksymbol(2);
			}
		} else {
			nk_lua_checkimage(2,&image);  // image userdata
			user_image = 1;
		}
	}

	nk_flags align = context.style.button.text_alignment;
	int ac = 0;
	if( btn_name != NULL ) {
		if(user_color)
			nk_assert(0,"%s:color button can not have titile name\n");
		else if(user_image) 
			ac = nk_button_image_label(&context,image,btn_name,align);
		else if( symbol != NK_SYMBOL_NONE)
			ac = nk_button_symbol_label(&context,symbol,btn_name,align);
		else 
			ac = nk_button_label( &context,btn_name);
	} else { 
		// no title name
		if(user_color)
			ac = nk_button_color(&context,color);
		else if(symbol != NK_SYMBOL_NONE)
			ac = nk_button_symbol(&context,symbol);
		else if(user_image)
			ac = nk_button_image(&context,image);
	}
	lua_pushboolean(L,ac);
	return 1;
}

// ctx
// edit type,data string,len,max_len,nk_plugin_filter
// lua args( type,text,filter)
static int 
lnk_edit(lua_State* L) {

	nk_flags  edit_type = nk_lua_checkedittype(1);
	if(!lua_istable(L,2))       // text table
		luaL_typerror(L,2,"table");    
	lua_getfield(L,2,"value");  // text value
	if(!lua_isstring(L,-1))
		luaL_argerror(L,2,"must have a string value.\n");
	
	const char *edit_value = lua_tostring(L,-1);
	size_t len  = NK_CLAMP( 0, strlen(edit_value), NK_ANT_EDIT_BUFFER_LEN-1 );
	memcpy( g_sys_edit_buffer,edit_value,len );
	g_sys_edit_buffer[len] = '\0';

	nk_plugin_filter filter = nk_filter_default;
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
    
	nk_flags event = nk_edit_string_zero_terminated(&context,edit_type,g_sys_edit_buffer,NK_ANT_EDIT_BUFFER_LEN-1,filter);

	lua_pushstring(L,g_sys_edit_buffer);
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
static int 
lnk_progress(lua_State *L) {
   // args 2 or 3 ,3 = modifiable
   nk_size max  = lua_tonumber(L,2);
   int modifiable = 0;
   if(!lua_isnil(L,3))
	  modifiable = lua_toboolean(L,3);
   if(lua_istable(L,1)) {
	   lua_getfield(L,1,"value");
	   nk_size value = lua_tonumber(L,-1);
	   int changed = nk_progress(&context,&value,max,modifiable);
	   if( changed ) {
		   lua_pushnumber(L,value);
		   lua_setfield(L,1,"value");
	   }
	   lua_pushboolean(L,changed);
   }
   else if(lua_isnumber(L,1)) {
	   nk_size value = luaL_checknumber(L,1);
	   nk_progress(&context,&value,max,modifiable);
	   lua_pushnumber(L,value);
   }
   else {
	   luaL_typerror(L,1,"progress value must be number or table.\n");
   }
}

// value ,min,max,step
static int 
lnk_slider(lua_State *L) {
	//args == 4
	float min = luaL_checknumber(L,2);
	float max = luaL_checknumber(L,3);
	float step = luaL_checknumber(L,4);

	if(lua_istable(L,1)) {
		lua_getfield(L,1,"value");
		float value = lua_tonumber(L,-1);
		int changed = nk_slider_float(&context,min,&value,max,step);
		if( changed ) {
			lua_pushnumber(L,value);
			lua_setfield(L,1,"value");
		}
		lua_pushboolean(L,changed);
	}
	else if(lua_isnumber(L,1)) {
		float value = luaL_checknumber(L,1);
		nk_slider_float(&context,min,&value,max,step);
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
	const char *label_name = luaL_checkstring(L,1);
	if(lua_isboolean(L,2)) {  // single value
		int value = lua_toboolean(L,2);
		value = nk_check_label(&context,label_name,value);
		lua_pushboolean(L,value);
	} else if(lua_istable(L,2)) { // table value
	    lua_getfield(L,2,"value");
		int value = lua_toboolean(L,-1);
		int changed = nk_checkbox_label(&context,label_name,&value);
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
	int num_args = lua_gettop(L);
	if(!lua_istable(L,1) && !lua_isnumber(L,1) )
		luaL_typerror(L,1,"arg 1 must be table or number");
	if(!lua_istable(L,2))
		luaL_typerror(L,2,"arg 2 must be items table");
	
	// get items 
	int itemId = 0; 
	for(itemId = 0;itemId < NK_ANT_COMBOBOX_MAX_ITEMS ;itemId++ ) {
		lua_rawgeti(L,2,itemId+1);
		if(lua_isstring(L,-1))
			g_combobox_items[itemId] = (char*) lua_tostring(L,-1);
		else if(lua_isnil(L,-1))
			break;
		else 
			luaL_argerror(L,2,"items must be string.\n");
	}

	struct nk_vec2  size;
	struct nk_rect 	bounds;
	int   			item_count;
	int 			item_height;

	bounds      = nk_widget_bounds(&context);
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
		nk_combobox(&context,(const char **)g_combobox_items,item_count,&value,item_height,size);
		int changed = (value != old_value);
		if( changed ) {
			lua_pushnumber(L,value+1);
			lua_setfield(L,1,"value");
			//printf_s("---combobox select changed--- .\n");
		}
		lua_pushboolean(L,changed);
	}
	else if(lua_isnumber(L,1)) {
		int value = lua_tointeger(L,1) -1;     // lua to c
		nk_combobox(&context,(const char **)g_combobox_items,item_count,&value,item_height,size);
		lua_pushnumber(L,value + 1);           // c to lua
	}
}

// name, value,
static int 
lnk_radio(lua_State* L) {
	int nargs = lua_gettop(L);

	const char *radio_name = luaL_checkstring(L,1);
	if(lua_istable(L,2)) {
		lua_getfield(L,2,"value");
		if( lua_isstring(L,-1)) {
			const char *value = lua_tostring(L,-1);
			int active = !strcmp(radio_name,value);
			int changed = nk_radio_label(&context,radio_name,&active);
			if(changed && active) {
				lua_pushstring(L,radio_name);
				lua_setfield(L,2,"value");
			}
			lua_pushboolean(L,changed);
		} else {
			luaL_typerror(L,2,"value must be table or string");
		}
	} 
	else if(lua_isstring(L,2)) {
		const char *value = lua_tostring(L,2);
		int active  = !strcmp(radio_name,value);
		active = nk_option_label(&context,radio_name,active);
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

	if(lua_istable(L,2)) {
		lua_getfield(L,2,"value");
		if(!lua_isnumber(L,-1))
			luaL_argerror(L,2,"must have a number value.\n");
		double value = lua_tonumber(L,-1);
		double old_value = value; 
		nk_property_double(&context,name,min,&value,max,step,inc);
		int changed = (value != old_value);
		if(changed) {
			lua_pushnumber(L,value);
			lua_setfield(L,2,"value");
		}
		lua_pushboolean(L,changed);
	}
	else if(lua_isnumber(L,2)) {
		double value = luaL_checknumber(L,2);
		nk_property_double(&context,name,min,&value,max,step,inc);
		lua_pushnumber(L,value);
	}
	else {
		luaL_typerror(L,2,"must be number or table.\n");
	}
	return 1;
}

static int 
lnk_spacing(lua_State *L) {
	int cols = luaL_checkinteger(L,1);
	nk_spacing(&context,cols);
	return 1;
}


static int
lnk_checkversion(lua_State* L) {
    printf_s("nuklearLua version %0.2f .\n",s_version);
    return 1;
}

static const struct 
luaL_Reg nuklear_Libs [] = {
    {"checkVersion",lnk_checkversion},

	{"setWindow",lnk_set_window},
	{"setWindowSize",lnk_set_window_size},
	{"reset",lnk_reset_window},
    {"init",lnk_init},
    {"shutdown",lnk_shutdown},
    {"mainloop",lnk_mainloop},
	{"setUpdate",lnk_setUpdate},
    {"draw",lnk_draw},
	{"mouse",lnk_mouse},
	{"motion",lnk_mouse_motion},

    {"frameBegin",lnk_frameBegin},
    {"frameEnd",lnk_frameEnd},
    {"windowBegin",lnk_windowBegin},
    {"windowEnd",lnk_windowEnd},
    {"layoutRow",lnk_layout_row},

	{"defaultStyle",lnk_set_style_default},
	{"themeStyle",lnk_set_style_theme},
	{"colorStyle",lnk_set_style_colors},
	{"setStyle",lnk_set_style},
	{"unsetStyle",lnk_unset_style},

	{"loadImage",lnk_load_image},
	{"freeImage",lnk_free_image},
	{"subImage",lnk_sub_image},
	{"subImageId",lnk_sub_image_id},
	{"loadFont",lnk_load_font},
	{"setFont",lnk_set_font},

	{"label",lnk_label},
	{"button",lnk_button},

	{"edit",lnk_edit},
	{"progress",lnk_progress},
	{"slider",lnk_slider},
	{"checkbox",lnk_checkbox},
	{"combobox",lnk_combobox},
	{"radio",lnk_radio},

	{"spacing",lnk_spacing},
	{"property",lnk_property},
    {NULL,NULL}
}; 

extern "C" {
    LUAMOD_API int
    luaopen_nuklearlua(lua_State* L) {
        luaL_newlib(L,nuklear_Libs);
        return 1;
    }
}

*/

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

	// todo: input
	nk_input_begin(&lc->context);
	nk_input_end(&lc->context);

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
		// nk api
		{"windowBegin",lnk_windowBegin},
		{"windowEnd",lnk_windowEnd},
		{ NULL, NULL },
	};
	luaL_newlibtable(L, l);
	lnk_context_new(L);
	luaL_setfuncs(L, l, 1);
	
	return 1;
}
