#include <lua.hpp>
#include <cassert>
#include <cstring>

#include <bgfx/c99/bgfx.h>

#include "efk_fileinterface.h"

#include "efkbgfx/renderer/bgfxrenderer.h"
#include "../../clibs/bgfx/bgfx_interface.h"
#include "../../clibs/fileinterface/fileinterface.h"
#include <Effekseer/Effekseer.DefaultEffectLoader.h>

extern "C" {
    #include <textureman.h>
}

struct efk_instance {
	Effekseer::EffectRef eptr;
	Effekseer::Handle inst;
	union {
		int next;
		int n;
	};
	bool shown;
	std::vector<Effekseer::Handle> clone;
};

class efk_ctx {
public:
    efk_ctx() = default;
    ~efk_ctx() = default;

    EffekseerRenderer::RendererRef renderer;
    Effekseer::ManagerRef manager;
    struct file_interface *fi;
	
	int freelist = -1;
    std::vector<efk_instance>   effects;
};

static efk_ctx*
EC(lua_State *L){
    return (efk_ctx*)lua_touserdata(L, 1);
}

static inline Effekseer::Matrix44*
TOM(lua_State *L, int index){
    const int t = lua_type(L, index);
    if (t == LUA_TUSERDATA || t == LUA_TLIGHTUSERDATA){
        return (Effekseer::Matrix44*)lua_touserdata(L, index);
    }

    if (t == LUA_TSTRING){
        return (Effekseer::Matrix44*)lua_tostring(L, index);
    }

    luaL_error(L, "Invalid data:%d, type:%s", index, lua_typename(L, index));

    return nullptr;
}

static int
lefkctx_render(lua_State *L){
    auto ctx = EC(L);
    auto viewmat = TOM(L, 2);
    auto projmat = TOM(L, 3);
    auto delta = (float)luaL_checknumber(L, 4) * 0.001f;

    ctx->renderer->SetCameraMatrix(*viewmat);
    ctx->renderer->SetProjectionMatrix(*projmat);
	// Stabilize in a variable frame environment
	// float deltaFrames = delta * 60.0f;
	// int iterations = std::max(1, (int)roundf(deltaFrames));
	// float advance = deltaFrames / iterations;
	// for (int i = 0; i < iterations; i++) {
    //     ctx->manager->Update(advance);
	// }
    ctx->manager->Update();
    ctx->renderer->SetTime(ctx->renderer->GetTime() + delta);
    ctx->renderer->BeginRendering();
    Effekseer::Manager::DrawParameter drawParameter;
    drawParameter.ZNear = 0.0f;
    drawParameter.ZFar = 1.0f;
    drawParameter.ViewProjectionMatrix = ctx->renderer->GetCameraProjectionMatrix();
    ctx->manager->Draw(drawParameter);
    ctx->renderer->EndRendering();

	// set invisible
	for (auto &slot : ctx->effects) {
		if (slot.eptr != nullptr) {
			ctx->manager->SetShown(slot.inst, false);
			if (slot.n == 0) {
				for (auto handle : slot.clone) {
					ctx->manager->StopEffect(handle);
				}
				slot.clone.resize(0);
			} else {
				for (auto handle : slot.clone) {
					ctx->manager->SetShown(handle, false);
				}
				slot.n = 0;
			}
		}
	}
    return 0;
}

static int
lefkctx_create(lua_State *L) {
    auto ctx = EC(L);
    auto filename = luaL_checkstring(L, 2);
    const float mag = (float)luaL_optnumber(L, 3, 1.f);
    char16_t u16_filename[1024];
    Effekseer::ConvertUtf8ToUtf16(u16_filename, 1024, filename);
    auto eff = Effekseer::Effect::Create(ctx->manager, u16_filename, mag);
    if (eff == nullptr){
        return luaL_error(L, "create effect failed, filename:%s", filename);
    }

	int handle;

	if (ctx->freelist >= 0) {
		auto slot = &ctx->effects[ctx->freelist];
		handle = ctx->freelist;
		ctx->freelist = slot->next;
	} else {
		handle = (int)ctx->effects.size();
		ctx->effects.resize(handle + 1);
	}


	struct efk_instance * slot = &ctx->effects[handle];
	slot->eptr = eff;
	slot->inst = -1;
	slot->n = 0;
	slot->shown = true;
	lua_pushinteger(L, handle);
    return 1;
}

