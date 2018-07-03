#define LUA_LIB

#include <string.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>
#include <bgfx/c99/bgfx.h>
#include <bgfx/c99/platform.h>
#include <assert.h>

#include "luabgfx.h"
#include "simplelock.h"

#if _MSC_VER > 0
#include <malloc.h>

#	ifdef USING_ALLOCA_FOR_VLA
#		define VLA(_TYPE, _VAR, _SIZE)	_TYPE _VAR = (_TYPE*)_alloca(sizeof(_TYPE) * (_SIZE))
#	else//!USING_ALLOCA_FOR_VLA
#		define V(_SIZE)	4096
#	endif //USING_ALLOCA_FOR_VLA
#else //!(_MSC_VER > 0)
#	ifdef USING_ALLOCA_FOR_VLA
#		define VLA(_TYPE, _VAR, _SIZE) _TYPE _VAR[(_SIZE)]
#	else //!USING_ALLOCA_FOR_VLA
#		define V(_SIZE)	(_SIZE)
#	endif //USING_ALLOCA_FOR_VLA

#endif //_MSC_VER > 0

// screenshot queue length
#define MAX_SCREENSHOT 16

struct screenshot {
	uint32_t width;
	uint32_t height;
	uint32_t pitch;
	uint32_t size;
	void *data;
	char *name;
};

struct screenshot_queue {
	spinlock_t lock;
	unsigned int head;
	unsigned int tail;
	struct screenshot *q[MAX_SCREENSHOT];
};

struct callback {
	bgfx_callback_interface_t base;
	struct screenshot_queue ss;
};

static void *
getfield(lua_State *L, const char *key) {
	lua_getfield(L, 1, key);
	void * ud = lua_touserdata(L, -1);
	lua_pop(L, 1);
	return ud;
}

static int
lsetPlatformData(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	bgfx_platform_data_t bpdt;
	memset(&bpdt, 0, sizeof(bpdt));

	bpdt.ndt = getfield(L, "ndt");
	bpdt.nwh = getfield(L, "nwh");
	bpdt.context = getfield(L, "context");
	bpdt.backBuffer = getfield(L, "backBuffer");
	bpdt.backBufferDS = getfield(L, "backBufferDS");
	bpdt.session = getfield(L, "session");
	
	bgfx_set_platform_data(&bpdt);

	return 0;
}

static bgfx_renderer_type_t
renderer_type_id(lua_State *L, int index) {
	const char * type = luaL_checkstring(L, index);
	bgfx_renderer_type_t id;
#define RENDERER_TYPE_ID(x) else if (strcmp(type, #x) == 0) id = BGFX_RENDERER_TYPE_##x
	if (0) ;
	RENDERER_TYPE_ID(NOOP);
	RENDERER_TYPE_ID(DIRECT3D9);
	RENDERER_TYPE_ID(DIRECT3D11);
	RENDERER_TYPE_ID(DIRECT3D12);
	RENDERER_TYPE_ID(GNM);
	RENDERER_TYPE_ID(METAL);
	RENDERER_TYPE_ID(OPENGLES);
	RENDERER_TYPE_ID(OPENGL);
	RENDERER_TYPE_ID(VULKAN);
	else return luaL_error(L, "Invalid renderer type %s", type);

	return id;
}

static void
cb_fatal(bgfx_callback_interface_t *self, bgfx_fatal_t code, const char *str) {
	fprintf(stderr, "Fatal error: 0x%08x: %s", code, str);
	fflush(stderr);
	abort();
}

static void
cb_trace_vargs(bgfx_callback_interface_t *self, const char *file, uint16_t line, const char *format, va_list ap) {
	fprintf(stderr, "%s (%d): ", file, line);
	vfprintf(stderr, format, ap);
	fflush(stderr);
}

// todo: bgfx callback

static void
cb_profiler_begin(bgfx_callback_interface_t *self, const char* _name, uint32_t _abgr, const char* _filePath, uint16_t _line) {
}


static void
cb_profiler_begin_literal(bgfx_callback_interface_t *self, const char* _name, uint32_t _abgr, const char* _filePath, uint16_t _line) {
}

static void
cb_profiler_end(bgfx_callback_interface_t *self) {
}

static uint32_t
cb_cache_read_size(bgfx_callback_interface_t *self, uint64_t id) {
	return 0;
}

static bool
cb_cache_read(bgfx_callback_interface_t *self,  uint64_t id, void *data, uint32_t size) {
	return false;
}

static void
cb_cache_write(bgfx_callback_interface_t *self, uint64_t id, const void *data, uint32_t size) {
}

static struct screenshot *
ss_pop(struct screenshot_queue *queue) {
	struct screenshot *r;
	spin_lock(queue);
	if (queue->head == queue->tail) {
		r = NULL;
	} else {
		r = queue->q[queue->tail % MAX_SCREENSHOT];
		++queue->tail;
	}
	spin_unlock(queue);
	return r;
}

// succ return NULL
static struct screenshot *
ss_push(struct screenshot_queue *queue, struct screenshot *s) {
	spin_lock(queue);
	if ((queue->head - queue->tail) != MAX_SCREENSHOT) {
		queue->q[queue->head % MAX_SCREENSHOT] = s;
		++queue->head;
		s = NULL;
	}
	spin_unlock(queue);
	return s;
}

static void
ss_free(struct screenshot * s) {
	if (s == NULL)
		return;
	free(s->name);
	free(s->data);
	free(s);
}

static void
cb_screen_shot(bgfx_callback_interface_t *self, const char* file, uint32_t width, uint32_t height, uint32_t pitch, const void* data, uint32_t size, bool yflip) {
	struct screenshot *s = malloc(sizeof(*s));
	size_t fn_sz = strlen(file);
	s->name = malloc(fn_sz + 1);
	memcpy(s->name, file, fn_sz+1);
	s->data = malloc(size);
	s->width = width;
	s->height = height;
	s->pitch = pitch;
	s->size = size;
	uint8_t * dst = (uint8_t *)s->data;
	const uint8_t * src = (const uint8_t *)data;
	int line_pitch = pitch;
	if (yflip) {
		src += (height-1) * pitch;
		line_pitch = - (int32_t)pitch;
	}
	uint32_t pixwidth = size / height;
	uint32_t i;
	for (i=0;i<height;i++) {
		memcpy(dst, src, pixwidth);
		dst += pixwidth;
		src += line_pitch;
	}
	struct callback *cb = (struct callback *)self;
	s = ss_push(&cb->ss, s);
	ss_free(s);
}

static void
cb_capture_begin(bgfx_callback_interface_t *self, uint32_t width, uint32_t height, uint32_t pitch, bgfx_texture_format_t format, bool yflip) {
}

static void
cb_capture_end(bgfx_callback_interface_t *self) {
}

static void
cb_capture_frame(bgfx_callback_interface_t* self, const void* _data, uint32_t _size) {
}

static uint32_t
reset_flags(lua_State *L, int index) {
	const char * flags = lua_tostring(L, index);
	uint32_t f = BGFX_RESET_NONE;
	if (flags) {
		int i;
		for (i=0;flags[i];i++) {
			switch(flags[i]) {
			case 'f' : f |= BGFX_RESET_FULLSCREEN; break;
			case 'v' : f |= BGFX_RESET_VSYNC; break;
			case 'a' : f |= BGFX_RESET_MAXANISOTROPY; break;
			case 'c' : f |= BGFX_RESET_CAPTURE; break;
			case 'h' : f |= BGFX_RESET_HMD; break;
			case 'd' : f |= BGFX_RESET_HMD_DEBUG; break;
			case 'r' : f |= BGFX_RESET_HMD_RECENTER; break;
			case 'u' : f |= BGFX_RESET_FLUSH_AFTER_RENDER; break;
			case 'i' : f |= BGFX_RESET_FLIP_AFTER_RENDER; break;
			case 's' : f |= BGFX_RESET_SRGB_BACKBUFFER; break;
			case 'm' :
				++i;
				switch (flags[i]) {
				case '2' : f |= BGFX_RESET_MSAA_X2; break;
				case '4' : f |= BGFX_RESET_MSAA_X4; break;
				case '8' : f |= BGFX_RESET_MSAA_X8; break;
				case 'x' : f |= BGFX_RESET_MSAA_X16; break;
				default:
					return luaL_error(L, "Invalid MSAA %c", flags[i]);
				}
				break;
			default:
				return luaL_error(L, "Invalid reset flag %c", flags[i]);
			}
		}
	}
	return f;
}

static void
read_uint32(lua_State *L, int index, const char * key, uint32_t *v) {
	if (lua_getfield(L, index, key) != LUA_TNIL) {
		*v = luaL_checkinteger(L, -1);
	}
	lua_pop(L, 1);
}

static void
read_boolean(lua_State *L, int index, const char *key, bool *v) {
	int t = lua_getfield(L, index, key);
	if (t == LUA_TBOOLEAN || t == LUA_TNIL) {
		*v = lua_toboolean(L, -1);
	} else {
		luaL_error(L, ".%s need boolean, it's %s", key, lua_typename(L, t));
	}
	lua_pop(L, 1);
}

static int
linit(lua_State *L) {
	static bgfx_callback_vtbl_t vtbl = {
		cb_fatal,
		cb_trace_vargs,
		cb_profiler_begin,
		cb_profiler_begin_literal,
		cb_profiler_end,
		cb_cache_read_size,
		cb_cache_read,
		cb_cache_write,
		cb_screen_shot,
		cb_capture_begin,
		cb_capture_end,
		cb_capture_frame,
	};
	struct callback *cb = lua_newuserdata(L, sizeof(*cb));
	memset(cb, 0, sizeof(*cb));
	lua_setfield(L, LUA_REGISTRYINDEX, "bgfx_cb");
	cb->base.vtbl = &vtbl;

	bgfx_init_t init;

	init.type = BGFX_RENDERER_TYPE_COUNT;
	init.vendorId = BGFX_PCI_ID_NONE;
	init.deviceId = 0;

	init.resolution.width = 1280;
	init.resolution.height = 720;
	init.resolution.reset = BGFX_RESET_NONE;	// reset flags

	init.limits.maxEncoders     = 8;	// BGFX_CONFIG_DEFAULT_MAX_ENCODERS;
	init.limits.transientVbSize = (6<<20);	// BGFX_CONFIG_TRANSIENT_VERTEX_BUFFER_SIZE
	init.limits.transientIbSize = (2<<20);	// BGFX_CONFIG_TRANSIENT_INDEX_BUFFER_SIZE;

	init.callback = &cb->base;
	init.allocator = NULL;
	init.debug = false;
	init.profile = false;

	if (!lua_isnoneornil(L, 1)) {
		luaL_checktype(L, 1, LUA_TTABLE);
		lua_settop(L, 1);
		if (lua_getfield(L, 1, "renderer") == LUA_TSTRING) {
			init.type = renderer_type_id(L, 2);
		}
		lua_pop(L, 1);
		read_uint32(L, 1, "width", &init.resolution.width);
		read_uint32(L, 1, "height", &init.resolution.height);
		if (lua_getfield(L, 1, "reset") == LUA_TSTRING) {
			init.resolution.reset = reset_flags(L, -1);
		}
		lua_pop(L, 1);
		if (lua_getfield(L, 1, "maxEncoders") == LUA_TNUMBER) {
			init.limits.maxEncoders = luaL_checkinteger(L, -1);
		}
		lua_pop(L, 1);
		read_uint32(L, 1, "transientVbSize", &init.limits.transientVbSize);
		read_uint32(L, 1, "transientIbSize", &init.limits.transientIbSize);
		read_boolean(L, 1, "debug", &init.debug);
		read_boolean(L, 1, "profile", &init.profile);
	}

	if (!bgfx_init(&init)) {
		return luaL_error(L, "bgfx init failed");
	}
	return 0;
}

static void
push_renderer_type(lua_State *L, bgfx_renderer_type_t t) {
	const char *st;
#define RENDERER_TYPE(x) case BGFX_RENDERER_TYPE_##x : st = #x; break
	switch(t) {
		RENDERER_TYPE(NOOP);
		RENDERER_TYPE(DIRECT3D9);
		RENDERER_TYPE(DIRECT3D11);
		RENDERER_TYPE(DIRECT3D12);
		RENDERER_TYPE(GNM);
		RENDERER_TYPE(METAL);
		RENDERER_TYPE(OPENGLES);
		RENDERER_TYPE(OPENGL);
		RENDERER_TYPE(VULKAN);
		default: {
			luaL_error(L, "Unknown renderer type %d", t);
			return;
		}
	}
	lua_pushstring(L, st);
}

static void
push_supported(lua_State *L, uint64_t supported) {
#define CAPSNAME(v) { BGFX_CAPS_##v, #v },
	struct {
		uint64_t caps;
		const char *name;
	} flags[] = {
		CAPSNAME(ALPHA_TO_COVERAGE)     // Alpha to coverage is supported.
		CAPSNAME(BLEND_INDEPENDENT)     // Blend independent is supported.
		CAPSNAME(COMPUTE)               // Compute shaders are supported.
		CAPSNAME(CONSERVATIVE_RASTER)   // Conservative rasterization is supported.
		CAPSNAME(DRAW_INDIRECT)         // Draw indirect is supported.
		CAPSNAME(FRAGMENT_DEPTH)        // Fragment depth is accessible in fragment shader.
		CAPSNAME(FRAGMENT_ORDERING)     // Fragment ordering is available in fragment shader.
		CAPSNAME(GRAPHICS_DEBUGGER)     // Graphics debugger is present.
		CAPSNAME(HIDPI)                 // HiDPI rendering is supported.
		CAPSNAME(HMD)                   // Head Mounted Display is available.
		CAPSNAME(INDEX32)               // 32-bit indices are supported.
		CAPSNAME(INSTANCING)            // Instancing is supported.
		CAPSNAME(OCCLUSION_QUERY)       // Occlusion query is supported.
		CAPSNAME(RENDERER_MULTITHREADED)// Renderer is on separate thread.
		CAPSNAME(SWAP_CHAIN)            // Multiple windows are supported.
		CAPSNAME(TEXTURE_2D_ARRAY)      // 2D texture array is supported.
		CAPSNAME(TEXTURE_3D)            // 3D textures are supported.
		CAPSNAME(TEXTURE_BLIT)          // Texture blit is supported.
		CAPSNAME(TEXTURE_COMPARE_ALL)   // All texture compare modes are supported.
		CAPSNAME(TEXTURE_COMPARE_LEQUAL)// Texture compare less equal mode is supported.
		CAPSNAME(TEXTURE_CUBE_ARRAY)    // Cubemap texture array is supported.
		CAPSNAME(TEXTURE_DIRECT_ACCESS) // CPU direct access to GPU texture memory.
		CAPSNAME(TEXTURE_READ_BACK)     // Read-back texture is supported.
		CAPSNAME(VERTEX_ATTRIB_HALF)    // Vertex attribute half-float is supported.
		CAPSNAME(VERTEX_ATTRIB_UINT10)  // Vertex attribute 10_10_10_2 is supported.
	};
	int n = sizeof(flags) / sizeof(flags[0]);
	lua_createtable(L, 0, n);
	int i;
	for (i=0;i<n;i++) {
		lua_pushboolean(L, supported & flags[i].caps);
		lua_setfield(L, -2, flags[i].name);
	}
}

static void
push_vendor_id(lua_State *L, uint16_t vid) {
	if (vid == BGFX_PCI_ID_SOFTWARE_RASTERIZER) {
		lua_pushstring(L, "SOFTWARE_RASTERIZER");
	} else if (vid == BGFX_PCI_ID_AMD) {
		lua_pushstring(L, "AMD");
	} else if (vid == BGFX_PCI_ID_INTEL) {
		lua_pushstring(L, "INTEL");
	} else if (vid == BGFX_PCI_ID_NVIDIA) {
		lua_pushstring(L, "NVIDIA");
	} else {
		lua_pushinteger(L, vid);
	}
}

static int
find_texture_format(const uint16_t *formats, int index) {
	int i;
	uint16_t c = formats[index];
	for (i=0;i<index;i++) {
		if (c == formats[i]) {
			return i+1;
		}
	}
	return 0;
}

#define TFNAME(v) #v,
static const char * c_texture_formats[] = {
	TFNAME(BC1)
	TFNAME(BC2)
	TFNAME(BC3)
	TFNAME(BC4)
	TFNAME(BC5)
	TFNAME(BC6H)
	TFNAME(BC7)
	TFNAME(ETC1)
	TFNAME(ETC2)
	TFNAME(ETC2A)
	TFNAME(ETC2A1)
	TFNAME(PTC12)
	TFNAME(PTC14)
	TFNAME(PTC12A)
	TFNAME(PTC14A)
	TFNAME(PTC22)
	TFNAME(PTC24)

	TFNAME(ATC)
	TFNAME(ATCE)
	TFNAME(ATCI)
	TFNAME(ASTC4x4)
	TFNAME(ASTC5x5)
	TFNAME(ASTC6x6)
	TFNAME(ASTC8x5)
	TFNAME(ASTC8x6)
	TFNAME(ASTC10x5)

	TFNAME(UNKNOWN)
	TFNAME(R1)
	TFNAME(A8)
	TFNAME(R8)
	TFNAME(R8I)
	TFNAME(R8U)
	TFNAME(R8S)
	TFNAME(R16)
	TFNAME(R16I)
	TFNAME(R16U)
	TFNAME(R16F)
	TFNAME(R16S)
	TFNAME(R32I)
	TFNAME(R32U)
	TFNAME(R32F)
	TFNAME(RG8)
	TFNAME(RG8I)
	TFNAME(RG8U)
	TFNAME(RG8S)
	TFNAME(RG16)
	TFNAME(RG16I)
	TFNAME(RG16U)
	TFNAME(RG16F)
	TFNAME(RG16S)
	TFNAME(RG32I)
	TFNAME(RG32U)
	TFNAME(RG32F)
	TFNAME(RGB8)
	TFNAME(RGB8I)
	TFNAME(RGB8U)
	TFNAME(RGB8S)
	TFNAME(RGB9E5F)
	TFNAME(BGRA8)
	TFNAME(RGBA8)
	TFNAME(RGBA8I)
	TFNAME(RGBA8U)
	TFNAME(RGBA8S)
	TFNAME(RGBA16)
	TFNAME(RGBA16I)
	TFNAME(RGBA16U)
	TFNAME(RGBA16F)
	TFNAME(RGBA16S)
	TFNAME(RGBA32I)
	TFNAME(RGBA32U)
	TFNAME(RGBA32F)
	TFNAME(R5G6B5)
	TFNAME(RGBA4)
	TFNAME(RGB5A1)
	TFNAME(RGB10A2)
	TFNAME(RG11B10F)
	TFNAME(UNKNOWN_DEPTH)
	TFNAME(D16)
	TFNAME(D24)
	TFNAME(D24S8)
	TFNAME(D32)
	TFNAME(D16F)
	TFNAME(D24F)
	TFNAME(D32F)
	TFNAME(D0S8)


};

