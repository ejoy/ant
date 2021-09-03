#define LUA_LIB 1
#include <lua.hpp>

#include <cstring>

#define LIGHTMAPPER_IMPLEMENTATION
#include "lightmapper.h"

#include "lua2struct.h"
#include "luabgfx.h"
#include "bgfx/c99/bgfx.h"

#include "glm/glm.hpp"

struct context{
    lm_context *lm_ctx;
    int size;
    float z_near, z_far;
    int interp_pass_count;
    float interp_threshold;
    float cam2surf_dis_modifier;
};

LUA2STRUCT(context, size, z_near, z_far, interp_pass_count, interp_threshold, cam2surf_dis_modifier);

struct lightmap{
    float* data;
    int width;
    int height;
    int channels;
    int sizebytes() const { return width * height * channels * sizeof(float);}
};

LUA2STRUCT(lightmap, width, height, channels);

struct geometry{
    const float* worldmat;
    int num;
    struct attrib{
        union {
            const struct memory* m;
            const void *nd;
        };
        
        const void* data() const {
            return (const uint8_t*)(native ? nd : m->data) + offset;
        };
        int offset;
        int stride;
        lm_type type;
        bool native;
    };
    attrib pos;
    attrib normal;
    attrib uv;

    attrib index;
};

namespace lua_struct{
    template <>
    inline void unpack<geometry::attrib>(lua_State* L, int idx, geometry::attrib& v, void*) {
        luaL_checktype(L, idx, LUA_TTABLE);
        lua_getfield(L, idx, "native");
        v.native = lua_toboolean(L, -1);
        lua_pop(L, 1);
        const auto datatype = lua_getfield(L, idx, "memory");
        if (v.native){
            v.nd = lua_touserdata(L, -1);
        } else {
            v.m = (const struct memory*)luaL_testudata(L, -1, "BGFX_MEMORY");
        }
        
        lua_pop(L, 1);

        unpack_field(L, idx, "offset", v.offset);
        unpack_field(L, idx, "stride", v.stride);

        lua_getfield(L, idx, "type");
        auto s = lua_tostring(L, -1);
        switch (s[0]){
            case 'B': v.type = LM_UNSIGNED_BYTE; break;
            case 'H': v.type = LM_UNSIGNED_SHORT; break;
            case 'I': v.type = LM_UNSIGNED_INT; break;
            case 'f': v.type = LM_FLOAT; break;
            case '\0':v.type = LM_NONE; break;
            default: luaL_error(L, "invalid data type:%s", s);
        }
        lua_pop(L, 1);
    }

    template<>
    inline void unpack<geometry>(lua_State* L, int idx, geometry& g, void*){
        unpack_field(L, idx, "num", g.num);
        unpack_field(L, idx, "worldmat", g.worldmat);
        unpack_field(L, idx, "pos", g.pos);
        if (LUA_TTABLE == lua_getfield(L, idx, "normal")){
            unpack(L, -1, g.normal);
        } else {
            g.normal.type = LM_NONE;
        }
        lua_pop(L, 1);

        unpack_field(L, idx, "uv", g.uv);

        auto t = lua_getfield(L, idx, "index");
        lua_pop(L, 1);

        if (t == LUA_TTABLE){
            unpack_field(L, idx, "index", g.index);
        }else{
            g.index.type = LM_NONE;
            g.index.m = nullptr;
            g.index.stride = 0;
            g.index.offset = 0;
        }
    }
}

//TODO: we should remove all render relate code from lightmapper.h
struct shadinginfo{
    struct viewid_range{
        bgfx_view_id_t base;
        uint16_t count;
    } viewids;
    
    uint16_t storage_viewid;
    struct downsampleT{
        uint16_t prog;
        uint16_t hemispheres;
    };

    struct weight_downsampleT : public downsampleT{
        uint16_t weights;
    };

    weight_downsampleT weight_downsample;
    downsampleT downsample;
};