static void
check_effect_valid(lua_State *L, efk_ctx *ctx, int handle){
     if (0 > handle || handle >= (int)ctx->effects.size() || ctx->effects[handle].eptr == nullptr) {
        luaL_error(L, "invalid handle: %d", handle);
    }
}

static struct efk_instance *
get_instance(lua_State *L, efk_ctx *ctx, int index) {
	int handle = (int)luaL_checkinteger(L, index);
	check_effect_valid(L, ctx, handle);
	return &ctx->effects[handle];
}

static void
stop_all(efk_ctx* ctx, struct efk_instance *slot, int delay) {
	if (delay) {
        ctx->manager->SetSpawnDisabled(slot->inst, true);
		for (auto handle : slot->clone) {
			ctx->manager->SetSpawnDisabled(handle, true);
		}
	} else {
		ctx->manager->StopEffect(slot->inst);
		for (auto handle : slot->clone) {
			ctx->manager->StopEffect(handle);
		}
	}
	slot->inst = -1;
	slot->clone.resize(0);
	slot->n = 0;
}

static int
lefkctx_destroy(lua_State *L) {
    auto ctx = EC(L);
	int handle = (int)luaL_checkinteger(L, 2);
	check_effect_valid(L, ctx, handle);
    auto slot = &ctx->effects[handle];
	slot->eptr = nullptr;
	stop_all(ctx, slot, false);
	slot->next = ctx->freelist;
	ctx->freelist = handle;
    return 0;
}

static void ToMatrix43(const Effekseer::Matrix44& src, Effekseer::Matrix43& dst)
{
    for (int m = 0; m < 4; m++) {
        for (int n = 0; n < 3; n++) {
            dst.Value[m][n] = src.Values[m][n];
        }
    }
}

static void
clone_effect(efk_ctx *ctx, struct efk_instance *slot, const Effekseer::Matrix43 &mat) {
	auto handle = ctx->manager->Play(slot->eptr, 0, 0, 0);
	float speed = ctx->manager->GetSpeed(slot->inst);
	ctx->manager->SetSpeed(handle, speed);
	bool paused = ctx->manager->GetPaused(slot->inst);
	ctx->manager->SetPaused(handle, paused);
	slot->clone.emplace_back(handle);
	++slot->n;
}

static int
lefkctx_update_transform(lua_State* L) {
	auto ctx = EC(L);
    auto slot = get_instance(L, ctx, 2);
    if (ctx->manager->Exists(slot->inst)) {
		if (slot->shown) {
			Effekseer::Matrix43 effekMat;
			auto effekMat44 = TOM(L, 3);
			ToMatrix43(*effekMat44, effekMat);
			if (slot->n == 0) {
				ctx->manager->SetMatrix(slot->inst, effekMat);
				ctx->manager->SetShown(slot->inst, true);
				slot->n = 1;
			} else {
				int idx = slot->n - 1;
				if (idx < (int)slot->clone.size()) {
					ctx->manager->SetMatrix(slot->clone[idx], effekMat);
					ctx->manager->SetShown(slot->clone[idx], true);
					++slot->n;
				} else {
					clone_effect(ctx, slot, effekMat);
				}
			}
		}
    } else {
		stop_all(ctx, slot, false);
	}
	return 0;
}

static int
lefkctx_is_alive(lua_State* L) {
    auto ctx = EC(L);
    auto slot = get_instance(L, ctx, 2);
    lua_pushboolean(L, ctx->manager->Exists(slot->inst));
    return 1;
}