static void
push_texture_formats(lua_State *L, const uint16_t *formats) {
#define CAPSTF(v) { BGFX_CAPS_FORMAT_TEXTURE_##v, #v },
	struct {
		uint16_t caps;
		const char * name;
	} caps_texture_format[] = {
		CAPSTF(2D)               //Texture format is supported.
		CAPSTF(2D_SRGB)          //Texture as sRGB format is supported.
		CAPSTF(2D_EMULATED)      //Texture format is emulated.
		CAPSTF(3D)               //Texture format is supported.
		CAPSTF(3D_SRGB)          //Texture as sRGB format is supported.
		CAPSTF(3D_EMULATED)      //Texture format is emulated.
		CAPSTF(CUBE)             //Texture format is supported.
		CAPSTF(CUBE_SRGB)        //Texture as sRGB format is supported.
		CAPSTF(CUBE_EMULATED)    //Texture format is emulated.
		CAPSTF(VERTEX)           //Texture format can be used from vertex shader.
		CAPSTF(IMAGE)            //Texture format can be used as image from compute shader.
		CAPSTF(FRAMEBUFFER)      //Texture format can be used as frame buffer.
		CAPSTF(FRAMEBUFFER_MSAA) //Texture format can be used as MSAA frame buffer.
		CAPSTF(MSAA)             //Texture can be sampled as MSAA.
		CAPSTF(MIP_AUTOGEN)      //Texture format supports auto-generated mips.
	};
	lua_createtable(L, 0, BGFX_TEXTURE_FORMAT_COUNT);
	int i,j;
	int ncaps = sizeof(caps_texture_format) / sizeof(caps_texture_format[0]);
	for (i=0;i<BGFX_TEXTURE_FORMAT_COUNT;i++) {
		uint16_t c = formats[i];
		int sameindex = find_texture_format(formats, i);
		if (sameindex) {
			lua_getfield(L, -1, c_texture_formats[sameindex-1]);
		} else {
			lua_newtable(L);
			for (j=0;j<ncaps;j++) {
				if (c & caps_texture_format[j].caps) {
					lua_pushboolean(L, 1);
					lua_setfield(L, -2, caps_texture_format[j].name);
				}
			}
		}
		lua_setfield(L, -2, c_texture_formats[i]);
	}
}

static void
push_limits(lua_State *L, const bgfx_caps_limits_t *lim) {
	lua_createtable(L, 0, 22);
#define PUSH_LIMIT(what) lua_pushinteger(L, lim->what); lua_setfield(L, -2, #what);

	PUSH_LIMIT(maxDrawCalls)
	PUSH_LIMIT(maxBlits)
	PUSH_LIMIT(maxTextureSize)
	PUSH_LIMIT(maxTextureLayers)
	PUSH_LIMIT(maxViews)
	PUSH_LIMIT(maxFrameBuffers)
	PUSH_LIMIT(maxFBAttachments)
	PUSH_LIMIT(maxPrograms)
	PUSH_LIMIT(maxShaders)
	PUSH_LIMIT(maxTextures)
	PUSH_LIMIT(maxTextureSamplers)
	PUSH_LIMIT(maxVertexDecls)
	PUSH_LIMIT(maxVertexStreams)
	PUSH_LIMIT(maxIndexBuffers)
	PUSH_LIMIT(maxVertexBuffers)
	PUSH_LIMIT(maxDynamicIndexBuffers)
	PUSH_LIMIT(maxDynamicVertexBuffers)
	PUSH_LIMIT(maxUniforms)
	PUSH_LIMIT(maxOcclusionQueries)
	PUSH_LIMIT(maxEncoders)
	PUSH_LIMIT(transientVbSize)
	PUSH_LIMIT(transientIbSize)
}

static int
lgetCaps(lua_State *L) {
	const bgfx_caps_t * caps = bgfx_get_caps();
	lua_createtable(L, 0, 9);
	push_renderer_type(L, caps->rendererType);
	lua_setfield(L, -2, "rendererType");
	push_supported(L, caps->supported);
	lua_setfield(L, -2, "supported");
	push_vendor_id(L, caps->vendorId);
	lua_setfield(L, -2, "vendorId");
	lua_pushinteger(L, caps->deviceId);
	lua_setfield(L, -2, "deviceId");
	lua_pushboolean(L, caps->homogeneousDepth);
	lua_setfield(L, -2, "homogeneousDepth");
	lua_pushboolean(L, caps->originBottomLeft);
	lua_setfield(L, -2, "originBottomLeft");
	lua_createtable(L, caps->numGPUs, 0);
	int i;
	for (i=0;i<caps->numGPUs;i++) {
		lua_createtable(L, 0, 2);
		push_vendor_id(L, caps->gpu[i].vendorId);
		lua_setfield(L, -2, "vendorId");
		lua_pushinteger(L, caps->gpu[i].deviceId);
		lua_setfield(L, -2, "deviceId");
		lua_seti(L, -2, i+1);
	}
	lua_setfield(L, -2, "gpu");
	push_texture_formats(L, caps->formats);
	lua_setfield(L, -2, "formats");
	push_limits(L, &caps->limits);
	lua_setfield(L, -2, "limits");
	return 1;
}

static int
lgetStats(lua_State *L) {
	size_t sz;
	const char * what = luaL_checklstring(L, 1, &sz);
	lua_settop(L, 2);
	if (!lua_istable(L, 2)) {
		lua_settop(L, 1);
		lua_createtable(L, 0, sz);
	}
	const bgfx_stats_t * stat = bgfx_get_stats();
	int i;
#define PUSHSTAT(v) lua_pushinteger(L, stat->v); lua_setfield(L, 2, #v)
	for (i=0;what[i];++i) {
	switch(what[i]) {
	case 's':	// back buffer size
		PUSHSTAT(width);
		PUSHSTAT(height);
		break;
	case 'd': // debug size
		PUSHSTAT(textWidth);
		PUSHSTAT(textHeight);
		break;
	case 'c':	// draw calls
		PUSHSTAT(numDraw);
		PUSHSTAT(numCompute);
		PUSHSTAT(maxGpuLatency);
#define PUSHPRIM(v,name) if (stat->numPrims[v] > 0) { lua_pushinteger(L, stat->numPrims[v]); lua_setfield(L, 2, name); }
		PUSHPRIM(BGFX_TOPOLOGY_TRI_LIST, "numTriList");
		PUSHPRIM(BGFX_TOPOLOGY_TRI_STRIP, "numTriStrip");
		PUSHPRIM(BGFX_TOPOLOGY_LINE_LIST, "numLineList");
		PUSHPRIM(BGFX_TOPOLOGY_LINE_STRIP, "numLineStrip");
		PUSHPRIM(BGFX_TOPOLOGY_POINT_LIST, "numPointList");
		break;
	case 'n':	// numbers
		PUSHSTAT(numDynamicIndexBuffers);
		PUSHSTAT(numDynamicVertexBuffers);
		PUSHSTAT(numFrameBuffers);
		PUSHSTAT(numIndexBuffers);
		PUSHSTAT(numOcclusionQueries);
		PUSHSTAT(numPrograms);
		PUSHSTAT(numShaders);
		PUSHSTAT(numTextures);
		PUSHSTAT(numUniforms);
		PUSHSTAT(numVertexBuffers);
		PUSHSTAT(numVertexDecls);
	case 'm': // memories
		PUSHSTAT(textureMemoryUsed);
		PUSHSTAT(rtMemoryUsed);
		PUSHSTAT(transientVbUsed);
		PUSHSTAT(transientIbUsed);
		break;
	case 't':	// timers
		PUSHSTAT(waitSubmit); break;
		PUSHSTAT(waitRender); break;
		lua_pushnumber(L, (stat->cpuTimeEnd - stat->cpuTimeBegin)*1000.0/stat->cpuTimerFreq);
		lua_setfield(L, 2, "cpu");
		lua_pushnumber(L, (stat->gpuTimeEnd - stat->gpuTimeBegin)*1000.0/stat->gpuTimerFreq);
		lua_setfield(L, 2, "gpu");
		break;
	case 'v': {	// views
		if (lua_getfield(L, 2, "view") != LUA_TTABLE) {
			lua_pop(L, 1);
			lua_createtable(L, stat->numViews, 0);
		}
		int i;
		int n = lua_rawlen(L, -1);
		if (n > stat->numViews) {
			for (i=n+1;i<=n;i++) {
				lua_pushnil(L);
				lua_seti(L, -2, i);
			}
		}
		double cpums = 1000.0 / stat->cpuTimerFreq;
		double gpums = 1000.0 / stat->gpuTimerFreq;
		for (i=0;i<stat->numViews;++i) {
			if (lua_geti(L, -1, i+1) != LUA_TTABLE) {
				lua_pop(L, 1);
				lua_createtable(L, 0, 4);
			}
			lua_pushstring(L, stat->viewStats[i].name);
			lua_setfield(L, -2, "name");
			lua_pushinteger(L, stat->viewStats[i].view);
			lua_setfield(L, -2, "view");
			lua_pushnumber(L, stat->viewStats[i].cpuTimeElapsed * cpums);
			lua_setfield(L, -2, "cpu");
			lua_pushnumber(L, stat->viewStats[i].gpuTimeElapsed * gpums);
			lua_setfield(L, -2, "gpu");
			lua_pop(L, 1);
		}
		lua_setfield(L, 2, "view");
		break;
	}
	default:
		return luaL_error(L, "Unkown stat format %c", what[i]);
	}}
	return 1;
}

/*
	f        : BGFX_RESET_FULLSCREEN - Not supported yet.
	m2/4/8/x : BGFX_RESET_MSAA_X[2/4/8/16] - Enable 2, 4, 8 or 16 x MSAA.
	v        : BGFX_RESET_VSYNC - Enable V-Sync.
	a        : BGFX_RESET_MAXANISOTROPY - Turn on/off max anisotropy.
	c        : BGFX_RESET_CAPTURE - Begin screen capture.
	h        : BGFX_RESET_HMD - HMD stereo rendering.
	d        : BGFX_RESET_HMD_DEBUG - HMD stereo rendering debug mode.
	r        : BGFX_RESET_HMD_RECENTER - HMD calibration.
	u        : BGFX_RESET_FLUSH_AFTER_RENDER - Flush rendering after submitting to GPU.
	i        : BGFX_RESET_FLIP_AFTER_RENDER - This flag specifies where flip occurs. Default behavior is that flip occurs before rendering new frame. This flag only has effect when BGFX_CONFIG_MULTITHREADED=0.
	s        : BGFX_RESET_SRGB_BACKBUFFER - Enable sRGB backbuffer.
*/
static int
lreset(lua_State *L) {
	int width = luaL_checkinteger(L, 1);
	int height = luaL_checkinteger(L, 2);
	uint32_t f = reset_flags(L, 3);
	bgfx_reset(width, height, f); 
	return 0;
}

static int
lshutdown(lua_State *L) {
	bgfx_shutdown();
	if (lua_getfield(L, LUA_REGISTRYINDEX, "bgfx_cb") == LUA_TUSERDATA) {
//		struct callback *cb = lua_touserdata(L, -1);
//		if (cb->L) {
//			lua_close(cb->L);
//			cb->L = NULL;
//		}
	}

	return 0;
}

/*
	C : BGFX_CLEAR_COLOR
	D : BGFX_CLEAR_DEPTH
	S : BGFX_CLEAR_STENCIL
	0-7 : BGFX_CLEAR_DISCARD_COLOR_*
	d : BGFX_CLEAR_DISCARD_DEPTH
	s : BGFX_CLEAR_DISCARD_STENCIL
 */

static int
clear_flags(lua_State *L, const char *flags) {
	int flag = BGFX_CLEAR_NONE;
	int i;
	for (i=0;flags[i];i++) {
		switch(flags[i]) {
#define CLEAR_FLAG(x) flag |= BGFX_CLEAR_##x; break
		case 'C' : CLEAR_FLAG(COLOR);
		case 'D' : CLEAR_FLAG(DEPTH);
		case 'S' : CLEAR_FLAG(STENCIL);
		case '0' : CLEAR_FLAG(DISCARD_COLOR_0);
		case '1' : CLEAR_FLAG(DISCARD_COLOR_1);
		case '2' : CLEAR_FLAG(DISCARD_COLOR_2);
		case '3' : CLEAR_FLAG(DISCARD_COLOR_3);
		case '4' : CLEAR_FLAG(DISCARD_COLOR_4);
		case '5' : CLEAR_FLAG(DISCARD_COLOR_5);
		case '6' : CLEAR_FLAG(DISCARD_COLOR_6);
		case '7' : CLEAR_FLAG(DISCARD_COLOR_7);
		case 'd' : CLEAR_FLAG(DISCARD_DEPTH);
		case 's' : CLEAR_FLAG(DISCARD_STENCIL);
		default:
			return luaL_error(L, "Invalid clear flag %c", flags[i]);
		}
	}
	return flag;
}

static int
lsetViewClear(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	const char * flags = luaL_checkstring(L, 2);
	uint32_t rgba = luaL_optinteger(L, 3, 0x000000ff);
	float depth = luaL_optnumber(L, 4, 1.0f);
	int stencil = luaL_optinteger(L, 5, 0);
	int flag = clear_flags(L, flags);
	bgfx_set_view_clear(viewid, flag, rgba, depth, stencil);
	return 0;
}

static int
lsetViewClearMRT(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	const char * flags = luaL_checkstring(L, 2);
	int flag = clear_flags(L, flags);
	float depth = luaL_checknumber(L, 3);
	int stencil = luaL_checkinteger(L, 4);
	uint8_t c[8];
	memset(c, UINT8_MAX, 8);
	int n = lua_gettop(L) - 4;
	int i;
	for (i=0;i<n;i++) {
		c[i] = (uint8_t)luaL_optinteger(L, 5+i, UINT8_MAX);
	}
	bgfx_set_view_clear_mrt(viewid, flag, depth, stencil,
		c[0],c[1],c[2],c[3],c[4],c[5],c[6],c[7]);
	return 0;
}

static int
ltouch(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	bgfx_touch(viewid);
	return 0;
}

static int
lframe(lua_State *L) {
	int capture = lua_toboolean(L, 1);
	int frame = bgfx_frame(capture);
	lua_pushinteger(L, frame);
	return 1;
}

static int
lsetDebug(lua_State *L) {
	const char *flags = luaL_checkstring(L, 1);
	int flag = BGFX_DEBUG_NONE;
	int i;
	for (i=0;flags[i];i++) {
		switch(flags[i]) {
#define DEBUG_FLAG(x) flag |= BGFX_DEBUG_##x; break
		case 'I' : DEBUG_FLAG(IFH);
		case 'W' : DEBUG_FLAG(WIREFRAME);
		case 'S' : DEBUG_FLAG(STATS);
		case 'T' : DEBUG_FLAG(TEXT);
		case 'P' : DEBUG_FLAG(PROFILER);
		default:
			return luaL_error(L, "Invalid debug flag %c", flags[i]);
		}
	}
	bgfx_set_debug(flag);
	return 0;
}

#define invalid_handle(h) (h.idx == UINT16_MAX)