LUA2STRUCT(shadinginfo::weight_downsampleT, prog, hemispheres, weights);
LUA2STRUCT(shadinginfo::downsampleT, prog, hemispheres);
LUA2STRUCT(shadinginfo::viewid_range, base, count);
LUA2STRUCT(shadinginfo, viewids, storage_viewid, weight_downsample, downsample);

static inline context*
tocontext(lua_State *L, int index=1){
    return (context*)luaL_checkudata(L, index, "LM_CONTEXT_MT");
}

static int
lcontext_gc_check(lua_State *L){
    auto ctx = tocontext(L);
    if (ctx->lm_ctx){
        luaL_error(L, "lightmap context should call 'destroy' to release context");
    }
    return 0;
}

static int
lcontext_destroy(lua_State *L){
    auto ctx = tocontext(L);
    if (ctx->lm_ctx){
        lmDestroy(ctx->lm_ctx);
    }
    return 0;
}

static int
lcontext_find_sample(lua_State *L){
    auto ctx = tocontext(L, 1);
    uint32_t triangleidx = (uint32_t)luaL_checkinteger(L, 2);

    auto lmctx = ctx->lm_ctx;
    lmctx->meshPosition.triangle.baseIndex = triangleidx;
    
    for(lm_initMeshRasterizerPosition(lmctx);
		!lm_hasConservativeTriangleRasterizerFinished(lmctx->meshPosition);
		lm_moveToNextPotentialConservativeTriangleRasterizerPosition(lmctx->meshPosition))
	{
		if (lm_trySamplingConservativeTriangleRasterizerPosition(
            lmctx->meshPosition,
            lmctx->lightmap,
            lmctx->hemisphere,
            lmctx->interpolationThreshold))
			break;
    }
    
    const auto& sample = lmctx->meshPosition.sample;
    lua_createtable(L, 3, 0);
    for(int ii=0; ii<3; ++ii){
        const float *v = &sample.position.x;
        lua_pushnumber(L, v[ii]);
        lua_seti(L, -2, ii+1);
    }

    lua_createtable(L, 3, 0);
    for(int ii=0; ii<3; ++ii){
        const float *v = &sample.direction.x;
        lua_pushnumber(L, v[ii]);
        lua_seti(L, -2, ii+1);
    }

    lua_createtable(L, 3, 0);
    for(int ii=0; ii<3; ++ii){
        const float *v = &sample.up.x;
        lua_pushnumber(L, v[ii]);
        lua_seti(L, -2, ii+1);
    }
    return 3;
}

static int lcontext_set_target_lightmap(lua_State *L);

static int
lcontext_set_geometry(lua_State *L){
    auto ctx = tocontext(L, 1);
    geometry g;
    lua_struct::unpack(L, 2, g);

    lmSetGeometry(ctx->lm_ctx, g.worldmat, 
        g.pos.type, g.pos.data(), g.pos.stride,
        g.normal.type, g.normal.data(),
        g.normal.stride, g.uv.type, g.uv.data(), g.uv.stride,
        g.num, g.index.type, g.index.data());
    return 0;
}

static inline lua_State* toL(lm_context*ctx) {return (lua_State*)ctx->render.userdata;}
static inline void 
load_call_cb_func(lua_State *L, int index, const char* name){
    if (lua_type(L, index) != LUA_TTABLE){
        luaL_error(L, "arg:%d, must be a table with callback function", index);
    }
    auto t = lua_getfield(L, index, name);
    if (t != LUA_TFUNCTION){
        luaL_error(L, "not found call back function: %s", name);
    }
}
static void
cb_init_buffer(lm_context *ctx){
    auto L = toL(ctx);
    load_call_cb_func(L, 2, "init_buffer");
    lua_call(L, 0, 0);
}