static int
lefkctx_play(lua_State *L) {
    auto ctx = EC(L);
    auto slot = get_instance(L, ctx, 2);
    if (ctx->manager->Exists(slot->inst)) {
		stop_all(ctx, slot, false);
	}
	slot->inst = ctx->manager->Play(slot->eptr, 0, 0, 0);
	
	float speed = (float)luaL_checknumber(L, 3);
	ctx->manager->SetSpeed(slot->inst, speed);

    return 0;
}

static int
lefkctx_stop(lua_State *L){
    auto ctx = EC(L);
    auto slot = get_instance(L, ctx, 2);
    bool delay = false;
	if (lua_type(L, 3) == LUA_TBOOLEAN) {
        delay = lua_toboolean(L, 3);
	}
	stop_all(ctx, slot, delay);
    return 0;
}

static int
lefkctx_set_visible(lua_State* L) {
	auto ctx = EC(L);
    auto slot = get_instance(L, ctx, 2);
	bool visible = true;
	if (lua_type(L, 3) == LUA_TBOOLEAN) {
		visible = lua_toboolean(L, 3);
	}
	slot->shown = visible;
	return 0;
}

static int
lefkctx_pause(lua_State* L) {
	auto ctx = EC(L);
    auto slot = get_instance(L, ctx, 2);

	bool pause = false;
	if (lua_type(L, 3) == LUA_TBOOLEAN) {
        pause = lua_toboolean(L, 3);
	}
	ctx->manager->SetPaused(slot->inst, pause);
	for (auto handle : slot->clone) {
		ctx->manager->SetPaused(handle, pause);
	}
	return 0;
}

static int
lefkctx_set_time(lua_State* L) {
	auto ctx = EC(L);
    auto slot = get_instance(L, ctx, 2);

	float frame = 0.0f;
	if (lua_type(L, 3) == LUA_TNUMBER) {
		frame = (float)lua_tonumber(L, 3);
        if (frame < 0.0f) {
            frame = 0.0f;
        }
	}

	auto play_handle = slot->inst;
    ctx->manager->SetPaused(play_handle, false);
    ctx->manager->UpdateHandleToMoveToFrame(slot->inst, frame);
    ctx->manager->SetPaused(play_handle, true);

	for (auto handle : slot->clone) {
		ctx->manager->SetPaused(handle, false);
	    ctx->manager->UpdateHandleToMoveToFrame(handle, frame);
		ctx->manager->SetPaused(handle, true);
	}

	return 0;
}

static int
lefkctx_set_speed(lua_State* L) {
	auto ctx = EC(L);
    auto slot = get_instance(L, ctx, 2);

    float speed = (float)lua_tonumber(L, 3);

	ctx->manager->SetSpeed(slot->inst, speed);
	for (auto handle : slot->clone) {
		ctx->manager->SetSpeed(handle, speed);
	}
	return 0;
}

static bgfx_texture_handle_t
texture_handle(int id, void *) {
    return texture_get(id);
}