static int
lcreateShader(lua_State *L) {
	size_t sz;
	const char *s = luaL_checklstring(L, 1, &sz);
	const bgfx_memory_t * m = bgfx_copy(s, sz);
	bgfx_shader_handle_t handle = bgfx_create_shader(m);
	if (invalid_handle(handle)) {
		return luaL_error(L, "create shader failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(SHADER, handle));
	return 1;
}

static int
ldestroy(lua_State *L) {
	if (lua_isnoneornil(L, 1))
		return 0;
	int idx = luaL_checkinteger(L, 1);
	int type = idx >> 16;
	int id = idx & 0xffff;
	switch(type) {
	case BGFX_HANDLE_PROGRAM: {
		bgfx_program_handle_t  handle = { id };
		bgfx_destroy_program(handle);
		break;
	}
	case BGFX_HANDLE_SHADER: {
		bgfx_shader_handle_t handle = { id };
		bgfx_destroy_shader(handle);
		break;
	}
	case BGFX_HANDLE_VERTEX_BUFFER: {
		bgfx_vertex_buffer_handle_t handle = { id };
		bgfx_destroy_vertex_buffer(handle);
		break;
	}
	case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: {
		bgfx_dynamic_vertex_buffer_handle_t handle = { id };
		bgfx_destroy_dynamic_vertex_buffer(handle);
		break;
	}
	case BGFX_HANDLE_INDEX_BUFFER: {
		bgfx_index_buffer_handle_t handle = { id };
		bgfx_destroy_index_buffer(handle);
		break;
	}
	case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32:
	case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER : {
		bgfx_dynamic_index_buffer_handle_t handle = { id };
		bgfx_destroy_dynamic_index_buffer(handle);
		break;
	}
	case BGFX_HANDLE_UNIFORM : {
		bgfx_uniform_handle_t handle = { id };
		bgfx_destroy_uniform(handle);
		break;
	}
	case BGFX_HANDLE_TEXTURE : {
		bgfx_texture_handle_t handle = { id };
		bgfx_destroy_texture(handle);
		break;
	}
	case BGFX_HANDLE_FRAME_BUFFER: {
		bgfx_frame_buffer_handle_t handle = { id };
		bgfx_destroy_frame_buffer(handle);
		break;
	}
	case BGFX_HANDLE_OCCLUSION_QUERY: {
		bgfx_occlusion_query_handle_t handle = { id };
		bgfx_destroy_occlusion_query(handle);
		break;
	}
	case BGFX_HANDLE_INDIRECT_BUFFER: {
		bgfx_indirect_buffer_handle_t handle = { id };
		bgfx_destroy_indirect_buffer(handle);
		break;
	}
	default:
		return luaL_error(L, "Invalid handle (id=%x)", idx);
	}
	return 0;
}

static int
lcreateProgram(lua_State *L) {
	int vs = BGFX_LUAHANDLE_ID(SHADER, luaL_checkinteger(L, 1));
	int fs = UINT16_MAX;
	int t = lua_type(L, 2);
	int d = 0;
	int compute = 0;
	switch (t) {
	case LUA_TNUMBER:
		fs = BGFX_LUAHANDLE_ID(SHADER, luaL_checkinteger(L, 2));
		break;
	case LUA_TBOOLEAN:
		d = lua_toboolean(L, 2);
		compute = 1;
		break;
	case LUA_TNONE:
		compute = 1;
		break;
	case LUA_TNIL:
		d = lua_toboolean(L, 3);
		break;
	};
	bgfx_program_handle_t ph;
	if (compute) {
		bgfx_shader_handle_t csh = { vs };
		ph = bgfx_create_compute_program(csh, d);
	} else {
		bgfx_shader_handle_t vsh = { vs };
		bgfx_shader_handle_t fsh = { fs };
		ph = bgfx_create_program(vsh, fsh, d);
	}
	if (invalid_handle(ph)) {
		return luaL_error(L, "create program failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(PROGRAM, ph));
	return 1;
}

static int
lsubmit(lua_State *L) {
	bgfx_view_id_t id = luaL_checkinteger(L, 1);
	int progid = BGFX_LUAHANDLE_ID(PROGRAM, luaL_checkinteger(L, 2));
	int depth = luaL_optinteger(L, 3, 0);
	int preserveState = lua_toboolean(L, 4);
	bgfx_program_handle_t ph = { progid };
	bgfx_submit(id, ph, depth, preserveState);
	return 0;
}

#define CASE(v) (strcmp(what,#v) == 0)

static uint64_t
get_equation(lua_State *L, const char *e) {
	char what[4] = { e[0], e[1], e[2], 0 };
	if CASE(ADD) return BGFX_STATE_BLEND_EQUATION_ADD;
	if CASE(SUB) return BGFX_STATE_BLEND_EQUATION_SUB;
	if CASE(REV) return BGFX_STATE_BLEND_EQUATION_REVSUB;
	if CASE(MIN) return BGFX_STATE_BLEND_EQUATION_MIN;
	if CASE(MAX) return BGFX_STATE_BLEND_EQUATION_MAX;
	return luaL_error(L, "Invalid BLEND EQUATION mode : %s", what);
}

// 0 : ZERO
// 1 : ONE
// s : SRC_COLOR
// S : INV_SRC_COLOR
// a : SRC_ALPHA
// A : INV_SRC_ALPHA
// b : DST_ALPHA
// B : INV_DST_ALPHA
// d : DST_COLOR
// D : INV_DST_COLOR
// t : SRC_ALPHA_SAT
// f : FACTOR
// F : INV_FACTOR
static uint64_t
get_blend_func(lua_State *L, char t) {
	switch (t) {
	case '0' : return BGFX_STATE_BLEND_ZERO;
	case '1' : return BGFX_STATE_BLEND_ONE;
	case 's' : return BGFX_STATE_BLEND_SRC_COLOR;
	case 'S' : return BGFX_STATE_BLEND_INV_SRC_COLOR;
	case 'a' : return BGFX_STATE_BLEND_SRC_ALPHA;
	case 'A' : return BGFX_STATE_BLEND_INV_SRC_ALPHA;
	case 'b' : return BGFX_STATE_BLEND_DST_ALPHA;
	case 'B' : return BGFX_STATE_BLEND_INV_DST_ALPHA;
	case 'd' : return BGFX_STATE_BLEND_DST_COLOR;
	case 'D' : return BGFX_STATE_BLEND_INV_DST_COLOR;
	case 't' : return BGFX_STATE_BLEND_SRC_ALPHA_SAT;
	case 'f' : return BGFX_STATE_BLEND_FACTOR;
	case 'F' : return BGFX_STATE_BLEND_INV_FACTOR;
	}
	return luaL_error(L, "Invalid BLEND FUNC type : %c", t);
}

static int
combine_state(lua_State *L, uint64_t *state) {
	if (lua_type(L, -2) != LUA_TSTRING) {
		luaL_error(L, "state key must be string, it's %s", lua_typename(L, lua_type(L, -2)));
	}
	const char * what = lua_tostring(L, -2);
	if CASE(PT) {
		*state &= ~BGFX_STATE_PT_MASK;
		const char * what = luaL_checkstring(L, -1);
		if CASE(TRISTRIP) *state |= BGFX_STATE_PT_TRISTRIP;
		else if CASE(LINES) *state |= BGFX_STATE_PT_LINES;
		else if CASE(POINTS) *state |= BGFX_STATE_PT_POINTS;
		else if CASE(LINESTRIP) *state |= BGFX_STATE_PT_LINESTRIP;
		else luaL_error(L, "Invalid PT mode : %s", what);
	} 
	else if CASE(BLEND) {
		*state &= ~BGFX_STATE_BLEND_MASK;
		const char * what = luaL_checkstring(L, -1);
		if CASE(ADD) *state |= BGFX_STATE_BLEND_ADD;
		else if CASE(ALPHA) *state |= BGFX_STATE_BLEND_ALPHA;
		else if CASE(DARKEN) *state |= BGFX_STATE_BLEND_DARKEN;
		else if CASE(LIGHTEN) *state |= BGFX_STATE_BLEND_LIGHTEN;
		else if CASE(MULTIPLY) *state |= BGFX_STATE_BLEND_MULTIPLY;
		else if CASE(NORMAL) *state |= BGFX_STATE_BLEND_NORMAL;
		else if CASE(SCREEN) *state |= BGFX_STATE_BLEND_SCREEN;
		else if CASE(LINEAR_BURN) *state |= BGFX_STATE_BLEND_LINEAR_BURN;
		else luaL_error(L, "Invalid BLEND mode : %s", what);
	}
	else if CASE(BLEND_FUNC) {
		*state &= ~BGFX_STATE_BLEND_MASK;
		size_t sz;
		const char *func = luaL_checklstring(L, -1, &sz);
		if (sz == 2) {
			uint64_t c1 = get_blend_func(L, func[0]);
			uint64_t c2 = get_blend_func(L, func[1]);
			*state |= BGFX_STATE_BLEND_FUNC(c1,c2);
		} else if (sz == 4) {
			uint64_t c1 = get_blend_func(L, func[0]);
			uint64_t c2 = get_blend_func(L, func[1]);
			uint64_t c3 = get_blend_func(L, func[2]);
			uint64_t c4 = get_blend_func(L, func[3]);
			*state |= BGFX_STATE_BLEND_FUNC_SEPARATE(c1,c2,c3,c4);
		} else {
			luaL_error(L, "Invalid BLEND FUNC : %s", func);
		}
	}
	else if CASE(BLEND_FUNC_RT) {
		size_t sz;
		const char *func = luaL_checklstring(L, -1, &sz);
		if (sz != 3) {
			luaL_error(L, "Invalid BLEND FUNC RT : %s", func);
		}
		return 1;
	}
	else if CASE(BLEND_EQUATION) {
		*state &= ~BGFX_STATE_BLEND_EQUATION_MASK;
		size_t sz;
		const char * eq = luaL_checklstring(L, -1, &sz);
		if (sz == 3) {
			uint64_t e = get_equation(L, eq);
			*state |= BGFX_STATE_BLEND_EQUATION(e);
		} else if (sz == 6) {
			uint64_t ergb = get_equation(L, eq);
			uint64_t ra = get_equation(L, eq+3);
			*state |= BGFX_STATE_BLEND_EQUATION_SEPARATE(ergb, ra);
		} else {
			luaL_error(L, "Invalid BLEND EQUATION mode : %s", eq);
		}
	}
	else if CASE(BLEND_ENABLE) {
		const char *be = luaL_checkstring(L, -1);
		int i;
		for (i=0;be[i];i++) {
			switch(be[i]) {
			case 'i':
				*state |= BGFX_STATE_BLEND_INDEPENDENT;
				break;
			case 'a':
				*state |= BGFX_STATE_BLEND_ALPHA_TO_COVERAGE;
				break;
			default:
				luaL_error(L, "Invalid BLEND ENABLE mode %s", be);
			}
		}
	}
	else if CASE(ALPHA_REF) {
		int ref = luaL_checkinteger(L, -1);
		*state &= ~BGFX_STATE_ALPHA_REF_MASK;
		*state |= BGFX_STATE_ALPHA_REF(ref);
	} else if CASE(POINT_SIZE) {
		int size = luaL_checkinteger(L, -1);
		*state &= ~BGFX_STATE_POINT_SIZE_MASK;
		*state |= BGFX_STATE_POINT_SIZE(size);
	} else if CASE(MSAA) {
		if (lua_toboolean(L, -1))
			*state |= BGFX_STATE_MSAA; 
		else 
			*state &= ~BGFX_STATE_MSAA;
	} else if CASE(WRITE_MASK) {
		*state &= ~BGFX_STATE_WRITE_MASK;
		const char * mask = luaL_checkstring(L, -1);
		int i;
		for (i=0;mask[i];i++) {
			switch (mask[i]) {
			case 'R':
				*state |= BGFX_STATE_WRITE_R;
				break;
			case 'G':
				*state |= BGFX_STATE_WRITE_G;
				break;
			case 'B':
				*state |= BGFX_STATE_WRITE_B;
				break;
			case 'A':
				*state |= BGFX_STATE_WRITE_A;
				break;
			case 'Z':
				*state |= BGFX_STATE_WRITE_Z;
				break;
			default:
				return luaL_error(L, "Invalid WRITE_MASK %s", mask);
			}
		}
	} else if CASE(DEPTH_TEST) {
		*state &= ~BGFX_STATE_DEPTH_TEST_MASK;
		const char * what = luaL_checkstring(L, -1);
		if CASE(NEVER) *state |= BGFX_STATE_DEPTH_TEST_NEVER;
		else if CASE(ALWAYS) *state |= BGFX_STATE_DEPTH_TEST_ALWAYS;
		else if CASE(LEQUAL) *state |= BGFX_STATE_DEPTH_TEST_LEQUAL;
		else if CASE(EQUAL) *state |= BGFX_STATE_DEPTH_TEST_EQUAL;
		else if CASE(GEQUAL) *state |= BGFX_STATE_DEPTH_TEST_GEQUAL;
		else if CASE(GREATER) *state |= BGFX_STATE_DEPTH_TEST_GREATER;
		else if CASE(NOTEQUAL) *state |= BGFX_STATE_DEPTH_TEST_NOTEQUAL;
		else if CASE(LESS) *state |= BGFX_STATE_DEPTH_TEST_LESS;
		else if CASE(NONE) ;
		else luaL_error(L, "Invalid DEPTH_TEST mode : %s", what);
	}
	else if CASE(CULL) {
		*state &= ~BGFX_STATE_CULL_MASK;
		const char * what = luaL_checkstring(L, -1);
		if CASE(CCW) *state |= BGFX_STATE_CULL_CCW;
		else if CASE(CW) *state |= BGFX_STATE_CULL_CW;
		else if CASE(NONE) ;
		else luaL_error(L, "Invalid CULL mode : %s", what);
	} else if CASE(BLEND_FACTOR) {
		return 1;
	}
	return 0;
}

static inline void
byte2hex(uint8_t c, uint8_t *t) {
	static char *hex = "0123456789ABCDEF";
	t[0] = hex[c>>4];
	t[1] = hex[c&0xf];
}

static int
lmakeState(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
/*#define BGFX_STATE_DEFAULT (0          \
			| BGFX_STATE_WRITE_RGB       \
			| BGFX_STATE_WRITE_A         \
			| BGFX_STATE_DEPTH_TEST_LESS \
			| BGFX_STATE_WRITE_Z         \
			| BGFX_STATE_CULL_CW         \
			| BGFX_STATE_MSAA            \
			)
*/
	uint64_t state = 0;
	uint32_t rgba = 0;
	int t = lua_type(L, 2);
	switch(t) {
	case LUA_TSTRING:
		get_state(L, 2, &state, &rgba);
		break;
	case LUA_TNIL:
		state = BGFX_STATE_DEFAULT;
		break;
	}
	lua_pushnil(L);
	int blend_factor = 0;
	while (lua_next(L, 1) != 0) {
		if (combine_state(L, &state)) {
			blend_factor = 1;
			if (lua_type(L, -1) == LUA_TNUMBER) {
				rgba = lua_tointeger(L, -1);
			} else {
				size_t sz;
				const char *func = luaL_checklstring(L, -1, &sz);
				if (sz != 3) {
					luaL_error(L, "Invalid BLEND FUNC RT : %s", func);
				}
				uint64_t c1 = get_blend_func(L, func[1]);
				uint64_t c2 = get_blend_func(L, func[2]);
				switch (func[0]) {
				case '1':
					rgba = BGFX_STATE_BLEND_FUNC_RT_1(c1,c2);
					break;
				case '2':
					rgba = BGFX_STATE_BLEND_FUNC_RT_2(c1,c2);
					break;
				case '3':
					rgba = BGFX_STATE_BLEND_FUNC_RT_3(c1,c2);
					break;
				default:
					luaL_error(L, "Invalid BLEND FUNC RT : %s", func);
				}
			}
		}
		lua_pop(L, 1);
	}
	uint8_t temp[24];
	int i;
	for (i=0;i<8;i++) {
		byte2hex((state >> ((7-i) * 8)) & 0xff, &temp[i*2]);
	}
	if (blend_factor) {
		for (i=0;i<4;i++) {
			byte2hex( (rgba >> ((3-i) * 8)) & 0xff, &temp[16+i*2]);
		}
		lua_pushlstring(L, (const char *)temp, 24);
	} else {
		lua_pushlstring(L, (const char *)temp, 16);
	}
	return 1;
}

static int
lsetState(lua_State *L) {
	if (lua_isnoneornil(L, 1)) {
		bgfx_set_state(BGFX_STATE_DEFAULT, 0);
	} else {
		uint64_t state;
		uint32_t rgba;
		get_state(L, 1, &state, &rgba);
		bgfx_set_state(state, rgba);
	}
	return 0;
}

struct AttribNamePairs {
	const char* name;
	bgfx_attrib_t attrib;
};

static struct AttribNamePairs attrib_name_pairs[BGFX_ATTRIB_COUNT] = {
		"POSITION", BGFX_ATTRIB_POSITION,
		"NORMAL", BGFX_ATTRIB_NORMAL,
		"TANGENT", BGFX_ATTRIB_TANGENT,
		"BITANGENT", BGFX_ATTRIB_BITANGENT,
		"COLOR0", BGFX_ATTRIB_COLOR0,
		"COLOR1", BGFX_ATTRIB_COLOR1,
		"COLOR2", BGFX_ATTRIB_COLOR2,
		"COLOR3", BGFX_ATTRIB_COLOR3,
		"INDICES", BGFX_ATTRIB_INDICES,
		"WEIGHT", BGFX_ATTRIB_WEIGHT,
		"TEXCOORD0", BGFX_ATTRIB_TEXCOORD0,
		"TEXCOORD1", BGFX_ATTRIB_TEXCOORD1,
		"TEXCOORD2", BGFX_ATTRIB_TEXCOORD2,
		"TEXCOORD3", BGFX_ATTRIB_TEXCOORD3,
		"TEXCOORD4", BGFX_ATTRIB_TEXCOORD4,
		"TEXCOORD5", BGFX_ATTRIB_TEXCOORD5,
		"TEXCOORD6", BGFX_ATTRIB_TEXCOORD6,
		"TEXCOORD7", BGFX_ATTRIB_TEXCOORD7,		
};

struct AttribTypeNamePairs{
	const char* name;
	bgfx_attrib_type_t type;
};

static struct AttribTypeNamePairs attrib_type_name_pairs[BGFX_ATTRIB_TYPE_COUNT] = {
	"UINT8", BGFX_ATTRIB_TYPE_UINT8,
	"UINT10", BGFX_ATTRIB_TYPE_UINT10,
	"INT16", BGFX_ATTRIB_TYPE_INT16,
	"HALF", BGFX_ATTRIB_TYPE_HALF,
	"FLOAT", BGFX_ATTRIB_TYPE_FLOAT,
};

#define ARRAY_COUNT(_ARRAY) sizeof(_ARRAY) / sizeof(_ARRAY[0])


static int
lexportVertexDecl(lua_State *L) {
	bgfx_vertex_decl_t *decl = (bgfx_vertex_decl_t *)lua_touserdata(L, 1);

	if (decl == NULL)
		luaL_error(L, "Invalid decl data!");

	lua_newtable(L);
	int num_attrib = 1;
	for (int attrib = BGFX_ATTRIB_POSITION; attrib < BGFX_ATTRIB_COUNT; ++attrib) {
		if (bgfx_vertex_decl_has(decl, (bgfx_attrib_t)attrib)) {
			lua_newtable(L);

			uint8_t num;
			bool nomalized, as_int;
			bgfx_attrib_type_t attrib_type;
			bgfx_vertex_decl_decode(decl, (bgfx_attrib_t)attrib, &num, &attrib_type, &nomalized, &as_int);
			assert(attrib_type < BGFX_ATTRIB_TYPE_COUNT);

			lua_pushstring(L, attrib_name_pairs[attrib].name);
			lua_seti(L, -2, 1);

			lua_pushnumber(L, num);
			lua_seti(L, -2, 2);

			lua_pushstring(L, attrib_type_name_pairs[attrib_type].name);
			lua_seti(L, -2, 3);

			lua_pushboolean(L, nomalized ? 1 : 0);
			lua_seti(L, -2, 4);

			lua_pushboolean(L, as_int ? 1 : 0);
			lua_seti(L, -2, 5);

			lua_seti(L, -2, num_attrib++);	// push this table
		}
	}

	luaL_checktype(L, -1, LUA_TTABLE);

	return 1;
}

static inline bgfx_attrib_t find_attrib(const char* what) {
	for (int ii = 0; ii < ARRAY_COUNT(attrib_name_pairs); ++ii) {
		if (strcmp(what, attrib_name_pairs[ii].name) == 0)
			return attrib_name_pairs[ii].attrib;
	}

	return BGFX_ATTRIB_COUNT;
}

static inline bgfx_attrib_type_t find_attrib_type(const char* what) {
	for (int ii = 0; ii < ARRAY_COUNT(attrib_type_name_pairs); ++ii) {
		if (strcmp(what, attrib_type_name_pairs[ii].name) == 0)
			return attrib_type_name_pairs[ii].type;
	}

	return BGFX_ATTRIB_TYPE_COUNT;
}

static void
vertex_decl_add(lua_State *L, bgfx_vertex_decl_t *vd) {
	if (lua_geti(L, -1, 1) != LUA_TSTRING) {
		luaL_error(L, "Invalid attrib enum");
	}
	
	const char * what = lua_tostring(L, -1);
	const bgfx_attrib_t attrib = find_attrib(what);
	if (attrib == BGFX_ATTRIB_COUNT) {
		luaL_error(L, "Invalid arrtib enum : %s", what); return;
	}

	
	//if CASE(POSITION) attrib = BGFX_ATTRIB_POSITION;
	//else if CASE(NORMAL) attrib = BGFX_ATTRIB_NORMAL;
	//else if CASE(TANGENT) attrib = BGFX_ATTRIB_TANGENT;
	//else if CASE(BITANGENT) attrib = BGFX_ATTRIB_BITANGENT;
	//else if CASE(COLOR0) attrib = BGFX_ATTRIB_COLOR0;
	//else if CASE(COLOR1) attrib = BGFX_ATTRIB_COLOR1;
	//else if CASE(COLOR2) attrib = BGFX_ATTRIB_COLOR2;
	//else if CASE(COLOR3) attrib = BGFX_ATTRIB_COLOR3;
	//else if CASE(INDICES) attrib = BGFX_ATTRIB_INDICES;
	//else if CASE(WEIGHT) attrib = BGFX_ATTRIB_WEIGHT;
	//else if CASE(TEXCOORD0) attrib = BGFX_ATTRIB_TEXCOORD0;
	//else if CASE(TEXCOORD1) attrib = BGFX_ATTRIB_TEXCOORD1;
	//else if CASE(TEXCOORD2) attrib = BGFX_ATTRIB_TEXCOORD2;
	//else if CASE(TEXCOORD3) attrib = BGFX_ATTRIB_TEXCOORD3;
	//else if CASE(TEXCOORD4) attrib = BGFX_ATTRIB_TEXCOORD4;
	//else if CASE(TEXCOORD5) attrib = BGFX_ATTRIB_TEXCOORD5;
	//else if CASE(TEXCOORD6) attrib = BGFX_ATTRIB_TEXCOORD6;
	//else if CASE(TEXCOORD7) attrib = BGFX_ATTRIB_TEXCOORD7;
	//else { luaL_error(L, "Invalid arrtib enum : %s", what); return; }
	lua_pop(L, 1);

	lua_geti(L, -1, 2);
	int num = lua_tointeger(L, -1);
	if (num < 1 || num > 4) {
		luaL_error(L, "Invalid number of elements : %d", num);
	}
	lua_pop(L, 1);

	if (lua_geti(L, -1, 3) != LUA_TSTRING) {
		luaL_error(L, "Invalid attrib type enum");	
	}

	what = lua_tostring(L, -1);
	
	bgfx_attrib_type_t attrib_type = find_attrib_type(what);
	if (attrib_type == BGFX_ATTRIB_TYPE_COUNT) {
		luaL_error(L, "Invalid arrtib type enum : %s", what); return;
	}
	
	//if CASE(FLOAT) attrib_type = BGFX_ATTRIB_TYPE_FLOAT;
	//else if CASE(UINT8) attrib_type = BGFX_ATTRIB_TYPE_UINT8;
	//else if CASE(INT16) attrib_type = BGFX_ATTRIB_TYPE_INT16;
	//else if CASE(UINT10) attrib_type = BGFX_ATTRIB_TYPE_UINT10;
	//else if CASE(HALF) attrib_type = BGFX_ATTRIB_TYPE_HALF;
	//else { luaL_error(L, "Invalid arrtib type enum : %s", what); return; }

	lua_pop(L, 1);

	lua_geti(L, -1, 4);
	int normalized = lua_toboolean(L, -1);
	lua_pop(L, 1);

	lua_geti(L, -1, 5);
	int asint = lua_toboolean(L, -1);
	lua_pop(L, 1);

	bgfx_vertex_decl_add(vd, attrib, num, attrib_type, normalized, asint);
}

struct string_reader {
	lua_State *L;
	const char * buffer;
	size_t sz;
	size_t total;
};

static inline uint32_t
read_int(struct string_reader *rd, int n) {
	if (rd->sz < n) {
		return luaL_error(rd->L, "Invalid stream");
	}
	const uint8_t *s = (const uint8_t *)rd->buffer;
	rd->buffer += n;
	rd->sz -= n;
	rd->total += n;
	int i;
	uint32_t v = 0;
	for (i=0;i<n;i++) {
		v |= s[i] << (i * 8);
	}
	return v;
}

static bgfx_attrib_t
idToAttrib(uint16_t id) {
	static struct {
		bgfx_attrib_t attr;
		uint16_t id;
	} s_attribToId[] = {
		// NOTICE: from vetexdecl.cpp
		// Attrib must be in order how it appears in Attrib::Enum! id is
		// unique and should not be changed if new Attribs are added.
		{ BGFX_ATTRIB_POSITION,  0x0001 },
		{ BGFX_ATTRIB_NORMAL,    0x0002 },
		{ BGFX_ATTRIB_TANGENT,   0x0003 },
		{ BGFX_ATTRIB_BITANGENT, 0x0004 },
		{ BGFX_ATTRIB_COLOR0,    0x0005 },
		{ BGFX_ATTRIB_COLOR1,    0x0006 },
		{ BGFX_ATTRIB_COLOR2,    0x0018 },
		{ BGFX_ATTRIB_COLOR3,    0x0019 },
		{ BGFX_ATTRIB_INDICES,   0x000E },
		{ BGFX_ATTRIB_WEIGHT,    0x000F },
		{ BGFX_ATTRIB_TEXCOORD0, 0x0010 },
		{ BGFX_ATTRIB_TEXCOORD1, 0x0011 },
		{ BGFX_ATTRIB_TEXCOORD2, 0x0012 },
		{ BGFX_ATTRIB_TEXCOORD3, 0x0013 },
		{ BGFX_ATTRIB_TEXCOORD4, 0x0014 },
		{ BGFX_ATTRIB_TEXCOORD5, 0x0015 },
		{ BGFX_ATTRIB_TEXCOORD6, 0x0016 },
		{ BGFX_ATTRIB_TEXCOORD7, 0x0017 },
	};

	int i;
	for (i = 0; i < sizeof(s_attribToId) / sizeof(s_attribToId[0]); i++) {
		if (s_attribToId[i].id == id)
			return s_attribToId[i].attr;
	}
	return BGFX_ATTRIB_COUNT;
}

static bgfx_attrib_type_t
idToAttribType(uint16_t id) {
	static struct {
		bgfx_attrib_type_t attr;
		uint16_t id;
	} s_attribTypeToId[] = {
		// NOTICE:
		// AttribType must be in order how it appears in AttribType::Enum!
		// id is unique and should not be changed if new AttribTypes are
		// added.
		{ BGFX_ATTRIB_TYPE_UINT8,  0x0001 },
		{ BGFX_ATTRIB_TYPE_UINT10, 0x0005 },
		{ BGFX_ATTRIB_TYPE_INT16,  0x0002 },
		{ BGFX_ATTRIB_TYPE_HALF,   0x0003 },
		{ BGFX_ATTRIB_TYPE_FLOAT,  0x0004 },
	};
	int i;
	for (i = 0; i < sizeof(s_attribTypeToId) / sizeof(s_attribTypeToId[0]); i++) {
		if (s_attribTypeToId[i].id == id)
			return s_attribTypeToId[i].attr;
	}
	return BGFX_ATTRIB_TYPE_COUNT;
}

static size_t
new_vdecl_from_string(lua_State *L, const char *vdecl, size_t sz) {
	bgfx_vertex_decl_t * vd = lua_newuserdata(L, sizeof(*vd));
	struct string_reader rd = { L, vdecl, sz, 0 };
	uint8_t numAttrs = read_int(&rd, 1);
	uint16_t stride = read_int(&rd, 2);
	bgfx_vertex_decl_begin(vd, BGFX_RENDERER_TYPE_NOOP);
	int i;
	for (i=0;i<numAttrs;i++) {
		uint16_t offset = read_int(&rd, 2);
		uint16_t attribId = read_int(&rd, 2);
		uint8_t num = read_int(&rd, 1);
		uint16_t attribTypeId = read_int(&rd, 2);
		bool normalized = read_int(&rd, 1);
		bool asInt = read_int(&rd, 1);
		bgfx_attrib_t attr = idToAttrib(attribId);
		bgfx_attrib_type_t type = idToAttribType(attribTypeId);
		if (attr != BGFX_ATTRIB_COUNT && type != BGFX_ATTRIB_TYPE_COUNT) {
			bgfx_vertex_decl_add(vd, attr, num, type, normalized, asInt);
			vd->offset[attr] = offset;
		}
	}
	bgfx_vertex_decl_end(vd);
	vd->stride = stride;
	lua_pushinteger(L, stride);
	return rd.total;
}

/*
	{
		{ attrib, num, attribType, normailzed=false, asint },
		skipnum,
		...
	}
 */
static int
lnewVertexDecl(lua_State *L) {
	if (lua_isstring(L, 1)) {
		int offset = luaL_optinteger(L, 2, 1) - 1;
		size_t sz;
		const char * vdecl = luaL_checklstring(L, 1, &sz);
		if (offset >= sz) {
			return luaL_error(L, "Invalid vertex decl");
		}
		size_t s = new_vdecl_from_string(L, vdecl+offset, sz-offset);
		lua_pushinteger(L, s + offset + 1);
		return 3;
	}
	luaL_checktype(L, 1, LUA_TTABLE);
	bgfx_renderer_type_t id = BGFX_RENDERER_TYPE_NOOP;
	if (!lua_isnoneornil(L, 2)) {
		id = renderer_type_id(L, 2);
	}
	bgfx_vertex_decl_t * vd = lua_newuserdata(L, sizeof(*vd));
	bgfx_vertex_decl_begin(vd, id);
	int i, type;
	for (i=1; (type = lua_geti(L, 1, i)) != LUA_TNIL; i++) {
		switch (type) {
		case LUA_TNUMBER:
			bgfx_vertex_decl_skip(vd, lua_tointeger(L, -1));
			break;
		case LUA_TTABLE:
			vertex_decl_add(L, vd);
			break;
		default:
			return luaL_error(L, "Invalid vertex decl %s", lua_typename(L, type));
		}
		lua_pop(L, 1);
	}
	lua_pop(L, 1);
	bgfx_vertex_decl_end(vd);
	lua_pushinteger(L, vd->stride);
	return 2;
}

static const bgfx_memory_t *
convert_by_decl(const void * data, size_t sz, bgfx_vertex_decl_t *src_vd, bgfx_vertex_decl_t *desc_vd) {
	int n = sz / src_vd->stride;
	const bgfx_memory_t *mem = bgfx_alloc(n * desc_vd->stride);
	bgfx_vertex_convert(desc_vd, mem->data, src_vd, data, n);
	return mem;
}

struct BufferDataStream {
	const uint8_t *data;
	uint32_t size;
};

static void 
extract_buffer_stream(lua_State* L, int idx, int n, struct BufferDataStream *stream) {
	luaL_checktype(L, idx, LUA_TTABLE);
	int datatype = lua_geti(L, idx, n);
	assert(datatype == LUA_TSTRING);

	size_t sz = 0;
	const char* data = lua_tolstring(L, -1, &sz);
	lua_pop(L, 1);
	int start = 1;
	if (lua_geti(L, idx, n + 1) == LUA_TNUMBER) {
		start = lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	if (start < 0)
		start = sz + start + 1;

	stream->data = data + start - 1;

	int end = -1;
	if (lua_geti(L, idx, n + 2) == LUA_TNUMBER) {
		end = lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	if (end < 0)
		end = sz + end + 1;
	if (end < start)
		luaL_error(L, "extract stream data : empty data");

	stream->size = end - start + 1;
}

static const bgfx_memory_t *
create_mem_from_table(lua_State *L, int idx, int n, bgfx_vertex_decl_t *src_vd, bgfx_vertex_decl_t *desc_vd) {
	// binary data
	int t = lua_geti(L, idx, n);
	if (t == LUA_TLIGHTUSERDATA || t == LUA_TUSERDATA) {
		void * data = lua_touserdata(L, -1);
		size_t sz;
		if (lua_geti(L, idx, n+1) == LUA_TNUMBER) {
			sz = lua_tointeger(L, -1);
		} else if (t == LUA_TLIGHTUSERDATA) {
			luaL_error(L, "Missing size for lightuserdata");
			return NULL;
		} else {
			sz = lua_rawlen(L, -2);
		}
		lua_pop(L, 2);
		if (src_vd) {
			return convert_by_decl(data, sz, src_vd, desc_vd);
		} else {
			const bgfx_memory_t *mem = bgfx_make_ref(data, sz);
			return mem;
		}
	}

	if (t != LUA_TSTRING) {
		luaL_error(L, "Missing data string");
	}
	
	lua_pop(L, 1);
	struct BufferDataStream stream;
	extract_buffer_stream(L, idx, n, &stream);

	if (src_vd) {
		return convert_by_decl(stream.data, stream.size, src_vd, desc_vd);
	} else {
		const bgfx_memory_t *mem = bgfx_alloc(stream.size);
		memcpy(mem->data, stream.data, stream.size);
		return mem;
	}
}

static int
get_stride(lua_State *L, const char *format) {
	int i;
	int stride = 0;
	for (i=0;format[i];i++) {
		switch(format[i]) {
		case 'f':
		case 'd':
			stride += 4;
			break;
		case 's':
			stride += 2;
			break;
		case 'b':
			stride += 1;
			break;
		default:
			luaL_error(L, "invalid layout %c", format[i]);
		}
	}
	return stride;
}

/*
	the first one is layout
	f : float
	d : dword
	s : int16
	b : uint8
 */
static const bgfx_memory_t *
create_from_table_decl(lua_State *L, int idx, bgfx_vertex_decl_t *vd) {
	luaL_checktype(L, idx, LUA_TTABLE);
	const int elemtype = lua_geti(L, idx, 1);
	if (elemtype == LUA_TUSERDATA) {
		// it's vd
		bgfx_vertex_decl_t *src_vd = lua_touserdata(L, -1);
		if (vd == NULL || memcmp(src_vd, vd, sizeof(*vd)) == 0) {
			return create_mem_from_table(L, idx, 2, NULL, NULL);
		} else {
			return create_mem_from_table(L, idx, 2, src_vd, vd);
		}
	}
	if (elemtype != LUA_TSTRING) {
		luaL_error(L, "Missing layout");
	}
	size_t sz;
	const char * layout = lua_tolstring(L, -1, &sz);
	lua_pop(L, 1);
	if (layout[0] == '!') {
		return create_mem_from_table(L, idx, 2, NULL, NULL);
	}
	int n = lua_rawlen(L, idx) - 1;
	int stride = get_stride(L, layout);
	int numv = n / sz;
	if (numv * sz != n) {
		luaL_error(L, "Invalid number of table %d", n);
	}
	const bgfx_memory_t *mem = bgfx_alloc(numv * stride);
	int i,j;
	int tidx = 2;
	uint8_t * addr = mem->data;
	for (i=0;i<numv;i++) {
		for (j=0;layout[j];j++) {
			if (lua_geti(L, idx, tidx) != LUA_TNUMBER) {
				luaL_error(L, "vertex buffer data %d type error %s", tidx, lua_typename(L, lua_type(L, -1)));
			}
			switch (layout[j]) {
			case 'f':
				*(float *)addr = lua_tonumber(L, -1);
				addr += 4;
				break;
			case 'd': {
				uint8_t * ptr = addr;
				uint32_t data = (uint32_t)lua_tointeger(L, -1);
				ptr[0] = data & 0xff;
				ptr[1] = (data >> 8) & 0xff;
				ptr[2] = (data >> 16) & 0xff;
				ptr[3] = (data >> 24) & 0xff;
				addr += 4;
				break;
			}
			case 's':
				*(int16_t *)addr = lua_tointeger(L, -1);
				addr += 2;
				break;
			case 'b':
				*(uint8_t *)addr = lua_tointeger(L, -1);
				addr += 1;
				break;
			}
			lua_pop(L, 1);
			++tidx;
		}
	}
	return mem;
}

static const bgfx_memory_t *
create_from_table_int16(lua_State *L, int idx) {
	luaL_checktype(L, idx, LUA_TTABLE);
	if (lua_geti(L, idx, 1) != LUA_TNUMBER) {
		lua_pop(L, 1);
		return create_mem_from_table(L, idx, 1, NULL, NULL);
	}
	int n = lua_rawlen(L, idx);
	const bgfx_memory_t *mem = bgfx_alloc(n * sizeof(uint16_t));
	int i;
	for (i=1;i<=n;i++) {
		lua_geti(L, idx, i);
		uint16_t * ptr = (uint16_t *)(mem->data + (i-1) * sizeof(uint16_t));
		*ptr = (uint16_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	return mem;
}

static const bgfx_memory_t *
create_from_table_int32(lua_State *L, int idx) {
	luaL_checktype(L, idx, LUA_TTABLE);
	if (lua_geti(L, idx, 1) != LUA_TNUMBER) {
		lua_pop(L, 1);
		return create_mem_from_table(L, idx, 1, NULL, NULL);
	}
	int n = lua_rawlen(L, idx);
	const bgfx_memory_t *mem = bgfx_alloc(n * sizeof(uint32_t));
	int i;
	for (i=1;i<=n;i++) {
		lua_geti(L, idx, i);
		uint32_t * ptr = (uint32_t *)(mem->data + (i-1) * sizeof(uint32_t));
		*ptr = (uint32_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	return mem;
}

#include <math.h>

static inline float
DOT(const float a[3], const float b[3]) {
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

static inline float *
CROSS(float v[3], const float a[3], const float b[3]) {
	v[0] = a[1] * b[2] - a[2] * b[1];
	v[1] = a[2] * b[0] - a[0] * b[2];
	v[2] = a[0] * b[1] - a[1] * b[0];

	return v;
}

static inline float *
NORMALIZE(float v[3]) {
	float invLen = 1.0f / sqrtf(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
	v[0] *= invLen;
	v[1] *= invLen;
	v[2] *= invLen;

	return v;
}

static void
calc_tangent_vb(lua_State *L, const bgfx_memory_t *mem, bgfx_vertex_decl_t *vd, int index) {
	void *vertices = mem->data;
	uint32_t numVertices = mem->size / vd->stride;
	const uint16_t *indices;
	uint32_t numIndices;
	float *tangents;
	if (lua_geti(L, index, 1) == LUA_TSTRING) {
		struct BufferDataStream stream;
		extract_buffer_stream(L, index, 1, &stream);
		numIndices = stream.size / sizeof(uint16_t); // assume 16 bits per index
		assert(numIndices <= 65535);
		indices = (const uint16_t*)stream.data;
		tangents = lua_newuserdata(L, 6*numVertices*sizeof(float));
	} else {
		numIndices = lua_rawlen(L, index);
		uint8_t * tmp = lua_newuserdata(L, 6*numVertices + numIndices * 2);
		uint16_t * ind = (uint16_t *)(tmp + 6*numVertices);
		uint32_t i;
		for (i=0;i<numIndices;i++) {
			if (lua_geti(L, index, i+1) != LUA_TNUMBER) {
				luaL_error(L, "Invalid index buffer data table");
			}
			ind[i] = (uint16_t)lua_tointeger(L, -1);
			lua_pop(L, 1);
		}
		indices = ind;
		tangents = (float *)tmp;
	}

	struct PosTexcoord {
		float m_x;
		float m_y;
		float m_z;
		float m_pad0;
		float m_u;
		float m_v;
		float m_pad1;
		float m_pad2;
	} v0,v1,v2;

	uint32_t ii,jj,num;
	for (ii = 0, num = numIndices/3; ii < num; ++ii) {
		uint32_t i0 = indices[ii*3];
		uint32_t i1 = indices[ii*3+1];
		uint32_t i2 = indices[ii*3+2];

		bgfx_vertex_unpack(&v0.m_x, BGFX_ATTRIB_POSITION,  vd, vertices, i0);
		bgfx_vertex_unpack(&v0.m_u, BGFX_ATTRIB_TEXCOORD0, vd, vertices, i0);

		bgfx_vertex_unpack(&v1.m_x, BGFX_ATTRIB_POSITION,  vd, vertices, i1);
		bgfx_vertex_unpack(&v1.m_u, BGFX_ATTRIB_TEXCOORD0, vd, vertices, i1);

		bgfx_vertex_unpack(&v2.m_x, BGFX_ATTRIB_POSITION,  vd, vertices, i2);
		bgfx_vertex_unpack(&v2.m_u, BGFX_ATTRIB_TEXCOORD0, vd, vertices, i2);

		const float bax = v1.m_x - v0.m_x;
		const float bay = v1.m_y - v0.m_y;
		const float baz = v1.m_z - v0.m_z;
		const float bau = v1.m_u - v0.m_u;
		const float bav = v1.m_v - v0.m_v;

		const float cax = v2.m_x - v0.m_x;
		const float cay = v2.m_y - v0.m_y;
		const float caz = v2.m_z - v0.m_z;
		const float cau = v2.m_u - v0.m_u;
		const float cav = v2.m_v - v0.m_v;

		const float det = (bau * cav - bav * cau);
		const float invDet = 1.0f / det;

		const float tx = (bax * cav - cax * bav) * invDet;
		const float ty = (bay * cav - cay * bav) * invDet;
		const float tz = (baz * cav - caz * bav) * invDet;

		const float bx = (cax * bau - bax * cau) * invDet;
		const float by = (cay * bau - bay * cau) * invDet;
		const float bz = (caz * bau - baz * cau) * invDet;

		for (jj = 0; jj < 3; ++jj) {
			float* tanu = &tangents[indices[jj]*6];
			float* tanv = &tanu[3];
			tanu[0] += tx;
			tanu[1] += ty;
			tanu[2] += tz;

			tanv[0] += bx;
			tanv[1] += by;
			tanv[2] += bz;
		}
	}

	for (ii = 0; ii < numVertices; ++ii) {
		const float* tanu = &tangents[ii*6];
		const float* tanv = &tangents[ii*6 + 3];

		float normal[4];
		bgfx_vertex_unpack(normal, BGFX_ATTRIB_NORMAL, vd, vertices, ii);
		float ndt = DOT(normal, tanu);
		// cross(normal, tanu)
		float nxt[3];
		CROSS(nxt, normal, tanu);

		float tangent[4];
		tangent[0] = tanu[0] - normal[0] * ndt;
		tangent[1] = tanu[1] - normal[1] * ndt;
		tangent[2] = tanu[2] - normal[2] * ndt;

		NORMALIZE(tangent);

		tangent[3] = DOT(nxt, tanv) < 0.0f ? -1.0f : 1.0f;
		bgfx_vertex_pack(tangent, true, BGFX_ATTRIB_TANGENT, vd, vertices, ii);
	}
}

/*
	table data / lightuserdata memory
	desc
	flags
		r BGFX_BUFFER_COMPUTE_READ 
		w BGFX_BUFFER_COMPUTE_WRITE
		s BGFX_BUFFER_ALLOW_RESIZE ( for dynamic buffer )
		d BGFX_BUFFER_INDEX32 ( for index buffer )
		t calc targent
 */
static int
lcreateVertexBuffer(lua_State *L) {
	bgfx_vertex_decl_t *vd = lua_touserdata(L, 2);
	if (vd == NULL)
		return luaL_error(L, "Invalid vertex decl");
	
	const bgfx_memory_t *mem = create_from_table_decl(L, 1, vd);
	uint16_t flags = BGFX_BUFFER_NONE;
	int calc_targent = 0;
	if (lua_isstring(L, 3)) {
		const char *f = lua_tostring(L, 3);
		int i;
		for (i=0;f[i];i++) {
			switch(f[i]) {
			case 'r' :
				flags |= BGFX_BUFFER_COMPUTE_READ;
				break;
			case 'w':
				flags |= BGFX_BUFFER_COMPUTE_WRITE;
				break;
			case 't':
				calc_targent = 1;
				break;
			default:
				return luaL_error(L, "Invalid buffer flag %c", f[i]);
			}
		}
	}
	if (calc_targent) {
		calc_tangent_vb(L, mem, vd, 4);	// todo
	}
	bgfx_vertex_buffer_handle_t handle = bgfx_create_vertex_buffer(mem, vd, flags);
	if (invalid_handle(handle)) {
		return luaL_error(L, "create vertex buffer failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(VERTEX_BUFFER, handle));
	return 1;
}

static int
lcreateDynamicVertexBuffer(lua_State *L) {
	bgfx_vertex_decl_t *vd = lua_touserdata(L, 2);
	if (vd == NULL)
		return luaL_error(L, "Invalid vertex decl");
	uint16_t flags = BGFX_BUFFER_NONE;
	if (lua_isstring(L, 3)) {
		const char *f = lua_tostring(L, 3);
		int i;
		for (i=0;f[i];i++) {
			switch(f[i]) {
			case 'r' :
				flags |= BGFX_BUFFER_COMPUTE_READ;
				break;
			case 'w':
				flags |= BGFX_BUFFER_COMPUTE_WRITE;
				break;
			case 'a':
				flags |= BGFX_BUFFER_ALLOW_RESIZE;
				break;
			default:
				return luaL_error(L, "Invalid buffer flag %c", f[i]);
			}
		}
	}

	bgfx_dynamic_vertex_buffer_handle_t handle;
	if (lua_type(L, 1) == LUA_TNUMBER) {
		uint32_t num = luaL_checkinteger(L, 1);
		handle = bgfx_create_dynamic_vertex_buffer(num, vd, flags);
	} else {
		const bgfx_memory_t *mem = create_from_table_decl(L, 1, vd);
		handle = bgfx_create_dynamic_vertex_buffer_mem(mem, vd, flags);
	}

	if (invalid_handle(handle)) {
		return luaL_error(L, "create dynamic vertex buffer failed");
	}

	lua_pushinteger(L, BGFX_LUAHANDLE(DYNAMIC_VERTEX_BUFFER, handle));
	return 1;
}

static uint16_t
index_buffer_flags(lua_State *L, int index) {
	uint16_t flags = BGFX_BUFFER_NONE;
	if (lua_isstring(L, index)) {
		const char *f = lua_tostring(L, index);
		int i;
		for (i=0;f[i];i++) {
			switch(f[i]) {
			case 'r' :
				flags |= BGFX_BUFFER_COMPUTE_READ;
				break;
			case 'w':
				flags |= BGFX_BUFFER_COMPUTE_WRITE;
				break;
			case 'a':
				flags |= BGFX_BUFFER_ALLOW_RESIZE;
				break;
			case 'd':
				flags |= BGFX_BUFFER_INDEX32;
				break;
			default:
				return luaL_error(L, "Invalid buffer flag %c", f[i]);
			}
		}
	}
	return flags;
}

/*
	table data / lightuserdata mem
	boolean 32bit index
 */
static int
lcreateIndexBuffer(lua_State *L) {
	const bgfx_memory_t *mem;
	uint16_t flags = index_buffer_flags(L, 2);
	if (flags & BGFX_BUFFER_INDEX32) {
		mem = create_from_table_int32(L, 1);
	} else {
		mem = create_from_table_int16(L, 1);
	}
	bgfx_index_buffer_handle_t handle = bgfx_create_index_buffer(mem, flags);
	if (invalid_handle(handle)) {
		return luaL_error(L, "create index buffer failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(INDEX_BUFFER, handle));
	return 1;
}

static int
lupdate(lua_State *L) {
	int id = luaL_checkinteger(L, 1);
	int idtype = id >> 16;
	int idx = id & 0xffff;
	uint32_t start = luaL_checkinteger(L, 2);
	if (idtype == BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER) {
		const bgfx_memory_t *mem = create_from_table_decl(L, 3, NULL);
		bgfx_dynamic_vertex_buffer_handle_t handle = { idx };
		bgfx_update_dynamic_vertex_buffer(handle, start, mem);
		return 0;
	}
	bgfx_dynamic_index_buffer_handle_t handle = { idx };
	const bgfx_memory_t *mem;
	if (idtype == BGFX_HANDLE_DYNAMIC_INDEX_BUFFER) {
		mem = create_from_table_int16(L, 3);
	} else {
		if (idtype != BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32) {
			return luaL_error(L, "Invalid dynamic index buffer type %d", idtype);
		}
		mem = create_from_table_int32(L, 3);
	}
	bgfx_update_dynamic_index_buffer(handle, start, mem);
	return 0;
}

static int
lcreateDynamicIndexBuffer(lua_State *L) {
	uint16_t flags = index_buffer_flags(L, 2);

	bgfx_dynamic_index_buffer_handle_t handle;
	if (lua_type(L, 1) == LUA_TNUMBER) {
		uint32_t num = luaL_checkinteger(L, 1);
		handle = bgfx_create_dynamic_index_buffer(num, flags);
	} else {
		const bgfx_memory_t *mem;
		if (flags & BGFX_BUFFER_INDEX32) {
			mem = create_from_table_int32(L, 1);
		} else {
			mem = create_from_table_int16(L, 1);
		}
		handle = bgfx_create_dynamic_index_buffer_mem(mem, flags);
	}

	if (invalid_handle(handle)) {
		return luaL_error(L, "create dynamic index buffer failed");
	}

	if (flags & BGFX_BUFFER_INDEX32) {
		lua_pushinteger(L, BGFX_LUAHANDLE(DYNAMIC_INDEX_BUFFER_32, handle));
	} else {
		lua_pushinteger(L, BGFX_LUAHANDLE(DYNAMIC_INDEX_BUFFER, handle));
	}
	return 1;
}

// from ibcompress.cpp
uint16_t create_compressed_ib(uint32_t num, uint32_t csize, const void * src);

/*
	integer num
	string data
	integer start
	integer end
 */
static int
lcreateIndexBufferCompress(lua_State *L) {
	uint32_t num = (uint32_t)luaL_checkinteger(L, 1);
	size_t sz = 0;
	const char * data = luaL_checklstring(L, 2, &sz);
	int start = luaL_optinteger(L, 3, 1);
	int end = luaL_optinteger(L, 4, -1);
	if (start < 0) {
		start = sz + start + 1;
	}
	if (end < 0) {
		end = sz + end + 1;
	}
	if (end < start)
		luaL_error(L, "empty compressed data");
	int s = end - start + 1;
	data += start - 1;
	uint16_t id = create_compressed_ib(num, s, data);
	bgfx_index_buffer_handle_t handle = { id };
	if (invalid_handle(handle)) {
		return luaL_error(L, "create index buffer failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(INDEX_BUFFER, handle));
	return 1;
}

static int
lsetViewTransform(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	void *view = lua_touserdata(L, 2);	// can be NULL
	if (view == NULL) {
		luaL_checktype(L, 2, LUA_TNIL);
	}
	void *projL = lua_touserdata(L, 3);
	if (projL == NULL) {
		luaL_checktype(L, 3, LUA_TNIL);
	}
	if (lua_isboolean(L, 4)) {
		int stero = lua_toboolean(L, 4);
		void *projR = lua_touserdata(L, 5);
		bgfx_set_view_transform_stereo(viewid, view, projL,
			stero ? BGFX_VIEW_STEREO : BGFX_VIEW_NONE, 
			projR);
	} else {
		bgfx_set_view_transform(viewid, view, projL);
	}
	return 0;
}

static int
lsetVertexBuffer(lua_State *L) {
	int stream = 0;
	int start = 0;
	int end = UINT32_MAX;
	int id;
	if (lua_gettop(L) <= 1) {
		if (lua_isnoneornil(L, 1)) {
			// empty
			bgfx_vertex_buffer_handle_t handle = { UINT16_MAX };
			bgfx_set_vertex_buffer(stream, handle, start, end);
			return 0;
		}
		id = luaL_checkinteger(L, 1);
	} else {
		stream = luaL_checkinteger(L, 1);
		id = luaL_optinteger(L, 2, BGFX_HANDLE_VERTEX_BUFFER | UINT16_MAX);
		start = luaL_optinteger(L, 3, 0);
		end = luaL_optinteger(L, 4, UINT32_MAX);
	}

	int idtype = id >> 16;
	int idx = id & 0xffff;
	if (idtype == BGFX_HANDLE_VERTEX_BUFFER) {
		bgfx_vertex_buffer_handle_t handle = { idx };
		bgfx_set_vertex_buffer(stream, handle, 0, UINT32_MAX);
	} else {
		if (idtype != BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER) {
			return luaL_error(L, "Invalid vertex buffer type %d", idtype);
		}
		bgfx_dynamic_vertex_buffer_handle_t handle = { idx };
		bgfx_set_dynamic_vertex_buffer(stream, handle, 0, UINT32_MAX);
	}
	return 0;
}

static int
lsetIndexBuffer(lua_State *L) {
	int id = luaL_optinteger(L, 1, BGFX_HANDLE_INDEX_BUFFER | UINT16_MAX);
	int idtype = id >> 16;
	int idx = id & 0xffff;
	int start = luaL_optinteger(L, 2, 0);
	uint32_t end = luaL_optinteger(L, 3, UINT32_MAX); 

	if (idtype == BGFX_HANDLE_INDEX_BUFFER) {
		bgfx_index_buffer_handle_t handle = { idx };
		bgfx_set_index_buffer(handle, start, end);
	} else {
		if (idtype != BGFX_HANDLE_DYNAMIC_INDEX_BUFFER &&
			idtype != BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32) {
			return luaL_error(L, "Invalid index buffer type %d", idtype);
		}
		bgfx_dynamic_index_buffer_handle_t handle = { idx };
		bgfx_set_dynamic_index_buffer(handle, start, end);
	}
	return 0;
}

static int
lsetTransform(lua_State *L) {
	int t = lua_type(L, 1);
	int num = luaL_optinteger(L, 2, 1);
	if (t == LUA_TUSERDATA || t == LUA_TLIGHTUSERDATA) {
		void *mat = lua_touserdata(L, 1);
		int id = bgfx_set_transform(mat, num);
		lua_pushinteger(L, id);
	} else if (t == LUA_TNUMBER) {
		int id = luaL_checkinteger(L, 1);
		bgfx_set_transform_cached(id, num);
		return 1;
	} else {
		return luaL_error(L, "Need matrix or cache id");
	}
	return 1;
}

static int
ldbgTextClear(lua_State *L) {
	int attrib = luaL_optinteger(L, 1, 0);
	int s = lua_toboolean(L, 2);
	bgfx_dbg_text_clear(attrib, s);
	return 0;
}

static int
ldbgTextPrint(lua_State *L) {
	int x = luaL_checkinteger(L, 1);
	int y = luaL_checkinteger(L, 2);
	int attrib = luaL_checkinteger(L, 3);
	const char * text = luaL_checkstring(L, 4);
	bgfx_dbg_text_printf(x,y,attrib,"%s",text);
	return 0;
}

static int
ldbgTextImage(lua_State *L) {
	int x = luaL_checkinteger(L, 1);
	int y = luaL_checkinteger(L, 2);
	int w = luaL_checkinteger(L, 3);
	int h = luaL_checkinteger(L, 4);
	const char * image = luaL_checkstring(L, 5);
	int pitch = luaL_optinteger(L, 6, 2 * w);
	bgfx_dbg_text_image(x,y,w,h,image, pitch);
	return 0;
}

struct ltb {
	bgfx_transient_vertex_buffer_t tvb;
	bgfx_transient_index_buffer_t tib;
	int cap_v;
	int cap_i;
	char format[1];
};

static int
lallocTB(lua_State *L) {
	struct ltb *v = luaL_checkudata(L, 1, "BGFX_TB");
	int max_v = luaL_checkinteger(L, 2);
	int max_i = 0;
	int vd_index = 3;
	if (lua_isinteger(L, 3)) {
		// alloc index
		max_i = lua_tointeger(L, 3);
		vd_index = 4;
	}
	bgfx_vertex_decl_t *vd = NULL;
	if (max_v) {
		vd = lua_touserdata(L, vd_index);
		if (vd == NULL) {
			return luaL_error(L, "Need vertex decl");
		}
	}

	if (max_v && max_i) {
		if (!bgfx_alloc_transient_buffers(&v->tvb, vd, max_v, &v->tib, max_i)) {
			v->cap_v = 0;
			v->cap_i = 0;
			return luaL_error(L, "Alloc transient buffers failed");
		}
	} else {
		if (max_v) {
			bgfx_alloc_transient_vertex_buffer(&v->tvb, max_v, vd);
		}
		if (max_i) {
			bgfx_alloc_transient_index_buffer(&v->tib, max_i);
		}
	}
	v->cap_v = max_v;
	v->cap_i = max_i;
	return 0;
}

static int
lsetTVB(lua_State *L) {
	struct ltb *v = luaL_checkudata(L, 1, "BGFX_TB");
	if (v->cap_v == 0) {
		return luaL_error(L, "Need alloc transient vb first");
	}
	int stream = luaL_checkinteger(L, 2);
	int start = luaL_optinteger(L, 3, 0);
	uint32_t end = luaL_optinteger(L, 4, UINT32_MAX); 

	bgfx_set_transient_vertex_buffer(stream, &v->tvb, start, end);
	v->cap_v = 0;
	return 0;
}

static int
lsetTIB(lua_State *L) {
	struct ltb *v = luaL_checkudata(L, 1, "BGFX_TB");
	if (v->cap_i == 0) {
		return luaL_error(L, "Need alloc transient ib first");
	}
	int start = luaL_optinteger(L, 2, 0);
	uint32_t end = luaL_optinteger(L, 3, UINT32_MAX); 
	bgfx_set_transient_index_buffer(&v->tib, start, end);
	v->cap_i = 0;
	return 0;
}

static int
lsetTB(lua_State *L) {
	struct ltb *v = luaL_checkudata(L, 1, "BGFX_TB");
	if (v->cap_i) {
		bgfx_set_transient_index_buffer(&v->tib, 0, v->cap_i);
		v->cap_i = 0;
	}
	if (v->cap_v) {
		bgfx_set_transient_vertex_buffer(0, &v->tvb, 0, v->cap_v);
		v->cap_v = 0;
	}
	return 0;
}

static int
lpackTVB(lua_State *L) {
	struct ltb *v = luaL_checkudata(L, 1, "BGFX_TB");
	int idx = luaL_checkinteger(L, 2);
	if (idx < 0 || idx >= v->cap_v) {
		return luaL_error(L, "Transient vb index out of range %d/%d", idx, v->cap_v);
	}
	int stride = v->tvb.stride;
	uint8_t * data = v->tvb.data + stride * idx;
	int i;
	int offset = 0;
	for (i=0;v->format[i];i++) {
		if (offset >= stride) {
			return luaL_error(L, "Invalid format %s for stride %d", v->format, stride);
		}
		uint32_t d;
		switch(v->format[i]) {
		case 'f':	// float
			*(float*)(data + offset) = luaL_checknumber(L, 3+i);
			break;
		case 'd':	// dword
			d = (uint32_t)luaL_checkinteger(L, 3+i);
			data[offset] = d & 0xff;
			data[offset+1] = (d >> 8) & 0xff;
			data[offset+2] = (d >> 16) & 0xff;
			data[offset+3] = (d >> 24) & 0xff;
			break;
		case 's':	// skip
			break;
		default:
			return luaL_error(L, "Invalid format %c", v->format[i]);
		}
		offset += 4;
	}
	return 0;
}

static int
lpackTIB(lua_State *L) {
	struct ltb *v = luaL_checkudata(L, 1, "BGFX_TB");
	luaL_checktype(L, 2, LUA_TTABLE);
	uint16_t* indices = (uint16_t*)v->tib.data;
	int i;
	for (i=0;i<v->cap_i;i++) {
		if (lua_geti(L, 2, i+1) != LUA_TNUMBER) {
			luaL_error(L, "Invalid index buffer data %d", i+1);
		}
		int v = lua_tointeger(L, -1);
		lua_pop(L, 1);
		indices[i] = (uint16_t)v;
	}

	return 0;
}

static int
lnewTransientBuffer(lua_State *L) {
	size_t sz;
	const char * format = luaL_checklstring(L, 1, &sz);
	struct ltb * v = lua_newuserdata(L, sizeof(*v) + sz);
	v->cap_v = 0;
	v->cap_i = 0;
	memcpy(v->format, format, sz+1);
	if (luaL_newmetatable(L, "BGFX_TB")) {
		luaL_Reg l[] = {
			{ "alloc", lallocTB },
			{ "setV", lsetTVB },
			{ "setI", lsetTIB },
			{ "set", lsetTB },
			{ "packV", lpackTVB },
			{ "packI", lpackTIB },
			{ NULL, NULL },
		};
		luaL_newlib(L, l);
		lua_setfield(L, -2, "__index");
		lua_pushcfunction(L, lpackTVB);
		lua_setfield(L, -2, "__call");
	}
	lua_setmetatable(L, -2);
	return 1;
}

struct lidb {
	bgfx_instance_data_buffer_t idb;
	int num;
	int stride;
	char format[1];
};

static int
lallocIDB(lua_State *L) {
	struct lidb *v = luaL_checkudata(L, 1, "BGFX_IDB");
	int num = luaL_checkinteger(L, 2);
	bgfx_alloc_instance_data_buffer(&v->idb, num, v->stride);
	v->num = num;
	return 0;
}

static int
lsetIDB(lua_State *L) {
	struct lidb *v = luaL_checkudata(L, 1, "BGFX_IDB");
	uint32_t num = UINT32_MAX;
	if (lua_isnumber(L, 2)) {
		num = lua_tointeger(L, 2);
		if (num >= (uint32_t)v->num) {
			return luaL_error(L, "Invalid instance data buffer num %d/%d",num, v->num);
		}
	}
	bgfx_set_instance_data_buffer(&v->idb, 0, num);
	v->num = 0;
	return 0;
}

static int
lpackIDB(lua_State *L) {
	struct lidb *v = luaL_checkudata(L, 1, "BGFX_IDB");
	int idx = luaL_checkinteger(L, 2);
	if (idx < 0 || idx >= v->num) {
		return luaL_error(L, "Instance data buffer index out of range %d/%d", idx, v->num);
	}
	int stride = v->stride;
	float * data = (float *)(v->idb.data + stride * idx);
	int i;
	int lidx = 3;
	int offset = 0;
	float * ud;
	for (i=0;v->format[i];i++) {
		switch(v->format[i]) {
		case 'm':	// matrix 4x4
			ud = lua_touserdata(L, lidx);
			if (ud == NULL) {
				return luaL_error(L, "Missing matrix");
			}
			memcpy(&data[offset], ud, 16 * sizeof(float));
			offset += 16;
			break;
		case 'v':	// vector 4
			if (lua_isnumber(L, lidx)) {
				// 4 floats
				data[offset] = lua_tonumber(L, lidx);
				data[offset+1] = luaL_checknumber(L, lidx+1);
				data[offset+2] = luaL_checknumber(L, lidx+2);
				data[offset+3] = luaL_checknumber(L, lidx+3);
				lidx += 3;
			} else {
				ud = lua_touserdata(L, lidx);
				if (ud == NULL) {
					return luaL_error(L, "Missing vector");
				}
				memcpy(&data[offset], ud, 4 * sizeof(float));
			}
			offset += 4;
			break;
		}
		lidx ++;
	}
	if (lua_gettop(L) != lidx - 1) {
		return luaL_error(L, "too much of data");
	}
	return 0;
}

static int
lnewInstanceBuffer(lua_State *L) {
	size_t sz;
	const char * format = luaL_checklstring(L, 1, &sz);
	struct lidb * v = lua_newuserdata(L, sizeof(*v) + sz);
	v->num = 0;
	int i;
	int stride = 0;
	for (i=0;format[i];i++) {
		switch(format[i]) {
		case 'm' :
			stride += 4*16;	// matrix 4x4
			break;
		case 'v':
			stride += 4*4;	// vector4
			break;
		default:
			return luaL_error(L, "Invalid instance data buffer format %c", format[i]);
		}
	}
	v->stride = stride;
	memcpy(v->format, format, sz+1);
	if (luaL_newmetatable(L, "BGFX_IDB")) {
		luaL_Reg l[] = {
			{ "alloc", lallocIDB },
			{ "set", lsetIDB },
			{ "pack", lpackIDB },
			{ NULL, NULL },
		};
		luaL_newlib(L, l);
		lua_setfield(L, -2, "__index");
		lua_pushcfunction(L, lpackIDB);
		lua_setfield(L, -2, "__call");
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
lcreateUniform(lua_State *L) {
	const char * name = luaL_checkstring(L, 1);
	const char * type = luaL_checkstring(L, 2);
	bgfx_uniform_type_t ut;
	switch(type[0]) {
	case 'i':
		if (type[1] != '1') {
			return luaL_error(L, "Invalid Uniform type %s", type);
		}
		ut = BGFX_UNIFORM_TYPE_INT1;
		break;
	case 'v':
		if (type[1] != '4') {
			return luaL_error(L, "Invalid Uniform type %s", type);
		}
		ut = BGFX_UNIFORM_TYPE_VEC4;
		break;
	case 'm':
		switch (type[1]) {
		case '3':
			ut = BGFX_UNIFORM_TYPE_MAT3;
			break;
		case '4':
			ut = BGFX_UNIFORM_TYPE_MAT4;
			break;
		default:
			return luaL_error(L, "Invalid Uniform type %s", type);
		}
		break;
	default:
		return luaL_error(L, "Invalid Uniform type %s", type);
	}
	int num = luaL_optinteger(L, 3, 1);
	bgfx_uniform_handle_t handle = bgfx_create_uniform(name, ut, num);
	if (invalid_handle(handle)) {
		return luaL_error(L, "create uniform failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(UNIFORM, handle));
	return 1;
}

static int
lgetUniformInfo(lua_State *L) {
	int uniformid = BGFX_LUAHANDLE_ID(UNIFORM, luaL_checkinteger(L, 1));
	bgfx_uniform_handle_t uh = { uniformid };
	bgfx_uniform_info_t ut;
	bgfx_get_uniform_info(uh, &ut);
	lua_pushstring(L, ut.name);
	switch (ut.type) {
	case BGFX_UNIFORM_TYPE_INT1:
		lua_pushstring(L, "i1");
		break;
	case BGFX_UNIFORM_TYPE_VEC4:
		lua_pushstring(L, "v4");
		break;
	case BGFX_UNIFORM_TYPE_MAT3:
		lua_pushstring(L, "m3");
		break;
	case BGFX_UNIFORM_TYPE_MAT4:
		lua_pushstring(L, "m4");
		break;
	default:
		return luaL_error(L, "Invalid uniform type %d", (int)ut.type);
	}
	lua_pushinteger(L, ut.num);
	return 3;
}

static int
uniform_size(lua_State *L, bgfx_uniform_handle_t uh) {
	int sz;
	bgfx_uniform_info_t uinfo;
	bgfx_get_uniform_info(uh, &uinfo);

	switch (uinfo.type) {
//	case BGFX_UNIFORM_TYPE_INT1: sz = 4; break;	// 1 int32 never be INT1
	case BGFX_UNIFORM_TYPE_VEC4: sz = 4; break;	// 4 float
	case BGFX_UNIFORM_TYPE_MAT3: sz = 3*4; break;	// 3*4 float
	case BGFX_UNIFORM_TYPE_MAT4: sz = 4*4; break;	// 4*4 float
	default:
		return luaL_error(L, "Invalid uniform type %d", uinfo.type);
	}
	return sz;
}

static int
lsetUniform(lua_State *L) {
	int uniformid = BGFX_LUAHANDLE_ID(UNIFORM, luaL_checkinteger(L, 1));
	bgfx_uniform_handle_t uh = { uniformid };
	int number = lua_gettop(L) - 1;
	int t = lua_type(L, 2);	// the first value type
	switch(t) {
	case LUA_TTABLE: {
		// vector or matrix
		int sz = uniform_size(L, uh);
		float buffer[V(sz * number)];
		int i,j;
		for (i=0;i<number;i++) {
			luaL_checktype(L, 2+i, LUA_TTABLE);
			for (j=0;j<sz;j++) {
				if (lua_geti(L, 2+i, j+1) != LUA_TNUMBER) {
					return luaL_error(L, "[%d,%d] should be number", i+2,j+1);
				}
				buffer[i*sz+j] = lua_tonumber(L, -1);
				lua_pop(L, 1);
			}
		}
		bgfx_set_uniform(uh, buffer, number);
		break;
	}
	case LUA_TNUMBER: {
		// int1
		uint32_t ints[V(number)];
		int i;
		for (i=0;i<number;i++) {
			ints[i] = luaL_checkinteger(L, i+2);
		}
		bgfx_set_uniform(uh, ints, number);
		break;
	}
	case LUA_TUSERDATA:
	case LUA_TLIGHTUSERDATA:
		// vectir or matrix
		if (number == 1) {
			// only one
			void *data = lua_touserdata(L, 2);
			if (data == NULL)
				return luaL_error(L, "Uniform can't be NULL");
			bgfx_set_uniform(uh, data, 1);
		} else {
			int sz = uniform_size(L, uh);
			float buffer[V(sz * number)];
			int i;
			for (i=0;i<number;i++) {
				void * ud = lua_touserdata(L, 2+i);
				if (ud == NULL) {
					return luaL_error(L, "Uniform need userdata at index %d", i+2);
				}
				memcpy(buffer + i * sz, ud, sz*sizeof(float));
			}
			bgfx_set_uniform(uh, buffer, number);
		}
		break;
	default:
		return luaL_error(L, "Invalid value type : %s", lua_typename(L, t));
	}
	return 0;
}

static uint32_t
border_color_or_compare(lua_State *L, char c) {
	int n  = 0;
	if (c>='0' && c<='9') {
		n = c-'0';
	} else if (c>='a' && c<='f') {
		n = c-'a'+10;
	} else {
		// compare
		switch(c) {
		case '<': return BGFX_TEXTURE_COMPARE_LESS;
		case '[': return BGFX_TEXTURE_COMPARE_LEQUAL;
		case '=': return BGFX_TEXTURE_COMPARE_EQUAL;
		case ']': return BGFX_TEXTURE_COMPARE_GEQUAL;
		case '>': return BGFX_TEXTURE_COMPARE_GREATER;
		case '!': return BGFX_TEXTURE_COMPARE_NOTEQUAL;
		case '-': return BGFX_TEXTURE_COMPARE_NEVER;
		case '+': return BGFX_TEXTURE_COMPARE_ALWAYS;
		default:
			luaL_error(L, "Invalid border color %c", c);
		}
	}
	return BGFX_TEXTURE_BORDER_COLOR(n);
}

static uint32_t
get_texture_flags(lua_State *L, const char *format) {
	int i;
	uint32_t flags = 0;
	for (i=0;format[i];i+=2) {
		int t = 0;
		switch(format[i]) {
		case 'u': t = 0x00; break;	// U
		case 'v': t = 0x10; break;	// V
		case 'w': t = 0x20; break;	// W
		case '-': t = 0x30; break;	// MIN
		case '+': t = 0x40; break;	// MAG
		case '*': t = 0x50; break;	// MIP
		case 'c':
			flags |= border_color_or_compare(L, format[i+1]);
			continue;
		case 'r':	// RT
			switch(format[i+1]) {
			case 't': flags |= BGFX_TEXTURE_RT; break;
			case 'w': flags |= BGFX_TEXTURE_RT_WRITE_ONLY; break;
			case '2': flags |= BGFX_TEXTURE_RT_MSAA_X2; break;
			case '4': flags |= BGFX_TEXTURE_RT_MSAA_X4; break;
			case '8': flags |= BGFX_TEXTURE_RT_MSAA_X8; break;
			case 'x': flags |= BGFX_TEXTURE_RT_MSAA_X16; break;
			default:
				luaL_error(L, "Invalid RT MSAA %c", format[i+1]);
			}
			continue;
		case 'b': // BLIT
			switch(format[i+1]) {
			case 'r' : flags |= BGFX_TEXTURE_READ_BACK; break;
			case 'w' : flags |= BGFX_TEXTURE_BLIT_DST; break;
			case 'c' : flags |= BGFX_TEXTURE_COMPUTE_WRITE; break;
			default:
				luaL_error(L, "Invalid BLIT %c", format[i+1]);
			}
			continue;			
		default:
			luaL_error(L, "Invalid texture flags %c",format[i]);
		}
		switch(format[i+1]) {
		case 'm': break;	// MIRROR
		case 'c': t|= 1; break;	// CLAMP
		case 'b': t|= 2; break;	// BORDER
		case 'p': t|= 3; break;	// POINT
		case 'a': t|= 4; break;	// ANISOTROPIC
		default:
			luaL_error(L, "Invalid texture flags %c", format[i+1]);
		}
		switch(t) {
		case 0x00: flags |= BGFX_TEXTURE_U_MIRROR; break;
		case 0x01: flags |= BGFX_TEXTURE_U_CLAMP; break;
		case 0x02: flags |= BGFX_TEXTURE_U_BORDER; break;
		case 0x10: flags |= BGFX_TEXTURE_V_MIRROR; break;
		case 0x11: flags |= BGFX_TEXTURE_V_CLAMP; break;
		case 0x12: flags |= BGFX_TEXTURE_V_BORDER; break;
		case 0x20: flags |= BGFX_TEXTURE_W_MIRROR; break;
		case 0x21: flags |= BGFX_TEXTURE_W_CLAMP; break;
		case 0x22: flags |= BGFX_TEXTURE_W_BORDER; break;
		case 0x33: flags |= BGFX_TEXTURE_MIN_POINT; break;
		case 0x34: flags |= BGFX_TEXTURE_MIN_ANISOTROPIC; break;
		case 0x43: flags |= BGFX_TEXTURE_MAG_POINT; break;      
		case 0x44: flags |= BGFX_TEXTURE_MAG_ANISOTROPIC; break;
		case 0x53: flags |= BGFX_TEXTURE_MIP_POINT; break;      
		default:
			luaL_error(L, "Invalid texture flags %c%c", format[i], format[i+1]);
		}
	}
	return flags;
}

static void
parse_texture_info(lua_State *L, int idx, bgfx_texture_info_t *info) {
	if (info->format >= BGFX_TEXTURE_FORMAT_COUNT) {
		luaL_error(L, "Invalid texture format %d", info->format);
	}
	lua_pushstring(L, c_texture_formats[info->format]);
	lua_setfield(L, idx, "format");
	lua_pushinteger(L, info->storageSize);
	lua_setfield(L, idx, "storageSize");
	lua_pushinteger(L, info->width);
	lua_setfield(L, idx, "width");
	lua_pushinteger(L, info->height);
	lua_setfield(L, idx, "height");
	lua_pushinteger(L, info->depth);
	lua_setfield(L, idx, "depth");
	lua_pushinteger(L, info->numLayers);
	lua_setfield(L, idx, "numLayers");
	lua_pushinteger(L, info->numMips);
	lua_setfield(L, idx, "numMips");
	lua_pushinteger(L, info->bitsPerPixel);
	lua_setfield(L, idx, "bitsPerpixel");
	lua_pushboolean(L, info->cubeMap);
	lua_setfield(L, idx, "cubeMap");
}

static int
memory_tostring(lua_State *L) {
	void * data = lua_touserdata(L, 1);
	size_t sz = lua_rawlen(L, 1);
	lua_pushlstring(L, data, sz);
	return 1;
}

// base 1
static int
memory_read(lua_State *L) {
	int index = luaL_checkinteger(L, 2)-1;
	uint32_t * data = (uint32_t *)lua_touserdata(L, 1);
	size_t sz = lua_rawlen(L, 1);
	if (index < 0 || index * sizeof(uint32_t) >=sz) {
		return 0;
	}
	lua_pushinteger(L, data[index]);
	return 1;
}

static int
memory_write(lua_State *L) {
	int index = luaL_checkinteger(L, 2)-1;
	uint32_t * data = (uint32_t *)lua_touserdata(L, 1);
	size_t sz = lua_rawlen(L, 1);
	if (index < 0 || index * sizeof(uint32_t) >=sz) {
		return luaL_error(L, "out of range %d/[1-%d]", index+1, sz / sizeof(uint32_t));
	}
	uint32_t v = luaL_checkinteger(L, 2);
	data[index] = v;
	return 0;
}

/*
	integer size	(width * height * 4 for RGBA8888)
 */
static int
lmemoryTexture(lua_State *L) {
	int size = luaL_checkinteger(L, 1);
	void * data = lua_newuserdata(L, size);
	memset(data, 0, size);
	if (luaL_newmetatable(L, "BGFX_MEMORY")) {
		lua_pushcfunction(L, memory_tostring);
		lua_setfield(L, -2, "__tostring");
		lua_pushcfunction(L, memory_read);
		lua_setfield(L, -2, "__index");
		lua_pushcfunction(L, memory_write);
		lua_setfield(L, -2, "__newindex");
	}
	lua_setmetatable(L, -2);
	return 1;
}

/*
	string imgdata
	string flags	-- [uvw]m/c[-+*]p/a  - MIN + MAG * MIP
	integer skip
	table info
 */
static int
lcreateTexture(lua_State *L) {
	size_t sz;
	const char *imgdata = luaL_checklstring(L, 1, &sz);
	int idx = 2;
	uint32_t flags = BGFX_TEXTURE_NONE;
	if (lua_type(L, idx) == LUA_TSTRING) {
		const char * f = lua_tostring(L, idx);
		flags = get_texture_flags(L, f);
		++idx;
	}
	int skip = 0;
	if (lua_type(L, idx) == LUA_TNUMBER) {
		skip = lua_tointeger(L, idx);
		++idx;
	}
	const bgfx_memory_t * mem = bgfx_copy(imgdata, sz);
	bgfx_texture_handle_t h;
	if (lua_type(L, idx) == LUA_TTABLE) {
		bgfx_texture_info_t info;
		h = bgfx_create_texture(mem, flags, skip, &info);
		parse_texture_info(L, idx, &info);
	} else {
		h = bgfx_create_texture(mem, flags, skip, NULL);
	}
	if (invalid_handle(h)) {
		return luaL_error(L, "create texture failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(TEXTURE, h));

	return 1;
}

static int
lsetName(lua_State *L) {
	int idx = luaL_checkinteger(L, 1);
	int type = idx >> 16;
	int id = idx & 0xffff;
	size_t sz;
	const char *name = luaL_checklstring(L, 2, &sz);
	switch(type) {
	case BGFX_HANDLE_SHADER: {
		bgfx_shader_handle_t handle = { id };
		bgfx_set_shader_name(handle, name, sz);
		break;
	}
	case BGFX_HANDLE_TEXTURE : {
		bgfx_texture_handle_t handle = { id };
		bgfx_set_texture_name(handle, name, sz);
		break;
	}
	default:
		return luaL_error(L, "set_name only support shader or texture");
	}
	return 0;
}

static int
lsetTexture(lua_State *L) {
	int stage = luaL_checkinteger(L, 1);
	int uniform_id = BGFX_LUAHANDLE_ID(UNIFORM, luaL_checkinteger(L, 2));
	int texture_id = BGFX_LUAHANDLE_ID(TEXTURE, luaL_checkinteger(L, 3));
	int flags = UINT32_MAX;
	if (!lua_isnoneornil(L, 4)) {
		const char * f = lua_tostring(L, 4);
		flags = get_texture_flags(L, f);
	}
	bgfx_uniform_handle_t uh = {uniform_id};
	bgfx_texture_handle_t th = {texture_id};

	bgfx_set_texture(stage, uh, th, flags);

	return 0;
}

static bgfx_texture_format_t
texture_format_from_string(lua_State *L, int idx) {
	lua_getfield(L, LUA_REGISTRYINDEX, "BGFX_TF");
	lua_pushvalue(L, idx);
	if (lua_rawget(L, -2) != LUA_TNUMBER) {
		luaL_error(L, "Invalid texture format %s", lua_tostring(L, idx));
	}
	int id = lua_tointeger(L, -1);
	lua_pop(L, 2);
	return (bgfx_texture_format_t)id;
}

static bgfx_frame_buffer_handle_t
create_fb(lua_State *L) {
	int width = luaL_checkinteger(L, 1);
	int height = luaL_checkinteger(L, 2);
	bgfx_texture_format_t fmt = texture_format_from_string(L, 3);
	uint32_t flags = BGFX_TEXTURE_U_CLAMP|BGFX_TEXTURE_V_CLAMP;
	if (!lua_isnoneornil(L, 4)) {
		const char * f = lua_tostring(L, 4);
		flags = get_texture_flags(L, f);
	}
	return bgfx_create_frame_buffer(width, height, fmt, flags);
}

static bgfx_backbuffer_ratio_t
get_ratio(lua_State *L, int idx) {
	bgfx_backbuffer_ratio_t ratio = 0;
	const char * r = luaL_checkstring(L, idx);
	if (strcmp(r, "1x")==0) {
		ratio = BGFX_BACKBUFFER_RATIO_EQUAL;
	} else if (strcmp(r, "1/2") == 0) {
		ratio = BGFX_BACKBUFFER_RATIO_HALF;
	} else if (strcmp(r, "1/4") == 0) {
		ratio = BGFX_BACKBUFFER_RATIO_QUARTER;
	} else if (strcmp(r, "1/8") == 0) {
		ratio = BGFX_BACKBUFFER_RATIO_EIGHTH;
	} else if (strcmp(r, "1/16") == 0) {
		ratio = BGFX_BACKBUFFER_RATIO_SIXTEENTH;
	} else if (strcmp(r, "2x") == 0) {
		ratio = BGFX_BACKBUFFER_RATIO_DOUBLE;
	} else {
		luaL_error(L, "Invalid back buffer ratio %s", r);
	}
	return ratio;
}

static bgfx_frame_buffer_handle_t
create_fb_scaled(lua_State *L) {
	bgfx_backbuffer_ratio_t ratio = get_ratio(L, 1);
	bgfx_texture_format_t fmt = texture_format_from_string(L, 2);
	uint32_t flags = BGFX_TEXTURE_U_CLAMP|BGFX_TEXTURE_V_CLAMP;
	if (!lua_isnoneornil(L, 3)) {
		const char * f = lua_tostring(L, 3);
		flags = get_texture_flags(L, f);
	}
	return bgfx_create_frame_buffer_scaled(ratio, fmt, flags);
}

static bgfx_frame_buffer_handle_t
create_fb_mrt(lua_State *L) {
	int n = lua_rawlen(L, 1);
	if (n == 0) {
		luaL_error(L, "At lease one frame buffer");
	}
	int destroy = lua_toboolean(L, 2);
	bgfx_texture_handle_t handles[V(n)];
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, 1, i+1) != LUA_TNUMBER) {
			luaL_error(L, "Invalid texture handle id");
		}
		handles[i].idx = BGFX_LUAHANDLE_ID(TEXTURE, lua_tointeger(L, -1));
		lua_pop(L, 1);
	}
	return bgfx_create_frame_buffer_from_handles(n, handles, destroy);
}

static bgfx_frame_buffer_handle_t
create_fb_nwh(lua_State *L) {
	void *nwh = lua_touserdata(L, 1);
	int w = luaL_checkinteger(L, 2);
	int h = luaL_checkinteger(L, 3);
	return bgfx_create_frame_buffer_from_nwh(nwh, w, h, BGFX_TEXTURE_FORMAT_UNKNOWN_DEPTH);
}

/*
	1.
		integer width
		integer height
		string format
		string flags
	2.
		string ratio : 1x 1/2 1/4 1/8 1/16 2x
		string format
		string flags
	3.
		table textures[]
		boolean destroyTex = false
	4.
		lightuserdata window_handle
		integer width
		integer height
	todo:
		from native window handle
		from attachment
 */
static int
lcreateFrameBuffer(lua_State *L) {
	int t = lua_type(L, 1);
	bgfx_frame_buffer_handle_t handle;
	switch(t) {
	case LUA_TNUMBER:
		handle = create_fb(L);
		break;
	case LUA_TTABLE:
		handle = create_fb_mrt(L);
		break;
	case LUA_TSTRING:
		handle = create_fb_scaled(L);
		break;
	case LUA_TLIGHTUSERDATA:
		handle = create_fb_nwh(L);
		break;
	default:
		return luaL_error(L, "Invalid argument type %s for create_frame_buffer", lua_typename(L, t));
	}
	if (invalid_handle(handle)) {
		return luaL_error(L, "create frame buffer failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(FRAME_BUFFER, handle));
	return 1;
}

/*
	1.
		integer width
		integer height
		boolean hasMips
		integer layers
		string format
		string flags
		todo : mem
	2.
		string radio : 1x 1/2 1/4 1/8 1/16 2x
		boolean hasMips
		integer layers
		string format
		string flags
*/
static int
lcreateTexture2D(lua_State *L) {
	int scaled;
	bgfx_backbuffer_ratio_t	ratio = 0;
	int idx;
	int width=0;
	int height=0;
	if (lua_type(L, 1) == LUA_TSTRING) {
		ratio = get_ratio(L, 1);
		scaled = 1;
		idx = 2;
	} else {
		width = luaL_checkinteger(L, 1);
		height = luaL_checkinteger(L, 2);
		scaled = 0;
		idx = 3;
	}
	int hasMips = lua_toboolean(L, idx++);
	int layers = luaL_checkinteger(L, idx++);
	bgfx_texture_format_t fmt = texture_format_from_string(L, idx++);
	uint32_t flags = BGFX_TEXTURE_NONE;
	if (!lua_isnoneornil(L, idx)) {
		const char * f = lua_tostring(L, idx++);
		flags = get_texture_flags(L, f);
	}
	bgfx_texture_handle_t handle;
	if (scaled) {
		handle = bgfx_create_texture_2d_scaled(ratio, hasMips, layers, fmt, flags);
	} else {
		const bgfx_memory_t * mem = NULL;
		switch (lua_type(L, idx)) {
		case LUA_TSTRING: {
			size_t sz;
			const char * data = lua_tolstring(L, idx, &sz);
			mem = bgfx_copy(data, sz);
			break;
		}
		case LUA_TUSERDATA: {
			void *data = luaL_checkudata(L, idx, "BGFX_MEMORY");
			size_t sz = lua_rawlen(L, idx);
			mem = bgfx_make_ref(data, sz);
			break;
		}
		case LUA_TNIL:
		case LUA_TNONE:
			break;
		default:
			return luaL_error(L, "Invalid texture data type %s", lua_typename(L, lua_type(L, idx)));
		}
		handle = bgfx_create_texture_2d(width, height, hasMips, layers, fmt, flags, mem);
	}
	if (invalid_handle(handle)) {
		return luaL_error(L, "create texture 2d failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(TEXTURE, handle));
	return 1;
}

/*
	integer texture id
	integer layer
	integer mip
	integer x
	integer y
	integer w
	integer h
	userdata BGFX_MEMORY
	integer pitch = UINT16_MAX
 */
static int
lupdateTexture2D(lua_State *L) {
	uint16_t tid = BGFX_LUAHANDLE_ID(TEXTURE, luaL_checkinteger(L, 1));
	bgfx_texture_handle_t th = { tid };
	int layer = luaL_checkinteger(L, 2);
	int mip = luaL_checkinteger(L, 3);
	int x = luaL_checkinteger(L, 4);
	int y = luaL_checkinteger(L, 5);
	int w = luaL_checkinteger(L, 6);
	int h = luaL_checkinteger(L, 7);
	void *data = luaL_checkudata(L, 8, "BGFX_MEMORY");
	size_t sz  = lua_rawlen(L, 8);
	const bgfx_memory_t *mem = bgfx_make_ref(data, sz);
	int pitch = luaL_optinteger(L, 9, UINT16_MAX);
	bgfx_update_texture_2d(th, layer, mip, x, y, w, h, mem, pitch);

	return 0;
}

/*
	integer depth
	boolean cubemap
	integer layers
	string format
	string flags
 */
static int
lisTextureValid(lua_State *L) {
	int depth = luaL_checkinteger(L, 1);
	bool cubemap = lua_toboolean(L, 2);
	int layers = luaL_checkinteger(L, 3);
	bgfx_texture_format_t fmt = texture_format_from_string(L, 4);
	const char * f = luaL_checkstring(L, 5);
	uint32_t flags = get_texture_flags(L, f);

	bool valid = bgfx_is_texture_valid(depth, cubemap, layers, fmt, flags);
	lua_pushboolean(L, valid);
	return 1;
}

static int
lsetViewOrder(lua_State *L) {
	if (lua_isnoneornil(L, 1)) {
		bgfx_set_view_order(0,UINT8_MAX,NULL);
		return 0;
	}
	luaL_checktype(L, 1, LUA_TTABLE);
	// todo: set first view not 0
	int n = lua_rawlen(L, 1);
	bgfx_view_id_t order[V(n)];
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, 1, i+1) != LUA_TNUMBER) {
			return luaL_error(L, "Invalid view id");
		}
		order[i] = (bgfx_view_id_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	bgfx_set_view_order(0,n,order);
	return 0;
}

static int
lsetViewRect(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);
	int t = lua_type(L, 4);
	switch(t) {
	case LUA_TSTRING: {
		bgfx_backbuffer_ratio_t ratio = get_ratio(L, 4);
		bgfx_set_view_rect_auto(viewid, x, y, ratio);
		break;
	}
	case LUA_TNONE:
	case LUA_TNIL:
		bgfx_set_view_rect_auto(viewid, x, y, BGFX_BACKBUFFER_RATIO_EQUAL);
		break;
	case LUA_TNUMBER: {
		int w = luaL_checkinteger(L, 4);
		int h = luaL_checkinteger(L, 5);
		bgfx_set_view_rect(viewid, x, y, w, h);
		break;
	}
	default:
		return luaL_error(L, "Invalid argument type %s", lua_typename(L, t));
	}
	return 0;
}

static int
lsetViewName(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	const char *name = luaL_checkstring(L, 2);
	bgfx_set_view_name(viewid, name);
	return 0;
}

static int
lsetViewFrameBuffer(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	uint16_t hid = UINT16_MAX;
	if (!lua_isnoneornil(L, 2)) {
		hid = BGFX_LUAHANDLE_ID(FRAME_BUFFER, luaL_checkinteger(L, 2));
	}
	bgfx_frame_buffer_handle_t h = {hid};
	bgfx_set_view_frame_buffer(viewid, h);
	return 0;
}

static int
lgetTexture(lua_State *L) {
	uint16_t hid = BGFX_LUAHANDLE_ID(FRAME_BUFFER, luaL_checkinteger(L, 1));
	int attachment = luaL_optinteger(L, 2, 0);

	bgfx_frame_buffer_handle_t h = {hid};
	bgfx_texture_handle_t th = bgfx_get_texture(h, attachment);
	if (invalid_handle(th)) {
		return luaL_error(L, "get texture failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(TEXTURE, th));
	return 1;
}

/*
	1. 5
		integer id
		integer dst texture handle
		integer dstX
		integer dstY
		integer src texture handle
	2. 9
		...
		integer srcX
		integer srcY
		integer width
		integer height
	3. 7
		integer id
		integer dst texture handle
		integer dstmip
		integer dstX
		integer dstY
		integer dstZ
		integer src texture handle
	4. 14
		...
		integer srcmip
		integer srcX
		integer srcY
		integer srcZ
		integer width
		integer height
		integer depth
 */
static int
lblit(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	uint16_t dstid = BGFX_LUAHANDLE_ID(TEXTURE, luaL_checkinteger(L, 2));
	int top = lua_gettop(L);
	uint16_t dstx;
	uint16_t dsty;
	uint16_t dstz = 0;
	uint16_t srcid;
	uint16_t srcx = 0;
	uint16_t srcy = 0;
	uint16_t srcz = 0;
	uint16_t width = UINT16_MAX;
	uint16_t height = UINT16_MAX;
	uint16_t depth = UINT16_MAX;
	uint8_t dstmip = 0;
	uint8_t srcmip = 0;

	switch(top) {
	case 9:
		srcx = (uint16_t)luaL_checkinteger(L, 6);
		srcy = (uint16_t)luaL_checkinteger(L, 7);
		width = (uint16_t)luaL_checkinteger(L, 8);
		height = (uint16_t)luaL_checkinteger(L, 9);
		// go though
	case 5:
		dstx = (uint16_t)luaL_checkinteger(L, 3);
		dsty = (uint16_t)luaL_checkinteger(L, 4);
		srcid = BGFX_LUAHANDLE_ID(TEXTURE, luaL_checkinteger(L, 5));
		break;
	case 14:
		srcmip = (uint8_t)luaL_checkinteger(L, 8);
		srcx = (uint16_t)luaL_checkinteger(L, 9);
		srcy = (uint16_t)luaL_checkinteger(L, 10);
		srcz = (uint16_t)luaL_checkinteger(L, 11);
		width = (uint16_t)luaL_checkinteger(L, 12);
		height = (uint16_t)luaL_checkinteger(L, 13);
		depth = (uint16_t)luaL_checkinteger(L, 14);
		// go though
	case 7:
		dstmip = (uint8_t)luaL_checkinteger(L, 3);
		dstx = (uint16_t)luaL_checkinteger(L, 4);
		dsty = (uint16_t)luaL_checkinteger(L, 5);
		dstz = (uint16_t)luaL_checkinteger(L, 6);
		srcid = BGFX_LUAHANDLE_ID(TEXTURE, luaL_checkinteger(L, 7));
		break;
	default:
		return luaL_error(L, "Invalid top %d", top);
	}
	bgfx_texture_handle_t sh = { srcid };
	bgfx_texture_handle_t dh = { dstid };

	bgfx_blit(viewid, dh, dstmip, dstx, dsty, dstz, sh, srcmip, srcx, srcy, srcz, width, height, depth);
	return 0;
}

/*
	integer texture id
	userdata BGFX_MEMORY
	integer mip = 0

	return string
 */
static int
lreadTexture(lua_State *L) {
	uint16_t tid = BGFX_LUAHANDLE_ID(TEXTURE, luaL_checkinteger(L, 1));
	void *data = luaL_checkudata(L, 2, "BGFX_MEMORY");
	int mip = luaL_optinteger(L, 3, 0);
	bgfx_texture_handle_t th = { tid };
	int frame = bgfx_read_texture(th, data, mip);
	lua_pushinteger(L, frame);
	return 1;
}

static uint32_t
stencil_id(lua_State *L) {
	if (lua_type(L, -2) != LUA_TSTRING) {
		luaL_error(L, "stencil key must be string, it's %s", lua_typename(L, lua_type(L, -2)));
	}
	const char * what = lua_tostring(L, -2);
	if CASE(TEST) {
		const char *what = luaL_checkstring(L, -1);
		if CASE(LESS) return BGFX_STENCIL_TEST_LESS;
		if CASE(LEQUAL) return BGFX_STENCIL_TEST_LEQUAL;
		if CASE(EQUAL) return BGFX_STENCIL_TEST_EQUAL;
		if CASE(GEQUAL) return BGFX_STENCIL_TEST_GEQUAL;
		if CASE(GREATER) return BGFX_STENCIL_TEST_GREATER;
		if CASE(NOTEQUAL) return BGFX_STENCIL_TEST_NOTEQUAL;
		if CASE(NEVER) return BGFX_STENCIL_TEST_NEVER;
		if CASE(ALWAYS) return BGFX_STENCIL_TEST_ALWAYS;
		luaL_error(L, "Invalid stencil test %s", what);
	}
	if CASE(FUNC_REF) {
		int r = luaL_checkinteger(L, -1);
		return BGFX_STENCIL_FUNC_REF(r);
	}
	if CASE(FUNC_RMASK) {
		int rmask = luaL_checkinteger(L, -1);
		return BGFX_STENCIL_FUNC_RMASK(rmask);
	}
	uint32_t v = 0;
	do {
		const char * what = luaL_checkstring(L, -1);
		if CASE(ZERO) v = BGFX_STENCIL_OP_FAIL_S_ZERO;
		else if CASE(KEEP) v = BGFX_STENCIL_OP_FAIL_S_KEEP;
		else if CASE(REPLACE) v = BGFX_STENCIL_OP_FAIL_S_REPLACE;
		else if CASE(INCR) v = BGFX_STENCIL_OP_FAIL_S_INCR;
		else if CASE(INCRSAT) v = BGFX_STENCIL_OP_FAIL_S_INCRSAT;
		else if CASE(DECR) v = BGFX_STENCIL_OP_FAIL_S_DECR;
		else if CASE(DECRSAT) v = BGFX_STENCIL_OP_FAIL_S_DECRSAT;
		else if CASE(INVERT) v = BGFX_STENCIL_OP_FAIL_S_INVERT;
		else luaL_error(L, "Invalid stencil op arg %s", what);
	} while(0);
	if CASE(OP_FAIL_Z) {
		v <<= (BGFX_STENCIL_OP_FAIL_Z_SHIFT - BGFX_STENCIL_OP_FAIL_S_SHIFT);
	} else if CASE(OP_PASS_Z) {
		v <<= (BGFX_STENCIL_OP_PASS_Z_SHIFT - BGFX_STENCIL_OP_FAIL_S_SHIFT);
	} else if (!CASE(OP_FAIL_S)) {
		luaL_error(L, "Invalid stencil arg %s", what);
	}
	return v;
}

static int
lmakeStencil(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_pushnil(L);
	uint32_t stencil = 0;
	while (lua_next(L, 1) != 0) {
		stencil |= stencil_id(L);
		lua_pop(L, 1);
	}
	lua_pushinteger(L, stencil);
	return 1;
}

static int
lsetStencil(lua_State *L) {
	uint32_t fstencil = (uint32_t)luaL_optinteger(L, 1, BGFX_STENCIL_NONE);
	uint32_t bstencil = (uint32_t)luaL_optinteger(L, 2, BGFX_STENCIL_NONE);
	bgfx_set_stencil(fstencil, bstencil);
	return 0;
}

static int
lsetPaletteColor(lua_State *L) {
	int index = luaL_checkinteger(L, 1);
	int n = lua_gettop(L);
	float c[4];
	if (n == 2) {
		// integer
		uint32_t rgba = (uint32_t)luaL_checkinteger(L, 2);
		int i;
		for (i=3;i>=0;i--) {
			uint8_t v = rgba & 0xff;
			rgba >>= 8;
			c[i] = (float)v / 255.0f;
		}
	} else if (n == 5) {
		// r g b a
		int i;
		for (i=0;i<4;i++) {
			c[i] = luaL_checknumber(L, 2+i);
			if (c[i]<0 || c[i]>1) {
				return luaL_error(L, "Color %f should be in [0,1]", c[i]);
			}
		}
	} else {
		return luaL_error(L, "set_palette_color need 4 float color or 1 uint32");
	}
	bgfx_set_palette_color(index, c);
	return 0;
}

static int
lsetScissor(lua_State *L) {
	int x = luaL_checkinteger(L, 1);
	int y = luaL_checkinteger(L, 2);
	int w = luaL_checkinteger(L, 3);
	int h = luaL_checkinteger(L, 4);
	bgfx_set_scissor(x,y,w,h);
	return 0;
}

static int
lcreateOcclusionQuery(lua_State *L) {
	bgfx_occlusion_query_handle_t h = bgfx_create_occlusion_query();
	if (invalid_handle(h)) {
		return luaL_error(L, "create occlusion query failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(OCCLUSION_QUERY, h));
	return 1;
}

static int
lsetCondition(lua_State *L) {
	int oqid = BGFX_LUAHANDLE_ID(OCCLUSION_QUERY, luaL_checkinteger(L, 1));
	luaL_checktype(L, 2, LUA_TBOOLEAN);
	int visible = lua_toboolean(L, 2);
	bgfx_occlusion_query_handle_t handle = { oqid };
	bgfx_set_condition(handle, visible);
	return 0;
}

static int
lsubmitOcclusionQuery(lua_State *L) {
	int id = luaL_checkinteger(L, 1);
	int progid = BGFX_LUAHANDLE_ID(PROGRAM, luaL_checkinteger(L, 2));
	int oqid = BGFX_LUAHANDLE_ID(OCCLUSION_QUERY, luaL_checkinteger(L, 3));
	int depth = luaL_optinteger(L, 4, 0);
	int preserveState = lua_toboolean(L, 5);
	bgfx_program_handle_t ph = { progid };
	bgfx_occlusion_query_handle_t oqh = { oqid };
	bgfx_submit_occlusion_query(id, ph, oqh, depth, preserveState);
	return 0;
}

static int
lsubmitIndirect(lua_State *L) {
	int id = luaL_checkinteger(L, 1);
	int progid = BGFX_LUAHANDLE_ID(PROGRAM, luaL_checkinteger(L, 2));
	int iid = BGFX_LUAHANDLE_ID(INDIRECT_BUFFER, luaL_checkinteger(L, 3));
	uint16_t start = luaL_optinteger(L, 4, 0);
	uint16_t num = luaL_optinteger(L, 5, 1);
	int32_t depth = luaL_optinteger(L, 6, 0);
	bool preserveState = lua_toboolean(L, 7);
	bgfx_program_handle_t ph = { progid };
	bgfx_indirect_buffer_handle_t ih = { iid };

	bgfx_submit_indirect(id, ph, ih, start, num, depth, preserveState);
	return 0;
}

static int
lgetResult(lua_State *L) {
	int oqid = BGFX_LUAHANDLE_ID(OCCLUSION_QUERY, luaL_checkinteger(L, 1));
	int32_t num=0;
	bgfx_occlusion_query_handle_t oqh = { oqid };
	bgfx_occlusion_query_result_t r = bgfx_get_result(oqh, &num);
	switch (r) {
	case BGFX_OCCLUSION_QUERY_RESULT_INVISIBLE :
		lua_pushboolean(L, 0);
		break;
	case BGFX_OCCLUSION_QUERY_RESULT_VISIBLE :
		lua_pushboolean(L, 1);
		break;
	case BGFX_OCCLUSION_QUERY_RESULT_NORESULT:
		lua_pushnil(L);
		break;
	default:
		return luaL_error(L, "Invalid result %d", (int)r);
	}
	lua_pushinteger(L, num);
	return 2;
}

static int
lcreateIndirectBuffer(lua_State *L) {
	int num = luaL_checkinteger(L, 1);
	bgfx_indirect_buffer_handle_t h = bgfx_create_indirect_buffer(num);
	if (invalid_handle(h)) {
		return luaL_error(L, "create occlusion query failed");
	}
	lua_pushinteger(L, BGFX_LUAHANDLE(INDIRECT_BUFFER, h));
	return 1;
}

static bgfx_access_t
access_string(lua_State *L, const char * access) {
	bgfx_access_t a;
	if (access[0] == 'r') {
		a = BGFX_ACCESS_READ;
	} else if (access[0] == 'w') {
		a = BGFX_ACCESS_WRITE;
	} else {
		return luaL_error(L, "Invalid buffer access %s", access);
	}
	if (access[1] != 0) {
		if ((a == BGFX_ACCESS_READ && access[1] == 'w') || (a == BGFX_ACCESS_WRITE && access[1] == 'r'))
			a = BGFX_ACCESS_READWRITE;
		else
			luaL_error(L, "Invalid buffer access %s", access);
	}
	return a;
}

static int
lsetBuffer(lua_State *L) {
	int stage = luaL_checkinteger(L, 1);
	int idx = luaL_checkinteger(L, 2);
	int type = idx >> 16;
	int id = idx & 0xffff;
	const char * access = luaL_checkstring(L, 3);
	bgfx_access_t a = access_string(L, access);
	switch(type) {
	case BGFX_HANDLE_VERTEX_BUFFER: {
		bgfx_vertex_buffer_handle_t handle = { id };
		bgfx_set_compute_vertex_buffer(stage, handle, a);
		break;
	}
	case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: {
		bgfx_dynamic_vertex_buffer_handle_t handle = { id };
		bgfx_set_compute_dynamic_vertex_buffer(stage, handle, a);
		break;
	}
	case BGFX_HANDLE_INDEX_BUFFER: {
		bgfx_index_buffer_handle_t handle = { id };
		bgfx_set_compute_index_buffer(stage, handle, a);
		break;
	}
	case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32:
	case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER: {
		bgfx_dynamic_index_buffer_handle_t handle = { id };
		bgfx_set_compute_dynamic_index_buffer(stage, handle, a);
		break;
	}
	case BGFX_HANDLE_INDIRECT_BUFFER: {
		bgfx_indirect_buffer_handle_t handle = { id };
		bgfx_set_compute_indirect_buffer(stage, handle, a);
		break;
	}
	default:
		return luaL_error(L, "Invalid buffer type %d", type);
	}
	return 0;
}

static int
lsetInstanceDataBuffer(lua_State *L) {
	int idx = luaL_checkinteger(L, 1);
	int type = idx >> 16;
	int id = idx & 0xffff;
	uint32_t start = luaL_checkinteger(L, 2);
	uint32_t num = luaL_checkinteger(L, 3);
	switch(type) {
	case BGFX_HANDLE_VERTEX_BUFFER: {
		bgfx_vertex_buffer_handle_t handle = { id };
		bgfx_set_instance_data_from_vertex_buffer(handle, start, num);
		break;
	}
	case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: {
		bgfx_dynamic_vertex_buffer_handle_t handle = { id };
		bgfx_set_instance_data_from_dynamic_vertex_buffer(handle, start, num);
		break;
	}
	default:
		return luaL_error(L, "Invalid set instance data buffer %d", type);
	}
	return 0;
}

static uint8_t
dispatch_flags(lua_State *L, int index) {
	const char * f = lua_tostring(L, index);
	uint8_t flags = 0;
	int i;
	for (i=0;f[i];i++) {
		switch(f[i]) {
		case 'l':
			flags |= BGFX_SUBMIT_EYE_LEFT;
			break;
		case 'r':
			flags |= BGFX_SUBMIT_EYE_RIGHT;
			break;
		default:
			luaL_error(L, "Invalid dispatch flags %s", f);
			return 0;
		}
	}
	return flags;
}

static uint8_t
dispatch_opt(lua_State *L, int *num, int n, int index) {
	int top = lua_gettop(L);
	int i;
	uint8_t flags = BGFX_SUBMIT_EYE_FIRST;
	for (i=index;i<=top;i++) {
		int t = lua_type(L, i);
		int idx = i - index;
		switch(t) {
		case LUA_TNUMBER:
			if (idx >= n) {
				luaL_error(L, "Too many parm for dispatch");
				return 0;
			}
			num[i-index] = lua_tointeger(L, i);
			break;
		case LUA_TSTRING:
			if (i != top) {
				luaL_error(L, "flags should be last");
				return 0;
			}
			flags = dispatch_flags(L, i);
			break;
		default:
			luaL_error(L, "Invalid param type %s at %d", lua_typename(L, i), i);
			return 0;
		}
	}
	return flags;
}

static int
ldispatch(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	int pid = BGFX_LUAHANDLE_ID(PROGRAM, luaL_checkinteger(L, 2));
	int num[3] = {1,1,1};
	uint8_t flags = dispatch_opt(L, num, 3, 3);

	bgfx_program_handle_t  handle = { pid };

	bgfx_dispatch(viewid, handle, num[0], num[1], num[2], flags); 

	return 0;
}

static int
ldispatchIndirect(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	int pid = BGFX_LUAHANDLE_ID(PROGRAM, luaL_checkinteger(L, 2));
	int iid = BGFX_LUAHANDLE_ID(INDIRECT_BUFFER, luaL_checkinteger(L, 3));
	int num[2] = { 0, 1 };
	uint8_t flags = dispatch_opt(L, num, 2, 4);
	bgfx_program_handle_t  phandle = { pid };
	bgfx_indirect_buffer_handle_t  ihandle = { iid };

	bgfx_dispatch_indirect(viewid, phandle, ihandle, num[0], num[1], flags); 

	return 0;
}

static int
lgetShaderUniforms(lua_State *L) {
	int sid = BGFX_LUAHANDLE_ID(SHADER, luaL_checkinteger(L, 1));
	bgfx_shader_handle_t shader = { sid };
	uint16_t n = bgfx_get_shader_uniforms(shader, NULL, 0);
	lua_createtable(L, n, 0);
	bgfx_uniform_handle_t u[V(n)];
	bgfx_get_shader_uniforms(shader, u, n);
	int i;
	for (i=0;i<n;i++) {
		int id = BGFX_LUAHANDLE(UNIFORM, u[i]);
		lua_pushinteger(L, id);
		lua_rawseti(L, -2, i+1);
	}
	return 1;
}

static int
lsetViewMode(lua_State *L) {
	bgfx_view_id_t viewid = luaL_checkinteger(L, 1);
	if (lua_isnoneornil(L, 2)) {
		bgfx_set_view_mode(viewid, BGFX_VIEW_MODE_DEFAULT);
	} else {
		const char* mode = luaL_checkstring(L, 2);
		switch(mode[0]) {
		case 'd': bgfx_set_view_mode(viewid, BGFX_VIEW_MODE_DEPTH_ASCENDING); break;
		case 'D': bgfx_set_view_mode(viewid, BGFX_VIEW_MODE_DEPTH_DESCENDING); break;
		case 's': bgfx_set_view_mode(viewid, BGFX_VIEW_MODE_SEQUENTIAL); break;
		default:
			return luaL_error(L, "Invalid view mode %s", mode);
		}
	}
	return 0;
}

static int
lsetImage(lua_State *L) {
	int stage = luaL_checkinteger(L, 1);
	int tid = BGFX_LUAHANDLE_ID(TEXTURE, luaL_checkinteger(L, 2));
	bgfx_texture_handle_t handle = { tid };
	int mip = luaL_checkinteger(L, 3);
	bgfx_access_t access = access_string(L, luaL_checkstring(L, 4));
	bgfx_texture_format_t format = 0;
	if (lua_isnoneornil(L, 5)) {
		format = BGFX_TEXTURE_FORMAT_COUNT;
	} else {
		format = texture_format_from_string(L, 5);
	}
	bgfx_set_image(stage, handle, mip, access, format);
	return 0;
}

static int
lrequestScreenshot(lua_State *L) {
	bgfx_frame_buffer_handle_t handle = { UINT16_MAX };	// Invalid handle (main window)
	if (lua_type(L,1) == LUA_TNUMBER) {
		int id = BGFX_LUAHANDLE_ID(FRAME_BUFFER, luaL_checkinteger(L, 1));
		handle.idx = id;
	}
	const char * file = luaL_optstring(L, 2, "");
	bgfx_request_screen_shot(handle, file);
	return 0;
}

static int
lgetScreenshot(lua_State *L) {
	int memptr = lua_toboolean(L, 1);
	if (lua_getfield(L, LUA_REGISTRYINDEX, "bgfx_cb") != LUA_TUSERDATA) {
		return luaL_error(L, "init first");
	}
	struct callback *cb = lua_touserdata(L, -1);
	struct screenshot * s = ss_pop(&cb->ss);
	if (s == NULL)
		return 0;
	lua_pushstring(L, s->name);
	lua_pushinteger(L, s->width);
	lua_pushinteger(L, s->height);
	lua_pushinteger(L, s->pitch);
	if (memptr) {
		lua_pushlightuserdata(L, s->data);
		lua_pushinteger(L, s->size);
		s->data = NULL;
	} else {
		lua_pushlstring(L, (const char *)s->data, s->size);
	}
	ss_free(s);
	return memptr ? 6 : 5;
}

LUAMOD_API int
luaopen_bgfx(lua_State *L) {
	luaL_checkversion(L);
	int tfn = sizeof(c_texture_formats) / sizeof(c_texture_formats[0]);
	lua_createtable(L, 0, tfn);
	int i;
	for (i=0;i<tfn;i++) {
		lua_pushstring(L, c_texture_formats[i]);
		lua_pushinteger(L, i);
		lua_settable(L, -3);
	}
	lua_setfield(L, LUA_REGISTRYINDEX, "BGFX_TF");
	luaL_Reg l[] = {
		{ "set_platform_data", lsetPlatformData },
		{ "init", linit },
		{ "get_caps", lgetCaps },
		{ "get_stats", lgetStats },
		{ "reset", lreset },
		{ "shutdown", lshutdown },
		{ "set_view_clear", lsetViewClear },
		{ "set_view_clear_mrt", lsetViewClearMRT },
		{ "set_view_rect", lsetViewRect },
		{ "set_view_transform", lsetViewTransform },
		{ "set_view_order", lsetViewOrder },
		{ "set_view_name", lsetViewName },
		{ "set_view_frame_buffer", lsetViewFrameBuffer },
		{ "touch", ltouch },
		{ "set_debug", lsetDebug },
		{ "frame", lframe },
		{ "create_shader", lcreateShader },
		{ "create_program", lcreateProgram },
		{ "submit", lsubmit },
		{ "make_state", lmakeState },
		{ "set_state", lsetState },
		{ "vertex_decl", lnewVertexDecl },
		{ "create_vertex_buffer", lcreateVertexBuffer },
		{ "create_dynamic_vertex_buffer", lcreateDynamicVertexBuffer },
		{ "create_index_buffer", lcreateIndexBuffer },
		{ "create_dynamic_index_buffer", lcreateDynamicIndexBuffer },
		{ "create_index_buffer_compress", lcreateIndexBufferCompress },
		{ "set_vertex_buffer", lsetVertexBuffer },
		{ "set_index_buffer", lsetIndexBuffer },
		{ "destroy", ldestroy },
		{ "set_transform", lsetTransform },
		{ "dbg_text_clear", ldbgTextClear },
		{ "dbg_text_print", ldbgTextPrint },
		{ "dbg_text_image", ldbgTextImage },
		{ "transient_buffer", lnewTransientBuffer },
		{ "create_uniform", lcreateUniform },
		{ "get_uniform_info", lgetUniformInfo },
		{ "set_uniform", lsetUniform },
		{ "instance_buffer", lnewInstanceBuffer },
		{ "memory_texture", lmemoryTexture },
		{ "create_texture", lcreateTexture },	// create texture from data string (DDS, KTX or PVR texture data)
		{ "create_texture2d", lcreateTexture2D },
		{ "update_texture2d", lupdateTexture2D },
		{ "is_texture_valid", lisTextureValid },
		{ "set_texture", lsetTexture },
		{ "set_name", lsetName },
		{ "create_frame_buffer", lcreateFrameBuffer },
		{ "get_texture", lgetTexture },
		{ "read_texture", lreadTexture },
		{ "blit", lblit },
		{ "make_stencil", lmakeStencil },
		{ "set_stencil", lsetStencil },
		{ "set_palette_color", lsetPaletteColor },
		{ "set_scissor", lsetScissor },
		{ "create_occlusion_query", lcreateOcclusionQuery },
		{ "set_condition", lsetCondition },
		{ "submit_occlusion_query", lsubmitOcclusionQuery },
		{ "get_result", lgetResult },
		{ "create_indirect_buffer", lcreateIndirectBuffer },
		{ "set_buffer", lsetBuffer },
		{ "dispatch", ldispatch },
		{ "dispatch_indirect", ldispatchIndirect },
		{ "set_instance_data_buffer", lsetInstanceDataBuffer },
		{ "submit_indirect", lsubmitIndirect },
		{ "update", lupdate },
		{ "get_shader_uniforms", lgetShaderUniforms },
		{ "set_view_mode", lsetViewMode },
		{ "set_image", lsetImage },
		{ "request_screenshot", lrequestScreenshot },
		{ "get_screenshot", lgetScreenshot },
		{ "export_vertex_decl", lexportVertexDecl },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