static void
cb_render_scene(lm_context *ctx, int *vp, float *view, float *proj){
    auto L = toL(ctx);

    auto pusharray = [L](auto v, int n){
        lua_createtable(L, n, 0);
        for(int ii=0; ii<n; ++ii){
            lua_pushnumber(L, float(v[ii]));
            lua_seti(L, -2, ii+1);
        }
    };

    load_call_cb_func(L, 2, "render_scene");
    pusharray(vp, 4);
    pusharray(view, 16);
    pusharray(proj, 16);
    lua_call(L, 3, 0);
}

static void
cb_downsample(lm_context *ctx){
    auto L= toL(ctx);
    load_call_cb_func(L, 2, "downsample");
    lua_pushinteger(L, ctx->hemisphere.size);
    lua_pushinteger(L, ctx->hemisphere.storage.writePosition.x);
    lua_pushinteger(L, ctx->hemisphere.storage.writePosition.y);
    lua_call(L, 3, 0);
}

static float*
cb_read_lightmap(lm_context *ctx, int size){
    auto L = toL(ctx);
    load_call_cb_func(L, 2, "read_lightmap");
    lua_pushinteger(L, size);
    lua_call(L, 1, 1);
    auto m = (struct memory*)luaL_checkudata(L, -1, "BGFX_MEMORY");
    return (float*)m->data;
}

static void
cb_process(lm_context *ctx){
    auto L = toL(ctx);
    load_call_cb_func(L, 2, "process");
    lua_pushnumber(L, lmProgress(ctx));
    lua_call(L, 1, 0);
}

static int
lcontext_process(lua_State *L){
    lua_pushnumber(L, lmProgress(tocontext(L, 1)->lm_ctx));
    return 1;
}

static int
lcontext_bake(lua_State *L){
    auto ctx = tocontext(L, 1);
    ctx->lm_ctx->render.init_buffer     = cb_init_buffer;
    ctx->lm_ctx->render.render_scene    = cb_render_scene;
    ctx->lm_ctx->render.downsample      = cb_downsample;
    ctx->lm_ctx->render.read_lightmap   = cb_read_lightmap;
    ctx->lm_ctx->render.process         = cb_process;
    ctx->lm_ctx->render.userdata        = L;
    lmBake(ctx->lm_ctx);
    return 0;
}

static int
lcontext_pass_count(lua_State *L){
    auto ctx = tocontext(L, 1);
    lua_pushinteger(L, ctx->lm_ctx->meshPosition.passCount);
    return 1;
}

static int
lcontext_hemi_count(lua_State *L){
    auto ctx = tocontext(L, 1);
    int hemix, hemiy;
    lmHemiCount(ctx->lm_ctx->hemisphere.size, &hemix, &hemiy);
    lua_pushinteger(L, hemix);
    lua_pushinteger(L, hemiy);
    return 2;
}

static int
lcontext_fetch_samples(lua_State *L){
    auto ctx = tocontext(L, 1);
    auto pass = (int)luaL_checkinteger(L, 2);
    if (pass < 1 || pass > ctx->lm_ctx->meshPosition.passCount){
        luaL_error(L, "invalid 'pass': %d, pass count:%d", pass, ctx->lm_ctx->meshPosition.passCount);
    }
    lmSamplePositions(ctx->lm_ctx, pass-1);
    lua_pushinteger(L, ctx->lm_ctx->samples.size());
    return 1;
}

struct sample_param{
    uint16_t x, y;
    uint16_t hemisize, side;
    float znear, zfar;
    uint32_t sampleidx;
};

LUA2STRUCT(sample_param, x, y, hemisize, side, znear, zfar, sampleidx);

