#include <lua.hpp>
#include <cassert>
#include <cstring>

#include <bgfx/c99/bgfx.h>

#include "efkbgfx/renderer/bgfxrenderer.h"
#include "../../clibs/bgfx/bgfx_interface.h"

struct efk_ctx {
    EffekseerRenderer::RendererRef renderer;
    Effekseer::ManagerRef manager;

    struct effect {
        Effekseer::EffectRef eff;
        Effekseer::Handle    handle;
    };
    std::vector<effect>   effects;
};

static efk_ctx*
EC(lua_State *L){
    return (efk_ctx*)lua_touserdata(L, 1);
}

static int
lefkctx_render(lua_State *L){
    auto ctx = EC(L);
    auto delta = (float)luaL_checknumber(L, 2);
    ctx->manager->Update(delta);
    ctx->renderer->BeginRendering();
    Effekseer::Manager::DrawParameter drawParameter;
    drawParameter.ZNear = 0.0f;
    drawParameter.ZFar = 1.0f;
    drawParameter.ViewProjectionMatrix = ctx->renderer->GetCameraProjectionMatrix();
    ctx->manager->Draw(drawParameter);
    ctx->renderer->EndRendering();
    return 0;
}

static int
lefkctx_destroy(lua_State *L){
    auto ctx = EC(L);
    ctx->manager.Reset();
    ctx->renderer.Reset();
    return 0;
}

static int
lefkctx_create_effect(lua_State *L){
    auto ctx = EC(L);
    size_t size = 0;
    auto data = luaL_checklstring(L, 2, &size);
    const float mag = (float)luaL_optnumber(L, 3, 1.f);
    auto eff = Effekseer::Effect::Create(ctx->manager, data, (uint32_t)size, mag);
    auto add_eff = [ctx](auto eff){
        auto it = std::find_if(std::begin(ctx->effects), std::end(ctx->effects),
            [](const efk_ctx::effect &e){
                return (e.eff == nullptr);
            }
        );
        it = ctx->effects.emplace(it, efk_ctx::effect{eff, 0});
        return std::distance(it, ctx->effects.begin());
    };

    auto handle = add_eff(eff);
    lua_pushinteger(L, handle);
    return 1;
}

static bool
check_effect_valid(efk_ctx *ctx, int handle){
    return 0 <= handle && handle < ctx->effects.size();
}

static int
lefkctx_destroy_effect(lua_State *L){
    auto ctx = EC(L);
    auto handle = (int)luaL_checkinteger(L, 2);
    if (!check_effect_valid(ctx, handle)){
        return luaL_error(L, "invalid handle: %d", handle);
    }

    auto e = ctx->effects[handle];
    ctx->effects[handle] = {nullptr, INT_MAX};
    e.eff = nullptr;
    return 0;
}

static int
lefkctx_play(lua_State *L){
    auto ctx = EC(L);
    auto handle = (int)luaL_checkinteger(L, 2);
    assert(check_effect_valid(ctx, handle));

    auto effhandle = ctx->manager->Play(ctx->effects[handle].eff, 0, 0, 0);
    lua_pushinteger(L, effhandle);
    return 1;
}

static int
lefkctx_stop(lua_State *L){
    auto ctx = EC(L);
    auto effhandle = (Effekseer::Handle)luaL_checkinteger(L, 2);
    ctx->manager->StopEffect(effhandle);
    return 0;
}


static int
lefk_create(lua_State *L){
    auto count = (int)luaL_checkinteger(L, 1);
    EffekseerRendererBGFX::InitArgs efkArgs {
        count, (bgfx_view_id_t)luaL_checkinteger(L, 2), bgfx_inf_,
    };

    efkArgs.shader_load = (decltype(efkArgs.shader_load))lua_touserdata(L, 3);
    efkArgs.texture_load = (decltype(efkArgs.texture_load))lua_touserdata(L, 4);
    efkArgs.texture_get = (decltype(efkArgs.texture_get))lua_touserdata(L, 5);
    efkArgs.texture_unload = (decltype(efkArgs.texture_unload))lua_touserdata(L, 6);
    efkArgs.ud = lua_touserdata(L, 7);

    auto ctx = (efk_ctx*)lua_newuserdatauv(L, sizeof(efk_ctx), 0);
    if (luaL_newmetatable(L, "EFK_CTX")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_Reg l[] = {
            {"__gc",            lefkctx_destroy},
            {"render",          lefkctx_render},
            {"create_effect",   lefkctx_create_effect},
            {"destroy_effect",  lefkctx_destroy_effect},
            {"play",            lefkctx_play},
            {"stop",            lefkctx_stop},
            {nullptr, nullptr},
        };

        luaL_setfuncs(L, l, 0);
    }
    lua_setmetatable(L, -2);
    

    ctx->renderer = EffekseerRendererBGFX::CreateRenderer(&efkArgs);
	ctx->manager = Effekseer::Manager::Create(count);
	ctx->manager->GetSetting()->SetCoordinateSystem(Effekseer::CoordinateSystem::LH);

    ctx->manager->SetModelRenderer(CreateModelRenderer(ctx->renderer, &efkArgs));
    ctx->manager->SetSpriteRenderer(ctx->renderer->CreateSpriteRenderer());
    ctx->manager->SetRibbonRenderer(ctx->renderer->CreateRibbonRenderer());
    ctx->manager->SetRingRenderer(ctx->renderer->CreateRingRenderer());
    ctx->manager->SetTrackRenderer(ctx->renderer->CreateTrackRenderer());
    ctx->manager->SetTextureLoader(ctx->renderer->CreateTextureLoader());
    ctx->manager->SetModelLoader(ctx->renderer->CreateModelLoader());
    ctx->manager->SetMaterialLoader(ctx->renderer->CreateMaterialLoader());
    ctx->manager->SetCurveLoader(Effekseer::MakeRefPtr<Effekseer::CurveLoader>());

    return 1;
}

extern "C" int
luaopen_efk(lua_State* L) {
    luaL_Reg lib[] = {
        { "create", lefk_create},
        { "render", lefkctx_render},
        { nullptr, nullptr },
    };
    luaL_newlib(L, lib);
    return 1;
}