static int
lefk_startup(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);

    EffekseerRendererBGFX::InitArgs efkArgs;
    efkArgs.invz = true;    //we use inverse z
    auto get_field = [L](const char* name, int idx, int luatype, auto op){
        auto ltype = lua_getfield(L, idx, name);
        if (luatype == ltype){
            op();
        } else {
            luaL_error(L, "invalid field:%s, miss match type:%s, %s", lua_typename(L, ltype), lua_typename(L, luatype));
        }

        lua_pop(L, 1);
    };
    
    get_field("max_count",  1, LUA_TNUMBER, [&](){efkArgs.squareMaxCount = (int)lua_tointeger(L, -1);});
    get_field("viewid",     1, LUA_TNUMBER, [&](){efkArgs.viewid = (bgfx_view_id_t)lua_tointeger(L, -1);});

    efkArgs.bgfx = bgfx_inf_;
    efkArgs.texture_handle = texture_handle;

    get_field("shader_load",    1, LUA_TLIGHTUSERDATA, [&](){efkArgs.shader_load = (decltype(efkArgs.shader_load))lua_touserdata(L, -1);});
    get_field("texture_load",   1, LUA_TLIGHTUSERDATA, [&](){efkArgs.texture_load = (decltype(efkArgs.texture_load))lua_touserdata(L, -1);});
    get_field("texture_get",    1, LUA_TLIGHTUSERDATA, [&](){efkArgs.texture_get = (decltype(efkArgs.texture_get))lua_touserdata(L, -1);});
    get_field("texture_unload", 1, LUA_TLIGHTUSERDATA, [&](){efkArgs.texture_unload = (decltype(efkArgs.texture_unload))lua_touserdata(L, -1);});
    struct file_interface *fi = nullptr;
    get_field("userdata", 1, LUA_TTABLE, [&](){
        get_field("callback", -1, LUA_TUSERDATA, [&](){efkArgs.ud = lua_touserdata(L, -1);});
        get_field("filefactory", -1, LUA_TUSERDATA, [&](){fi = (struct file_interface*)lua_touserdata(L, -1);});
    });

    auto ctx = (efk_ctx*)lua_newuserdatauv(L, sizeof(efk_ctx), 0);
    new (ctx)efk_ctx();
    if (luaL_newmetatable(L, "EFK_CTX")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_Reg l[] = {
            {"render",          lefkctx_render},
            {"create",          lefkctx_create},
            {"destroy",         lefkctx_destroy},
            {"play",            lefkctx_play},
            {"stop",            lefkctx_stop},
            {"set_visible",     lefkctx_set_visible},
			{"pause",           lefkctx_pause},
		    {"set_time",        lefkctx_set_time},
			{"set_speed",       lefkctx_set_speed},
			{"update_transform", lefkctx_update_transform},
            {"is_alive",        lefkctx_is_alive},
            {nullptr, nullptr},
        };

        luaL_setfuncs(L, l, 0);
    }
    lua_setmetatable(L, -2);

    new (ctx) efk_ctx();

    ctx->fi = fi;

    ctx->renderer = EffekseerRendererBGFX::CreateRenderer(&efkArgs);
    if (ctx->renderer == nullptr){
        return luaL_error(L, "create efkbgfx renderer failed");
    }
	ctx->manager = Effekseer::Manager::Create(efkArgs.squareMaxCount);
	ctx->manager->GetSetting()->SetCoordinateSystem(Effekseer::CoordinateSystem::LH);

    auto efk_fi = Effekseer::MakeRefPtr<EfkFileInterface>(fi);
    ctx->manager->SetModelRenderer(CreateModelRenderer(ctx->renderer, &efkArgs));
    ctx->manager->SetSpriteRenderer(ctx->renderer->CreateSpriteRenderer());
    ctx->manager->SetRibbonRenderer(ctx->renderer->CreateRibbonRenderer());
    ctx->manager->SetRingRenderer(ctx->renderer->CreateRingRenderer());
    ctx->manager->SetTrackRenderer(ctx->renderer->CreateTrackRenderer());
    ctx->manager->SetEffectLoader(Effekseer::MakeRefPtr<Effekseer::DefaultEffectLoader>(efk_fi));
    ctx->manager->SetTextureLoader(ctx->renderer->CreateTextureLoader(efk_fi));
    ctx->manager->SetModelLoader(ctx->renderer->CreateModelLoader(efk_fi));
    ctx->manager->SetMaterialLoader(ctx->renderer->CreateMaterialLoader(efk_fi));
    ctx->manager->SetCurveLoader(Effekseer::MakeRefPtr<Effekseer::CurveLoader>());

    return 1;
}

static int
lefk_shutdown(lua_State *L){
    auto ctx = EC(L);
    ctx->manager.Reset();
    ctx->renderer.Reset();
    ctx->~efk_ctx();
    return 0;
}

extern "C" int
luaopen_efk(lua_State* L) {
    luaL_Reg lib[] = {
        { "startup", lefk_startup},
        { "shutdown",lefk_shutdown},
        { nullptr, nullptr },
    };
    luaL_newlib(L, lib);
    return 1;
}