static int
lcontext_sample_hemisphere(lua_State *L){
    auto ctx = tocontext(L, 1);
    int x, y;
    lua_struct::unpack(L, 2, x);
    lua_struct::unpack(L, 3, y);
    int hemisize, side;
    lua_struct::unpack(L, 4, hemisize);
    lua_struct::unpack(L, 5, side);
    float znear, zfar;
    lua_struct::unpack(L, 6, znear);
    lua_struct::unpack(L, 7, zfar);
    uint32_t sampleidx;
    lua_struct::unpack(L, 8, sampleidx);
    if (sampleidx > ctx->lm_ctx->samples.size()){
        luaL_error(L, "invalid sample index:%d", sampleidx);
    }
    --sampleidx;
    const auto& sp = ctx->lm_ctx->samples[sampleidx];
    int vp[4];
    float viewmat[16], projmat[16];
    lm_sampleHemisphere(x, y, hemisize, side-1, znear, zfar, sp.sample.position, sp.sample.direction, sp.sample.up, vp, viewmat, projmat);

    auto create_table = [L](auto v, int n){
        lua_createtable(L, n, 0);
        for (int ii=0; ii<n; ++ii){
            lua_pushnumber(L, float(v[ii]));
            lua_seti(L, -2, ii+1);
        }
    };
    create_table(vp, 4);
    create_table(viewmat, 16);
    create_table(projmat, 16);
    return 3;
}

static inline lightmap*
tolm(lua_State *L, int index){
    return (lightmap*)luaL_checkudata(L, index, "LIGHTMAP_MT");
}

static int
lcontext_write2lightmap(lua_State *L){
    auto ctx = tocontext(L, 1);
    auto m = (struct memory*)luaL_checkudata(L, 2, "BGFX_MEMORY");
    auto lm = tolm(L, 3);
    auto hemix = luaL_checkinteger(L, 4);
    auto hemiy = luaL_checkinteger(L, 5);
    auto storage_nx = luaL_checkinteger(L, 6);
    auto storage_ny = luaL_checkinteger(L, 7);

    auto w = hemix * storage_nx;

    auto hemicount = hemix * hemiy;
    const auto &samples = ctx->lm_ctx->samples;
    for (size_t sampleidx=0; sampleidx<samples.size(); ++sampleidx){
        auto s = samples[sampleidx];
        auto storage_idx = sampleidx / hemicount;
        auto storage_x = storage_idx % storage_nx;
        auto storage_y = storage_idx / storage_nx;

        auto hemiidx = sampleidx-storage_idx*hemicount;
        auto local_hx = hemiidx % hemix;
        auto local_hy = hemiidx / hemiy;

        auto mem_idx = (local_hy + storage_y * hemiy) * w + (local_hx + storage_x * hemix);

        if (mem_idx * 16 >= m->size){
            luaL_error(L, "invalid index, sampleidx:%d, storage:{nx=%d, ny=%d, x=%d, y=%d}, mem_idx=%d", 
            sampleidx, storage_nx, storage_ny, storage_x, storage_y, mem_idx);
        }

        const glm::vec4 &c = *((glm::vec4 *)m->data + mem_idx);
        const float validity = c[3];
        float *lmdata = (float*)lm->data +  (s.pos.y * lm->width + s.pos.x) * lm->channels;
        if (!lmdata[0] && validity > 0.9)
        {
            float scale = 1.0f / validity;
            switch (lm->channels)
            {
            case 1:
                lmdata[0] = lm_maxf((c[0] + c[1] + c[2]) * scale / 3.0f, FLT_MIN);
                break;
            case 2:
                lmdata[0] = lm_maxf((c[0] + c[1] + c[2]) * scale / 3.0f, FLT_MIN);
                lmdata[1] = 1.0f; // do we want to support this format?
                break;
            case 3:
                lmdata[0] = lm_maxf(c[0] * scale, FLT_MIN);
                lmdata[1] = lm_maxf(c[1] * scale, FLT_MIN);
                lmdata[2] = lm_maxf(c[2] * scale, FLT_MIN);
                break;
            case 4:
                lmdata[0] = lm_maxf(c[0] * scale, FLT_MIN);
                lmdata[1] = lm_maxf(c[1] * scale, FLT_MIN);
                lmdata[2] = lm_maxf(c[2] * scale, FLT_MIN);
                lmdata[3] = 1.0f;
                break;
            default:
                assert(LM_FALSE);
                break;
            }

#ifdef LM_DEBUG_INTERPOLATION
            // set sampled pixel to red in debug output
            lm->debug[(s.pos.y * lm->width + s.pos.x) * 3 + 0] = 255;
#endif
        }
        
    }
    return 0;
}

static void
register_lm_context_mt(lua_State *L){
    if (luaL_newmetatable(L, "LM_CONTEXT_MT")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");

        luaL_Reg l[] = {
            {"__gc",                lcontext_gc_check},
            {"destroy",             lcontext_destroy},
            {"set_target_lightmap", lcontext_set_target_lightmap},
            {"set_geometry",        lcontext_set_geometry},
            {"hemi_count",          lcontext_hemi_count},
            {"bake",                lcontext_bake},
            {"pass_count",          lcontext_pass_count},
            {"fetch_samples",       lcontext_fetch_samples},
            {"sample_hemisphere",   lcontext_sample_hemisphere},
            {"write2lightmap",      lcontext_write2lightmap},
            {"process",             lcontext_process},
            {"find_sample",         lcontext_find_sample},
            {nullptr,               nullptr},
        };

        luaL_setfuncs(L, l, 0);
    }
}

static int
llightmap_create_context(lua_State *L){
    auto ctx = (context*)lua_newuserdata(L, sizeof(context));
    if (LUA_TTABLE != luaL_getmetatable(L, "LM_CONTEXT_MT")){
        return luaL_error(L, "LM_CONTEXT_MT not register");
    }
    lua_setmetatable(L, -2);

    lua_struct::unpack(L, 1, *ctx);
    ctx->lm_ctx = lmCreate(ctx->size, ctx->z_near, ctx->z_far,
        ctx->interp_pass_count, ctx->interp_threshold, 
        ctx->cam2surf_dis_modifier);
    return 1;
}

static int
llm_destroy(lua_State *L){
    auto lm = tolm(L, 1);
    delete[] lm->data;
    return 0;
}

static int
llm_postprocess(lua_State *L){
    auto lm = tolm(L, 1);
    auto dilate_times = (int)luaL_optinteger(L, 2, 16);
    auto gamma_correct = lua_isnoneornil(L, 3) ? true : lua_toboolean(L, 3);
    // postprocess texture
	float *temp = new float[lm->sizebytes()];
    float *data = lm->data;
	for (int i = 0; i < dilate_times; i++)
	{
		lmImageDilate(data, temp, lm->width, lm->height, lm->channels);
		lmImageDilate(temp, data, lm->width, lm->height, lm->channels);
	}
	lmImageSmooth(data, temp, lm->width, lm->height, lm->channels);
	lmImageDilate(temp, data, lm->width, lm->height, lm->channels);
    if (gamma_correct){
        lmImagePower(data, lm->width, lm->height, lm->channels, 1.0f / 2.2f, 0x7); // gamma correct color channels
    }
	
	delete[] temp;
    return 0;
}

static int
llm_tostring(lua_State *L){
    auto lm = tolm(L, 1);
    const auto size = lm->sizebytes();
    lua_pushlstring(L, (const char*)lm->data, size);
    lua_pushinteger(L, size);
    return 2;
}
#ifdef _DEBUG
static int
llm_save(lua_State *L){
    auto lm = tolm(L, 1);
    auto fn = lua_tostring(L, 2);
    lmImageSaveTGAf(fn, lm->data, lm->width, lm->height, lm->channels, 1.0f);
    return 0;
}
#endif 
static int
llm_data(lua_State *L){
    auto lm = tolm(L, 1);
    lua_pushlightuserdata(L, lm->data);
    return 1;
}
static int
lcontext_set_target_lightmap(lua_State *L){
    auto ctx = tocontext(L, 1);
    lightmap *lm = (lightmap*)lua_newuserdata(L, sizeof(lightmap));
    lua_struct::unpack(L, 2, *lm);

    if (luaL_newmetatable(L, "LIGHTMAP_MT")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");

        luaL_Reg l[] = {
            {"__gc", llm_destroy},
            {"postprocess", llm_postprocess},
            {"tostring", llm_tostring},
            {"data", llm_data},
#ifdef _DEBUG
            {"save", llm_save},
#endif
            {nullptr, nullptr},
        };

        luaL_setfuncs(L, l, 0);
    }
    lua_setmetatable(L, -2);

    lm->data = new float[lm->sizebytes()];
    memset(lm->data, 0, lm->sizebytes());
    lmSetTargetLightmap(ctx->lm_ctx, lm->data, lm->width, lm->height, lm->channels);
    return 1;
}

static int
llightmap_context(lua_State *L){
    luaL_getmetatable(L, "LM_CONTEXT_MT");
    return 1;
}

#ifdef _DEBUG
static int
llightmap_read_obj(lua_State *L){
    //static int loadSimpleObjFile(const char *filename, vertex_t **vertices, unsigned int *vertexCount, unsigned short **indices, unsigned int *indexCount)
    const char* filename = luaL_checkstring(L, 1);
	FILE *file = fopen(filename, "rt");
	if (!file)
		return 0;
	char line[1024];

	// first pass
	unsigned int np = 0, nn = 0, nt = 0, nf = 0;
	while (!feof(file))
	{
		fgets(line, 1024, file);
		if (line[0] == '#') continue;
		if (line[0] == 'v')
		{
			if (line[1] == ' ') { np++; continue; }
			if (line[1] == 'n') { nn++; continue; }
			if (line[1] == 't') { nt++; continue; }
			assert(!"unknown vertex attribute");
		}
		if (line[0] == 'f') { nf++; continue; }
		assert(!"unknown identifier");
	}
	assert(np && np == nn && np == nt && nf); // only supports obj files without separately indexed vertex attributes

	// allocate memory
	int vertexCount = np;

    float *p = (float*)lua_newuserdata(L, np * sizeof(float) * 3);
	float *n = (float*)lua_newuserdata(L, np * sizeof(float) * 3);
    float *t = (float*)lua_newuserdata(L, np * sizeof(float) * 2);

    lua_pushinteger(L, vertexCount);
	int indexCount = nf * 3;
	uint16_t *indices = (uint16_t*)lua_newuserdata(L, indexCount * sizeof(uint16_t));
    lua_pushinteger(L, indexCount);

	// second pass
	fseek(file, 0, SEEK_SET);
	unsigned int cp = 0, cn = 0, ct = 0, cf = 0;
	while (!feof(file))
	{
		fgets(line, 1024, file);
		if (line[0] == '#') continue;
		if (line[0] == 'v')
		{
			if (line[1] == ' ') { float *pp = p+(cp++*3);char *e1, *e2; pp[0] = (float)strtod(line + 2, &e1); pp[1] = (float)strtod(e1, &e2); pp[2] = (float)strtod(e2, 0); continue; }
			if (line[1] == 'n') { /*float *n = (*vertices)[cn++].n; char *e1, *e2; n[0] = (float)strtod(line + 3, &e1); n[1] = (float)strtod(e1, &e2); n[2] = (float)strtod(e2, 0);*/ continue; } // no normals needed
			if (line[1] == 't') { float *tt = t+(ct++*2);char *e1;      tt[0] = (float)strtod(line + 3, &e1); tt[1] = (float)strtod(e1, 0);                                continue; }
			assert(!"unknown vertex attribute");
		}
		if (line[0] == 'f')
		{
			unsigned short *tri = indices + cf;
			cf += 3;
			char *e1, *e2, *e3 = line + 1;
			for (int i = 0; i < 3; i++)
			{
				unsigned long pi = strtoul(e3 + 1, &e1, 10);
				assert(e1[0] == '/');
				unsigned long ti = strtoul(e1 + 1, &e2, 10);
				assert(e2[0] == '/');
				unsigned long ni = strtoul(e2 + 1, &e3, 10);
				assert(pi == ti && pi == ni);
				tri[i] = (unsigned short)(pi - 1);
			}
			continue;
		}
		assert(!"unknown identifier");
	}

	fclose(file);
	return 6;
}
#endif //_DEBUG

static int
llightmap_framebuffer_size(lua_State *L){
    int w = 0, h = 0;
    lmFramebufferSize(&w, &h);
    lua_pushinteger(L, w);
    lua_pushinteger(L, h);
    lua_pushinteger(L, HEMI_FRAMEBUFFER_UNIT_SIZE);
    return 3;
}

static int
llightmap_hemi_count(lua_State *L){
    int X, Y;
    int size = (int)luaL_checkinteger(L, 1);
    lmHemiCount(size, &X, &Y);
    lua_pushinteger(L, X);
    lua_pushinteger(L, Y);
    return 2;
}

#ifdef _DEBUG
static int
llightmap_save_tga(lua_State *L){
    auto fn = luaL_checkstring(L, 1);
    auto m = (struct memory*)luaL_checkudata(L, 2, "BGFX_MEMORY");
    auto w = (int)luaL_checkinteger(L, 3);
    auto h = (int)luaL_checkinteger(L, 4);
    auto c = (int)luaL_checkinteger(L, 5);
    if (w*h*c*sizeof(float) != m->size){
        luaL_error(L, "memory size not equal to w * h * c * sizeof(float)");
    }
    lmImageSaveTGAf(fn, (float*)m->data, w, h, c);
    return 0;
}
#endif //_DEBUG


static int 
llightmap_set_view(lua_State *L){
    int x = (int)luaL_checkinteger(L, 1);
    int y = (int)luaL_checkinteger(L, 2);
    int size = (int)luaL_checkinteger(L, 3);
    int side = (int)luaL_checkinteger(L, 4);
    float zNear = (float)luaL_checknumber(L, 5);
    float zFar = (float)luaL_checknumber(L, 6);

    const lm_vec3* pos =(lm_vec3*)lua_touserdata(L, 7);
    const lm_vec3* dir =(lm_vec3*)lua_touserdata(L, 8);
    const lm_vec3* up = (lm_vec3*)lua_touserdata(L, 9);

    // glm::vec3 right = glm::cross(up, dir);
    // glm::vec3 nright = -right;
    // glm::vec3 ndir = -dir;
    // glm::vec3 nup = -up;
    //#define P(_V) *(lm_vec3*)(&(_V.x))

    int vp[4];
    float view[16], proj[16];
    lm_sampleHemisphere(x, y, size, side, zNear, zFar, *pos, *dir, *up, vp, view, proj);

    lua_createtable(L, 4, 0);
    for (int ii=0; ii<4; ++ii){
        lua_pushnumber(L, (float)vp[ii]);
        lua_seti(L, -2, ii+1);
    }

    lua_createtable(L, 16, 0);
    for (int ii=0; ii<16; ++ii){
        lua_pushnumber(L, view[ii]);
        lua_seti(L, -2, ii+1);
    }

    lua_createtable(L, 16, 0);
    for (int ii=0; ii<16; ++ii){
        lua_pushnumber(L, proj[ii]);
        lua_seti(L, -2, ii+1);
    }
    return 3;
}

extern "C"{
LUAMOD_API int
luaopen_bake_radiosity(lua_State* L) {
    register_lm_context_mt(L);
    luaL_Reg lib[] = {
        { "create_lightmap_context", llightmap_create_context},
        { "context_metatable", llightmap_context},
        {"framebuffer_size", llightmap_framebuffer_size},
        {"hemi_count", llightmap_hemi_count},
        #ifdef _DEBUG
        {"read_obj", llightmap_read_obj},
        {"save_tga", llightmap_save_tga},
        #endif 
        {"set_view", llightmap_set_view},
        { nullptr, nullptr },
    };
    luaL_newlib(L, lib);
    return 1;
}
}